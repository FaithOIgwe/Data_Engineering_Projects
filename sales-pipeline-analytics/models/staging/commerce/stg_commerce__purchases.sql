{# Test-mode purchases are removed here so nothing downstream can count them by accident. #}
select
    purchase_id,
    product_id,
    creator_id,
    buyer_id,
    cast(amount as bigint)              as amount_minor,
    upper(currency)                     as currency,
    status                              as payment_status,
    cast(purchased_at as timestamp)     as purchased_at,
    cast(refunded_at as timestamp)      as refunded_at
from {{ source('commerce', 'purchases') }}
where not coalesce(is_test, false)
