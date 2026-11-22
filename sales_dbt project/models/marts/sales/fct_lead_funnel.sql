{#
  Grain: one row per contact that became a lead. The sales-led funnel:
  Lead -> MQL -> SQL -> Opportunity -> Customer, using HubSpot lifecycle-stage dates.

  A contact can skip lifecycle stages in HubSpot (e.g. set straight to SQL). As with deal
  stages, reaching a later stage counts as reaching the earlier ones.
#}
with contacts as (
    select * from {{ ref('stg_hubspot__contacts') }}
    where became_lead_at is not null
)

select
    contact_id,
    company_id,
    lead_source,
    became_lead_at,
    cast({{ dbt.date_trunc('month', 'became_lead_at') }} as date)              as lead_cohort_month,
    coalesce(became_mql_at, became_sql_at, became_opportunity_at, became_customer_at) is not null as reached_mql,
    coalesce(became_sql_at, became_opportunity_at, became_customer_at) is not null                as reached_sql,
    coalesce(became_opportunity_at, became_customer_at) is not null                               as reached_opportunity,
    became_customer_at is not null                                                                as reached_customer,
    became_mql_at,
    became_sql_at,
    became_opportunity_at,
    became_customer_at,
    {{ dbt.datediff('became_lead_at', 'became_mql_at', 'day') }}               as days_lead_to_mql,
    {{ dbt.datediff('became_lead_at', 'became_opportunity_at', 'day') }}       as days_lead_to_opportunity,
    {{ dbt.datediff('became_lead_at', 'became_customer_at', 'day') }}          as days_lead_to_customer
from contacts
