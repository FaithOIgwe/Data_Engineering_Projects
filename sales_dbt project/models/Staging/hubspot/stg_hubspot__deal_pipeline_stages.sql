select
    pipeline_id,
    pipeline_label,
    stage_id,
    stage_label,
    cast(display_order as integer)                  as stage_order,
    cast(probability as {{ dbt.type_numeric() }})   as default_probability,
    cast(is_closed as boolean)                      as is_closed,
    cast(is_won as boolean)                         as is_won,
    cast(is_closed as boolean) and not cast(is_won as boolean) as is_lost
from {{ source('hubspot', 'deal_pipeline_stages') }}
