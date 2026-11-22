{#
  Use the custom schema name as-is (staging, sales, commerce...) instead of dbt's default
  <target_schema>_<custom_schema>. In CI / dev on a shared warehouse you'd prefix with the
  developer's schema; locally on DuckDB the clean names read better in the docs site.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- elif target.name in ('dev', 'ci') and target.type == 'duckdb' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
