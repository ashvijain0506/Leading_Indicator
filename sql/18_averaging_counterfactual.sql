-- sql/18_averaging_counterfactual.sql
-- The aggregation rule, measured instead of asserted.
--
-- Every rate in this project is SUM(recordable_cases) * 200000.0 / SUM(total_hours_worked):
-- cases summed, hours summed, divided once. The alternative anyone reaches for first is
-- AVG(trir) — the mean of the per-establishment rates. This query runs both side by side, per
-- sector, with the ranking each rule produces, so the cost of the wrong rule is a number rather
-- than an argument in a code comment.
--
-- Why AVG(trir) is wrong: it is a vote of establishments, not a measure of exposure. Each
-- establishment contributes one rate regardless of how many hours stand behind it, so a
-- 9-employee site working 1,002 hours counts as much as one working 455 million. Small
-- establishments are both numerous (99,492 of the 369,996 clean rows are under 20 employees)
-- and volatile, because on 1,000 hours a single recordable case moves the rate by 200 points.
-- Averaging therefore hands the ranking to the noisiest, smallest observations.
--
-- This is the only place in the repo where AVG(trir) is computed, and it exists solely to be
-- reported against the correct figure. Nothing downstream reads it, and no chart uses it.
--
-- places_moved_under_averaging = rank_average_of_rates - rank_sum_then_divide:
--   positive -> the sector falls down the table under the wrong rule
--   negative -> it rises
--
-- The last row is the whole clean table. Its rank columns are NULL because a single row has
-- nothing to be ranked against; it carries the two overall figures.

WITH per_sector AS (
    SELECT
        sector,
        COUNT(*)                                                   AS n_establishments,
        SUM(total_hours_worked)                                    AS total_hours,
        SUM(recordable_cases)                                      AS total_cases,
        SUM(recordable_cases) * 200000.0 / SUM(total_hours_worked) AS trir_sum_then_divide,
        AVG(trir)                                                  AS trir_average_of_rates
    FROM clean_300a
    GROUP BY sector
),
ranked AS (
    SELECT
        *,
        RANK() OVER (ORDER BY trir_sum_then_divide  DESC) AS rank_sum_then_divide,
        RANK() OVER (ORDER BY trir_average_of_rates DESC) AS rank_average_of_rates
    FROM per_sector
)

SELECT
    sector,
    n_establishments,
    total_hours,
    total_cases,
    trir_sum_then_divide,
    trir_average_of_rates,
    trir_average_of_rates - trir_sum_then_divide AS overstatement,
    rank_sum_then_divide,
    rank_average_of_rates,
    rank_average_of_rates - rank_sum_then_divide AS places_moved_under_averaging
FROM ranked

UNION ALL

SELECT
    'ALL SECTORS (whole clean table)',
    COUNT(*),
    SUM(total_hours_worked),
    SUM(recordable_cases),
    SUM(recordable_cases) * 200000.0 / SUM(total_hours_worked),
    AVG(trir),
    AVG(trir) - SUM(recordable_cases) * 200000.0 / SUM(total_hours_worked),
    CAST(NULL AS BIGINT),
    CAST(NULL AS BIGINT),
    CAST(NULL AS BIGINT)
FROM clean_300a

ORDER BY rank_sum_then_divide NULLS LAST;
