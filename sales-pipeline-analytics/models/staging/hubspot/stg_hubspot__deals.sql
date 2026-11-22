with source as (
    select * from {{ source('hubspot', 'deals') }}
),

renamed as (
    select
        cast(deal_id as bigint)                         as deal_id,
        deal_name,
        pipeline                                        as pipeline_id,
        deal_stage                                      as current_stage_id,
        cast(amount as {{ dbt.type_numeric() }})        as amount_usd,
        cast(hubspot_owner_id as bigint)                as current_owner_id,
        cast(associated_company_id as bigint)           as company_id,
        cast(create_date as timestamp)                  as created_at,
        cast(close_date as date)                        as close_date,
        case deal_type
            when 'newbusiness' then 'New business'
            when 'existingbusiness' then 'Expansion'
            else deal_type
        end                                             as deal_type,
        lead_source,
        nullif(trim(closed_lost_reason), '')            as closed_lost_reason,
        cast(updated_at as timestamp)                   as updated_at,
        cast(_fivetran_synced as timestamp)             as synced_at,
        coalesce(is_deleted, false)                     as is_deleted
    from source
)

select * from renamed
