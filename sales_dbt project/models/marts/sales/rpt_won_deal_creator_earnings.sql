{#
  Grain: one row per won new-business deal.

  Joins Sales to Commerce: after we close a creator, how much do they actually sell through
  the platform? Useful for judging which segments and lead sources produce creators who earn,
  not just creators who sign.
#}
with won as (
    select deal_id, company_id, current_owner_id, lead_source, amount_usd, close_date, closed_at
    from {{ ref('fct_deals') }}
    where deal_status = 'Won' and deal_type = 'New business'
),

companies as (
    select company_id, company_name, creator_category, audience_size_band, creator_id
    from {{ ref('dim_companies') }}
),

orders as (
    select creator_id, purchased_at, net_amount_usd
    from {{ ref('fct_commerce_orders') }}
)

select
    w.deal_id,
    w.company_id,
    c.company_name,
    c.creator_id,
    c.creator_category,
    c.audience_size_band,
    w.lead_source,
    w.current_owner_id,
    w.amount_usd                                                                        as deal_amount_usd,
    w.close_date,
    {{ dbt.datediff('w.closed_at', as_of_date(), 'day') }}                              as days_since_close,
    {{ dbt.datediff('w.closed_at', as_of_date(), 'day') }} >= 90                        as has_90_days_of_data,
    {{ dbt.datediff('w.closed_at', as_of_date(), 'day') }} >= 180                       as has_180_days_of_data,
    min(o.purchased_at)                                                                 as first_sale_at,
    coalesce(sum(case when o.purchased_at < {{ dbt.dateadd('day', 90, 'w.closed_at') }} then o.net_amount_usd end), 0)  as creator_net_sales_first_90d_usd,
    coalesce(sum(case when o.purchased_at < {{ dbt.dateadd('day', 180, 'w.closed_at') }} then o.net_amount_usd end), 0) as creator_net_sales_first_180d_usd,
    coalesce(sum(o.net_amount_usd), 0)                                                  as creator_net_sales_to_date_usd
from won as w
left join companies as c
    on w.company_id = c.company_id
left join orders as o
    on c.creator_id = o.creator_id
   and o.purchased_at >= w.closed_at
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
