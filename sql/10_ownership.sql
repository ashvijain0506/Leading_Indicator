-- sql/10_ownership.sql
-- Split the clean table by ownership (establishment_type), for the BLS comparison.
--
-- Why this query exists: the BLS SOII private-industry total recordable case rate excludes
-- government entirely, while this file includes state and local government establishments
-- (establishment_type 2 and 3). Comparing our overall rate to a private-industry-only
-- benchmark without knowing how much government is in our denominator would be sloppy.
--
-- PRD.md section 4 codes: 1 = private, 2 = state government, 3 = local government.
-- M1 found 440 NULL and 3 zero values in the raw file; any that survived cleaning are shown
-- as 'unknown' rather than folded into a real category.
--
-- Two scopes: the whole clean table, and Public Administration on its own — the sector that
-- tops the rate ranking, and the one most likely to be government.

WITH labelled AS (
    SELECT *,
           CASE establishment_type
               WHEN 1 THEN '1 private'
               WHEN 2 THEN '2 state government'
               WHEN 3 THEN '3 local government'
               ELSE '4 unknown / not coded'
           END AS ownership
    FROM clean_300a
),
by_scope AS (
    SELECT 'All sectors' AS scope, ownership, * EXCLUDE (ownership) FROM labelled
    UNION ALL
    SELECT 'Public Administration', ownership, * EXCLUDE (ownership)
    FROM labelled WHERE sector = 'Public Administration'
)
SELECT
    scope,
    ownership,
    COUNT(*)                                                   AS n_establishments,
    SUM(annual_average_employees)                              AS employees,
    SUM(total_hours_worked)                                    AS total_hours,
    SUM(recordable_cases)                                      AS total_cases,
    SUM(total_deaths)                                          AS deaths,
    SUM(recordable_cases) * 200000.0 / SUM(total_hours_worked) AS trir,
    ROUND(100.0 * SUM(total_hours_worked)
          / SUM(SUM(total_hours_worked)) OVER (PARTITION BY scope), 2) AS pct_of_scope_hours
FROM by_scope
GROUP BY scope, ownership
ORDER BY scope, ownership;
