-- Weekly pipeline review: open new-business deals that need attention, worst first.
select
    o.owner_name,
    d.deal_name,
    d.current_stage_label,
    d.amount_usd,
    d.close_date                       as expected_close,
    d.days_since_stage_change,
    d.is_stale,
    d.is_past_due,
    d.close_date_change_count          as times_close_date_pushed
from {{ ref('fct_deals') }} as d
left join {{ ref('dim_owners') }} as o
    on d.current_owner_id = o.owner_id
where d.deal_status = 'Open'
  and d.deal_type = 'New business'
  and (d.is_stale or d.is_past_due or d.close_date_change_count >= 2)
order by d.amount_usd desc nulls last
