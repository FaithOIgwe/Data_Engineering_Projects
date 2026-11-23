{#
  Grain: one row per device (user_pseudo_id).

  Identity stitching. A device is anonymous until someone logs in on it (user_id appears).
  Once it does, every event from that device, including the anonymous browsing *before*
  login, belongs to that person. Two devices that log in as the same user_id become one person.

  Shared devices (more than one user_id) are attributed to the most recent user_id and flagged;
  splitting them by time window is possible but rare enough not to be worth the complexity yet.

  The public GA4 sample has no logged-in users, so on that data every device is its own person.
  The logic is covered by unit tests (models/intermediate/_intermediate__unit_tests.yml).
#}
with logins as (
    select
        user_pseudo_id,
        user_id,
        max(event_at) as last_seen_with_user_id
    from {{ ref('stg_ga4__events') }}
    where user_id is not null
    group by 1, 2
),

latest_login as (
    select
        user_pseudo_id,
        user_id,
        count(*) over (partition by user_pseudo_id) as user_ids_on_device
    from logins
    qualify row_number() over (partition by user_pseudo_id order by last_seen_with_user_id desc) = 1
),

devices as (
    select user_pseudo_id, min(event_at) as first_seen_at
    from {{ ref('stg_ga4__events') }}
    group by 1
)

select
    d.user_pseudo_id,
    coalesce('user:' || l.user_id, 'device:' || d.user_pseudo_id)   as person_id,
    l.user_id,
    l.user_id is not null                                           as is_identified,
    coalesce(l.user_ids_on_device, 0) > 1                           as is_shared_device,
    d.first_seen_at                                                 as device_first_seen_at
from devices as d
left join latest_login as l
    on d.user_pseudo_id = l.user_pseudo_id
