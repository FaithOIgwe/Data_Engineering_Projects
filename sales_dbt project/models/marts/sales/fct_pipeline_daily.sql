{{
    config(
        materialized='incremental',
        unique_key=['snapshot_date', 'deal_id'],
        incremental_strategy='delete+insert',
        on_schema_change='append_new_columns',
        sort='snapshot_date',
        dist='deal_id'
    )
}}
{#
  Grain: one row per open deal per day (end-of-day state).

  Rebuilt from property history, so it can answer "what did pipeline look like on 1 March?"
  even for days before this model existed, unlike a nightly snapshot of the deals table.

  Incremental: each run reprocesses the last `lookback_days` days to pick up late-arriving
  syncs, and appends new days.
#}
{% set lookback_days = 3 %}

with days as (
    {{ date_spine("'2024-01-01'", as_of_date()) }}
),

filtered_days as (
    select date_day as snapshot_date
    from days
    {% if is_incremental() %}
    where date_day > (select {{ dbt.dateadd('day', -lookback_days, 'max(snapshot_date)') }} from {{ this }})
    {% endif %}
),

stage_windows as (
    select * from {{ ref('int_deal_stage_history') }}
),

amounts as (
    select * from {{ ref('int_deal_property_snapshots') }} where property_name = 'amount'
),

close_dates as (
    select * from {{ ref('int_deal_property_snapshots') }} where property_name = 'closedate'
),

-- end-of-day cutoff = start of the next day
deal_days as (
    select
        fd.snapshot_date,
        sw.deal_id,
        sw.pipeline_id,
        sw.stage_id,
        sw.stage_label,
        sw.stage_order,
        sw.entered_at as stage_entered_at
    from filtered_days as fd
    inner join stage_windows as sw
        on sw.entered_at < {{ dbt.dateadd('day', 1, 'fd.snapshot_date') }}
       and (sw.exited_at is null or sw.exited_at >= {{ dbt.dateadd('day', 1, 'fd.snapshot_date') }})
    where not sw.is_closed
)

select
    dd.snapshot_date,
    dd.deal_id,
    dd.pipeline_id,
    dd.stage_id,
    dd.stage_label,
    dd.stage_order,
    oh.owner_id,
    a.amount_value                                              as amount_usd,
    a.amount_value * st.default_probability                     as weighted_amount_usd,
    cd.close_date_value                                         as expected_close_date,
    {{ dbt.datediff('dd.stage_entered_at', 'dd.snapshot_date', 'day') }} as days_in_stage
from deal_days as dd
inner join {{ ref('dim_deal_stages') }} as st
    on dd.stage_id = st.stage_id
left join {{ ref('int_deal_owner_history') }} as oh
    on dd.deal_id = oh.deal_id
   and oh.valid_from < {{ dbt.dateadd('day', 1, 'dd.snapshot_date') }}
   and (oh.valid_to is null or oh.valid_to >= {{ dbt.dateadd('day', 1, 'dd.snapshot_date') }})
left join amounts as a
    on dd.deal_id = a.deal_id
   and a.valid_from < {{ dbt.dateadd('day', 1, 'dd.snapshot_date') }}
   and (a.valid_to is null or a.valid_to >= {{ dbt.dateadd('day', 1, 'dd.snapshot_date') }})
left join close_dates as cd
    on dd.deal_id = cd.deal_id
   and cd.valid_from < {{ dbt.dateadd('day', 1, 'dd.snapshot_date') }}
   and (cd.valid_to is null or cd.valid_to >= {{ dbt.dateadd('day', 1, 'dd.snapshot_date') }})
