{#
  Grain: one row per person per day they had any session.
  "Active" in this project means had an *engaged* session (docs/metric_definitions.md).
  DAU / WAU / MAU are count-distinct of person_id where is_active, over the period.
#}
select
    md5(person_id || '|' || cast(session_date as varchar))     as person_day_key,
    person_id,
    session_date                                                as activity_date,
    count(*)                                                    as sessions,
    count(case when is_engaged then 1 end)                      as engaged_sessions,
    bool_or(is_engaged)                                         as is_active,
    bool_or(purchased)                                          as purchased
from {{ ref('fct_sessions') }}
group by person_id, session_date
