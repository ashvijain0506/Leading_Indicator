-- sql/13_pivot_source.sql
-- Pre-aggregated pivot source: one row per sector x size_band x state.
--
-- This is the recommended input for the Excel PivotTable. A pivot calculated field
--     TRIR = recordable_cases * 200000 / total_hours_worked
-- is evaluated on the SUMMED fields, which is exactly the sum-then-divide rule. Feeding it
-- pre-summed groups therefore produces identical numbers to feeding it 369,996 raw rows,
-- because summing a sum is the same sum. The only thing lost is the ability to drill below
-- sector x size_band x state, which this project does not do anyway.

SELECT
    sector,
    size_band,
    size_order,
    state,
    COUNT(*)                       AS n_establishments,
    SUM(total_hours_worked)        AS total_hours,
    SUM(recordable_cases)          AS total_cases,
    SUM(total_deaths)              AS deaths,
    SUM(total_dafw_cases + total_djtr_cases) AS dart_cases
FROM clean_300a
GROUP BY sector, size_band, size_order, state
ORDER BY sector, size_order, state;
