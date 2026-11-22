-- A won deal has, by definition, been through every open stage of its pipeline.
with expected as (
    select pipeline_id, count(*) as open_stage_count
    from {{ ref('dim_deal_stages') }}
    where not is_closed
    group by 1
)

select r.deal_id, count(*) as stages_reached, e.open_stage_count
from {{ ref('fct_stage_reached') }} as r
inner join expected as e on r.pipeline_id = e.pipeline_id
where r.deal_status = 'Won'
group by r.deal_id, e.open_stage_count
having count(*) != e.open_stage_count
