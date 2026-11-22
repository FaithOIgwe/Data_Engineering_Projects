select
    stage_id,
    pipeline_id,
    pipeline_label,
    stage_label,
    stage_order,
    default_probability,
    is_closed,
    is_won,
    is_lost,
    case
        when is_won then 'Won'
        when is_lost then 'Lost'
        else 'Open'
    end as stage_status
from {{ ref('stg_hubspot__deal_pipeline_stages') }}
