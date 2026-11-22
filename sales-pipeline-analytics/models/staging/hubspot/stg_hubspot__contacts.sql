select
    cast(contact_id as bigint)                  as contact_id,
    cast(company_id as bigint)                  as company_id,
    lower(email)                                as email,
    lead_source,
    cast(created_at as timestamp)               as created_at,
    cast(became_lead_at as timestamp)           as became_lead_at,
    cast(became_mql_at as timestamp)            as became_mql_at,
    cast(became_sql_at as timestamp)            as became_sql_at,
    cast(became_opportunity_at as timestamp)    as became_opportunity_at,
    cast(became_customer_at as timestamp)       as became_customer_at
from {{ source('hubspot', 'contacts') }}
