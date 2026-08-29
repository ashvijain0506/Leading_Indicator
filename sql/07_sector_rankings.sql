-- sql/07_sector_rankings.sql
-- One row per NAICS sector, ranked two ways: by hours-normalised rate and by raw case count.
-- The gap between those two rankings is the finding this project exists to make.
--
-- Both ranks are computed in the same query so they cannot drift apart. Sum-then-divide
-- throughout. Every row carries n_establishments, total_hours and total_cases so the exposure
-- behind each rate is visible.
--
-- PRD section 5 sets a minimum of 30 establishments for a ranked group. Smaller groups are
-- still shown, marked "insufficient n" — never silently dropped.

SELECT
    sector,
    COUNT(*)                                                   AS n_establishments,
    SUM(annual_average_employees)                              AS employees,
    SUM(total_hours_worked)                                    AS total_hours,
    SUM(recordable_cases)                                      AS total_cases,
    SUM(total_deaths)                                          AS deaths,
    SUM(recordable_cases) * 200000.0 / SUM(total_hours_worked) AS trir,
    SUM(total_dafw_cases + total_djtr_cases) * 200000.0
        / SUM(total_hours_worked)                              AS dart,
    RANK() OVER (ORDER BY SUM(recordable_cases) * 200000.0
                          / SUM(total_hours_worked) DESC)      AS rank_by_rate,
    RANK() OVER (ORDER BY SUM(recordable_cases) DESC)          AS rank_by_count,
    CASE WHEN COUNT(*) < 30 THEN 'insufficient n' ELSE '' END  AS note
FROM clean_300a
GROUP BY sector
ORDER BY trir DESC;
