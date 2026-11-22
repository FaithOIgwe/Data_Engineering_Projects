{#
  Grain: one row per deal per open pipeline stage it *reached*.

  A deal "reaches" a stage if it was ever in that stage or any later stage. So a deal that
  jumped Qualified -> Proposal still counts as having reached Demo. Without this, skipped
  stages make conversion rates look worse than they are and stage counts stop adding up.
  Closed-won deals have reached every open stage.

  This is the base for stage-to-stage conversion: of deals that reached stage N, how many reached N+1.
#}
with deals as (
    select
        deal_id,
        pipeline_id,
        deal_status,
        deal_type,
        lead_source,
        created_date,
        original_owner_id,
        case when deal_status = 'Won' then 999 else furthest_open_stage_order end as max_order_reached
    from {{ ref('fct_deals') }}
),

open_stages as (
    select pipeline_id, stage_id, stage_label, stage_order
    from {{ ref('dim_deal_stages') }}
    where not is_closed
),

first_entry as (
    select deal_id, stage_id, min(entered_at) as first_entered_at
    from {{ ref('int_deal_stage_history') }}
    group by 1, 2
)

select
    d.deal_id,
    d.pipeline_id,
    s.stage_id,
    s.stage_label,
    s.stage_order,
    d.deal_type,
    d.lead_source,
    d.original_owner_id,
    cast({{ dbt.date_trunc('month', 'd.created_date') }} as date)       as created_cohort_month,
    fe.first_entered_at,
    fe.first_entered_at is null                                         as was_skipped,
    d.max_order_reached > s.stage_order                                 as reached_next_stage,
    d.deal_status = 'Won'                                               as eventually_won,
    d.deal_status
from deals as d
inner join open_stages as s
    on d.pipeline_id = s.pipeline_id
   and s.stage_order <= d.max_order_reached
left join first_entry as fe
    on d.deal_id = fe.deal_id
   and s.stage_id = fe.stage_id
