{{ config(schema='semantic') }}
-- Daily time spine required by the dbt Semantic Layer (MetricFlow).
select cast(date_day as date) as date_day
from {{ ref('dim_date') }}
