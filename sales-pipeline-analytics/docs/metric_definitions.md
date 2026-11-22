# Metric definitions and the decisions behind them

Sales numbers get argued about when two people use the same word for different things.
This file writes down each definition, the options I considered, and why I picked one.
The governed versions live in `models/semantic/`; this is the reasoning.

---

## 1. Which date does a closed deal belong to?

HubSpot gives two candidates.

| Option | What it is | For | Against |
|---|---|---|---|
| **HubSpot `close_date`** | The Close date property. HubSpot sets it when a deal is closed, but reps can edit it. | It is what reps, managers and the board already use. Forecasts are built on it. | It can be backdated. In this data 64 closed deals have a close date earlier than the day they actually closed, and 18 of those land in a different month. |
| **`closed_at` from stage history** | The moment the deal entered Closed Won / Closed Lost. | Cannot be edited. Always tells the truth about timing. | Doesn't match what Sales sees in HubSpot, so reconciling a pipeline review becomes a conversation about dates instead of deals. |

**Decision.** Bookings, deals won and win rate use `close_date`, because those are the
numbers Sales runs the business on and they need to match HubSpot. Sales-cycle length uses
`closed_at`, because a backdated close date makes deals look faster than they were.

**Guardrail.** `fct_deals.is_close_date_backdated` flags every deal where the two disagree,
so month-end review can look at them instead of finding out later.

---

## 2. Win rate

`win rate = deals won ÷ (deals won + deals lost)`, by `close_date`, count-based.

- **Open deals are excluded.** Including them pushes win rate down for recent periods, purely because those deals haven't finished yet.
- **Count, not amount, by default.** One large deal can swing an amount-based rate. `win_rate_by_amount` exists for when value matters.
- **Period = when the deal closed, not when it was created.** "Of deals created in March, how many were won?" is a different, cohort question. It is answered by `fct_stage_reached` and is only final once every March deal has closed.
- **New business vs expansion.** Both pipelines are in `fct_deals`. Most questions mean new business, so the golden questions and the dashboard filter `deal_type = 'New business'`. Expansion win rates run much higher and would flatter the number.

---

## 3. Stage conversion and skipped stages

About 12% of deals skip a stage (a hot inbound lead goes straight from Qualified to Proposal).

| Option | Result |
|---|---|
| Count a stage only if the deal was actually in it | Demo looks like it converts *fewer* deals than Proposal receives. Stage counts stop adding up. |
| **Count a stage as reached if the deal was in it or any later stage** | Counts only go down the funnel, conversion rates are comparable stage to stage. |

**Decision.** The second. `fct_stage_reached` has one row per deal per stage reached and a
`was_skipped` flag, so skips are still visible when someone asks about them.

Deals that move backwards (about 8%) count once per stage for conversion (first entry) but
every visit shows up in `fct_deal_stage_transitions`, so time-in-stage is still right.

---

## 4. Open pipeline

`open pipeline = sum of amount on open deals at the end of the period.`

- Built from property history in `fct_pipeline_daily`, so it reflects the amount, stage and owner **as they were** on that day, not as they are now.
- It is semi-additive. Summing it across days is meaningless, so the semantic layer takes the last day of whatever period you ask for.
- **Weighted pipeline** multiplies each deal by its stage's HubSpot default probability. These probabilities are HubSpot's defaults, not our real conversion rates. Replacing them with observed stage-to-won rates from `fct_stage_reached` is an open question for RevOps.

---

## 5. Deal owner

Ownership changes (reassignments, and a rep leaving mid-quarter) make "rep performance" ambiguous.

- `current_owner_id`: who owns it now. Use for "what's on my plate".
- `original_owner_id`: who it started with. Use for sourcing / rep win rates, so a rep isn't credited or blamed for deals they inherited after the work was done.
- `fct_deal_stage_transitions.owner_id_at_entry`: who owned the deal when it entered a stage. Use for stage-level coaching questions.

---

## 6. Creator commerce: gross, refunds, net

- **Gross** = money captured from buyers (succeeded payments, including ones later refunded). Failed payments carry zero.
- **Net** = gross − refunds. "What creators earned" means net.
- **Currency.** Everything is converted to USD at the month-average rate for the purchase month.
- **Which month does a refund hit?**
  - In `fct_commerce_orders` (and the `creator_net_sales_usd` metric) a refund reduces the **purchase** month. Good for product questions: "how much did this launch really make?"
  - In `fct_creator_commerce_monthly` a refund lands in the **refund** month, so closed months stay closed. Good for finance-style monthly reporting.
  - The two agree in total, and `tests/assert_creator_monthly_reconciles_to_orders.sql` checks it to the cent.
- **Test purchases** are dropped in staging so nothing downstream can count them by accident.

---

## Open questions I'd take to Sales and RevOps

1. Should backdated close dates be blocked in HubSpot (a workflow that locks the property after close), or just flagged?
2. Are HubSpot's default stage probabilities still the right weights for forecasting, or should we use observed rates?
3. For rep leaderboards, is credit by original owner the agreed rule?
4. Should a deal that regresses from Proposal back to Demo restart its stage clock, or keep the original entry date?
