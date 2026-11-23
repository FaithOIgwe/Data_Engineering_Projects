{#
  Grain: one row per session. The base for traffic, engagement and funnel questions.
  Channel uses the session's own source/medium; a session with none (a returning visit with
  no campaign) counts as Direct, which matches GA4's session-scoped reporting.
#}
select
    session_key,
    person_id,
    user_pseudo_id,
    ga_session_number,
    ga_session_number = 1                                           as is_first_session,
    session_start_at,
    session_end_at,
    session_date,
    duration_seconds,
    crosses_midnight,
    events,
    page_views,
    engagement_seconds,
    is_engaged,
    session_source,
    session_medium,
    {{ channel_group('session_source', 'session_medium') }}        as session_channel,
    landing_page,
    device_category,
    country,
    viewed_item,
    added_to_cart,
    began_checkout,
    purchased,
    used_search,
    has_late_events
from {{ ref('int_sessions') }}
