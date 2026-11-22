{#
  Grain: one row per deal per stage visit. Use for time-in-stage and stage-to-stage flow.
  Owner is the owner at the moment the deal entered the stage, which is what you want for
  rep-level conversion (a deal reassigned after it was lost should not count against the new owner).
#}
{% set stage_end = "coalesce(h.exited_at, cast(" ~ as_of_date() ~ " as timestamp))" %}

select
    h.deal_id,
    h.visit_number,
    h.pipeline_id,
    h.stage_id,
    h.stage_label,
    h.stage_order,
    h.previous_stage_id,
    h.next_stage_id,
    h.transition_type,
    h.stages_skipped,
    h.entered_at,
    h.exited_at,
    h.exited_at is null and not h.is_closed                             as is_current_open_stage,
    case when not h.is_closed then
        round({{ dbt.datediff('h.entered_at', stage_end, 'hour') }} / 24.0, 1)
    end                                                                 as days_in_stage,
    oh.owner_id                                                         as owner_id_at_entry,
    d.deal_type,
    d.lead_source
from {{ ref('int_deal_stage_history') }} as h
inner join {{ ref('int_deals__active') }} as d
    on h.deal_id = d.deal_id
left join {{ ref('int_deal_owner_history') }} as oh
    on h.deal_id = oh.deal_id
   and h.entered_at >= oh.valid_from
   and (h.entered_at < oh.valid_to or oh.valid_to is null)
