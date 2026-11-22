{#
  Amount and close-date history per deal, as validity windows, so we can answer
  "what was this deal worth / when was it expected to close, on day X?".
#}
with changes as (
    select
        h.deal_id,
        h.property_name,
        h.property_value,
        h.changed_at
    from {{ ref('stg_hubspot__deal_property_history') }} as h
    inner join {{ ref('int_deals__active') }} as d
        on h.deal_id = d.deal_id
    where h.property_name in ('amount', 'closedate')
)

select
    deal_id,
    property_name,
    property_value,
    case when property_name = 'amount' then cast(property_value as {{ dbt.type_numeric() }}) end as amount_value,
    case when property_name = 'closedate' then cast(property_value as date) end as close_date_value,
    changed_at                                                                          as valid_from,
    lead(changed_at) over (partition by deal_id, property_name order by changed_at)     as valid_to,
    row_number() over (partition by deal_id, property_name order by changed_at)         as change_number
from changes
