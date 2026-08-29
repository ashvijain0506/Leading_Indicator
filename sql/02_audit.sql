-- 02_audit.sql
-- The 12 data-quality checks from PRD.md section 6, as one query returning one row per
-- check: check_no, description, rows_failing, pct_of_raw.
--
-- M1 counts problems; it does not fix them. Nothing here drops or alters a row.
-- A row may fail several checks. Each check is evaluated independently against all raw
-- rows, so the counts deliberately do not sum to a total.
--
-- Three judgement calls, made explicit:
--   * Check 1 is written `IS NULL OR <> 2025`, not plain `<> 2025`. In SQL, NULL <> 2025
--     evaluates to NULL rather than true, so a plain inequality would silently miss the
--     rows whose year is missing. A missing year is a failure of this check.
--   * Check 2 uses PRD's definition literally: rows minus distinct establishment_id, i.e.
--     the number of *excess* rows, not the number of rows involved in a duplicate group.
--   * Check 10 can only be evaluated where employees > 0 and hours is not null; rows where
--     the ratio is undefined are counted by checks 3 and 5, not here.
--
-- `recordable_cases` is computed inline as dafw + djtr + other (the OSHA Total Case Rate
-- numerator) for checks 8 and 9. total_deaths is deliberately not in it; see PRD section 5,
-- where that definition is still awaiting a decision.

WITH sectors AS (
    SELECT sector_code FROM read_csv_auto('{SECTORS_PATH}', header = true)
),
base AS (
    SELECT
        *,
        total_dafw_cases + total_djtr_cases + total_other_cases AS recordable_cases,
        CASE WHEN annual_average_employees > 0
             THEN total_hours_worked / annual_average_employees END AS hours_per_employee,
        naics_code // 10000 AS sector_code
    FROM raw_300a
),
totals AS (SELECT COUNT(*) AS n_raw FROM raw_300a),

checks AS (

    SELECT 1 AS check_no,
           'year_filing_for is not 2025 (or is NULL)' AS description,
           COUNT(*) FILTER (WHERE year_filing_for IS NULL OR year_filing_for <> 2025) AS rows_failing
    FROM base

    UNION ALL
    SELECT 2, 'duplicate establishment_id (rows minus distinct ids)',
           COUNT(*) - COUNT(DISTINCT establishment_id)
    FROM base

    UNION ALL
    SELECT 3, 'total_hours_worked is NULL',
           COUNT(*) FILTER (WHERE total_hours_worked IS NULL)
    FROM base

    UNION ALL
    SELECT 4, 'total_hours_worked < 1000',
           COUNT(*) FILTER (WHERE total_hours_worked < 1000)
    FROM base

    UNION ALL
    SELECT 5, 'annual_average_employees is NULL or 0',
           COUNT(*) FILTER (WHERE annual_average_employees IS NULL
                               OR annual_average_employees = 0)
    FROM base

    UNION ALL
    SELECT 6, 'naics_code NULL, not six digits, or sector not in lookup',
           COUNT(*) FILTER (WHERE naics_code IS NULL
                               OR naics_code < 100000
                               OR naics_code > 999999
                               OR sector_code NOT IN (SELECT sector_code FROM sectors))
    FROM base

    UNION ALL
    SELECT 7, 'a case-count column is NULL or negative',
           COUNT(*) FILTER (WHERE total_deaths IS NULL OR total_deaths < 0
                               OR total_dafw_cases IS NULL OR total_dafw_cases < 0
                               OR total_djtr_cases IS NULL OR total_djtr_cases < 0
                               OR total_other_cases IS NULL OR total_other_cases < 0)
    FROM base

    UNION ALL
    SELECT 8, 'recordable_cases > annual_average_employees',
           COUNT(*) FILTER (WHERE recordable_cases > annual_average_employees)
    FROM base

    UNION ALL
    SELECT 9, 'no_injuries_illnesses inconsistent with the case counts',
           COUNT(*) FILTER (WHERE (no_injuries_illnesses = 2 AND recordable_cases > 0)
                               OR (no_injuries_illnesses = 1 AND recordable_cases = 0))
    FROM base

    UNION ALL
    SELECT 10, 'hours per employee above 5,000 or below 100',
           COUNT(*) FILTER (WHERE hours_per_employee IS NOT NULL
                              AND (hours_per_employee > 5000 OR hours_per_employee < 100))
    FROM base

    UNION ALL
    SELECT 11, 'size code disagrees with the annual_average_employees band',
           COUNT(*) FILTER (WHERE annual_average_employees IS NOT NULL AND (
                    size IS NULL
                 OR size NOT IN (1, 2, 21, 22, 3)
                 OR (size = 1  AND NOT annual_average_employees < 20)
                 OR (size = 21 AND NOT (annual_average_employees BETWEEN 20 AND 99))
                 OR (size = 22 AND NOT (annual_average_employees BETWEEN 100 AND 249))
                 OR (size = 3  AND NOT annual_average_employees >= 250)
                 OR (size = 2  AND NOT (annual_average_employees BETWEEN 20 AND 249))))
    FROM base

    UNION ALL
    SELECT 12, 'legacy size code 2 present (retired in 2023)',
           COUNT(*) FILTER (WHERE size = 2)
    FROM base
)

SELECT c.check_no,
       c.description,
       c.rows_failing,
       ROUND(100.0 * c.rows_failing / t.n_raw, 3) AS pct_of_raw
FROM checks c CROSS JOIN totals t
ORDER BY c.check_no;
