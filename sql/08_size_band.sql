-- sql/08_size_band.sql
-- One row per derived size band. Bands come from annual_average_employees, not from OSHA's
-- `size` code — see PRD.md section 5 for why: annual_average_employees measures the same
-- population the hours denominator measures, while OSHA's `size` is peak headcount.
--
-- Two validation columns, not corrections:
--   n_legacy_size_code    rows still carrying the retired code 2 (20-249, split in 2023)
--   pct_agree_with_osha_size  share of NON-legacy rows whose OSHA code matches the derived
--                         band, mapping band order 1/2/3/4 to codes 1/21/22/3. Legacy rows
--                         are excluded from this statistic because code 2 spans two bands
--                         and could never match one.

SELECT
    size_band,
    size_order,
    COUNT(*)                                                   AS n_establishments,
    SUM(annual_average_employees)                              AS employees,
    SUM(total_hours_worked)                                    AS total_hours,
    SUM(recordable_cases)                                      AS total_cases,
    SUM(total_deaths)                                          AS deaths,
    SUM(recordable_cases) * 200000.0 / SUM(total_hours_worked) AS trir,
    SUM(total_dafw_cases + total_djtr_cases) * 200000.0
        / SUM(total_hours_worked)                              AS dart,
    COUNT(*) FILTER (WHERE size = 2)                           AS n_legacy_size_code,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE size <> 2 AND size = CASE size_order
                                           WHEN 1 THEN 1
                                           WHEN 2 THEN 21
                                           WHEN 3 THEN 22
                                           WHEN 4 THEN 3 END)
        / NULLIF(COUNT(*) FILTER (WHERE size <> 2), 0), 2)     AS pct_agree_with_osha_size,
    CASE WHEN COUNT(*) < 30 THEN 'insufficient n' ELSE '' END  AS note
FROM clean_300a
GROUP BY size_band, size_order
ORDER BY size_order;
