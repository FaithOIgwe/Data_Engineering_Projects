{# Deals that still exist in the CRM. Everything downstream starts here so deleted deals never leak into metrics. #}
select *
from {{ ref('stg_hubspot__deals') }}
where not is_deleted
