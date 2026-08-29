-- sql/17_regression_input.sql
-- Input for the OLS model in M4b:  trir ~ log(annual_average_employees) + C(sector)
--
-- The question the aggregates raised but cannot answer: the size gradient (4.166 down to
-- 3.196 across the four bands) could simply be sector mix, if small establishments are
-- concentrated in high-rate sectors. C(sector) holds sector constant so the size coefficient
-- is a within-sector estimate.
--
-- log(employees) rather than employees, because establishment size spans 1 to 138,396 and
-- the interesting comparison is proportional: a 20-person site against a 200-person site,
-- not a 20-person site against one 20 people larger. A coefficient on log base e times
-- ln(2) gives the predicted change per doubling.
--
-- Only the columns the model needs, so a 370,000-row frame stays small in memory.

SELECT
    trir,
    annual_average_employees,
    sector,
    size_band,
    recordable_cases,
    total_hours_worked
FROM clean_300a;
