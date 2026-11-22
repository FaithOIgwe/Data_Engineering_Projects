{{ config(sort='created_at', dist='deal_id') }}
{#
  Grain: one row per (non-deleted) deal, current state plus lifecycle facts derived from history.

  Date conventions (see docs/metric_definitions.md):
    - close_date      = HubSpot "Close date". What reps, forecasts and board decks use. Can be backdated.
    - closed_at       = when the deal actually entered a closed stage, from stage history. Never edited.
    Win rate and bookings use close_date; sales-cycle length uses closed_at.
#}
with deals as (
    select * from {{ ref('int_deals__active') }}
),

stage_history as (
    select * from {{ ref('int_deal_stage_history') }}
),

stage_rollup as (
    select
        deal_id,
        min(entered_at)                                                     as first_stage_entered_at,
        max(entered_at)                                                     as last_stage_change_at,
        max(case when not is_closed then stage_order end)                   as furthest_open_stage_order,
        min(case when is_closed then entered_at end)                        as closed_at,
        sum(case when transition_type = 'regression' then 1 else 0 end)     as regression_count,
        sum(stages_skipped)                                                 as stages_skipped,
        count(*)                                                            as stage_visit_count
    from stage_history
    group by 1
),

owners as (
    select
        deal_id,
        max(case when owner_sequence = 1 then owner_id end)    as original_owner_id,
        count(*) - 1                                           as owner_change_count
    from {{ ref('int_deal_owner_history') }}
    group by 1
),

properties as (
    select
        deal_id,
        max(case when property_name = 'amount' and change_number = 1 then amount_value end)    as original_amount_usd,
        sum(case when property_name = 'amount' then 1 else 0 end) - 1                         as amount_change_count,
        sum(case when property_name = 'closedate' then 1 else 0 end) - 1                      as close_date_change_count
    from {{ ref('int_deal_property_snapshots') }}
    group by 1
),

stages as (
    select * from {{ ref('dim_deal_stages') }}
),

furthest as (
    select stage_id as furthest_open_stage_id, pipeline_id, stage_order, stage_label as furthest_open_stage_label
    from stages
    where not is_closed
)

select
    d.deal_id,
    d.deal_name,
    d.pipeline_id,
    s.pipeline_label,
    d.company_id,
    d.deal_type,
    d.lead_source,

    -- current state
    d.current_stage_id,
    s.stage_label                                                   as current_stage_label,
    s.stage_order                                                   as current_stage_order,
    s.stage_status                                                  as deal_status,
    d.current_owner_id,
    o.original_owner_id,
    coalesce(o.owner_change_count, 0)                               as owner_change_count,
    d.closed_lost_reason,

    -- money
    d.amount_usd,
    p.original_amount_usd,
    coalesce(p.amount_change_count, 0)                              as amount_change_count,
    case when s.stage_status = 'Open'
        then d.amount_usd * s.default_probability end               as weighted_open_amount_usd,
    case when s.stage_status = 'Won' then d.amount_usd end          as won_amount_usd,

    -- dates
    d.created_at,
    cast(d.created_at as date)                                      as created_date,
    d.close_date,
    sr.closed_at,
    cast(sr.closed_at as date)                                      as closed_date_actual,
    coalesce(p.close_date_change_count, 0)                          as close_date_change_count,
    coalesce(s.is_closed and d.close_date < cast(sr.closed_at as date), false)
                                                                    as is_close_date_backdated,
    case when s.is_closed
        then {{ dbt.datediff('d.created_at', 'sr.closed_at', 'day') }} end
                                                                    as sales_cycle_days,
    {{ dbt.datediff('sr.last_stage_change_at', as_of_date(), 'day') }}
                                                                    as days_since_stage_change,
    s.stage_status = 'Open'
        and {{ dbt.datediff('sr.last_stage_change_at', as_of_date(), 'day') }} > {{ var('stale_deal_days') }}
                                                                    as is_stale,
    s.stage_status = 'Open' and d.close_date < {{ as_of_date() }}   as is_past_due,

    -- path through the pipeline
    f.furthest_open_stage_id,
    f.furthest_open_stage_label,
    sr.furthest_open_stage_order,
    coalesce(sr.regression_count, 0)                                as regression_count,
    coalesce(sr.stages_skipped, 0)                                  as stages_skipped,
    sr.stage_visit_count
from deals as d
inner join stages as s
    on d.current_stage_id = s.stage_id
left join stage_rollup as sr
    on d.deal_id = sr.deal_id
left join owners as o
    on d.deal_id = o.deal_id
left join properties as p
    on d.deal_id = p.deal_id
left join furthest as f
    on f.pipeline_id = d.pipeline_id
   and f.stage_order = sr.furthest_open_stage_order
