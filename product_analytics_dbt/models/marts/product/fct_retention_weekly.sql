{#
  Grain: one row per first-seen cohort week per week number (0 = the week they arrived).

  Retained in week N = had an engaged session in calendar week N after their cohort week.
  This is "bracket" retention (came back *in* that week), not "unbounded" (came back in that
  week or any later one). is_complete is false when week N hasn't fully happened yet for
  this cohort, so a dashboard doesn't show a fake drop at the end. Week 0 is below 100%:
  a user whose only visit bounced was never active, so they count in the cohort but not as retained.
#}
with users as (
    select person_id, cohort_week from {{ ref('dim_users') }}
),

activity as (
    select distinct person_id, cast(date_trunc('week', activity_date) as date) as activity_week
    from {{ ref('fct_user_daily_activity') }}
    where is_active
),

cohort_sizes as (
    select cohort_week, count(*) as cohort_users from users group by 1
),

week_numbers as (
    select range as week_number from range(0, {{ var('retention_weeks') }} + 1)
),

grid as (
    select c.cohort_week, c.cohort_users, w.week_number,
           cast(c.cohort_week + w.week_number * interval '7 days' as date) as calendar_week
    from cohort_sizes as c
    cross join week_numbers as w
),

retained as (
    select
        u.cohort_week,
        cast(datediff('week', u.cohort_week, a.activity_week) as integer) as week_number,
        count(distinct u.person_id) as retained_users
    from users as u
    inner join activity as a on u.person_id = a.person_id
    group by 1, 2
),

last_full_week as (
    select cast(date_trunc('week', max(activity_date)) as date) - 7 as last_complete_week
    from {{ ref('fct_user_daily_activity') }}
)

select
    g.cohort_week,
    g.week_number,
    g.calendar_week,
    g.cohort_users,
    coalesce(r.retained_users, 0)                                   as retained_users,
    coalesce(r.retained_users, 0) * 1.0 / g.cohort_users            as retention_rate,
    g.calendar_week <= l.last_complete_week                         as is_complete
from grid as g
cross join last_full_week as l
left join retained as r
    on g.cohort_week = r.cohort_week and g.week_number = r.week_number
