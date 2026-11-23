# Metric definitions and the decisions behind them

Product numbers go wrong in quiet ways: a "user" that is really a browser, an "active user" that
only loaded a page, a retention curve that drops at the end because the last week isn't over yet.
This file writes down each definition, the options I weighed, and why I picked one. The governed
versions live in `models/semantic/`.

> Figures quoted here come from the stand-in dataset in `data/raw`, which follows the GA4 export
> schema. Swap in the real export (`scripts/export_ga4_sample.sql`) and rerun to get real numbers.
> The definitions don't change.

---

## 1. What is a "user"?

GA4 gives you `user_pseudo_id`, which is a cookie on one browser on one device. The same person on
their phone and their laptop is two `user_pseudo_id`s, and clearing cookies makes a third.

| Option | For | Against |
|---|---|---|
| Count `user_pseudo_id` | Always available | Overcounts people, undercounts per-person activity |
| **Stitch devices into people using `user_id` when someone logs in** | Closest to a real person; anonymous browsing *before* login gets credited to the person | Only works for people who log in |

**Decision.** `person_id` everywhere. `int_identity_map` gives every device a person: once a device
logs in, all its events (including the anonymous ones before login) belong to that `user_id`, and two
devices with the same `user_id` become one person. Devices that never log in stay their own person.

**Edge case.** A shared device with two logins (a family laptop) goes to the most recent `user_id`
and is flagged `is_shared_device`. Splitting it by time window is possible but not worth it until the
flag shows it matters.

**On the public GA4 sample** there are no logins (`user_id` is always null), so every device is its
own person. The stitching logic is proven by unit tests instead
(`models/intermediate/_intermediate__models.yml`).

---

## 2. What is an "active user"?

| Option | What counts | Problem |
|---|---|---|
| Any event | Anyone who loaded a page | A bot, an accidental click and a bounced ad visit all count |
| Any session | Same, grouped | Same problem, ~36% of sessions here are bounces |
| **Engaged session** | 10+ seconds, or 2+ page views, or a purchase (GA4's definition) | Slightly lower numbers that people need explaining once |
| A key action (e.g. viewed a product) | Clear intent | Too narrow for a "how many people use the site" number |

**Decision.** Active = had at least one **engaged session** in the period. DAU, WAU and MAU are the
same metric (`active_users`) grouped by day, week or month, counted in people not devices.

Why GA4's engaged definition rather than my own: it is what the GA4 UI shows, so the number in the
warehouse matches the number marketing sees, and the argument about which is "right" never starts.

---

## 3. Sessions

- A session is `user_pseudo_id` + `ga_session_id`. GA4 has no session id of its own.
- **Sessions that cross midnight stay one session.** They are keyed on `ga_session_id`, not on
  `event_date`, so a session from 23:59 to 00:01 isn't split into two (10 sessions here).
- **Channel** is the session's own source/medium. A returning visit with no campaign is Direct, which
  matches GA4's session-scoped reports. Google's obfuscation in the public sample replaces some sources
  with `(data deleted)` or `<Other>`; those get their own bucket, "Unknown (obfuscated)", rather than
  being guessed into another channel.

---

## 4. Activation

The activation event should happen early, be reached by a meaningful share of new users, and predict
the outcome the business cares about. Here that outcome is a purchase within 30 days.
`rpt_activation_candidates` scores each candidate on users with a full 30-day window:

| Candidate (within 7 days of first visit) | Share who hit it | 30-day purchase rate if hit | if not | Share of 30-day buyers who hit it |
|---|---|---|---|---|
| **Added to cart** | 16% | 25% | 0.6% | **88%** |
| Used site search | 22% | 11% | 2.6% | 54% |
| Viewed 3+ products | 13% | 16% | 2.8% | 45% |
| 2+ engaged sessions | 8% | 15% | 3.6% | 25% |
| Purchased | 4% | 100% | 0.8% | 83% |

**Decision.** Activation = **added a product to cart within 7 days of first visit**. It catches 88% of
future buyers while still being early and common enough to move. "Purchased" predicts perfectly
because it *is* the outcome; using it would make activation a lagging metric that product teams can't
influence directly.

**Right-censoring.** Someone who arrived 3 days before the data ends hasn't had their 7 days yet.
Counting them as "not activated" would drag the latest numbers down every single week. They are flagged
`is_activation_window_complete = false` and left out of the rate, not counted as failures.

---

## 5. Retention

- **Cohort** = the calendar week a person was first seen.
- **Retained in week N** = had an engaged session in week N (bracket retention).
  The alternative, unbounded retention ("came back in week N *or any later week*"), always looks better
  and hides when people actually return. Bracket is the honest default; unbounded is easy to derive.
- **Incomplete weeks are flagged, not shown as zero.** `is_complete = false` for any week that hasn't
  finished for that cohort, so a curve never shows a fake drop-off at the end.
- **Week 0 is below 100%** because a person whose first visit bounced was never active. That is
  intended: it shows how many new visitors were never really there.

---

## 6. Revenue and orders

GA4 fires `purchase` again when a buyer reloads the order confirmation page, so the same
`transaction_id` appears more than once with a later timestamp. Summing purchase events overstates
revenue (12 repeat purchase events here).

**Decision.** `fct_orders` keeps the first event per transaction and counts the repeats in
`duplicate_purchase_events`, so the tracking bug stays visible instead of silently disappearing.
Purchases with no transaction id or `(not set)` are excluded from revenue.

---

## 7. Late-arriving events

GA4 keeps accepting events for up to 72 hours after they happen (offline phones, batched app hits),
and writes them into the table for the day they *happened*. An incremental model that filters on
event time would never see them.

**Decision.** `base_ga4__events` filters on **arrival time** (`event_timestamp +
event_server_timestamp_offset`) and reprocesses the last 3 days of arrivals every run, with
`delete+insert` on a hashed event key so reruns are idempotent.

**Proof.** `scripts/check_incremental.py` builds the warehouse twice: once as two incremental runs
(everything that had arrived by 20 Jan, then the rest) and once as a single full refresh. Every mart
must match exactly. In the stand-in data, 13 events happened before the cutoff but arrived after it;
those are the events an event-time filter would lose.

Exact duplicate events (same device, timestamp, name, session and bundle) are removed in the same
model: 368 here.

---

## 8. Experiments

The public GA4 data has no experiments, so the project runs an **A/A test** on top of the traffic
(`scripts/simulate_aa_assignment.py`). Both arms see the same thing, so the true effect is zero. That
makes it a test of the experiment pipeline rather than of a feature: if an A/A test comes out
"significant" or unbalanced, the bucketing, exposure logic or statistics are broken.

| Decision | Why |
|---|---|
| **Analysis unit = the bucketing unit** (`user_pseudo_id`) | Analysing at a different unit from the one you randomised on breaks the independence the statistics assume. |
| **Users seen in both arms are excluded** from the primary readout (38 of 1,887 here) | Their outcome can't be credited to either experience. A sensitivity check keeps them in their first-exposed arm, and the conclusion must not change between the two. |
| **Outcome window starts at first exposure, 14 days for everyone** | Someone exposed on the last day must get the same chance to convert as someone exposed on day one. Purchases before exposure don't count. |
| **Sample ratio mismatch check first** | If a planned 50/50 split comes out 52/48 on thousands of users, assignment is broken and no metric should be read. `has_sample_ratio_mismatch` flags p < 0.001. |
| **Two-proportion z-test for rates, Welch's test for revenue per user** | Standard, explainable, and runs in plain SQL. The normal CDF is a macro (`macros/stats.sql`) tested against published values. |

A singular test fails the build if the A/A readout ever shows a significant result or a sample ratio
mismatch on the fixed dataset, because that would mean something in the logic changed.

---

## Open questions I'd take to Product and Growth

1. Is add-to-cart the activation event the team wants to *drive*, or should it be something only the product controls (e.g. creating an account)?
2. Should retention use engaged sessions or a key action like viewing a product? The curves differ.
3. For experiments, is 14 days long enough for higher-priced items with longer consideration?
4. Do we want to block shipping of a test when the sensitivity check (contaminated users included) disagrees with the primary readout, or just flag it?
