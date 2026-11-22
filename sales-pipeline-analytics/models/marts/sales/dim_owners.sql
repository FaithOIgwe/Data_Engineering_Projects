select
    owner_id,
    owner_name,
    owner_email,
    sales_team,
    is_active,
    started_on,
    left_on
from {{ ref('stg_hubspot__owners') }}
