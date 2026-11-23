with days as (
    {{ date_spine("'2020-10-01'", "'2021-03-31'") }}
)
select
    date_day,
    cast(date_trunc('week', date_day) as date)  as week_start,
    cast(date_trunc('month', date_day) as date) as month_start,
    extract(dow from date_day) in (0, 6)        as is_weekend
from days
