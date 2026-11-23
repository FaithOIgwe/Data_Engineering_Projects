-- An A/A test has a true effect of zero. If the primary readout ever shows a significant result
-- or a sample ratio mismatch, the pipeline (bucketing, exposure or stats) is broken.
-- At alpha = 0.05 a real A/A test fails this ~5% of the time per metric by chance; with a fixed
-- dataset it is deterministic, so a failure here means something changed in the logic.
select *
from {{ ref('rpt_experiment_readout') }}
where experiment_id like 'aa_%'
  and population = 'primary'
  and (is_significant_at_5pct or has_sample_ratio_mismatch)
