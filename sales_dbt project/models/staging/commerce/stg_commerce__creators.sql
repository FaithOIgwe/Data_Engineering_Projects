select
    creator_id,
    cast(signed_up_at as timestamp)     as signed_up_at,
    acquisition_channel,
    plan,
    cast(hubspot_company_id as bigint)  as hubspot_company_id,
    country                             as country_code
from {{ source('commerce', 'creators') }}
