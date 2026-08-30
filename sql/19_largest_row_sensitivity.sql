-- sql/19_largest_row_sensitivity.sql
-- How much does one row move a sector rate?
--
-- The eight exclusion rules in sql/03_stage.sql are RATIO tests, not magnitude tests. Step 8
-- rejects a row whose hours per employee is implausible; nothing rejects a row whose hours are
-- implausibly large in absolute terms as long as the ratio looks reasonable. That is a deliberate
-- design choice — a large plant genuinely does work tens of millions of hours — but it means a
-- single filing can be a meaningful share of a sector's denominator, and sum-then-divide gives
-- every hour equal weight by construction.
--
-- So measure it. For each sector: its largest single row by hours, that row's share of the
-- sector's total hours, and the sector rate recomputed with that one row removed. The gap
-- between the two rates is how much the sector's published figure depends on one submission.
--
-- This query diagnoses; it does not fix. Nothing here is excluded on the strength of it, and the
-- sector rates published everywhere else in this project include every clean row. The result is
-- reported in the README's limits section.

WITH totals AS (
    SELECT
        sector,
        COUNT(*)                AS n_establishments,
        SUM(total_hours_worked) AS sector_hours,
        SUM(recordable_cases)   AS sector_cases
    FROM clean_300a
    GROUP BY sector
),
largest AS (
    SELECT sector, annual_average_employees, total_hours_worked, recordable_cases
    FROM (
        SELECT
            sector,
            annual_average_employees,
            total_hours_worked,
            recordable_cases,
            ROW_NUMBER() OVER (PARTITION BY sector ORDER BY total_hours_worked DESC) AS rn
        FROM clean_300a
    )
    WHERE rn = 1
)

SELECT
    t.sector,
    t.n_establishments,
    l.annual_average_employees                        AS largest_row_employees,
    l.total_hours_worked                              AS largest_row_hours,
    l.recordable_cases                                AS largest_row_cases,
    ROUND(100.0 * l.total_hours_worked / t.sector_hours, 2)
                                                      AS largest_row_pct_of_sector_hours,
    t.sector_cases * 200000.0 / t.sector_hours        AS trir,
    (t.sector_cases - l.recordable_cases) * 200000.0
        / (t.sector_hours - l.total_hours_worked)     AS trir_excluding_largest_row,
    (t.sector_cases - l.recordable_cases) * 200000.0
        / (t.sector_hours - l.total_hours_worked)
        - t.sector_cases * 200000.0 / t.sector_hours  AS change_if_excluded
FROM totals t
JOIN largest l ON l.sector = t.sector
ORDER BY largest_row_pct_of_sector_hours DESC;
