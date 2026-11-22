{#
  Small date spine so the project has no package dependencies (dbt deps needs network).
  Generates one row per day between two dates using a recursive CTE, which works on
  DuckDB, Postgres and Redshift.
#}
{% macro date_spine(start_date, end_date) %}
    with recursive spine(date_day) as (
        select cast({{ start_date }} as date)
        union all
        select cast({{ dbt.dateadd('day', 1, 'date_day') }} as date)
        from spine
        where date_day < cast({{ end_date }} as date)
    )
    select date_day from spine
{% endmacro %}
