{#
  Standard normal CDF, Abramowitz & Stegun 26.2.17 (max error 7.5e-8). Plain arithmetic,
  so it runs on any warehouse without a stats extension.
#}
{% macro normal_cdf(z) -%}
    (case when ({{ z }}) >= 0 then 1 - (
        exp(-({{ z }}) * ({{ z }}) / 2) / sqrt(2 * pi())
        * (0.319381530 * (1 / (1 + 0.2316419 * abs({{ z }})))
         - 0.356563782 * power(1 / (1 + 0.2316419 * abs({{ z }})), 2)
         + 1.781477937 * power(1 / (1 + 0.2316419 * abs({{ z }})), 3)
         - 1.821255978 * power(1 / (1 + 0.2316419 * abs({{ z }})), 4)
         + 1.330274429 * power(1 / (1 + 0.2316419 * abs({{ z }})), 5))
    ) else (
        exp(-({{ z }}) * ({{ z }}) / 2) / sqrt(2 * pi())
        * (0.319381530 * (1 / (1 + 0.2316419 * abs({{ z }})))
         - 0.356563782 * power(1 / (1 + 0.2316419 * abs({{ z }})), 2)
         + 1.781477937 * power(1 / (1 + 0.2316419 * abs({{ z }})), 3)
         - 1.821255978 * power(1 / (1 + 0.2316419 * abs({{ z }})), 4)
         + 1.330274429 * power(1 / (1 + 0.2316419 * abs({{ z }})), 5))
    ) end)
{%- endmacro %}

{# Two-sided p-value for a z statistic. #}
{% macro two_sided_p(z) -%}
    (2 * (1 - {{ normal_cdf('abs(' ~ z ~ ')') }}))
{%- endmacro %}
