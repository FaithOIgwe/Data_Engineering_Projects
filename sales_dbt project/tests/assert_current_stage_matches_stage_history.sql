-- The deals table's current stage must equal the last stage in property history.
with last_visit as (
    select deal_id, stage_id
    from {{ ref('int_deal_stage_history') }}
    where exited_at is null
)

select d.deal_id, d.current_stage_id, l.stage_id as history_stage_id
from {{ ref('int_deals__active') }} as d
left join last_visit as l
    on d.deal_id = l.deal_id
where l.stage_id is null or l.stage_id != d.current_stage_id
