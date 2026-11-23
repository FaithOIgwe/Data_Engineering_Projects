-- The hand-rolled normal CDF behind every p-value must match published values to 4 decimals.
with cases as (
    select * from (values (0.0, 0.5), (1.0, 0.841345), (1.96, 0.975002), (-1.96, 0.024998), (2.576, 0.995002), (-3.0, 0.001350))
        as t(z, expected)
)
select z, expected, {{ normal_cdf('z') }} as got
from cases
where abs({{ normal_cdf('z') }} - expected) > 0.0001
