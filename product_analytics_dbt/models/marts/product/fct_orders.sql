{#
  Grain: one row per transaction.

  GA4 fires `purchase` again when a buyer reloads the confirmation page, so the same
  transaction_id shows up more than once with a later timestamp. Summing purchase events
  overstates revenue. Keep the first event per transaction; count the repeats so the
  tracking problem stays visible.
#}
with purchases as (
    select *
    from {{ ref('int_events__stitched') }}
    where event_name = 'purchase'
      and transaction_id is not null
)

select
    transaction_id,
    arg_min(person_id, event_at)                as person_id,
    arg_min(user_pseudo_id, event_at)           as user_pseudo_id,
    arg_min(session_key, event_at)              as session_key,
    min(event_at)                               as ordered_at,
    cast(min(event_at) as date)                 as order_date,
    arg_min(purchase_revenue_usd, event_at)     as revenue_usd,
    arg_min(item_count, event_at)               as item_count,
    count(*) - 1                                as duplicate_purchase_events
from purchases
group by 1
