{# The "current" timestamp for the dataset. Swap for current_timestamp in production. #}
{% macro as_of_date() -%}
    cast('{{ var("as_of_date") }}' as date)
{%- endmacro %}
