{# Events with the stitched person_id attached. #}
select
    e.*,
    coalesce('user:' || e.user_id, m.person_id) as person_id
from {{ ref('stg_ga4__events') }} as e
inner join {{ ref('int_identity_map') }} as m
    on e.user_pseudo_id = m.user_pseudo_id
