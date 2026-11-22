with sales as (
    select
        creator_id,
        min(purchased_at)       as first_sale_at,
        max(purchased_at)       as last_sale_at,
        sum(net_amount_usd)     as lifetime_net_sales_usd,
        count(case when is_successful_payment then purchase_id end) as lifetime_orders
    from {{ ref('fct_commerce_orders') }}
    group by 1
),

products as (
    select creator_id, count(*) as product_count, count(case when not is_archived then 1 end) as live_product_count
    from {{ ref('stg_commerce__products') }}
    group by 1
)

select
    c.creator_id,
    c.signed_up_at,
    cast({{ dbt.date_trunc('month', 'c.signed_up_at') }} as date)  as signup_cohort_month,
    c.acquisition_channel,
    c.acquisition_channel = 'sales_led'                             as is_sales_led,
    c.plan,
    c.country_code,
    c.hubspot_company_id,
    coalesce(p.product_count, 0)                                    as product_count,
    coalesce(p.live_product_count, 0)                               as live_product_count,
    s.first_sale_at,
    s.last_sale_at,
    s.first_sale_at is not null                                     as has_sold,
    {{ dbt.datediff('c.signed_up_at', 's.first_sale_at', 'day') }}  as days_to_first_sale,
    coalesce(s.lifetime_orders, 0)                                  as lifetime_orders,
    coalesce(s.lifetime_net_sales_usd, 0)                           as lifetime_net_sales_usd
from {{ ref('stg_commerce__creators') }} as c
left join sales as s on c.creator_id = s.creator_id
left join products as p on c.creator_id = p.creator_id
