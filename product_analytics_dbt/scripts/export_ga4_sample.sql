-- Pulls a fixed 1-in-40 sample of users from Google's public GA4 Merchandise Store dataset,
-- flattened to one row per event with the columns this project expects.
-- Run in the BigQuery console (free tier is enough), save results as CSV, gzip it and put it at
-- data/raw/ga4_events.csv.gz, then: python scripts/simulate_aa_assignment.py && make build
select
  event_date,
  event_timestamp,
  event_name,
  user_pseudo_id,
  user_id,
  user_first_touch_timestamp,
  (select value.int_value from unnest(event_params) where key = 'ga_session_id')        as ga_session_id,
  (select value.int_value from unnest(event_params) where key = 'ga_session_number')    as ga_session_number,
  (select value.string_value from unnest(event_params) where key = 'page_location')     as page_location,
  (select value.string_value from unnest(event_params) where key = 'page_title')        as page_title,
  (select value.string_value from unnest(event_params) where key = 'page_referrer')     as page_referrer,
  (select value.int_value from unnest(event_params) where key = 'engagement_time_msec') as engagement_time_msec,
  coalesce(
    (select value.string_value from unnest(event_params) where key = 'session_engaged'),
    cast((select value.int_value from unnest(event_params) where key = 'session_engaged') as string)
  )                                                                                      as session_engaged,
  (select value.string_value from unnest(event_params) where key = 'source')            as event_source,
  (select value.string_value from unnest(event_params) where key = 'medium')            as event_medium,
  traffic_source.source                                                                  as first_user_source,
  traffic_source.medium                                                                  as first_user_medium,
  device.category                                                                        as device_category,
  device.operating_system                                                                as device_os,
  device.web_info.browser                                                                as browser,
  geo.country                                                                            as country,
  ecommerce.transaction_id                                                               as transaction_id,
  ecommerce.purchase_revenue_in_usd                                                      as purchase_revenue_usd,
  array_length(items)                                                                    as item_count,
  event_bundle_sequence_id,
  event_server_timestamp_offset
from `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
where mod(abs(farm_fingerprint(user_pseudo_id)), 40) = 0
