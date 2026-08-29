-- 01_load.sql
-- Load the raw OSHA ITA Form 300A summary file into DuckDB, unmodified.
--
-- sample_size = -1  : scan the whole file before inferring column types, so a
--                     stray text value late in the file cannot break a type
--                     guessed from the first few thousand rows.
-- no ignore_errors  : a row that will not parse must raise, not vanish.
-- The raw CSV is never modified; this table is a faithful copy of it.

CREATE OR REPLACE TABLE raw_300a AS
SELECT *
FROM read_csv_auto(
    '{CSV_PATH}',
    sample_size = -1,
    header = true
);
