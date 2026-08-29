-- sql/09_state.sql
-- One row per state, ranked by rate. Sum-then-divide, with n, hours and cases on every row.
--
-- PRD section 5 sets a minimum of 30 establishments for a ranked group. At state level this
-- matters: a state with a handful of reporting establishments can post an extreme rate on
-- almost no exposure. Such states are shown here and marked, and the notebook builds the
-- top-10 list only from states meeting the threshold.

SELECT
    state,
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
    CASE WHEN COUNT(*) < 30 THEN 'insufficient n' ELSE '' END  AS note
FROM clean_300a
GROUP BY state
ORDER BY trir DESC;
