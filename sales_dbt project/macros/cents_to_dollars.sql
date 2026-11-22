{% macro cents_to_dollars(column_name, scale=2) -%}
    round(cast({{ column_name }} as {{ dbt.type_numeric() }}) / 100, {{ scale }})
{%- endmacro %}
