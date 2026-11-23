-- Sessions must account for every event (nothing dropped by the sessionization).
select
    (select count(*) from {{ ref('stg_ga4__events') }}) as events,
    (select sum(events) from {{ ref('fct_sessions') }}) as events_in_sessions
where (select count(*) from {{ ref('stg_ga4__events') }}) != (select sum(events) from {{ ref('fct_sessions') }})
