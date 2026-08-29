-- sql/12_clean_export.sql
-- Row-level export of the clean table for Excel. One row per establishment.
-- Deliberately excludes establishment_name and company_name: PRD.md section 4 forbids any
-- output that names an individual establishment or employer, and an Excel file is exactly
-- the artefact someone would sort by rate and screenshot.

SELECT
    establishment_id,
    state,
    sector,
    naics_code,
    size_band,
    annual_average_employees,
    total_hours_worked,
    total_deaths,
    total_dafw_cases,
    total_djtr_cases,
    total_other_cases,
    recordable_cases,
    trir,
    dart
FROM clean_300a
ORDER BY sector, size_band, state;
