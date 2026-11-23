{#
  Grain: one row per experiment × analysis population × metric.

  - Proportion metrics: two-proportion z-test (pooled standard error for the test, unpooled for the CI).
  - Revenue per user: Welch's z on the means (large samples).
  - Sample ratio mismatch (SRM): chi-square goodness-of-fit against the planned 50/50 split.
    If srm_p_value < 0.001 the split itself is broken and no result should be trusted.

  Populations:
    'primary'         contaminated users excluded (the decision population)
    'first_exposure'  everyone, analysed in the arm they saw first (sensitivity check)
#}
with assignments as (
    select * from {{ ref('fct_experiment_assignments') }}
),

populations as (
    select experiment_id, 'primary' as population, analysis_variant as variant,
           added_to_cart, began_checkout, converted, revenue_usd
    from assignments
    where not is_contaminated
    union all
    select experiment_id, 'first_exposure', first_variant,
           added_to_cart, began_checkout, converted, revenue_usd
    from assignments
),

long as (
    select experiment_id, population, variant, 'add_to_cart_rate' as metric, 'proportion' as metric_type, case when added_to_cart then 1.0 else 0.0 end as value from populations
    union all
    select experiment_id, population, variant, 'checkout_rate', 'proportion', case when began_checkout then 1.0 else 0.0 end from populations
    union all
    select experiment_id, population, variant, 'conversion_rate', 'proportion', case when converted then 1.0 else 0.0 end from populations
    union all
    select experiment_id, population, variant, 'revenue_per_user', 'mean', revenue_usd from populations
),

arms as (
    select
        experiment_id, population, metric, metric_type,
        count(case when variant = 'control' then 1 end)              as n_control,
        count(case when variant = 'treatment' then 1 end)            as n_treatment,
        avg(case when variant = 'control' then value end)            as mean_control,
        avg(case when variant = 'treatment' then value end)          as mean_treatment,
        var_samp(case when variant = 'control' then value end)       as var_control,
        var_samp(case when variant = 'treatment' then value end)     as var_treatment,
        avg(value)                                                   as mean_pooled
    from long
    group by 1, 2, 3, 4
),

stats as (
    select
        *,
        mean_treatment - mean_control                                as abs_diff,
        sqrt(var_control / n_control + var_treatment / n_treatment)  as se_unpooled,
        case when metric_type = 'proportion'
            then sqrt(mean_pooled * (1 - mean_pooled) * (1.0 / n_control + 1.0 / n_treatment))
            else sqrt(var_control / n_control + var_treatment / n_treatment)
        end                                                          as se_test,
        power(n_control - (n_control + n_treatment) / 2.0, 2) / ((n_control + n_treatment) / 2.0)
      + power(n_treatment - (n_control + n_treatment) / 2.0, 2) / ((n_control + n_treatment) / 2.0)
                                                                     as srm_chi_square
    from arms
)

select
    experiment_id,
    population,
    metric,
    metric_type,
    n_control,
    n_treatment,
    round(n_treatment * 1.0 / (n_control + n_treatment), 4)          as treatment_share,
    mean_control,
    mean_treatment,
    abs_diff,
    abs_diff / nullif(mean_control, 0)                               as relative_lift,
    abs_diff - 1.96 * se_unpooled                                    as ci_95_lower,
    abs_diff + 1.96 * se_unpooled                                    as ci_95_upper,
    abs_diff / nullif(se_test, 0)                                    as z_score,
    {{ two_sided_p('abs_diff / nullif(se_test, 0)') }}               as p_value,
    {{ two_sided_p('sqrt(srm_chi_square)') }}                        as srm_p_value,
    {{ two_sided_p('sqrt(srm_chi_square)') }} < 0.001                as has_sample_ratio_mismatch,
    {{ two_sided_p('abs_diff / nullif(se_test, 0)') }} < 0.05        as is_significant_at_5pct
from stats
