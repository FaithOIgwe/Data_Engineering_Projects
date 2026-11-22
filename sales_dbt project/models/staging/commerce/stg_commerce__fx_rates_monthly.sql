select
    cast(rate_month as date)                        as rate_month,
    upper(currency)                                 as currency,
    cast(usd_per_unit as {{ dbt.type_numeric() }})  as usd_per_unit
from {{ source('commerce', 'fx_rates_monthly') }}
