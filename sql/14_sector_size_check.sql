-- sql/14_sector_size_check.sql
-- Sector x size_band rates straight from SQL, for checking against the Excel pivot cells.
-- If a pivot cell disagrees with the matching row here, the pivot's calculated field is
-- averaging rates instead of dividing summed cases by summed hours.

SELECT
    sector,
    size_band,
    size_order,
    COUNT(*)                                                   AS n_establishments,
    SUM(total_hours_worked)                                    AS total_hours,
    SUM(recordable_cases)                                      AS total_cases,
    ROUND(SUM(recordable_cases) * 200000.0
          / SUM(total_hours_worked), 2)                        AS trir
FROM clean_300a
GROUP BY sector, size_band, size_order
ORDER BY sector, size_order;
