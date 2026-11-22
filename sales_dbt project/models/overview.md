{% docs __overview__ %}
# Sales pipeline analytics

dbt project that turns HubSpot CRM data into trusted pipeline, deal and funnel metrics,
and models creator commerce (what creators sell and earn) alongside it.

- **Sales marts:** `fct_deals`, `fct_deal_stage_transitions`, `fct_stage_reached`, `fct_pipeline_daily`, `fct_lead_funnel`
- **Commerce marts:** `fct_commerce_orders`, `fct_creator_commerce_monthly`, `dim_creators`
- **Cross-domain:** `rpt_won_deal_creator_earnings`
- **Semantic layer:** governed metrics in `models/semantic/` (win rate, bookings, open pipeline, creator net sales...)

Metric definitions and the trade-offs behind them: `docs/metric_definitions.md` in the repo.
{% enddocs %}
