with won as (
    select
        company_id,
        min(case when deal_type = 'New business' then close_date end)   as first_won_close_date,
        count(*)                                                        as won_deal_count,
        sum(amount_usd)                                                 as lifetime_won_amount_usd
    from {{ ref('fct_deals') }}
    where deal_status = 'Won'
    group by 1
),

open_deals as (
    select company_id, count(*) as open_deal_count
    from {{ ref('fct_deals') }}
    where deal_status = 'Open'
    group by 1
)

select
    c.company_id,
    c.company_name,
    c.company_domain,
    c.creator_category,
    c.audience_size_band,
    c.country_code,
    c.creator_id,
    c.created_at,
    won.first_won_close_date,
    won.first_won_close_date is not null           as is_customer,
    coalesce(won.won_deal_count, 0)                 as won_deal_count,
    coalesce(won.lifetime_won_amount_usd, 0)        as lifetime_won_amount_usd,
    coalesce(open_deals.open_deal_count, 0)         as open_deal_count
from {{ ref('stg_hubspot__companies') }} as c
left join won on c.company_id = won.company_id
left join open_deals on c.company_id = open_deals.company_id
