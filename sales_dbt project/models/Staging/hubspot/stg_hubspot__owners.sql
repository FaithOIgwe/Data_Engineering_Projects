select
    cast(owner_id as bigint)                    as owner_id,
    first_name || ' ' || last_name              as owner_name,
    lower(email)                                as owner_email,
    team                                        as sales_team,
    coalesce(is_active, false)                  as is_active,
    cast(created_at as date)                    as started_on,
    cast(archived_at as date)                   as left_on
from {{ source('hubspot', 'owners') }}
