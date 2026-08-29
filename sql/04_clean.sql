-- sql/04_clean.sql
-- TRIR = recordable cases x 200,000 / hours worked. 200,000 is 100 employees x
-- 40 hours x 50 weeks, so the rate reads as cases per 100 full-time workers.
-- recordable_cases is dafw + djtr + other (OSHA Total Case Rate); deaths are excluded
-- from the numerator and carried as their own count. See PRD.md section 5.
-- size_band is derived from annual_average_employees (see the locked decisions);
-- OSHA's size code is kept alongside so 08 can report how often the two agree.
--
-- Establishments reporting zero recordable cases are kept. They contribute hours to
-- every denominator, and removing them would inflate every rate in this project.

CREATE OR REPLACE TABLE clean_300a AS
SELECT
    *,
    recordable_cases * 200000.0 / total_hours_worked                      AS trir,
    (total_dafw_cases + total_djtr_cases) * 200000.0 / total_hours_worked AS dart,
    CASE WHEN annual_average_employees < 20  THEN 'Under 20'
         WHEN annual_average_employees < 100 THEN '20-99'
         WHEN annual_average_employees < 250 THEN '100-249'
         ELSE '250+' END                                                  AS size_band,
    CASE WHEN annual_average_employees < 20  THEN 1
         WHEN annual_average_employees < 100 THEN 2
         WHEN annual_average_employees < 250 THEN 3
         ELSE 4 END                                                       AS size_order
FROM staged_300a
WHERE drop_step IS NULL;
