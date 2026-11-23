{#
  Grain: one row per week per feature.
  Adoption = share of that week's active users (engaged session) who used the feature.
  Features are mapped from GA4 events in one place below, so adding one is a one-line change.
#}
with features as (
    select * from (values
        ('site_search',        'view_search_results', 'Searched the store'),
        ('product_lists',      'select_item',         'Clicked a product from a list'),
        ('promotions',         'select_promotion',    'Clicked a promotion'),
        ('checkout',           'begin_checkout',      'Started checkout')
    ) as f(feature, event_name, feature_description)
),

active_users as (
    select cast(date_trunc('week', activity_date) as date) as activity_week, person_id
    from {{ ref('fct_user_daily_activity') }}
    where is_active
    group by 1, 2
),

weekly_active as (
    select activity_week, count(*) as active_users from active_users group by 1
),

feature_users as (
    select
        cast(date_trunc('week', e.event_at) as date)   as activity_week,
        f.feature,
        count(distinct e.person_id)                    as feature_users
    from {{ ref('int_events__stitched') }} as e
    inner join features as f on e.event_name = f.event_name
    group by 1, 2
)

select
    w.activity_week,
    f.feature,
    f.feature_description,
    w.active_users,
    coalesce(fu.feature_users, 0)                           as feature_users,
    coalesce(fu.feature_users, 0) * 1.0 / w.active_users    as adoption_rate
from weekly_active as w
cross join features as f
left join feature_users as fu
    on w.activity_week = fu.activity_week and f.feature = fu.feature
