"""Draw the four charts from the CSVs in output/tables/.

The charts read the saved query results rather than re-querying, so a chart can
never disagree with the table behind it.  Run:  python scripts/make_charts.py
"""
import pathlib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import pandas as pd

REPO = pathlib.Path(__file__).resolve().parents[1]
TABLES, CHARTS = REPO / "output" / "tables", REPO / "output" / "charts"
CHARTS.mkdir(parents=True, exist_ok=True)

SOURCE = "Source: OSHA Injury Tracking Application, Form 300A summary data, CY2025 (submissions through 15 Mar 2026)."
RATE_LABEL = "Recordable cases per 100 full-time workers (TRIR)"
BAR = "#3f6f8e"
TOP_N = 10


def _finish(fig, ax, path, note):
    ax.spines[["top", "right"]].set_visible(False)
    ax.grid(axis="x" if ax.get_yticklabels() and ax.get_xlabel() else "y", alpha=0.3, linewidth=0.6)
    caption = SOURCE + note
    fig.text(0.01, 0.012, caption, fontsize=6.5, color="#555", wrap=True)
    # Reserve footer space proportional to the caption's line count. A fixed 9% collided
    # with the x-axis label on the charts with five-line captions.
    n_lines = caption.count("\n") + 1
    bottom = 0.014 + (n_lines * 9.5 + 8) / (fig.get_figheight() * 72)
    fig.tight_layout(rect=(0, bottom, 1, 1))
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print("wrote", path.relative_to(REPO))


def _hbar(df, value, label_col, title, xlabel, path, note="", fmt="{:.2f}", xpad=1.28):
    d = df.iloc[::-1]
    fig, ax = plt.subplots(figsize=(10, 0.42 * len(d) + 2.6))
    ax.barh(d[label_col], d[value], color=BAR)
    for y, (v, n) in enumerate(zip(d[value], d.n_establishments)):
        ax.text(v, y, f"  {fmt.format(v)}  (n={int(n):,})", va="center", fontsize=8, color="#333")
    ax.set_xlabel(xlabel)
    ax.set_title(title, loc="left", fontsize=12, fontweight="bold")
    ax.set_xlim(0, d[value].max() * xpad)
    if d[value].max() >= 10_000:
        # Six-digit ticks run together without separators and thinning.
        ax.xaxis.set_major_locator(mticker.MaxNLocator(nbins=6))
        ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: f"{v:,.0f}"))
    _finish(fig, ax, path, note)


def main():
    sector = pd.read_csv(TABLES / "sector_by_rate.csv")
    ranked = sector[sector.note != "insufficient n"]

    _hbar(ranked.nsmallest(TOP_N, "rank_by_rate"), "trir", "sector",
          f"Top {TOP_N} sectors by injury RATE", RATE_LABEL,
          CHARTS / "01_sector_by_rate.png",
          note=" n = reporting establishments in the cleaned data. Rate = total cases / total hours for the sector.")

    _hbar(ranked.nsmallest(TOP_N, "rank_by_count"), "total_cases", "sector",
          f"Top {TOP_N} sectors by injury COUNT", "Total recordable cases",
          CHARTS / "02_sector_by_count.png",
          note=" Count largely tracks sector employment; compare the ordering with chart 01.",
          fmt="{:,.0f}", xpad=1.52)

    size = pd.read_csv(TABLES / "size_band.csv").sort_values("size_order")
    fig, ax = plt.subplots(figsize=(8.5, 5.0))
    ax.bar(size.size_band, size.trir, color=BAR)
    for x, (v, n) in enumerate(zip(size.trir, size.n_establishments)):
        ax.text(x, v, f"{v:.2f}\n(n={int(n):,})", ha="center", va="bottom", fontsize=8, color="#333")
    ax.set_xlabel("Establishment size (annual average employees)")
    ax.set_ylabel(RATE_LABEL)
    ax.set_title("Injury rate by establishment size", loc="left", fontsize=12, fontweight="bold")
    ax.set_ylim(0, size.trir.max() * 1.22)
    _finish(fig, ax, CHARTS / "03_size_band_rate.png",
            "\nBands derived from annual average employees, not OSHA's size code. The Under-20 band is not a clean read on small"
            "\nworkplaces: it mixes genuinely small establishments (largely exempt from routine reporting, so self-selected toward"
            "\nhigh-hazard industries) with seasonal establishments whose peak headcount is far above their annual average."
            "\nSector mix also differs across bands and is not controlled for here; the optional regression (M4b) is the test"
            "\nof whether size still matters once sector is accounted for.")

    state = pd.read_csv(TABLES / "state_top10.csv")
    _hbar(state, "trir", "state",
          "Top 10 states by injury rate", RATE_LABEL,
          CHARTS / "04_state_top10_rate.png",
          note="\nStates with under 30 reporting establishments are excluded. Industry mix does not explain this ranking: giving Maine"
               "\nits own mix of hours but the national rate for each sector yields an expected 3.54, against its actual 6.24 and a"
               "\nnational 3.48 - mix accounts for 2.3% of the gap. Maine reports higher rates within nearly every sector (manufacturing"
               "\n5.08 vs 2.54 nationally). The remaining candidate is difference in reporting practice and completeness between states."
               "\nThis cannot distinguish more injuries occurring from more injuries being recorded and submitted.")


if __name__ == "__main__":
    main()
