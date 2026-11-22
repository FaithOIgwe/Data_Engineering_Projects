{# SCD2-style owner history: who owned the deal, and for which window. #}
with owner_changes as (
    select
        h.deal_id,
        cast(h.property_value as bigint) as owner_id,
        h.changed_at,
        h.change_source,
        lag(h.property_value) over (partition by h.deal_id order by h.changed_at) as previous_value
    from {{ ref('stg_hubspot__deal_property_history') }} as h
    inner join {{ ref('int_deals__active') }} as d
        on h.deal_id = d.deal_id
    where h.property_name = 'hubspot_owner_id'
)

select
    deal_id,
    owner_id,
    changed_at                                                              as valid_from,
    lead(changed_at) over (partition by deal_id order by changed_at)        as valid_to,
    change_source,
    row_number() over (partition by deal_id order by changed_at)            as owner_sequence
from owner_changes
where previous_value is null or cast(previous_value as bigint) != owner_id
