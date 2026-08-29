-- sql/11_maine_mix.sql
-- Is Maine's top-of-the-table injury rate explained by its industry mix?
--
-- Chart 04 ranks states by rate. A state can rank high simply by having more of its hours in
-- high-rate sectors, which is a composition effect and not a statement about safety. This
-- query tests that directly instead of guessing in the caption.
--
-- Per sector: Maine's hours and its share of Maine's total, the national hours and share, and
-- the national rate for that sector. The notebook then computes an indirect standardisation —
-- what Maine's rate would be if every sector in Maine ran at the NATIONAL rate for that
-- sector, weighted by Maine's own hours:
--
--     expected = SUM(maine_hours * national_rate) / SUM(maine_hours)
--
-- If that expected rate is close to Maine's actual rate, mix explains the ranking. If it sits
-- near the national average instead, mix does not explain it and something else does.

WITH national AS (
    SELECT sector,
           SUM(total_hours_worked)  AS nat_hours,
           SUM(recordable_cases)    AS nat_cases,
           SUM(recordable_cases) * 200000.0 / SUM(total_hours_worked) AS nat_trir
    FROM clean_300a GROUP BY sector
),
maine AS (
    SELECT sector,
           COUNT(*)                 AS me_n,
           SUM(total_hours_worked)  AS me_hours,
           SUM(recordable_cases)    AS me_cases,
           SUM(recordable_cases) * 200000.0 / SUM(total_hours_worked) AS me_trir
    FROM clean_300a WHERE state = 'ME' GROUP BY sector
)
SELECT
    n.sector,
    COALESCE(m.me_n, 0)                                                  AS me_n_establishments,
    COALESCE(m.me_hours, 0)                                              AS me_hours,
    ROUND(100.0 * COALESCE(m.me_hours, 0) / SUM(COALESCE(m.me_hours, 0)) OVER (), 2)
                                                                         AS me_pct_of_hours,
    ROUND(100.0 * n.nat_hours / SUM(n.nat_hours) OVER (), 2)             AS nat_pct_of_hours,
    ROUND(100.0 * COALESCE(m.me_hours, 0) / SUM(COALESCE(m.me_hours, 0)) OVER ()
          - 100.0 * n.nat_hours / SUM(n.nat_hours) OVER (), 2)           AS pct_point_diff,
    m.me_trir,
    n.nat_trir
FROM national n
LEFT JOIN maine m ON m.sector = n.sector
ORDER BY me_pct_of_hours DESC;
