select
    cast(company_id as bigint)              as company_id,
    name                                    as company_name,
    lower(domain)                           as company_domain,
    creator_category,
    audience_size_band,
    country                                 as country_code,
    nullif(creator_account_id, '')          as creator_id,
    cast(created_at as timestamp)           as created_at,
    cast(_fivetran_synced as timestamp)     as synced_at
from {{ source('hubspot', 'companies') }}
