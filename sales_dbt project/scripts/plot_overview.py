"""Renders docs/img/pipeline_overview.png from the built warehouse. Run after `dbt build`."""
import duckdb
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

MIN_CLOSED_DEALS = 20  # skip quarters too small for a win rate to mean anything

con = duckdb.connect("sales_pipeline.duckdb", read_only=True)
stages = con.execute("""
    select stage_label, stage_order, count(*), avg(reached_next_stage::int)
    from sales.fct_stage_reached where pipeline_id = 'default' group by 1, 2 order by 2
""").fetchall()
won = con.execute("select count(*) from sales.fct_deals where pipeline_id = 'default' and deal_status = 'Won'").fetchall()[0][0]
quarters = con.execute(f"""
    select date_trunc('quarter', close_date) as q, avg((deal_status = 'Won')::int) as win_rate, count(*) as n
    from sales.fct_deals
    where deal_type = 'New business' and deal_status <> 'Open' and close_date < '2026-10-01'
    group by 1 having count(*) >= {MIN_CLOSED_DEALS} order by 1
""").fetchall()

INK, MUTED, GRID, GREEN = "#10140F", "#4A5049", "#E3E6E0", "#0B5D3B"
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 11, "text.color": INK,
                     "axes.labelcolor": MUTED, "xtick.color": MUTED, "ytick.color": MUTED})
fig, (left, right) = plt.subplots(1, 2, figsize=(13, 5.2), gridspec_kw={"width_ratios": [1.1, 1]})

labels = [s[0] for s in stages] + ["Closed Won"]
values = [s[2] for s in stages] + [won]
y = list(range(len(labels)))[::-1]
left.barh(y, values, color=GREEN, height=0.62)
for yi, v, lab in zip(y, values, labels):
    left.text(-12, yi, lab, ha="right", va="center", color=INK)
    left.text(v + 12, yi, f"{v:,}", va="center", fontsize=10.5, color=INK)
for i, s in enumerate(stages):
    left.text(max(values) * 0.98, y[i] - 0.5, f"↓ {s[3]:.0%} move on", ha="right", va="center", fontsize=9.5, color=MUTED)
left.set_yticks([]); left.set_xticks([])
for sp in left.spines.values():
    sp.set_visible(False)
left.set_xlim(0, max(values) * 1.12)
left.set_title("New-business deals reaching each stage\n(skipped stages count as reached)", loc="left", fontsize=13, pad=12)

ticks = [f"Q{(q[0].month - 1) // 3 + 1}" + (f"\n{q[0].year}" if i == 0 or q[0].month == 1 else "") for i, q in enumerate(quarters)]
rates = [q[1] * 100 for q in quarters]
right.plot(range(len(rates)), rates, color=GREEN, lw=2)
right.scatter(range(len(rates)), rates, color=GREEN, s=40, zorder=3, edgecolor="white", linewidth=2)
right.set_xticks(range(len(ticks))); right.set_xticklabels(ticks, fontsize=9.5)
right.set_ylim(0, max(rates) * 1.25)
right.yaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(lambda v, _: f"{v:.0f}%"))
right.grid(axis="y", color=GRID, lw=1); right.set_axisbelow(True)
for sp in ["top", "right", "left"]:
    right.spines[sp].set_visible(False)
right.spines["bottom"].set_color(GRID)
right.annotate(f"{rates[-1]:.0f}%", (len(rates) - 1, rates[-1]), xytext=(6, 8), textcoords="offset points", fontsize=10.5)
right.set_title("Win rate by quarter, by HubSpot close date\n(won ÷ won + lost)", loc="left", fontsize=13, pad=12)

fig.text(0.01, 0.01, f"sales-pipeline-analytics · dbt + DuckDB · synthetic HubSpot-shaped data · quarters with < {MIN_CLOSED_DEALS} closed deals not shown",
         fontsize=9, color=MUTED)
plt.tight_layout(rect=(0.06, 0.03, 1, 1))
plt.savefig("docs/img/pipeline_overview.png", dpi=160, facecolor="white")
