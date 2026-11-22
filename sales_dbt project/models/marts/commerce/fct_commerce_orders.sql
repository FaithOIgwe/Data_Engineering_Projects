{{ config(sort='purchased_at', dist='creator_id') }}
{#
  Grain: one row per purchase attempt (test purchases already removed in staging).
  Amounts in USD. net = gross - refund. Failed payments are kept (for payment-failure rates)
  but carry zero revenue.
#}
select
    p.purchase_id,
    p.creator_id,
    p.product_id,
    pr.product_type,
    p.buyer_id,
    c.acquisition_channel,
    p.payment_status,
    p.payment_status in ('succeeded', 'refunded')   as is_successful_payment,
    p.payment_status = 'refunded'                   as is_refunded,
    p.purchased_at,
    cast(p.purchased_at as date)                    as purchase_date,
    p.refunded_at,
    p.currency,
    p.amount_minor,
    p.usd_per_unit,
    p.gross_amount_usd,
    p.refund_amount_usd,
    p.gross_amount_usd - p.refund_amount_usd        as net_amount_usd
from {{ ref('int_purchases__usd') }} as p
left join {{ ref('stg_commerce__products') }} as pr
    on p.product_id = pr.product_id
left join {{ ref('stg_commerce__creators') }} as c
    on p.creator_id = c.creator_id
