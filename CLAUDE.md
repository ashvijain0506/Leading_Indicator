# CLAUDE.md — Leading Indicator

Read `PROJECT_BRIEF.md` (domain spec, hard constraints) and `PRD.md` (milestones, acceptance criteria, locked definitions) before doing anything. On process, `PRD.md` wins; on scope limits, `PROJECT_BRIEF.md` wins. This file is the repo's operating rules and applies in every session.

## Stack — nothing else without asking

- macOS, Python 3 in `.venv`. Packages: `duckdb pandas matplotlib jupyter statsmodels openpyxl` (openpyxl only to verify the Excel file). Pinned in `requirements.txt`.
- Plain SQL in `sql/*.sql`, one query per file, executed from the notebook through a small `run("NN_name.sql")` helper. No ORM, no pipeline framework, no cloud service, no ML library.
- Persistent DuckDB file at `data/leading_indicator.duckdb`. The raw CSV is never modified.
- No new dependency, tool, or feature beyond the PRD milestones. If it seems needed, stop and ask.

## How to work

1. Explain before writing. Before each cell or query: what it does, why, and what output to expect. Ashvi must be able to defend every line in an interview; code she cannot explain is worse than no code.
2. One cell at a time. Add the cell, execute the notebook (`jupyter nbconvert --to notebook --execute --inplace notebooks/analysis.ipynb`), read the real output, then move on. Never generate the whole notebook in one shot.
3. Never invent numbers. Every figure in notebook markdown, the README, or the resume comes from a query that ran, saved under `output/tables/`. Not yet computed → `[TBD]`.
4. Flag surprises. If the data looks odd, say so and stop; never filter silently. Never use `ignore_errors=true` in `read_csv`. Every excluded row is counted and its reason recorded.
5. Sum then divide. Aggregate rates are `SUM(cases) * 200000.0 / SUM(hours)`, never an average of per-establishment rates. Every aggregate carries n, hours, and cases.
6. Wording: "highest recordable-injury rate among reporting establishments". Never "most dangerous". No ranking or chart names an individual establishment or company.
7. Paths in the notebook are anchored to the repo root so it runs from both Jupyter and `nbconvert`.

## Milestone gating

- One milestone at a time. Stop at the end of each and print the checkpoint report. Do not start the next milestone until the human sends its prompt.
- Do not proceed past a failing acceptance criterion. Report the failure and stop.
- M2 does not start until the exclusion list (`PRD.md` §7) and the recordable-cases definition (`PRD.md` §5) have been written in by the human.

Checkpoint report format — end every milestone with exactly these six headings:

1. What was built
2. Commands run + real output (verbatim, trimmed to the relevant lines)
3. Test / verification results verbatim (row counts, audit table, nbconvert exit code)
4. Files changed (`git status --short` and `git log --oneline -5`)
5. Open problems and surprises
6. What M(n+1) needs from the human

## Git rules

- Before any git command: `git rev-parse --show-toplevel` must print this repo's path. If it prints anything else, or the home directory, stop and report.
- `git add` takes explicit paths only. Never `git add -A`, `git add .`, or `git commit -a`.
- Never stage `data/`, `*.duckdb`, `.venv/`, `.ipynb_checkpoints/`, or anything under `/tmp`. Run `git status --short` before every commit.
- At least one commit per milestone with a descriptive message (`m1: load CY2025 300A data into DuckDB and run 12 audit checks`). No end-of-day squash.
- Commits are authored solely under Ashvi's git identity. Never add `Co-Authored-By` trailers, "Generated with Claude Code" lines, or any AI attribution to commit messages or PR descriptions — not as a trailer, not in the body. After the first commit, run `git log -1` and confirm.
- Commit the executed notebook with its outputs (GitHub renders them), the PNGs, and `dashboard.xlsx`. Never the raw CSV.

## Secrets

None are needed for this project. `.gitignore` covers `.venv/`, `data/`, `*.duckdb`, `.ipynb_checkpoints/`, `.DS_Store`. If a key or token ever appears anywhere in the repo, stop and report before doing anything else.

## Verification commands

- Clean-kernel run: `jupyter nbconvert --to notebook --execute notebooks/analysis.ipynb --output /tmp/clean_run.ipynb` (exit 0)
- Nothing tracked that shouldn't be: `git ls-files data/` is empty; `git ls-files | grep -E '\.duckdb$|^\.venv/'` is empty
- Attribution: `git log --format='%an%n%s%n%b' | grep -i -E 'co-authored|claude'` is empty
- Excel pivot present: openpyxl `load_workbook(...)`, then any worksheet whose `ws._pivots` is non-empty
