-- sql/15_deaths_by_sector.sql
-- Deaths per sector, and a death rate per 100 million hours worked, ranked against TRIR.
--
-- Why 100 million hours: 745 deaths across 77.8 billion hours makes the usual 200,000-hour
-- base give numbers like 0.0019, which are unreadable. 100 million hours is roughly 50,000
-- full-time worker-years, so the figure reads as deaths per 50,000 worker-years.
--
-- The question: does a sector rank far higher on deaths than on recordable-injury rate?
-- If so, the two measure different things and a sector can look mild on one and severe on
-- the other.
--
-- CAVEAT, and it is a large one: 745 deaths spread over 20 sectors is a small number, these
-- rates are noisy, and OSHA ITA 300A is NOT the authoritative source for workplace
-- fatalities — BLS's Census of Fatal Occupational Injuries is. This is a directional
-- observation inside one dataset, not a fatality-rate estimate.

SELECT
    sector,
    COUNT(*)                                                        AS n_establishments,
    SUM(total_deaths)                                               AS deaths,
    SUM(total_hours_worked)                                         AS total_hours,
    SUM(recordable_cases)                                           AS total_cases,
    SUM(total_deaths) * 100000000.0 / SUM(total_hours_worked)       AS deaths_per_100m_hours,
    SUM(recordable_cases) * 200000.0 / SUM(total_hours_worked)      AS trir,
    RANK() OVER (ORDER BY SUM(recordable_cases) * 200000.0
                          / SUM(total_hours_worked) DESC)           AS rank_by_trir,
    RANK() OVER (ORDER BY SUM(total_deaths) * 100000000.0
                          / SUM(total_hours_worked) DESC)           AS rank_by_death_rate,
    CASE WHEN COUNT(*) < 30 THEN 'insufficient n'
         WHEN SUM(total_deaths) < 10 THEN 'fewer than 10 deaths - too thin to rank'
         ELSE '' END                                                AS note
FROM clean_300a
GROUP BY sector
ORDER BY deaths_per_100m_hours DESC;
