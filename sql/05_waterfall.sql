-- sql/05_waterfall.sql
-- Row accounting: one line per exclusion step, then the clean count.
-- Every raw row is tagged with exactly one drop_step (or NULL), so the rows_dropped
-- column plus the clean count must sum to the raw row count. The notebook asserts this.

WITH steps AS (
    SELECT 1 AS step, 'year_filing_for missing or not 2025' AS rule
    UNION ALL SELECT 2, 'duplicate submission for the same establishment and year (kept the latest)'
    UNION ALL SELECT 3, 'total_hours_worked NULL or below 1,000'
    UNION ALL SELECT 4, 'annual_average_employees NULL or 0'
    UNION ALL SELECT 5, 'naics_code invalid or sector not in the lookup'
    UNION ALL SELECT 6, 'a case-count column NULL or negative'
    UNION ALL SELECT 7, 'recordable cases greater than annual average employees'
    UNION ALL SELECT 8, 'hours per employee below 100 or above 5,000'
),
counts AS (
    SELECT drop_step, COUNT(*) AS rows_dropped
    FROM staged_300a WHERE drop_step IS NOT NULL GROUP BY drop_step
)
SELECT s.step, s.rule, COALESCE(c.rows_dropped, 0) AS rows_dropped
FROM steps s LEFT JOIN counts c ON c.drop_step = s.step
UNION ALL
SELECT 99, 'clean rows kept', COUNT(*) FROM staged_300a WHERE drop_step IS NULL
ORDER BY step;
