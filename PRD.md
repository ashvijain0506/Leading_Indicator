# Leading Indicator — PRD

Companion to `PROJECT_BRIEF.md`. The brief owns the domain spec and the hard constraints (macOS, free tools, two days, first-co-op level). This file owns milestones, acceptance criteria, locked definitions, and the definition of done. On process, this file wins; on scope limits, the brief wins.

Sprint dates: Sat 29 Aug 2026 (M1–M2), Sun 30 Aug 2026 (M3–M4). New work is dated Aug 2026.

## 1. Goal

Show that ranking US workplaces by raw recordable-injury count and by hours-normalised rate (TRIR) gives different answers, and quantify the difference at the industry-sector level from one year of OSHA Form 300A data. The finding is the reordering itself, stated with the sectors and numbers that actually come out of the queries.

## 2. User story

A data-analytics hiring manager opens the README and within 60 seconds sees the finding, the evidence (four charts), how the data was cleaned (a row-count waterfall), and the limits. Opening the notebook, the SQL, or the Excel pivot lets them reproduce any number in the README from the raw file.

## 3. Scope

In: one year of ITA 300A summary data; DuckDB + SQL for cleaning and aggregation; pandas/matplotlib for tables and charts; an Excel PivotTable dashboard; a one-page README; `docs/INTERVIEW_NOTES.md`; one optional OLS regression.

Out (do not build even if it looks quick):
- Multi-year trends; the 300/301 Case Detail files
- Establishment-level "most dangerous" rankings, or naming individual employers in the write-up
- Machine learning, forecasting, star schemas, orchestration, cloud services, BI tools
- Geocoding, maps, interactive dashboards
- Any statistics beyond the one optional regression

## 4. Data (verified 29 Aug 2026 against osha.gov)

- File: `ITA_300A_Summary_Data_2025_through_03-15-2026_v2.csv` — CY2025 injuries, submissions received 1 Jan–15 Mar 2026. Plain CSV, linked from https://www.osha.gov/itadata. Ashvi downloads it in a browser into `data/`; Claude Code does not fetch from osha.gov.
- Data dictionary: https://www.osha.gov/sites/default/files/summary_data_dictionary.pdf
- Read before M4 (they supply the limits section): the "ITA Data Users Guide" and "Comparison Between OSHA ITA Data and BLS SOII Estimates" PDFs, both linked from the same page.

Columns per the dictionary (confirm with `DESCRIBE`; check the exact case of the header):

`id, establishment_name, establishment_id, ein, company_name, street_address, city, state, zip_code, naics_code, naics_year, industry_description, establishment_type, size, annual_average_employees, total_hours_worked, no_injuries_illnesses, total_deaths, total_dafw_cases, total_djtr_cases, total_other_cases, total_dafw_days, total_djtr_days, total_injuries, total_skin_disorders, total_respiratory_conditions, total_poisonings, total_hearing_loss, total_other_illnesses, created_timestamp, change_reason, year_filing_for`

Coded fields:
- `size`: 1 = under 20 employees, 21 = 20–99, 22 = 100–249, 3 = 250+. Legacy code 2 (= 20–249) was split in 2023 and should not appear in 2025 data; flag it if it does. `size` is peak headcount during the year; `annual_average_employees` is the average. They can legitimately differ.
- `establishment_type`: 1 = private, 2 = state government, 3 = local government
- `no_injuries_illnesses`: 1 = had recordable cases, 2 = had none

Who is in the data: establishments with 250+ employees outside the partially-exempt industries, plus 20–249-employee establishments in designated high-hazard industries; OSHA also keeps submissions from establishments that were not required to file. The sample is skewed toward large and high-hazard workplaces, and OSHA states it is not generalisable to all workers. That is a named limit in the README, not a footnote.

### Two verified facts that change the brief

1. OSHA's own Total Case Rate is (Field H + I + J) × 200,000 / hours: days-away cases + restricted/transfer cases + other recordable cases. Deaths (Field G) are not in it, matching the BLS convention of tracking fatalities separately. The brief adds deaths. Decision in §5.
2. OSHA's data-quality note says that calling establishments "most dangerous" or "least dangerous" from these rates alone would be inappropriate, because OSHA does not validate submitted counts. So: the analysis stays at sector / size-band / state level, the wording is "highest recordable-injury rate among reporting establishments", and no ranking names an individual establishment or company.

## 5. Locked definitions (settled at the M1 checkpoint, before any cleaning)

**Status: locked by Ashvi at the M1 checkpoint, 29 Aug 2026.** The decisions this section
left open are now closed and recorded below.

- `recordable_cases = total_dafw_cases + total_djtr_cases + total_other_cases` (OSHA Total Case Rate definition). **DECIDED at M1: deaths are excluded from the numerator** and `total_deaths` is carried as its own count on every aggregate. Chosen over the brief's deaths-inclusive version because it is directly comparable to published OSHA and BLS SOII rates, which is what makes the M2 sanity check meaningful. The README states which definition was used.
- `trir = recordable_cases * 200000.0 / total_hours_worked`, per establishment, computed on the clean table only.
- Optional second metric: `dart = (total_dafw_cases + total_djtr_cases) * 200000.0 / total_hours_worked`.
- Aggregation: `SUM(recordable_cases) * 200000.0 / SUM(total_hours_worked)`. Never `AVG(trir)`. Every aggregate row also carries `n_establishments`, `total_hours`, `total_cases`, so the exposure behind each rate is visible.
- Sector: first two digits of `naics_code`, with 31–33 → Manufacturing, 44–45 → Retail Trade, 48–49 → Transportation and Warehousing collapsed. The lookup lives in `sql/naics_sectors.csv` (table below). Do not derive sector names from `industry_description`.
  **NAICS vintages — DECIDED at M1: no exclusion.** M1 found rows coded against three NAICS vintages: 2022 (60.39%), 2012 (36.39%), 2017 (3.17%), plus 167 rows at `naics_year = 0`. NAICS has kept the same 20 two-digit sectors across all three vintages; revisions operate below the sector level. The largest 2022 change — eliminating subsector 454, Nonstore Retailers — redistributed those establishments to store retailers, still inside Retail Trade 44–45. Mixing vintages is therefore safe at two digits and would only bite at 4–6 digit detail. Recorded as a README limitation with the real split, not as an exclusion.
- Size band: **DECIDED at M1 — derived from `annual_average_employees`, not from OSHA's `size` code.** Four bands: Under 20 / 20–99 / 100–249 / 250+.
  Reasoning for the README: `annual_average_employees` measures the same population the hours denominator measures, while OSHA's `size` is *peak* headcount during the year. Deriving the band from the average makes numerator, denominator and grouping describe one thing. The alternative — keeping OSHA's code and patching only the 33,123 legacy `size = 2` rows — would band 91% of rows by peak and 9% by average, a hybrid definition. The M1 numbers argue against the patch directly: of the legacy rows, 23,401 imply 20–99 and 6,646 imply 100–249, totalling 30,047 — so roughly 3,076 rows carry the legacy 20–249 code while averaging outside 20–249 altogether.
  OSHA's `size` code is retained in the clean table as a validation statistic only: `sql/08_size_band.sql` reports the percentage agreement between the code and the derived band, excluding legacy code 2. Neither column is "fixed".
- Minimum exposure for any ranked group: 30 establishments. Smaller groups are shown but marked "insufficient n". Irrelevant at sector level, essential for anything finer.

NAICS sector lookup (2022 NAICS, `sector_code,sector`):

| sector_code | sector |
|---|---|
| 11 | Agriculture, Forestry, Fishing and Hunting |
| 21 | Mining, Quarrying, and Oil and Gas Extraction |
| 22 | Utilities |
| 23 | Construction |
| 31 | Manufacturing |
| 32 | Manufacturing |
| 33 | Manufacturing |
| 42 | Wholesale Trade |
| 44 | Retail Trade |
| 45 | Retail Trade |
| 48 | Transportation and Warehousing |
| 49 | Transportation and Warehousing |
| 51 | Information |
| 52 | Finance and Insurance |
| 53 | Real Estate and Rental and Leasing |
| 54 | Professional, Scientific, and Technical Services |
| 55 | Management of Companies and Enterprises |
| 56 | Administrative and Support and Waste Management and Remediation Services |
| 61 | Educational Services |
| 62 | Health Care and Social Assistance |
| 71 | Arts, Entertainment, and Recreation |
| 72 | Accommodation and Food Services |
| 81 | Other Services (except Public Administration) |
| 92 | Public Administration |

## 6. Audit checks (M1: count only, drop nothing)

Each check is one query returning a count and a percentage of raw rows. A row can fail several checks; M1 reports each check independently.

1. `year_filing_for <> 2025`
2. Duplicate `establishment_id` (rows minus distinct ids); show the `change_reason` distribution and whether duplicates differ in `created_timestamp`
3. `total_hours_worked` NULL
4. `total_hours_worked < 1000`
5. `annual_average_employees` NULL or `= 0`
6. `naics_code` NULL, not six digits, or first two digits not in the sector lookup
7. Any of the four case-count columns NULL or negative
8. `recordable_cases > annual_average_employees`
9. `no_injuries_illnesses` inconsistent with the case counts (2 but cases > 0, or 1 but cases = 0)
10. Hours per employee (`total_hours_worked / annual_average_employees`) above 5,000 or below 100 — implausible in both directions and the usual sign of hours entered in the wrong unit
11. `size` code disagrees with the `annual_average_employees` band
12. Legacy `size = 2` present

Plus: null rate for every column, and value counts for `establishment_type` and `size`.

At the M1 checkpoint Ashvi decides which checks become exclusions. Recommended: the brief's five (checks 3, 4, 5, 6, 8) plus 1, 2, and 7 as exclusions; 9–12 as reported flags unless the counts are alarming. The decision is written into §7 before M2 starts.

## 7. Exclusion rules (locked by Ashvi at the M1 checkpoint, 29 Aug 2026)

Applied sequentially in this order so the waterfall reconciles exactly (`raw − Σ dropped = clean`).
Implemented in `sql/03_stage.sql`, which tags every raw row with the **first** step it fails, so a
row lands on exactly one step and the reconciliation holds by construction. Counts are filled from
`output/tables/drop_waterfall.csv`, never by hand.

**Excluded (8 steps):** M1 checks 1, 2, 3, 4, 5, 6, 7, 8 and 10, collapsed into the eight steps below
(M1 checks 3 and 4 merge into step 3; M1 check 10 becomes step 8).

**Flag only, never excluded:** M1 checks 9, 11 and 12. Their counts are reported in the README.

| step | rule | rows dropped |
|---|---|---|
| 1 | `year_filing_for` missing or not 2025 | 6 |
| 2 | duplicate submission for the same establishment and year → keep latest `created_timestamp` | 0 |
| 3 | `total_hours_worked` NULL or `< 1000` | 9,046 |
| 4 | `annual_average_employees` NULL or `= 0` | 221 |
| 5 | `naics_code` invalid or sector not in the lookup | 15 |
| 6 | a case-count column NULL or negative | 0 |
| 7 | recordable cases greater than annual average employees | 146 |
| 8 | hours per employee below 100 or above 5,000 | 3,853 |
| | **total excluded** | **13,287** |
| | **clean rows kept** | **369,996** |

Raw 383,283 rows → clean 369,996 rows: 13,287 excluded (3.47%). Counts read from `output/tables/drop_waterfall.csv`, generated by `sql/05_waterfall.sql`; the notebook asserts that they reconcile to the raw row count.

Notes on two steps that were argued at the checkpoint:

- **Step 2 is expected to drop 0 rows.** M1 established that the only repeated `establishment_id` is
  the literal string `"TX"`, a state code shifted into the id column on two of the six corrupt tail
  rows, and step 1 removes those first. The rule is kept anyway: a waterfall line reading
  "duplicate submissions: 0" is better evidence than a missing rule — it shows de-duplication was
  considered and measured, and it keeps the pipeline correct if it is ever pointed at another year's
  file. **If step 2 is not 0, stop and report.**
- **Step 8 was promoted from a flag to an exclusion.** It is the step that removes the
  employee/hours concatenation rows in both directions: 81,170,689 employees against 170,689 hours
  gives 0.002 hours per employee, while the 140-billion-hour rows give an absurdly high one. Because
  aggregation sums hours before dividing, one surviving row of that kind could swamp a sector's
  denominator.

### Guards that apply to every query built on the clean table

- Establishments reporting **zero recordable cases stay in the clean table**. They contribute hours
  to every denominator. Filtering to `no_injuries_illnesses = 1` would inflate every rate in this
  project. The count of zero-case clean rows is reported in `sql/06_overall.sql`.
- Never `AVG(trir)`. Every aggregate rate is `SUM(cases) * 200000.0 / SUM(hours)`, and every
  aggregate row carries `n_establishments`, `total_hours` and `total_cases`.
- Nothing below sector / size band / state level. No ranking names an establishment or company.
  Wording is "highest recordable-injury rate among reporting establishments", never "most dangerous".
- Groups with fewer than 30 establishments are shown but marked "insufficient n" and excluded from
  top-10 lists.
- Numbers in notebook markdown come from a cell output above them. Nothing typed in by hand.

## 8. Milestones

### M1 — Environment, load, audit (Sat morning, ~3h)

Build: `.venv` + pinned `requirements.txt`; repo layout + `.gitignore`; raw CSV loaded into `data/leading_indicator.duckdb` as `raw_300a` via `sql/01_load.sql`; `sql/02_audit.sql`; `sql/naics_sectors.csv`; notebook sections 1–2 with executed outputs; first commit.

Acceptance:
- `DESCRIBE raw_300a` printed; every difference from the §4 column list named
- Row count, distinct `establishment_id` count, `year_filing_for` value counts, file size on disk
- Null-rate table, one row per column
- Audit table: check number, description, count, % of raw rows, for all 12 checks
- Markdown cell "Three things that look wrong", each backed by a number from a cell above
- No row dropped, no value altered
- `git log -1` shows Ashvi's identity and no AI-attribution line
- Checkpoint report printed; Claude Code stops. Ashvi returns the exclusion decisions and the recordable-cases decision.

### M2 — Clean table and analysis (Sat afternoon, ~4h)

Build: `sql/03_clean.sql` (creates `clean_300a` with `recordable_cases`, `trir`, `sector`, `size_band`), `sql/04_drop_waterfall.sql`, `sql/05_sector.sql`, `sql/06_size_band.sql`, `sql/07_state.sql`; results written to `output/tables/*.csv`; notebook sections 3–4.

Acceptance:
- Waterfall reconciles exactly; saved as `output/tables/drop_waterfall.csv`
- Overall TRIR of the clean table, the deaths count, and a sanity comparison against the most recent published BLS SOII total recordable case rate (Ashvi looks it up — likely CY2024, since BLS publishes SOII in November — and records the number and URL in a notebook markdown cell)
- `sector_by_rate.csv` and `sector_by_count.csv`, each with `n_establishments`, `total_hours`, `total_cases`, `trir`, `rank_by_rate`, `rank_by_count`
- The difference stated in one sentence with real values: which sectors are top-5 by count but not top-5 by rate, and the reverse. Spearman correlation between the two rankings across sectors as a single summary number (cheap, optional)
- `size_band.csv` (four bands with n, hours, cases, rate) and `state_top10.csv` (by rate, with n; states under 30 establishments flagged)
- Every number in notebook markdown comes from a cell output above it; no literals typed in
- Commit; checkpoint; stop

### M3 — Charts and Excel dashboard (Sun morning, ~3h)

Build: `output/charts/01_sector_by_rate.png`, `02_sector_by_count.png`, `03_size_band_rate.png`, `04_state_top10_rate.png`, drawn from the M2 CSVs (not re-queried); `output/clean_300a.csv` for Excel; `output/dashboard.xlsx` (built by Ashvi in Excel for Mac).

Chart standard: title states the takeaway; axis labels with units ("Recordable cases per 100 full-time workers (TRIR)" / "Recordable cases"); bars sorted; n per bar or in the caption; source line "OSHA ITA Form 300A, CY2025, submissions through 15 Mar 2026"; sector names identical to the SQL output; one colour; no 3-D.

Excel (Ashvi): PivotTable over `clean_300a.csv` — rows = sector, columns = size_band, value = a calculated field `TRIR = recordable_cases * 200000 / total_hours_worked`. A pivot calculated field is evaluated on the summed fields, which is exactly the sum-then-divide rule, and that is the sentence to say in an interview. Colour-scale conditional formatting on the rate cells; slicers for `state` and `sector`.

Acceptance:
- Four PNGs exist; each opened and checked for title, labels, units, n, source
- `dashboard.xlsx` exists; Claude Code confirms with openpyxl that at least one PivotTable is present and prints three sector × size-band rates from SQL for Ashvi to compare against the pivot cells (match to two decimals)
- Commit; checkpoint; stop

### M4 — Write-up, publish, interview notes (Sun afternoon, ~3h)

Build: README (finding as the first sentence → charts 01 and 02 side by side, then 03 and 04 → drop waterfall table → method in five lines → limits → how to run); clean-kernel verification; push; `docs/INTERVIEW_NOTES.md`; resume bullet.

Limits to name: self-reported and not validated by OSHA; reporting thresholds skew the sample toward large and high-hazard establishments, so these are not national rates; one year is not a trend; the 2025 file is a snapshot of submissions through 15 Mar 2026; OSHA's own caution against calling establishments "most dangerous"; which recordable-cases definition was used.

Acceptance:
- `jupyter nbconvert --to notebook --execute notebooks/analysis.ipynb --output /tmp/clean_run.ipynb` exits 0
- README's first sentence is the finding with numbers; every number in the README matches a file in `output/tables/`
- `git ls-files data/` is empty; no `.venv` or `.duckdb` tracked
- Pushed; the GitHub page renders the notebook outputs and the charts
- `docs/INTERVIEW_NOTES.md` written in a fresh Claude Code session that reads the finished repo: plain-English overview; data-flow diagram (CSV → DuckDB → SQL → tables → charts / Excel / README); one query lifecycle; 5–7 design decisions with the rejected alternative (TRIR vs counts; sum-then-divide; exclusion thresholds; OSHA `size` vs computed bands; DuckDB vs pandas-only; pivot in Excel vs Python); the numbers and the one command to reproduce them; 8–10 likely questions with truthful answers; glossary; limitations and next steps
- Resume bullet filled only with values from `output/tables/`

### M4b — Optional regression (only if M4 is done by ~4pm Sunday)

`statsmodels` OLS on the clean table: `trir ~ np.log(annual_average_employees) + C(sector)`. Report the log-employees coefficient with its 95% CI, R², n; one-sentence interpretation. State the simplification: OLS on a rate with many zero-case establishments is a first pass; a Poisson model with `log(total_hours_worked)` as an offset is the rigorous version and goes in "what I'd do next". If M4b is not done, nothing about it appears in the README or on the resume.

## 9. Definition of done

- [ ] Notebook runs top to bottom on a clean kernel (nbconvert exit 0)
- [ ] Every dropped row accounted for: the waterfall reconciles to the clean row count
- [ ] Sector rankings by rate and by count both present; the difference stated in one sentence with numbers
- [ ] Four labelled charts with units, n, and source
- [ ] `dashboard.xlsx` with a working PivotTable and slicers; values match SQL
- [ ] README opens with the finding, not the stack; limits section present
- [ ] Everything pushed; no data, venv, or DuckDB files in the repo
- [ ] Commits under Ashvi's identity, no AI-attribution lines (`git log --format='%an%n%s%n%b'` checked)
- [ ] `docs/INTERVIEW_NOTES.md` present and matches the repo
- [ ] Resume bullet filled with measured values only; anything unmeasured deleted, not softened

## 10. Resume bullet (template — placeholders filled only from `output/tables/`)

Leading Indicator — OSHA Workplace-Injury Rate Analysis | DuckDB, SQL, Python (pandas, matplotlib), Excel PivotTables — Aug 2026
– Analyzed [N] OSHA Form 300A establishment records (CY2025) in DuckDB/SQL; ran 12 data-quality checks and excluded [X]% of rows with every exclusion counted and documented; computed hours-normalized injury rates (TRIR) by sector, establishment size, and state
– Found that ranking sectors by injury rate rather than raw count reorders the top five ([sector A] is #[a] by count but #[b] by rate); delivered four charts, an Excel PivotTable dashboard with slicers, and a one-page write-up with stated limits
[Only if M4b ships: – Fit an OLS model of injury rate on log(establishment size) controlling for sector; [one-clause result with the coefficient sign and CI]]

Note: the current resume targets AI/FDE roles. This bullet belongs in a data-analytics variant, next to the existing "Data & Business Analytics" skills line.

## 11. Human tasks (Ashvi, not Claude Code)

1. Before M1: download the 2025 CSV into `data/`
2. M1 checkpoint: choose the exclusion list and the recordable-cases definition; paste both into §5 and §7
3. M2: look up the latest published BLS SOII total recordable case rate; record the number and URL
4. M3: build the PivotTable, conditional formatting, and slicers in Excel for Mac
5. M4: write the README narrative in her own words — Claude Code drafts the structure and pastes tables and charts; the finding sentence and the limits are hers
6. After M4: read `docs/INTERVIEW_NOTES.md` (~15 min)
