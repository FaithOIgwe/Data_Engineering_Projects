{# Rows where the expression is false fail. Use the test's `where` config to scope it. #}
{% test expression_is_true(model, expression, column_name=none) %}
    select * from {{ model }}
    where not ({{ expression }})
{% endtest %}
