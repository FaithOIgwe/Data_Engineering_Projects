-- Stage-to-stage conversion by the rep who originally owned the deal, closed deals only.
select
    o.owner_name,
    r.stage_order,
    r.stage_label,
    count(*)                                                as deals_reached,
    round(avg(case when r.reached_next_stage then 1.0 else 0 end), 3) as conversion_to_next
from {{ ref('fct_stage_reached') }} as r
left join {{ ref('dim_owners') }} as o
    on r.original_owner_id = o.owner_id
where r.pipeline_id = 'default'
  and r.deal_status in ('Won', 'Lost')
group by 1, 2, 3
order by 1, 2
