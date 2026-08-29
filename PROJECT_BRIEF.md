# Leading Indicator — Project Brief

Paste this into the repo root as `PROJECT_BRIEF.md` (or rename to `CLAUDE.md` so Claude Code
picks it up automatically). It is written to be handed to Claude Code in VS Code.

---

## What this is

A two-day data analysis project on US workplace injury data. The question:
**which kinds of workplaces are actually the most dangerous, and why the obvious answer is wrong.**

Raw injury counts mostly track how many people a company employs. Normalising by hours worked
gives a comparable rate (TRIR), and the ranking by rate differs from the ranking by count.
That difference is the finding.

Built by Ashvi Jain, Drexel CS, targeting Fall/Winter 2026 co-op roles in data analytics.

## Hard constraints

- **macOS.** Everything must run natively. No Power BI Desktop, no Windows-only tools.
- **Free tools only.** DuckDB, Python (pandas, matplotlib, statsmodels), Jupyter, Excel.
- **Two days.** Saturday is data work, Sunday is presentation. Scope accordingly.
- **First co-op level.** Clear and correct beats clever. No star schemas, no ML pipelines,
  no orchestration frameworks.

## Data

OSHA Injury Tracking Application, Form 300A summary data. One row per establishment per year.
Public, no login required.

Source: https://www.osha.gov/Establishment-Specific-Injury-and-Illness-Data
Take **one recent year**. The 2025 file is a plain CSV; earlier years are ZIPs.

Key columns (confirm with `DESCRIBE` first, names shift slightly between years):

| Column | Meaning |
|---|---|
| `establishment_name` | workplace name |
| `naics_code` | industry code, first 2 digits give the sector |
| `state` | two-letter state |
| `annual_average_employees` | headcount |
| `total_hours_worked` | denominator for the rate |
| `total_deaths`, `total_dafw_cases`, `total_djtr_cases`, `total_other_cases` | the four recordable case types |

`recordable cases = deaths + dafw + djtr + other`

## The metric

```
TRIR = (recordable cases * 200,000) / total hours worked
```

200,000 = 100 employees x 40 hours x 50 weeks. This is the real OSHA industry metric,
not something invented for the project.

**Critical:** when aggregating to industry or state level, sum the cases and sum the hours,
then divide. Do NOT average the per-establishment rates. Averaging treats a 10-person shop
the same as a 5,000-person plant and gives the wrong answer.

## Build order

### Saturday — data work

1. **Load and look.** Read the CSV into DuckDB. Row count, column list, null rate per column.
   Write down three things that look wrong.
2. **Find the broken rows.** Count how many records fail each check:
   - missing `total_hours_worked`
   - `annual_average_employees = 0`
   - `total_hours_worked < 1000` (implausible, and it produces absurd rates)
   - missing or malformed `naics_code`
   - injuries greater than employee count

   Record these counts. They go in the write-up and on the resume.
3. **Build the clean table** with `trir` computed per row, excluding the failing records.
   State how many rows were dropped and why.
4. **Analyse.** Industries by rate. Industries by raw count. Compare the two lists.
   Then by establishment size band, then by state.

### Sunday — presentation

5. **Four charts** in matplotlib: industries by rate, industries by count side by side,
   rate by size band, top ten states. Axis labels and units on every one.
6. **Excel dashboard.** Export the clean table to CSV, build a PivotTable of industry against
   size band with rate in the cells, conditional formatting, slicers for state and industry.
7. **Write-up.** One page. Finding in the first sentence, then evidence, then limits.
   Limits to name: self-reported data, small employers are exempt from reporting,
   one year is not a trend.
8. **Publish.** Push notebook, SQL, Excel file, and README to GitHub.

### Optional, only if Sunday is going well

9. **One regression** with statsmodels: does establishment size predict injury rate once
   industry is accounted for? Roughly `trir ~ log(employees) + C(industry)`.
   This is honest statistical analysis and it matches the Charles River posting's
   "perform statistical analysis to identify trends" line.

## Definition of done

- [ ] Notebook runs top to bottom without errors on a clean kernel
- [ ] Every dropped row is accounted for with a count and a reason
- [ ] Industry rankings by rate and by count both present, and the difference is stated
- [ ] Four labelled charts
- [ ] Excel file with a working PivotTable
- [ ] README opens with the finding, not the tech stack
- [ ] Everything pushed to GitHub

## Rules for Claude Code

1. **Explain before writing.** For each step, say what it does and why before producing code.
   Ashvi has to defend every line of this in an interview. Code she cannot explain is worse
   than no code.
2. **Small steps.** One cell at a time, run it, check the output, then move on.
   Do not generate the whole notebook in one shot.
3. **Never invent numbers.** Every figure in the README and on the resume must come from a
   query that actually ran. If a number is not yet computed, leave a placeholder.
4. **Prefer plain SQL and pandas.** No ORM, no pipeline framework, no cloud services.
5. **Flag surprises.** If the data looks odd, say so rather than silently filtering it out.

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install duckdb pandas matplotlib jupyter statsmodels
jupyter notebook
```

## Repo layout

```
leading-indicator/
  README.md              <- finding first, then charts, then method
  PROJECT_BRIEF.md       <- this file
  notebooks/analysis.ipynb
  sql/                   <- the queries, as .sql files
  data/                  <- raw CSV, gitignored if large
  output/
    charts/              <- the four PNGs
    dashboard.xlsx
```

Add a `.gitignore` for `.venv/`, `data/`, and `*.duckdb`.
