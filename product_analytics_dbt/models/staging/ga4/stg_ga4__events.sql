{# Clean, deduplicated events. Downstream models read this, never the base table's incremental logic. #}
select
    *,
    arrival_delay_hours > 1                         as is_late_arriving,
    cast(event_date as date) != cast(event_at as date) as is_date_mismatch
from {{ ref('base_ga4__events') }}
