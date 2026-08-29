-- sql/06_overall.sql
-- One row describing the whole clean table.
--
-- The rate is SUM(cases) * 200000.0 / SUM(hours) — summed first, divided once. An average of
-- per-establishment rates would weight a 10-person shop the same as a 5,000-person plant and
-- give a different, wrong answer.
--
-- Deaths are excluded from the TRIR numerator (OSHA Total Case Rate) and reported separately.
-- n_zero_case_establishments is reported because those establishments are deliberately KEPT:
-- they contribute hours to the denominator, and dropping them would inflate every rate here.

SELECT
    COUNT(*)                                              AS n_establishments,
    SUM(annual_average_employees)                         AS employees,
    SUM(total_hours_worked)                               AS total_hours,
    SUM(recordable_cases)                                 AS total_cases,
    SUM(total_deaths)                                     AS deaths,
    SUM(recordable_cases) * 200000.0 / SUM(total_hours_worked)                      AS trir,
    SUM(total_dafw_cases + total_djtr_cases) * 200000.0 / SUM(total_hours_worked)   AS dart,
    COUNT(*) FILTER (WHERE recordable_cases = 0)          AS n_zero_case_establishments,
    ROUND(100.0 * COUNT(*) FILTER (WHERE recordable_cases = 0) / COUNT(*), 2)
                                                          AS pct_zero_case
FROM clean_300a;
