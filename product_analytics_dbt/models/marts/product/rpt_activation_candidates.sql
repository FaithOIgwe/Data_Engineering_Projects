{#
  Grain: one row per candidate activation definition.

  How the activation definition was chosen. A good activation event happens early, is reached
  by a meaningful share of new users, and predicts the outcome we care about (a purchase within
  30 days). For each candidate:
    share_activated       how many new users hit it in their first 7 days
    p30_if_activated      30-day purchase rate for those who did
    p30_if_not            ... and for those who didn't
    lift                  ratio of the two
    buyers_captured       share of all 30-day buyers who had hit it within 7 days (recall)
  Only users with a complete 30-day window are included.
#}
with users as (
    select person_id, first_seen_at, purchased_within_30d
    from {{ ref('dim_users') }}
    where is_30d_window_complete
),

first_week as (
    select
        u.person_id,
        count(distinct case when e.event_name = 'view_item' then e.event_key end)          as items_viewed,
        bool_or(e.event_name = 'add_to_cart')                                                as added_to_cart,
        bool_or(e.event_name = 'view_search_results')                                        as searched,
        bool_or(e.event_name = 'purchase')                                                   as purchased_7d
    from users as u
    left join {{ ref('int_events__stitched') }} as e
        on e.person_id = u.person_id
       and e.event_at < u.first_seen_at + interval '{{ var("activation_window_days") }} days'
    group by 1
),

engaged_first_week as (
    select u.person_id, count(*) as engaged_sessions
    from users as u
    inner join {{ ref('fct_sessions') }} as s
        on s.person_id = u.person_id
       and s.is_engaged
       and s.session_start_at < u.first_seen_at + interval '{{ var("activation_window_days") }} days'
    group by 1
),

flags as (
    select
        u.person_id,
        u.purchased_within_30d,
        coalesce(f.added_to_cart, false)                as c_add_to_cart,
        coalesce(f.items_viewed, 0) >= 3                as c_viewed_3_items,
        coalesce(f.searched, false)                     as c_searched,
        coalesce(ef.engaged_sessions, 0) >= 2           as c_2_engaged_sessions,
        coalesce(f.purchased_7d, false)                 as c_purchased
    from users as u
    left join first_week as f on u.person_id = f.person_id
    left join engaged_first_week as ef on u.person_id = ef.person_id
),

long as (
    select 'Added to cart' as candidate, c_add_to_cart as hit, purchased_within_30d from flags
    union all select 'Viewed 3+ products', c_viewed_3_items, purchased_within_30d from flags
    union all select 'Used site search', c_searched, purchased_within_30d from flags
    union all select '2+ engaged sessions', c_2_engaged_sessions, purchased_within_30d from flags
    union all select 'Purchased', c_purchased, purchased_within_30d from flags
)

select
    candidate,
    count(*)                                                                                as users,
    avg(case when hit then 1.0 else 0 end)                                                  as share_activated,
    avg(case when hit then (case when purchased_within_30d then 1.0 else 0 end) end)        as p30_if_activated,
    avg(case when not hit then (case when purchased_within_30d then 1.0 else 0 end) end)    as p30_if_not,
    avg(case when hit then (case when purchased_within_30d then 1.0 else 0 end) end)
      / nullif(avg(case when not hit then (case when purchased_within_30d then 1.0 else 0 end) end), 0) as lift,
    avg(case when purchased_within_30d then (case when hit then 1.0 else 0 end) end)        as buyers_captured
from long
group by 1
