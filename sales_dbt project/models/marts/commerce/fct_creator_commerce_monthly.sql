{#
  Grain: one row per creator per month in which they had at least one successful sale or refund.

  Refunds land in the month the refund happened (cash view), not the month of the original
  purchase. That keeps closed months closed: a refund in March does not change February's number.
  Net for a month can therefore be negative.
#}
with sales as (
    select
        creator_id,
        cast({{ dbt.date_trunc('month', 'purchased_at') }} as date)    as activity_month,
        count(*)                                                        as orders,
        count(distinct buyer_id)                                        as unique_buyers,
        count(distinct product_id)                                      as products_sold,
        sum(gross_amount_usd)                                           as gross_sales_usd,
        0                                                               as refunds_usd
    from {{ ref('fct_commerce_orders') }}
    where is_successful_payment
    group by 1, 2
),

refunds as (
    select
        creator_id,
        cast({{ dbt.date_trunc('month', 'refunded_at') }} as date)     as activity_month,
        0 as orders, 0 as unique_buyers, 0 as products_sold, 0 as gross_sales_usd,
        sum(refund_amount_usd)                                          as refunds_usd
    from {{ ref('fct_commerce_orders') }}
    where is_refunded
    group by 1, 2
),

combined as (
    select creator_id, activity_month,
        sum(orders) as orders, sum(unique_buyers) as unique_buyers, sum(products_sold) as products_sold,
        sum(gross_sales_usd) as gross_sales_usd, sum(refunds_usd) as refunds_usd
    from (select * from sales union all select * from refunds) as u
    group by 1, 2
)

select
    {{ dbt.hash(dbt.concat(['combined.creator_id', "'|'", 'cast(combined.activity_month as varchar)'])) }} as creator_month_id,
    combined.creator_id,
    combined.activity_month,
    c.acquisition_channel,
    combined.orders,
    combined.unique_buyers,
    combined.products_sold,
    combined.gross_sales_usd,
    combined.refunds_usd,
    combined.gross_sales_usd - combined.refunds_usd                         as net_sales_usd,
    sum(combined.gross_sales_usd - combined.refunds_usd) over (
        partition by combined.creator_id order by combined.activity_month
        rows between unbounded preceding and current row
    )                                                                       as cumulative_net_sales_usd,
    row_number() over (partition by combined.creator_id order by combined.activity_month) = 1
                                                                            as is_first_active_month
from combined
left join {{ ref('stg_commerce__creators') }} as c
    on combined.creator_id = c.creator_id
