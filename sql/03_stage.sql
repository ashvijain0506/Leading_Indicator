-- sql/03_stage.sql
-- Tag every raw row with the FIRST exclusion rule it fails, in the order below,
-- or NULL if it passes all of them. Because a row lands on exactly one step, the
-- waterfall reconciles by construction: raw = clean + sum(rows dropped per step).
-- Steps 3 and 4 run before step 8, so hours is non-null and employees > 0 by the
-- time hours_per_employee is evaluated.
--
-- Exclusion list locked by Ashvi at the M1 checkpoint; see PRD.md section 7.
--
-- Two adaptations to what M1 actually found in this file:
--   * The sector lookup is read from sql/naics_sectors.csv through the {SECTORS_PATH}
--     placeholder rather than a pre-built table, so this file needs no separate setup
--     step and carries no machine-specific path. sector_code is cast to VARCHAR to
--     match LEFT(naics_txt, 2).
--   * created_timestamp is stored as M/D/YYYY text (e.g. "2/27/2026"). M1 confirmed
--     TRY_CAST(... AS TIMESTAMP) returns NULL for all 383,280 non-null values, which
--     would leave the de-duplication ordering permanently inert. TRY_STRPTIME with
--     '%m/%d/%Y' parses it correctly, so it leads and the plain cast remains as a
--     fallback. Ordering only decides ties, and M1 established there are none.

CREATE OR REPLACE TABLE staged_300a AS
WITH naics_sectors AS (
    SELECT CAST(sector_code AS VARCHAR) AS sector_code, sector
    FROM read_csv_auto('{SECTORS_PATH}', header = true)
),
ranked AS (
    SELECT
        r.*,
        CAST(r.naics_code AS VARCHAR)                                   AS naics_txt,
        r.total_dafw_cases + r.total_djtr_cases + r.total_other_cases   AS recordable_cases,
        CASE WHEN r.annual_average_employees > 0
             THEN r.total_hours_worked * 1.0 / r.annual_average_employees END AS hours_per_employee,
        ROW_NUMBER() OVER (
            PARTITION BY r.establishment_id, r.year_filing_for
            ORDER BY COALESCE(
                         TRY_STRPTIME(r.created_timestamp, '%m/%d/%Y'),
                         TRY_CAST(r.created_timestamp AS TIMESTAMP)
                     ) DESC NULLS LAST,
                     r.id DESC
        ) AS submission_rank
    FROM raw_300a r
)
SELECT
    ranked.*,
    s.sector,
    CASE
        WHEN year_filing_for IS NULL OR year_filing_for <> 2025                        THEN 1
        WHEN submission_rank > 1                                                       THEN 2
        WHEN total_hours_worked IS NULL OR total_hours_worked < 1000                   THEN 3
        WHEN annual_average_employees IS NULL OR annual_average_employees = 0          THEN 4
        WHEN naics_txt IS NULL OR LENGTH(naics_txt) <> 6 OR s.sector IS NULL           THEN 5
        WHEN total_deaths IS NULL OR total_dafw_cases IS NULL
             OR total_djtr_cases IS NULL OR total_other_cases IS NULL
             OR total_deaths < 0 OR total_dafw_cases < 0
             OR total_djtr_cases < 0 OR total_other_cases < 0                          THEN 6
        WHEN recordable_cases > annual_average_employees                               THEN 7
        WHEN hours_per_employee < 100 OR hours_per_employee > 5000                     THEN 8
        ELSE NULL
    END AS drop_step
FROM ranked
LEFT JOIN naics_sectors s ON LEFT(ranked.naics_txt, 2) = s.sector_code;
