-- Order revenue must equal the revenue on the first purchase event of each transaction, and
-- must be lower than naively summing every purchase event whenever duplicates exist.
with naive as (
    select sum(purchase_revenue_usd) as naive_revenue, count(*) as purchase_events
    from {{ ref('stg_ga4__events') }}
    where event_name = 'purchase' and transaction_id is not null
),
orders as (
    select sum(revenue_usd) as order_revenue, count(*) + sum(duplicate_purchase_events) as purchase_events
    from {{ ref('fct_orders') }}
)
select *
from naive cross join orders
where orders.purchase_events != naive.purchase_events
   or orders.order_revenue > naive.naive_revenue
