-- Do some lead sources bring in creators who earn more after we close them?
-- Only deals with a full 90 days since close are compared.
select
    lead_source,
    count(*)                                        as won_deals,
    round(avg(deal_amount_usd))                     as avg_deal_amount_usd,
    round(avg(creator_net_sales_first_90d_usd))     as avg_creator_net_sales_first_90d_usd,
    round(avg(case when first_sale_at is not null then 1.0 else 0 end), 2) as share_with_a_sale
from {{ ref('rpt_won_deal_creator_earnings') }}
where has_90_days_of_data
group by 1
order by 4 desc
