{#
  Grain: one row per session (user_pseudo_id + ga_session_id).

  Keyed on ga_session_id rather than event_date, so a session that runs past midnight stays
  one session instead of being split across two days.

  Engaged session follows GA4's definition: lasted 10+ seconds, or had 2+ page views, or had
  a conversion (purchase). GA4's own session_engaged flag is also honoured when present.
#}
with events as (
    select * from {{ ref('int_events__stitched') }}
),

rolled as (
    select
        session_key,
        user_pseudo_id,
        any_value(person_id)                                                    as person_id,
        any_value(ga_session_id)                                                as ga_session_id,
        max(ga_session_number)                                                  as ga_session_number,
        min(event_at)                                                           as session_start_at,
        max(event_at)                                                           as session_end_at,
        count(*)                                                                as events,
        count(case when event_name = 'page_view' then 1 end)                    as page_views,
        coalesce(sum(engagement_time_msec), 0) / 1000.0                         as engagement_seconds,
        bool_or(is_session_engaged_flag)                                        as ga4_engaged_flag,
        arg_min(event_source, case when event_source is not null then event_at end) as session_source,
        arg_min(event_medium, case when event_medium is not null then event_at end) as session_medium,
        arg_min(page_location, case when event_name = 'page_view' then event_at end) as landing_page,
        any_value(first_user_source)                                            as first_user_source,
        any_value(first_user_medium)                                            as first_user_medium,
        any_value(device_category)                                              as device_category,
        any_value(country)                                                      as country,
        bool_or(event_name = 'view_item')                                       as viewed_item,
        bool_or(event_name = 'add_to_cart')                                     as added_to_cart,
        bool_or(event_name = 'begin_checkout')                                  as began_checkout,
        bool_or(event_name = 'purchase' and transaction_id is not null)         as purchased,
        bool_or(event_name = 'view_search_results')                             as used_search,
        bool_or(is_late_arriving)                                               as has_late_events
    from events
    group by 1, 2
)

select
    *,
    cast(session_start_at as date)                                              as session_date,
    extract(epoch from session_end_at - session_start_at)                       as duration_seconds,
    cast(session_start_at as date) != cast(session_end_at as date)              as crosses_midnight,
    (
        ga4_engaged_flag
        or extract(epoch from session_end_at - session_start_at) >= 10
        or page_views >= 2
        or purchased
    )                                                                           as is_engaged
from rolled
