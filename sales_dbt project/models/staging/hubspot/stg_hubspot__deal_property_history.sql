{#
  One row per real property change. Fivetran re-syncs occasionally land the same change twice
  (same deal, property, value and timestamp, different _fivetran_synced); keep the first copy.
#}
with source as (
    select * from {{ source('hubspot', 'deal_property_history') }}
),

deduped as (
    select
        *,
        row_number() over (
            partition by deal_id, property_name, property_value, change_timestamp
            order by _fivetran_synced
        ) as copy_number
    from source
)

select
    {{ dbt.hash(dbt.concat(["cast(deal_id as varchar)", "'|'", "property_name", "'|'", "cast(change_timestamp as varchar)", "'|'", "coalesce(property_value, '')"])) }} as change_id,
    cast(deal_id as bigint)             as deal_id,
    property_name,
    nullif(property_value, '')          as property_value,
    cast(change_timestamp as timestamp) as changed_at,
    change_source,
    cast(_fivetran_synced as timestamp) as synced_at
from deduped
where copy_number = 1
