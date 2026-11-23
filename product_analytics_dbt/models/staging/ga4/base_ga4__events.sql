{{
    config(
        materialized='incremental',
        unique_key='event_key',
        incremental_strategy='delete+insert',
        on_schema_change='append_new_columns'
    )
}}
{#
  Grain: one row per distinct event.

  Late-arriving data. GA4 keeps accepting events for up to 72 hours (offline devices, batched
  mobile hits), and they land in the table for the day they *happened*. So an incremental
  filter on event time would miss them forever. This model filters on when the event reached
  Google's servers (received_at = client time + server offset), and each run reprocesses the
  last `late_arrival_lookback_days` days of arrivals. delete+insert on event_key keeps reruns
  idempotent.

  `load_cutoff` simulates "what had arrived by then", so CI can prove an incremental build
  in two steps ends up identical to a full refresh.
#}
with source as (
    select
        *,
        make_timestamp(event_timestamp)                                       as event_at,
        make_timestamp(event_timestamp + coalesce(event_server_timestamp_offset, 0)) as received_at
    from {{ source('ga4', 'events') }}
),

filtered as (
    select *
    from source
    where true
    {% if var('load_cutoff') %}
      and received_at <= cast('{{ var("load_cutoff") }}' as timestamp)
    {% endif %}
    {% if is_incremental() %}
      and received_at > (
          select max(received_at) - interval '{{ var("late_arrival_lookback_days") }} days' from {{ this }}
      )
    {% endif %}
),

keyed as (
    select
        md5(concat_ws('|', user_pseudo_id, cast(event_timestamp as varchar), event_name,
                      cast(ga_session_id as varchar), cast(event_bundle_sequence_id as varchar))) as event_key,
        *
    from filtered
),

deduped as (
    -- GA4 occasionally delivers the exact same event twice; keep the first that arrived
    select *
    from keyed
    qualify row_number() over (partition by event_key order by received_at) = 1
)

select
    event_key,
    strptime(event_date, '%Y%m%d')::date                    as event_date,
    event_at,
    received_at,
    extract(epoch from received_at - event_at) / 3600.0     as arrival_delay_hours,
    event_name,
    user_pseudo_id,
    nullif(user_id, '')                                     as user_id,
    make_timestamp(user_first_touch_timestamp)      as user_first_touch_at,
    ga_session_id,
    ga_session_number,
    user_pseudo_id || '-' || cast(ga_session_id as varchar) as session_key,
    nullif(page_location, '')                               as page_location,
    nullif(page_title, '')                                  as page_title,
    nullif(page_referrer, '')                               as page_referrer,
    engagement_time_msec,
    session_engaged = '1'                                   as is_session_engaged_flag,
    nullif(event_source, '')                                as event_source,
    nullif(event_medium, '')                                as event_medium,
    nullif(first_user_source, '')                           as first_user_source,
    nullif(first_user_medium, '')                           as first_user_medium,
    device_category,
    device_os,
    browser,
    country,
    nullif(nullif(transaction_id, ''), '(not set)')         as transaction_id,
    purchase_revenue_usd,
    item_count
from deduped
