select
    experiment_id,
    cast(user_pseudo_id as varchar) as user_pseudo_id,
    lower(variant)                  as variant,
    cast(exposed_at as timestamp)   as exposed_at
from {{ source('experiments', 'exposures') }}
