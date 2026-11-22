"""
Generates synthetic raw data shaped like a HubSpot export (via Fivetran) and a
creator-commerce payments feed, then writes them as dbt seeds.

The data is deliberately messy in the ways real CRM data is messy:
  - deal stage history with skipped stages and the odd step backwards
  - owners reassigned mid-deal, including a bulk reassignment when a rep leaves
  - close dates that reps backdate, sometimes edited days after the deal closed
  - amounts that are blank at creation and revised at proposal
  - duplicate history rows from connector re-syncs
  - soft-deleted deals, failed / refunded / test purchases, non-USD currencies

Run:  python scripts/generate_data.py      (deterministic; seed fixed below)
"""

import csv
import hashlib
import math
import random
from datetime import datetime, timedelta, date
from pathlib import Path

random.seed(20261122)

ROOT = Path(__file__).resolve().parents[1]
HUBSPOT_DIR = ROOT / "seeds" / "hubspot"
COMMERCE_DIR = ROOT / "seeds" / "commerce"

START = datetime(2024, 1, 1)
AS_OF = datetime(2026, 11, 20, 18, 0, 0)  # "today" for the dataset
SYNC_LAG = timedelta(hours=2)


def ts(d: datetime) -> str:
    return d.strftime("%Y-%m-%d %H:%M:%S")


def rand_time(day: datetime) -> datetime:
    # working hours, US East-ish
    return day.replace(hour=random.randint(13, 22), minute=random.randint(0, 59), second=random.randint(0, 59))


def write_csv(path: Path, header, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"  {path.relative_to(ROOT)}: {len(rows):,} rows")


# --------------------------------------------------------------------------------------
# Reference data
# --------------------------------------------------------------------------------------

OWNERS = [
    # id, first, last, team, active, created, deactivated
    (101, "Dana", "Whitfield", "Sales Leadership", True, "2023-06-01", None),
    (201, "Marcus", "Bell", "New Business", True, "2023-07-10", None),
    (202, "Priya", "Raman", "New Business", False, "2023-07-10", "2025-09-30"),
    (203, "Tomás", "Ortega", "New Business", True, "2023-11-01", None),
    (204, "Grace", "Adeyemi", "New Business", True, "2024-04-15", None),
    (205, "Liam", "Becker", "New Business", True, "2025-02-03", None),
    (206, "Hannah", "Cole", "New Business", True, "2025-10-01", None),
    (301, "Noah", "Fischer", "Account Management", True, "2024-01-08", None),
    (302, "Amara", "Nwosu", "Account Management", True, "2025-05-12", None),
]

SALES_STAGES = [
    # stage_id, label, order, probability, is_closed, is_won
    ("appointmentscheduled", "Discovery", 1, 0.10, False, False),
    ("qualifiedtobuy", "Qualified", 2, 0.20, False, False),
    ("presentationscheduled", "Demo", 3, 0.40, False, False),
    ("decisionmakerboughtin", "Proposal", 4, 0.60, False, False),
    ("contractsent", "Contract Sent", 5, 0.80, False, False),
    ("closedwon", "Closed Won", 6, 1.00, True, True),
    ("closedlost", "Closed Lost", 7, 0.00, True, False),
]
EXPANSION_STAGES = [
    ("exp_identified", "Opportunity Identified", 1, 0.30, False, False),
    ("exp_proposal", "Expansion Proposal", 2, 0.60, False, False),
    ("exp_closedwon", "Expansion Won", 3, 1.00, True, True),
    ("exp_closedlost", "Expansion Lost", 4, 0.00, True, False),
]

CATEGORIES = ["Newsletter writer", "YouTuber", "Podcaster", "Course creator", "Coach", "Author", "Musician", "Visual artist"]
AUDIENCE_BANDS = [("10k-50k", 0.38, 3200), ("50k-250k", 0.34, 9000), ("250k-1M", 0.20, 22000), ("1M+", 0.08, 55000)]
COUNTRIES = [("US", 0.55), ("GB", 0.12), ("CA", 0.08), ("AU", 0.06), ("DE", 0.05), ("NG", 0.04), ("IN", 0.04), ("FR", 0.03), ("BR", 0.03)]
LEAD_SOURCES = [("Inbound demo request", 0.34), ("Self-serve upgrade", 0.20), ("Outbound", 0.22), ("Referral", 0.12), ("Webinar", 0.07), ("Partner", 0.05)]
LOST_REASONS = ["Price", "Went with competitor", "No decision", "Timing", "Missing feature", "Unresponsive"]

WORDS_A = ["North", "Quiet", "Golden", "Little", "Wild", "Paper", "Bright", "Slow", "Honest", "Studio", "Open", "Salt", "Maple", "Iron", "Blue", "Field", "Common", "Kind", "Early", "True"]
WORDS_B = ["Notes", "Kitchen", "Lab", "Letters", "Works", "Collective", "Club", "Press", "Sessions", "Garden", "Academy", "Journal", "House", "Craft", "Radio", "Society", "Supply", "Weekly", "Room", "Daily"]


def weighted(choices):
    r = random.random()
    acc = 0.0
    for value, w in choices:
        acc += w
        if r <= acc:
            return value
    return choices[-1][0]


def growth_date(start: datetime, end: datetime, growth=1.6) -> datetime:
    """Random date between start and end, skewed later so volume grows over time."""
    u = random.random() ** (1 / growth)
    return start + (end - start) * u


def active_owner(team: str, on: datetime) -> int:
    pool = []
    for oid, _, _, t, active, created, deactivated in OWNERS:
        if t != team:
            continue
        if datetime.fromisoformat(created) > on:
            continue
        if deactivated and datetime.fromisoformat(deactivated) < on:
            continue
        pool.append(oid)
    return random.choice(pool)


# --------------------------------------------------------------------------------------
# Companies + contacts (funnel)
# --------------------------------------------------------------------------------------

def build_companies_and_contacts(n_companies=4200):
    companies, contacts, opportunities = [], [], []
    contact_id = 500000
    used_names = set()
    for i in range(n_companies):
        company_id = 9000000 + i
        while True:
            name = f"{random.choice(WORDS_A)} {random.choice(WORDS_B)}"
            if random.random() < 0.35:
                name += f" {random.choice(['Co', 'Media', 'HQ', 'Studio'])}"
            if name not in used_names or random.random() < 0.02:  # a few genuine duplicate names
                used_names.add(name)
                break
        created = rand_time(growth_date(START, AS_OF - timedelta(days=3)))
        band = weighted([(b[0], b[1]) for b in AUDIENCE_BANDS])
        companies.append({
            "company_id": company_id,
            "name": name,
            "domain": name.lower().replace(" ", "") + random.choice([".com", ".co", ".io", ".substack.com"]),
            "creator_category": random.choice(CATEGORIES),
            "audience_size_band": band,
            "country": weighted(COUNTRIES),
            "created_at": created,
        })

        lead_source = weighted(LEAD_SOURCES)
        # primary contact walks the lifecycle funnel
        lead_at = created + timedelta(minutes=random.randint(1, 600))
        mql_at = sql_at = opp_at = None
        p_mql = 0.62 if lead_source in ("Inbound demo request", "Self-serve upgrade", "Referral") else 0.45
        if random.random() < p_mql:
            mql_at = lead_at + timedelta(days=random.expovariate(1 / 4))
            if random.random() < 0.58:
                sql_at = mql_at + timedelta(days=random.expovariate(1 / 6))
                if random.random() < 0.72:
                    opp_at = sql_at + timedelta(days=random.expovariate(1 / 5))
        stamps = [lead_at, mql_at, sql_at, opp_at]
        stamps = [s if s and s < AS_OF else None for s in stamps]
        # if an earlier stage is in the future, later ones must be too
        for k in range(1, 4):
            if stamps[k - 1] is None:
                stamps[k] = None
        lead_at, mql_at, sql_at, opp_at = stamps

        first = random.choice(["alex", "sam", "jo", "chris", "maya", "ade", "lena", "omar", "kim", "ruth", "theo", "ivy"])
        contacts.append({
            "contact_id": contact_id,
            "company_id": company_id,
            "email": f"{first}@{companies[-1]['domain']}",
            "lead_source": lead_source,
            "created_at": lead_at,
            "became_lead_at": lead_at,
            "became_mql_at": mql_at,
            "became_sql_at": sql_at,
            "became_opportunity_at": opp_at,
            "became_customer_at": None,
        })
        primary_contact_idx = len(contacts) - 1
        contact_id += 1

        # a few extra contacts per company that never progress
        for _ in range(random.choice([0, 0, 1, 1, 2])):
            c_created = lead_at + timedelta(days=random.randint(0, 60))
            if c_created >= AS_OF:
                continue
            contacts.append({
                "contact_id": contact_id, "company_id": company_id,
                "email": f"{random.choice(['team', 'hello', 'ops', 'partnerships'])}@{companies[-1]['domain']}",
                "lead_source": lead_source, "created_at": c_created, "became_lead_at": c_created,
                "became_mql_at": None, "became_sql_at": None, "became_opportunity_at": None, "became_customer_at": None,
            })
            contact_id += 1

        if opp_at:
            opportunities.append((companies[-1], primary_contact_idx, opp_at, lead_source, band))
    return companies, contacts, opportunities


# --------------------------------------------------------------------------------------
# Deals + property history
# --------------------------------------------------------------------------------------

DWELL_MEAN = {1: 6, 2: 9, 3: 12, 4: 14, 5: 9}
ADVANCE_P = {1: 0.80, 2: 0.74, 3: 0.68, 4: 0.66, 5: 0.76}


class DealSim:
    def __init__(self):
        self.deals = []
        self.history = []
        self.next_id = 30000000

    def _hist(self, deal_id, prop, value, at, source="CRM_UI"):
        self.history.append([deal_id, prop, "" if value is None else str(value), at, source])

    def _round_amount(self, x):
        return int(round(x / 50.0) * 50)

    def simulate_new_business(self, company, created, lead_source, band):
        deal_id = self.next_id
        self.next_id += 1
        owner = active_owner("New Business", created)
        base = dict((b[0], b[2]) for b in AUDIENCE_BANDS)[band]
        true_amount = self._round_amount(base * math.exp(random.gauss(0, 0.4)))
        amount = None if random.random() < 0.15 else true_amount
        expected_close = (created + timedelta(days=45)).date()

        self._hist(deal_id, "dealstage", "appointmentscheduled" if random.random() > 0.1 else "qualifiedtobuy", created)
        self._hist(deal_id, "hubspot_owner_id", owner, created)
        if amount is not None:
            self._hist(deal_id, "amount", amount, created)
        self._hist(deal_id, "closedate", expected_close, created)

        stage = 1 if self.history[-4 if amount is not None else -3][2] == "appointmentscheduled" else 2
        t = created
        regressed = False
        outcome = None  # 'won' | 'lost' | None (still open)
        lost_reason = None
        updated = created

        handover = datetime(2025, 10, 1, 14, 5, 0)

        def handover_if_needed(now):
            # Priya left on 2025-09-30: her open deals were bulk-reassigned the next morning
            nonlocal owner
            if owner == 202 and now > handover:
                owner = random.choice([201, 203, 204, 205])
                self._hist(deal_id, "hubspot_owner_id", owner, handover, source="IMPORT")

        while True:
            dwell = random.gammavariate(2.0, DWELL_MEAN[stage] / 2.0)
            t_next = t + timedelta(days=dwell)
            if t_next >= AS_OF:
                break
            t = max(rand_time(t_next), t + timedelta(hours=1))
            updated = t
            handover_if_needed(t)

            r = random.random()
            if stage > 1 and not regressed and r < 0.04:
                stage -= 1
                regressed = True
                self._hist(deal_id, "dealstage", SALES_STAGES[stage - 1][0], t)
                continue
            if r < ADVANCE_P[stage]:
                if stage == 5:
                    outcome = "won"
                    break
                jump = 2 if (random.random() < 0.08 and stage <= 3) else 1
                stage += jump
                self._hist(deal_id, "dealstage", SALES_STAGES[stage - 1][0], t)
            else:
                outcome = "lost"
                lost_reason = random.choice(LOST_REASONS)
                break

            # the deal is still open: amount filled in once qualified, revised at proposal
            if amount is None and stage >= 2:
                amount = true_amount
                self._hist(deal_id, "amount", amount, t + timedelta(minutes=3))
            elif stage == 4 and random.random() < 0.4:
                amount = self._round_amount(amount * random.uniform(0.8, 1.2))
                self._hist(deal_id, "amount", amount, t + timedelta(minutes=3))

            # close date slips
            if t.date() > expected_close:
                expected_close = (t + timedelta(days=30)).date()
                self._hist(deal_id, "closedate", expected_close, t + timedelta(minutes=1))

            # mid-deal reassignment
            if random.random() < 0.04:
                new_owner = active_owner("New Business", t)
                if new_owner != owner:
                    owner = new_owner
                    self._hist(deal_id, "hubspot_owner_id", owner, t + timedelta(minutes=5))

        if not outcome:
            handover_if_needed(AS_OF)

        if amount is None and outcome is not None:
            amount = true_amount
            self._hist(deal_id, "amount", amount, t)

        close_date = None
        if outcome:
            final_stage = "closedwon" if outcome == "won" else "closedlost"
            self._hist(deal_id, "dealstage", final_stage, t)
            # HubSpot sets closedate to the moment the deal is closed...
            close_date = t.date()
            # ...but reps sometimes backdate it so the deal lands in the "right" month
            if random.random() < 0.07:
                close_date = (t - timedelta(days=random.randint(2, 20))).date()
                edit_at = t + timedelta(days=random.randint(0, 9), hours=random.randint(1, 8))
                if edit_at < AS_OF:
                    self._hist(deal_id, "closedate", close_date, edit_at)
                    updated = max(updated, edit_at)
                else:
                    close_date = t.date()
                    self._hist(deal_id, "closedate", close_date, t)
            else:
                self._hist(deal_id, "closedate", close_date, t)

        current_stage = {"won": "closedwon", "lost": "closedlost"}.get(outcome, SALES_STAGES[stage - 1][0])
        self.deals.append({
            "deal_id": deal_id,
            "deal_name": f"{company['name']} - New Business",
            "pipeline": "default",
            "deal_stage": current_stage,
            "amount": amount,
            "hubspot_owner_id": owner,
            "associated_company_id": company["company_id"],
            "create_date": created,
            "close_date": close_date if outcome else expected_close,
            "deal_type": "newbusiness",
            "lead_source": lead_source,
            "closed_lost_reason": lost_reason,
            "is_deleted": False,
            "updated_at": updated,
        })
        return outcome, t, true_amount

    def simulate_expansion(self, company, won_at, base_amount):
        created = rand_time(won_at + timedelta(days=random.randint(90, 420)))
        if created >= AS_OF:
            return
        deal_id = self.next_id
        self.next_id += 1
        owner = active_owner("Account Management", created)
        amount = self._round_amount(base_amount * random.uniform(0.2, 0.5))
        expected_close = (created + timedelta(days=30)).date()
        self._hist(deal_id, "dealstage", "exp_identified", created)
        self._hist(deal_id, "hubspot_owner_id", owner, created)
        self._hist(deal_id, "amount", amount, created)
        self._hist(deal_id, "closedate", expected_close, created)

        t = created
        stage = 1
        outcome = None
        while True:
            t_next = t + timedelta(days=random.gammavariate(2.0, 6.0))
            if t_next >= AS_OF:
                break
            t = max(rand_time(t_next), t + timedelta(hours=1))
            if stage == 1:
                if random.random() < 0.75:
                    stage = 2
                    self._hist(deal_id, "dealstage", "exp_proposal", t)
                else:
                    outcome = "lost"
                    break
            else:
                outcome = "won" if random.random() < 0.68 else "lost"
                break
        if outcome:
            self._hist(deal_id, "dealstage", "exp_closedwon" if outcome == "won" else "exp_closedlost", t)
            self._hist(deal_id, "closedate", t.date(), t)
        current = {"won": "exp_closedwon", "lost": "exp_closedlost"}.get(outcome, EXPANSION_STAGES[stage - 1][0])
        self.deals.append({
            "deal_id": deal_id,
            "deal_name": f"{company['name']} - Expansion",
            "pipeline": "expansion",
            "deal_stage": current,
            "amount": amount,
            "hubspot_owner_id": owner,
            "associated_company_id": company["company_id"],
            "create_date": created,
            "close_date": t.date() if outcome else expected_close,
            "deal_type": "existingbusiness",
            "lead_source": "Existing customer",
            "closed_lost_reason": random.choice(LOST_REASONS) if outcome == "lost" else None,
            "is_deleted": False,
            "updated_at": t,
        })


# --------------------------------------------------------------------------------------
# Commerce
# --------------------------------------------------------------------------------------

PRODUCT_TYPES = [("digital_download", 0.34, 1900), ("course", 0.22, 14900), ("paid_newsletter", 0.24, 800),
                 ("coaching", 0.08, 25000), ("membership", 0.12, 1500)]
CURRENCIES = [("USD", 0.86), ("EUR", 0.07), ("GBP", 0.07)]


def month_iter(start: date, end: date):
    d = date(start.year, start.month, 1)
    while d <= end:
        yield d
        d = date(d.year + (d.month // 12), d.month % 12 + 1, 1)


def poisson(lam):
    if lam <= 0:
        return 0
    if lam > 30:
        return max(0, int(round(random.gauss(lam, math.sqrt(lam)))))
    L, k, p = math.exp(-lam), 0, 1.0
    while True:
        p *= random.random()
        if p <= L:
            return k
        k += 1


def build_commerce(won_companies):
    creators, products, purchases = [], [], []
    cid = 100000
    pid = 700000
    buy_id = 1

    def new_creator(signed_up, channel, company_id=None, country=None):
        nonlocal cid
        cid += 1
        creators.append({
            "creator_id": f"cr_{cid}",
            "signed_up_at": signed_up,
            "acquisition_channel": channel,
            "plan": "pro" if channel == "sales_led" else weighted([("newsletter", 0.5), ("creator", 0.38), ("pro", 0.12)]),
            "hubspot_company_id": company_id,
            "country": country or weighted(COUNTRIES),
        })
        return creators[-1]

    for _ in range(3600):
        new_creator(rand_time(growth_date(START, AS_OF - timedelta(days=1), growth=1.8)), "self_serve")
    company_to_creator = {}
    for company, won_at in won_companies:
        c = new_creator(rand_time(won_at + timedelta(days=random.randint(0, 3))), "sales_led", company["company_id"], company["country"])
        company_to_creator[company["company_id"]] = c["creator_id"]

    for c in creators:
        sales_led = c["acquisition_channel"] == "sales_led"
        if c["signed_up_at"] >= AS_OF:
            continue
        if random.random() > (0.9 if sales_led else 0.45):
            continue
        audience = math.exp(random.gauss(1.3 if sales_led else -0.1, 0.8))  # monthly purchases scale
        for _ in range(random.randint(1, 4 if sales_led else 2)):
            pid += 1
            ptype = weighted([(p[0], p[1]) for p in PRODUCT_TYPES])
            base_price = dict((p[0], p[2]) for p in PRODUCT_TYPES)[ptype]
            price = int(round(base_price * random.choice([0.5, 0.75, 1, 1, 1.5, 2]) / 100.0)) * 100 - 1
            created = c["signed_up_at"] + timedelta(days=random.randint(3, 120))
            if created >= AS_OF:
                continue
            archived = random.random() < 0.1
            products.append({
                "product_id": f"prod_{pid}", "creator_id": c["creator_id"], "product_type": ptype,
                "product_name": f"{random.choice(WORDS_A)} {ptype.replace('_', ' ').title()}",
                "price_cents": price, "created_at": created, "is_archived": archived,
            })
            currency = "USD" if c["country"] in ("US", "CA", "NG", "IN", "BR") else ("GBP" if c["country"] == "GB" else ("EUR" if c["country"] in ("DE", "FR") else weighted(CURRENCIES)))
            for m in month_iter(created.date(), AS_OF.date()):
                lam = audience * (0.5 if ptype in ("coaching", "course") else 1.0)
                if archived and random.random() < 0.6:
                    lam *= 0.1
                for _ in range(poisson(lam)):
                    day = random.randint(1, 28)
                    at = rand_time(datetime(m.year, m.month, day))
                    if at < created or at >= AS_OF:
                        continue
                    amount = price if random.random() > 0.12 else int(price * random.choice([0.8, 0.7, 0.5]))
                    status = weighted([("succeeded", 0.93), ("failed", 0.04), ("refunded", 0.03)])
                    refunded_at = at + timedelta(days=random.randint(1, 25)) if status == "refunded" else None
                    if refunded_at and refunded_at >= AS_OF:
                        refunded_at, status = None, "succeeded"
                    buyer = hashlib.md5(f"{c['creator_id']}-{random.randint(1, 4000)}".encode()).hexdigest()[:16]
                    purchases.append({
                        "purchase_id": f"pur_{buy_id:07d}", "product_id": f"prod_{pid}", "creator_id": c["creator_id"],
                        "buyer_id": buyer, "amount": amount, "currency": currency, "status": status,
                        "purchased_at": at, "refunded_at": refunded_at, "is_test": random.random() < 0.004,
                    })
                    buy_id += 1
    return creators, products, purchases, company_to_creator


def build_fx():
    rows = []
    eur, gbp = 1.09, 1.27
    for m in month_iter(START.date(), AS_OF.date()):
        eur = round(eur * math.exp(random.gauss(0, 0.012)), 4)
        gbp = round(gbp * math.exp(random.gauss(0, 0.012)), 4)
        rows.append([m, "EUR", eur])
        rows.append([m, "GBP", gbp])
        rows.append([m, "USD", 1.0])
    return rows


# --------------------------------------------------------------------------------------

def main():
    print("Generating data as of", AS_OF)
    companies, contacts, opportunities = build_companies_and_contacts()
    sim = DealSim()
    won_companies = []
    contact_by_company = {c["company_id"]: c for c in contacts if c["became_lead_at"] == c["created_at"] and c["email"].split("@")[0] not in ("team", "hello", "ops", "partnerships")}

    for company, contact_idx, opp_at, lead_source, band in sorted(opportunities, key=lambda o: o[2]):
        outcome, closed_at, amount = sim.simulate_new_business(company, rand_time(opp_at), lead_source, band)
        if outcome == "won":
            contacts[contact_idx]["became_customer_at"] = closed_at
            won_companies.append((company, closed_at))
            if random.random() < 0.5:
                sim.simulate_expansion(company, closed_at, amount)

    # a handful of deals deleted in the CRM (junk, test or duplicate deals)
    for d in random.sample(sim.deals, k=int(len(sim.deals) * 0.015)):
        d["is_deleted"] = True

    # connector re-syncs produce exact duplicate history rows
    hist_rows = []
    for deal_id, prop, value, at, source in sim.history:
        synced = at + SYNC_LAG + timedelta(minutes=random.randint(0, 50))
        hist_rows.append([deal_id, prop, value, ts(at), source, ts(synced)])
        if random.random() < 0.015:
            hist_rows.append([deal_id, prop, value, ts(at), source, ts(synced + timedelta(days=random.randint(1, 30)))])
    hist_rows.sort(key=lambda r: (r[0], r[3]))

    creators, products, purchases, company_to_creator = build_commerce(won_companies)

    print("Writing seeds")
    write_csv(HUBSPOT_DIR / "owners.csv",
              ["owner_id", "email", "first_name", "last_name", "team", "is_active", "created_at", "archived_at"],
              [[o[0], f"{o[1].lower()}.{o[2].lower()}@example.com".replace("á", "a"), o[1], o[2], o[3], o[4], o[5], o[6] or ""] for o in OWNERS])
    write_csv(HUBSPOT_DIR / "deal_pipeline_stages.csv",
              ["pipeline_id", "pipeline_label", "stage_id", "stage_label", "display_order", "probability", "is_closed", "is_won"],
              [["default", "Sales Pipeline", *s] for s in SALES_STAGES] + [["expansion", "Expansion Pipeline", *s] for s in EXPANSION_STAGES])
    write_csv(HUBSPOT_DIR / "companies.csv",
              ["company_id", "name", "domain", "creator_category", "audience_size_band", "country", "creator_account_id", "created_at", "_fivetran_synced"],
              [[c["company_id"], c["name"], c["domain"], c["creator_category"], c["audience_size_band"], c["country"],
                company_to_creator.get(c["company_id"], ""), ts(c["created_at"]), ts(c["created_at"] + SYNC_LAG)] for c in companies])
    write_csv(HUBSPOT_DIR / "contacts.csv",
              ["contact_id", "company_id", "email", "lead_source", "created_at", "became_lead_at", "became_mql_at",
               "became_sql_at", "became_opportunity_at", "became_customer_at"],
              [[c["contact_id"], c["company_id"], c["email"], c["lead_source"]] +
               [ts(c[k]) if c[k] else "" for k in ("created_at", "became_lead_at", "became_mql_at", "became_sql_at", "became_opportunity_at", "became_customer_at")]
               for c in contacts])
    write_csv(HUBSPOT_DIR / "deals.csv",
              ["deal_id", "deal_name", "pipeline", "deal_stage", "amount", "hubspot_owner_id", "associated_company_id",
               "create_date", "close_date", "deal_type", "lead_source", "closed_lost_reason", "is_deleted", "updated_at", "_fivetran_synced"],
              [[d["deal_id"], d["deal_name"], d["pipeline"], d["deal_stage"], "" if d["amount"] is None else d["amount"],
                d["hubspot_owner_id"], d["associated_company_id"], ts(d["create_date"]), d["close_date"], d["deal_type"],
                d["lead_source"], d["closed_lost_reason"] or "", d["is_deleted"], ts(d["updated_at"]), ts(min(d["updated_at"] + SYNC_LAG, AS_OF))]
               for d in sim.deals])
    write_csv(HUBSPOT_DIR / "deal_property_history.csv",
              ["deal_id", "property_name", "property_value", "change_timestamp", "change_source", "_fivetran_synced"], hist_rows)

    write_csv(COMMERCE_DIR / "creators.csv",
              ["creator_id", "signed_up_at", "acquisition_channel", "plan", "hubspot_company_id", "country"],
              [[c["creator_id"], ts(c["signed_up_at"]), c["acquisition_channel"], c["plan"], c["hubspot_company_id"] or "", c["country"]] for c in creators])
    write_csv(COMMERCE_DIR / "products.csv",
              ["product_id", "creator_id", "product_type", "product_name", "price_cents", "created_at", "is_archived"],
              [[p["product_id"], p["creator_id"], p["product_type"], p["product_name"], p["price_cents"], ts(p["created_at"]), p["is_archived"]] for p in products])
    write_csv(COMMERCE_DIR / "purchases.csv",
              ["purchase_id", "product_id", "creator_id", "buyer_id", "amount", "currency", "status", "purchased_at", "refunded_at", "is_test"],
              [[p["purchase_id"], p["product_id"], p["creator_id"], p["buyer_id"], p["amount"], p["currency"], p["status"],
                ts(p["purchased_at"]), ts(p["refunded_at"]) if p["refunded_at"] else "", p["is_test"]] for p in purchases])
    write_csv(COMMERCE_DIR / "fx_rates_monthly.csv", ["rate_month", "currency", "usd_per_unit"], build_fx())


if __name__ == "__main__":
    main()
