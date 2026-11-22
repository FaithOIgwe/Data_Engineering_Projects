{#
  Grain: one row per deal per stage *visit* (a deal that goes Demo -> Proposal -> Demo has two Demo rows).

  Built from property history rather than the deals table, because the deals table only holds
  the current stage. Consecutive duplicate stage values (a rep re-saving the same stage) are
  collapsed so time-in-stage is not split.
#}
with stage_changes as (
    select
        h.deal_id,
        h.property_value as stage_id,
        h.changed_at,
        h.change_source
    from {{ ref('stg_hubspot__deal_property_history') }} as h
    inner join {{ ref('int_deals__active') }} as d
        on h.deal_id = d.deal_id
    where h.property_name = 'dealstage'
),

flag_repeats as (
    select
        *,
        lag(stage_id) over (partition by deal_id order by changed_at) as previous_stage_id
    from stage_changes
),

visits as (
    select deal_id, stage_id, previous_stage_id, changed_at as entered_at, change_source
    from flag_repeats
    where previous_stage_id is null or previous_stage_id != stage_id
),

with_exit as (
    select
        v.*,
        lead(v.entered_at) over (partition by v.deal_id order by v.entered_at) as exited_at,
        lead(v.stage_id) over (partition by v.deal_id order by v.entered_at)   as next_stage_id,
        row_number() over (partition by v.deal_id order by v.entered_at)       as visit_number
    from visits as v
)

select
    w.deal_id,
    w.visit_number,
    w.stage_id,
    s.pipeline_id,
    s.stage_label,
    s.stage_order,
    s.is_closed,
    s.is_won,
    s.is_lost,
    w.previous_stage_id,
    prev.stage_order                                        as previous_stage_order,
    w.next_stage_id,
    w.entered_at,
    w.exited_at,
    w.change_source,
    case
        when w.previous_stage_id is null then 'created'
        when s.is_won then 'won'
        when s.is_lost then 'lost'
        when s.stage_order < prev.stage_order then 'regression'
        when s.stage_order > prev.stage_order + 1 then 'skip'
        else 'advance'
    end                                                     as transition_type,
    case
        when s.is_closed or w.previous_stage_id is null then 0
        else greatest(s.stage_order - prev.stage_order - 1, 0)
    end                                                     as stages_skipped
from with_exit as w
inner join {{ ref('stg_hubspot__deal_pipeline_stages') }} as s
    on w.stage_id = s.stage_id
left join {{ ref('stg_hubspot__deal_pipeline_stages') }} as prev
    on w.previous_stage_id = prev.stage_id
