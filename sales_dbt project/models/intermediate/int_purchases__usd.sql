{#
  Purchases converted to USD at the month-average rate for the purchase month.
  Gross = money captured (succeeded or later refunded). Failed payments carry zero.
#}
select
    p.purchase_id,
    p.product_id,
    p.creator_id,
    p.buyer_id,
    p.payment_status,
    p.currency,
    p.amount_minor,
    p.purchased_at,
    p.refunded_at,
    fx.usd_per_unit,
    case when p.payment_status in ('succeeded', 'refunded')
        then round({{ cents_to_dollars('p.amount_minor', 6) }} * fx.usd_per_unit, 2) else 0 end as gross_amount_usd,
    case when p.payment_status = 'refunded'
        then round({{ cents_to_dollars('p.amount_minor', 6) }} * fx.usd_per_unit, 2) else 0 end as refund_amount_usd
from {{ ref('stg_commerce__purchases') }} as p
left join {{ ref('stg_commerce__fx_rates_monthly') }} as fx
    on fx.currency = p.currency
   and fx.rate_month = cast({{ dbt.date_trunc('month', 'p.purchased_at') }} as date)
