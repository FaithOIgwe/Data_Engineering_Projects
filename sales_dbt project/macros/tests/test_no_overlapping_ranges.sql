{#
  For SCD-style tables: within each partition, a row's [valid_from, valid_to) window must
  not overlap the next row's. Catches broken history logic (e.g. duplicate events that
  survived dedup, or ties on the change timestamp).
#}
{% test no_overlapping_ranges(model, partition_by, valid_from='valid_from', valid_to='valid_to') %}
    with ordered as (
        select
            {{ partition_by }} as partition_key,
            {{ valid_from }} as valid_from,
            {{ valid_to }} as valid_to,
            lead({{ valid_from }}) over (partition by {{ partition_by }} order by {{ valid_from }}) as next_valid_from
        from {{ model }}
    )
    select *
    from ordered
    where next_valid_from is not null
      and (valid_to is null or valid_to > next_valid_from)
{% endtest %}
