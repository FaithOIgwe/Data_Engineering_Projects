-- The last day of the rebuilt daily pipeline must match the deals table's open deals exactly
-- (same deals, same amounts). If this fails, history and current state disagree somewhere.
with snapshot as (
    select deal_id, amount_usd
    from {{ ref('fct_pipeline_daily') }}
    where snapshot_date = {{ as_of_date() }}
),

current_open as (
    select deal_id, amount_usd
    from {{ ref('fct_deals') }}
    where deal_status = 'Open'
)

select coalesce(s.deal_id, c.deal_id) as deal_id, s.amount_usd as snapshot_amount, c.amount_usd as current_amount
from snapshot as s
full outer join current_open as c
    on s.deal_id = c.deal_id
where s.deal_id is null
   or c.deal_id is null
   or coalesce(s.amount_usd, -1) != coalesce(c.amount_usd, -1)
