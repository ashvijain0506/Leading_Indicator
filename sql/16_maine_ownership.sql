-- sql/16_maine_ownership.sql
-- Second standardisation for Maine: does OWNERSHIP mix explain its rank?
--
-- sql/11_maine_mix.sql controlled for sector and found mix explains 2.3% of Maine's gap.
-- But that test held sector constant and let ownership vary, and the ownership table shows
-- local government at 5.293 against private at 3.453. A state with unusually heavy local
-- government reporting would post a high rate for reasons that have nothing to do with its
-- industries, and the sector test would not have caught it.
--
-- Same method as 11: per ownership category, Maine's hours and share against the national
-- hours and share, plus the national rate for that category. The notebook then computes
--
--     expected = SUM(maine_hours * national_ownership_rate) / SUM(maine_hours)
--
-- If that lands near Maine's actual 6.242, ownership mix explains the rank. If it lands near
-- the national 3.475, it does not.

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
national AS (
    SELECT ownership,
           SUM(total_hours_worked) AS nat_hours,
           SUM(recordable_cases) * 200000.0 / SUM(total_hours_worked) AS nat_trir
    FROM labelled GROUP BY ownership
),
maine AS (
    SELECT ownership,
           COUNT(*)                AS me_n,
           SUM(total_hours_worked) AS me_hours,
           SUM(recordable_cases) * 200000.0 / SUM(total_hours_worked) AS me_trir
    FROM labelled WHERE state = 'ME' GROUP BY ownership
)
SELECT
    n.ownership,
    COALESCE(m.me_n, 0)                                                  AS me_n_establishments,
    COALESCE(m.me_hours, 0)                                              AS me_hours,
    ROUND(100.0 * COALESCE(m.me_hours, 0)
          / SUM(COALESCE(m.me_hours, 0)) OVER (), 2)                     AS me_pct_of_hours,
    ROUND(100.0 * n.nat_hours / SUM(n.nat_hours) OVER (), 2)             AS nat_pct_of_hours,
    ROUND(100.0 * COALESCE(m.me_hours, 0) / SUM(COALESCE(m.me_hours, 0)) OVER ()
          - 100.0 * n.nat_hours / SUM(n.nat_hours) OVER (), 2)           AS pct_point_diff,
    m.me_trir,
    n.nat_trir
FROM national n
LEFT JOIN maine m ON m.ownership = n.ownership
ORDER BY n.ownership;
