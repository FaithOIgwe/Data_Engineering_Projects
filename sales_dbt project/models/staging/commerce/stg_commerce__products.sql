select
    product_id,
    creator_id,
    product_type,
    product_name,
    price_cents,
    cast(created_at as timestamp)   as created_at,
    coalesce(is_archived, false)    as is_archived
from {{ source('commerce', 'products') }}
