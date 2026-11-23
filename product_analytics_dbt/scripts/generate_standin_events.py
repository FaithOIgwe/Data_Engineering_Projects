"""
Stand-in for the real GA4 export.

Writes data/raw/ga4_events.csv.gz with exactly the columns produced by
scripts/export_ga4_sample.sql (the BigQuery query that pulls a 1-in-40 user sample of
Google's public GA4 Merchandise Store dataset). Use it to develop and run CI without a
Google Cloud account. Behaviour and quirks are modelled on the real export:

  - user_id is always null (the public sample has no logged-in users)
  - sessions keyed by ga_session_id, which is the session start time in seconds
  - sessions that cross midnight span two event_date values
  - events that reach Google's servers late (event_server_timestamp_offset of hours/days)
  - exact duplicate events, and purchases re-sent with the same transaction_id
  - "(data deleted)" / "<Other>" traffic sources from Google's obfuscation

Run: python scripts/generate_standin_events.py
"""

import csv
import gzip
import io
import hashlib
import math
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path

random.seed(4040)

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "raw"
START = datetime(2020, 11, 1, tzinfo=timezone.utc)
END = datetime(2021, 2, 1, tzinfo=timezone.utc)
N_USERS = 6800

COLUMNS = [
    "event_date", "event_timestamp", "event_name", "user_pseudo_id", "user_id", "user_first_touch_timestamp",
    "ga_session_id", "ga_session_number", "page_location", "page_title", "page_referrer", "engagement_time_msec",
    "session_engaged", "event_source", "event_medium", "first_user_source", "first_user_medium",
    "device_category", "device_os", "browser", "country", "transaction_id", "purchase_revenue_usd",
    "item_count", "event_bundle_sequence_id", "event_server_timestamp_offset",
]

SOURCES = [(("google", "organic"), 0.33), (("(direct)", "(none)"), 0.24), (("<Other>", "<Other>"), 0.12),
           (("(data deleted)", "(data deleted)"), 0.14), (("google", "cpc"), 0.08),
           (("shop.googlemerchandisestore.com", "referral"), 0.05), (("(data deleted)", "referral"), 0.04)]
DEVICES = [(("desktop", "Windows", "Chrome"), 0.32), (("desktop", "Macintosh", "Chrome"), 0.18),
           (("desktop", "Macintosh", "Safari"), 0.06), (("mobile", "iOS", "Safari"), 0.21),
           (("mobile", "Android", "Chrome"), 0.18), (("tablet", "iOS", "Safari"), 0.03), (("desktop", "Web", "Edge"), 0.02)]
COUNTRIES = [("United States", 0.44), ("India", 0.09), ("Canada", 0.07), ("United Kingdom", 0.04), ("France", 0.03),
             ("Spain", 0.03), ("Taiwan", 0.03), ("China", 0.03), ("Germany", 0.02), ("Japan", 0.02), ("Nigeria", 0.01), ("Other", 0.19)]
PAGES = [("https://shop.googlemerchandisestore.com/", "Home"),
         ("https://shop.googlemerchandisestore.com/Google+Redesign/Apparel", "Apparel | Google Merchandise Store"),
         ("https://shop.googlemerchandisestore.com/Google+Redesign/Lifestyle/Drinkware", "Drinkware | Lifestyle | Google Merchandise Store"),
         ("https://shop.googlemerchandisestore.com/Google+Redesign/Shop+by+Brand/YouTube", "YouTube | Shop by Brand | Google Merchandise Store"),
         ("https://shop.googlemerchandisestore.com/Google+Redesign/Sale", "Sale | Google Merchandise Store"),
         ("https://shop.googlemerchandisestore.com/Google+Redesign/New", "New | Google Merchandise Store"),
         ("https://shop.googlemerchandisestore.com/store.html", "Store search results")]
PDP = ("https://shop.googlemerchandisestore.com/Google+Redesign/Apparel/Google+Dino+Game+Tee", "Google Dino Game Tee")
CART = ("https://shop.googlemerchandisestore.com/basket.html", "Shopping Cart")
CHECKOUT = ("https://shop.googlemerchandisestore.com/payment.html", "Checkout Your Information")
THANKS = ("https://shop.googlemerchandisestore.com/ordercompleted.html", "Checkout Confirmation")


def weighted(options):
    r, acc = random.random(), 0.0
    for value, w in options:
        acc += w
        if r <= acc:
            return value
    return options[-1][0]


def micros(dt):
    return int(dt.timestamp() * 1_000_000)


def holiday_weight(d):
    # Black Friday / December gifting lift, quiet January
    if datetime(2020, 11, 23, tzinfo=timezone.utc) <= d <= datetime(2020, 12, 18, tzinfo=timezone.utc):
        return 1.8
    if d >= datetime(2021, 1, 1, tzinfo=timezone.utc):
        return 0.75
    return 1.0


def random_first_touch():
    while True:
        d = START + (END - START) * random.random()
        if random.random() < holiday_weight(d) / 1.8:
            return d.replace(hour=random.choices(range(24), weights=[2, 1, 1, 1, 1, 2, 3, 4, 5, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 5, 4, 3, 2])[0],
                             minute=random.randint(0, 59), second=random.randint(0, 59))


rows = []
transaction_seq = 10000
users = []

for u in range(N_USERS):
    pseudo = f"{random.randint(1_000_000, 2_147_483_647)}.{random.randint(1_600_000_000, 1_612_000_000)}"
    first = random_first_touch()
    source = weighted(SOURCES)
    device = weighted(DEVICES)
    country = weighted(COUNTRIES)
    # latent intent drives depth, return visits and buying
    intent = random.betavariate(1.2, 6)
    users.append((pseudo, first, intent))

    session_start = first
    session_number = 0
    while session_start < END:
        session_number += 1
        sid = int(session_start.timestamp())
        sess_source = source if session_number == 1 else weighted(SOURCES[:3] + [(("(direct)", "(none)"), 0.5)])
        t = session_start
        bundle = random.randint(1_000_000, 9_999_999)
        sess_rows = []

        def add(name, page=None, referrer=None, engagement=None, extra=None):
            global transaction_seq
            nonlocal_t = t
            r = {
                "event_name": name, "ts": nonlocal_t, "ga_session_id": sid, "ga_session_number": session_number,
                "page_location": page[0] if page else None, "page_title": page[1] if page else None,
                "page_referrer": referrer, "engagement_time_msec": engagement,
                "event_source": sess_source[0] if name in ("session_start", "page_view") and session_number == 1 else None,
                "event_medium": sess_source[1] if name in ("session_start", "page_view") and session_number == 1 else None,
            }
            if extra:
                r.update(extra)
            sess_rows.append(r)

        landing = random.choice(PAGES[:6])
        if session_number == 1:
            add("first_visit", landing)
        add("session_start", landing)
        add("page_view", landing, referrer="https://www.google.com/" if sess_source[1] == "organic" else None)

        bounced = random.random() < 0.45 * (1 - intent)  # left after the landing page
        depth = 0 if bounced else 1 + int(random.expovariate(1 / (1.5 + 10 * intent)))
        engaged_ms = 0
        carted = False
        for _ in range(depth):
            t += timedelta(seconds=random.randint(5, 90))
            dwell = random.randint(800, 40000)
            engaged_ms += dwell
            r = random.random()
            if r < 0.35:
                add("view_item", PDP, engagement=dwell, extra={"item_count": 1})
                add("page_view", PDP)
            elif r < 0.45:
                add("view_search_results", PAGES[6])
                add("page_view", PAGES[6])
            elif r < 0.55:
                add("view_promotion", PAGES[0], extra={"item_count": 1})
                if random.random() < 0.1:
                    add("select_promotion", PAGES[0], extra={"item_count": 1})
            else:
                p = random.choice(PAGES[1:6])
                add("view_item_list", p, extra={"item_count": random.randint(4, 20)})
                add("page_view", p)
                if random.random() < 0.25:
                    add("select_item", p, extra={"item_count": 1})
            if random.random() < 0.5:
                add("scroll", None, engagement=random.randint(200, 3000))
            if not carted and random.random() < 0.02 + 0.25 * intent:
                carted = True
                t += timedelta(seconds=random.randint(5, 30))
                add("add_to_cart", PDP, extra={"item_count": random.randint(1, 3)})
        if carted and random.random() < 0.45:
            t += timedelta(seconds=random.randint(20, 120))
            add("page_view", CART)
            add("begin_checkout", CART, extra={"item_count": random.randint(1, 3)})
            if random.random() < 0.75:
                t += timedelta(seconds=random.randint(30, 200))
                add("add_shipping_info", CHECKOUT)
                add("add_payment_info", CHECKOUT)
                if random.random() < 0.62:
                    t += timedelta(seconds=random.randint(10, 90))
                    transaction_seq += 1
                    revenue = round(max(4.0, random.lognormvariate(3.9, 0.7)), 2)
                    add("page_view", THANKS)
                    add("purchase", THANKS, extra={"transaction_id": str(transaction_seq), "purchase_revenue_usd": revenue,
                                                   "item_count": random.randint(1, 4)})
        if not bounced:
            t += timedelta(seconds=random.randint(1, 20))
            add("user_engagement", None, engagement=engaged_ms)
        engaged = (t - session_start).total_seconds() > 10 or sum(1 for r in sess_rows if r["event_name"] == "page_view") >= 2

        for r in sess_rows:
            if r["ts"] >= END:
                continue
            offset = random.randint(50_000, 1_500_000)
            if random.random() < 0.012:  # sent from a device that was offline / batched: hours to ~3 days late
                offset = random.randint(3600, 70 * 3600) * 1_000_000
            out = {
                "event_date": r["ts"].strftime("%Y%m%d"),
                "event_timestamp": micros(r["ts"]),
                "event_name": r["event_name"],
                "user_pseudo_id": pseudo,
                "user_id": "",
                "user_first_touch_timestamp": micros(first),
                "ga_session_id": r["ga_session_id"],
                "ga_session_number": r["ga_session_number"],
                "page_location": r.get("page_location") or "",
                "page_title": r.get("page_title") or "",
                "page_referrer": r.get("page_referrer") or "",
                "engagement_time_msec": r.get("engagement_time_msec") or "",
                "session_engaged": "1" if engaged else "0",
                "event_source": r.get("event_source") or "",
                "event_medium": r.get("event_medium") or "",
                "first_user_source": source[0],
                "first_user_medium": source[1],
                "device_category": device[0],
                "device_os": device[1],
                "browser": device[2],
                "country": country,
                "transaction_id": r.get("transaction_id", ""),
                "purchase_revenue_usd": r.get("purchase_revenue_usd", ""),
                "item_count": r.get("item_count", ""),
                "event_bundle_sequence_id": bundle,
                "event_server_timestamp_offset": offset,
            }
            rows.append(out)
            if random.random() < 0.004:  # exact duplicate delivered twice
                rows.append(dict(out))
            if r["event_name"] == "purchase" and random.random() < 0.06:  # purchase re-sent on a later page load
                dup = dict(out)
                later = r["ts"] + timedelta(minutes=random.randint(1, 600))
                dup["event_timestamp"] = micros(later)
                dup["event_date"] = later.strftime("%Y%m%d")
                rows.append(dup)

        # next session
        if random.random() > 0.18 + 0.6 * intent:
            break
        session_start = t + timedelta(days=random.expovariate(1 / (9 - 6 * intent)), minutes=random.randint(30, 600))

rows.sort(key=lambda r: (r["event_date"], r["event_timestamp"]))
OUT.mkdir(parents=True, exist_ok=True)
with open(OUT / "ga4_events.csv.gz", "wb") as raw_file, gzip.GzipFile(fileobj=raw_file, mode="wb", mtime=0, filename="") as gz, io.TextIOWrapper(gz, newline="") as f:  # mtime=0 keeps the file byte-identical across runs
    w = csv.DictWriter(f, fieldnames=COLUMNS, lineterminator="\n")
    w.writeheader()
    w.writerows(rows)
print(f"ga4_events.csv.gz: {len(rows):,} events, {N_USERS:,} users")
