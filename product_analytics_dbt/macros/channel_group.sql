{#
  Simplified GA4 default channel grouping. The public sample replaces some sources with
  "(data deleted)" and "<Other>"; those get their own bucket instead of being guessed at.
#}
{% macro channel_group(source, medium) -%}
    case
        when {{ source }} is null and {{ medium }} is null                       then 'Direct'
        when {{ source }} = '(data deleted)' or {{ medium }} = '(data deleted)'
          or {{ source }} = '<Other>'                                           then 'Unknown (obfuscated)'
        when {{ source }} = '(direct)' and {{ medium }} in ('(none)', '(not set)') then 'Direct'
        when {{ medium }} = 'organic'                                           then 'Organic Search'
        when {{ medium }} in ('cpc', 'ppc', 'paidsearch')                       then 'Paid Search'
        when {{ medium }} = 'referral'                                          then 'Referral'
        when {{ medium }} in ('email', 'e-mail')                                then 'Email'
        when {{ medium }} in ('social', 'social-network', 'sm')                 then 'Organic Social'
        else 'Other'
    end
{%- endmacro %}
