-- Monthly creator net sales must add up to order-level net sales (to the cent).
select
    (select round(sum(net_amount_usd), 2) from {{ ref('fct_commerce_orders') }})            as orders_net,
    (select round(sum(net_sales_usd), 2) from {{ ref('fct_creator_commerce_monthly') }})     as monthly_net
where abs(
    (select sum(net_amount_usd) from {{ ref('fct_commerce_orders') }})
  - (select sum(net_sales_usd) from {{ ref('fct_creator_commerce_monthly') }})
) > 0.01
