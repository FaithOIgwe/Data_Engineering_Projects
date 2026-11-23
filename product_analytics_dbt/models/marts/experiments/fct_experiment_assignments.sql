{#
  Grain: one row per experiment per device (user_pseudo_id, the unit the service buckets on).

  The exposure log has many rows per user (one per page load) and, because of a caching bug,
  some users were logged in BOTH arms. Those users are flagged `is_contaminated` and left out
  of the primary analysis: their outcome can't be credited to either experience. The readout
  also runs a sensitivity check that keeps them in their first-exposed arm.

  Outcomes are measured from first exposure for `experiment_outcome_window_days` (14) days,
  so every user gets the same amount of time to convert.
#}
with exposures as (
    select * from {{ ref('stg_experiments__exposures') }}
),

per_user as (
    select
        experiment_id,
        user_pseudo_id,
        min(exposed_at)                                 as first_exposed_at,
        arg_min(variant, exposed_at)                    as first_variant,
        count(*)                                        as exposure_count,
        count(distinct variant)                         as variants_seen
    from exposures
    group by 1, 2
),

events as (
    select user_pseudo_id, event_name, event_at, transaction_id
    from {{ ref('int_events__stitched') }}
    where event_name in ('add_to_cart', 'begin_checkout', 'purchase')
),

orders as (
    select user_pseudo_id, ordered_at, revenue_usd
    from {{ ref('fct_orders') }}
),

outcomes as (
    select
        p.experiment_id,
        p.user_pseudo_id,
        bool_or(e.event_name = 'add_to_cart')       as added_to_cart,
        bool_or(e.event_name = 'begin_checkout')    as began_checkout
    from per_user as p
    left join events as e
        on e.user_pseudo_id = p.user_pseudo_id
       and e.event_at >= p.first_exposed_at
       and e.event_at < p.first_exposed_at + interval '{{ var("experiment_outcome_window_days") }} days'
    group by 1, 2
),

order_outcomes as (
    select
        p.experiment_id,
        p.user_pseudo_id,
        count(o.ordered_at)                         as orders,
        coalesce(sum(o.revenue_usd), 0)             as revenue_usd
    from per_user as p
    left join orders as o
        on o.user_pseudo_id = p.user_pseudo_id
       and o.ordered_at >= p.first_exposed_at
       and o.ordered_at < p.first_exposed_at + interval '{{ var("experiment_outcome_window_days") }} days'
    group by 1, 2
)

select
    p.experiment_id,
    p.user_pseudo_id,
    p.first_exposed_at,
    p.first_variant,
    p.variants_seen > 1                                         as is_contaminated,
    case when p.variants_seen = 1 then p.first_variant end      as analysis_variant,
    p.exposure_count,
    coalesce(o.added_to_cart, false)                            as added_to_cart,
    coalesce(o.began_checkout, false)                           as began_checkout,
    oo.orders > 0                                               as converted,
    oo.revenue_usd
from per_user as p
left join outcomes as o
    on p.experiment_id = o.experiment_id and p.user_pseudo_id = o.user_pseudo_id
left join order_outcomes as oo
    on p.experiment_id = oo.experiment_id and p.user_pseudo_id = oo.user_pseudo_id
