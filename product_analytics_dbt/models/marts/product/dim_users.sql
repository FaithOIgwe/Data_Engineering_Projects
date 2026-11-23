{#
  Grain: one row per person (stitched across devices when they log in).

  Activation = added a product to cart within `activation_window_days` (7) of first visit.
  Why add-to-cart and not purchase: see docs/metric_definitions.md. Users first seen less
  than 7 days before the end of the data can't have finished their window yet, so
  `is_activation_window_complete` is false and they're left out of activation rates.
#}
with sessions as (
    select * from {{ ref('fct_sessions') }}
),

data_end as (
    select max(session_start_at) as data_end_at from sessions
),

firsts as (
    select
        person_id,
        min(session_start_at)                                           as first_seen_at,
        arg_min(session_channel, session_start_at)                      as first_channel,
        arg_min(device_category, session_start_at)                      as first_device_category,
        arg_min(country, session_start_at)                              as country,
        count(*)                                                        as sessions,
        count(case when is_engaged then 1 end)                          as engaged_sessions,
        count(distinct user_pseudo_id)                                  as devices
    from sessions
    group by 1
),

events as (
    select
        e.person_id,
        min(case when e.event_name = 'add_to_cart' then e.event_at end)    as first_add_to_cart_at,
        min(case when e.event_name = 'purchase' then e.event_at end)       as first_purchase_event_at
    from {{ ref('int_events__stitched') }} as e
    group by 1
),

orders as (
    select person_id, count(*) as orders, sum(revenue_usd) as revenue_usd, min(ordered_at) as first_order_at
    from {{ ref('fct_orders') }}
    group by 1
)

select
    f.person_id,
    f.first_seen_at,
    cast(f.first_seen_at as date)                                                       as first_seen_date,
    cast(date_trunc('week', f.first_seen_at) as date)                                   as cohort_week,
    f.first_channel,
    f.first_device_category,
    f.country,
    f.devices,
    f.sessions,
    f.engaged_sessions,
    e.first_add_to_cart_at,
    f.first_seen_at + interval '{{ var("activation_window_days") }} days' <= de.data_end_at
                                                                                        as is_activation_window_complete,
    coalesce(e.first_add_to_cart_at < f.first_seen_at + interval '{{ var("activation_window_days") }} days', false)
                                                                                        as is_activated,
    o.first_order_at,
    coalesce(o.first_order_at < f.first_seen_at + interval '30 days', false)            as purchased_within_30d,
    f.first_seen_at + interval '30 days' <= de.data_end_at                              as is_30d_window_complete,
    coalesce(o.orders, 0)                                                               as orders,
    coalesce(o.revenue_usd, 0)                                                          as revenue_usd
from firsts as f
cross join data_end as de
left join events as e on f.person_id = e.person_id
left join orders as o on f.person_id = o.person_id
