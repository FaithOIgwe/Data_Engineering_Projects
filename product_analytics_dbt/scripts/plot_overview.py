"""Renders docs/img/overview.png from the built warehouse. Run after `dbt build`."""
import duckdb
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

con = duckdb.connect("product_analytics.duckdb", read_only=True)
cohorts = con.execute("""
    -- the week of 26 Oct only holds 1 Nov (data starts that Sunday), so it is left out
    select date_trunc('month', cohort_week + interval 3 day) as cohort_month, week_number,
           sum(retained_users) * 1.0 / sum(cohort_users) as retention
    from product.fct_retention_weekly
    where is_complete and week_number between 1 and 8 and cohort_week >= date '2020-11-02'
    group by 1, 2 order by 1, 2
""").fetchall()
readout = con.execute("""
    select metric, relative_lift, ci_95_lower / mean_control, ci_95_upper / mean_control, p_value
    from experiments.rpt_experiment_readout
    where population = 'primary' order by metric desc
""").fetchall()

INK, MUTED, GRID = "#10140F", "#4A5049", "#E3E6E0"
SHADES = ["#9CC9B0", "#3F8F66", "#0B5D3B"]  # one hue, light to dark = older to newer cohort
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 11, "text.color": INK,
                     "axes.labelcolor": MUTED, "xtick.color": MUTED, "ytick.color": MUTED})
fig, (left, right) = plt.subplots(1, 2, figsize=(13, 5.2), gridspec_kw={"width_ratios": [1.1, 1]})

months = sorted({c[0] for c in cohorts})
for i, m in enumerate(months):
    pts = [(w, r * 100) for cm, w, r in cohorts if cm == m]
    xs, ys = zip(*pts)
    left.plot(xs, ys, color=SHADES[i % 3], lw=2, label=m.strftime("%b %Y cohort"))
    left.scatter(xs, ys, color=SHADES[i % 3], s=28, zorder=3, edgecolor="white", linewidth=1.5)
left.set_xticks(range(1, 9)); left.set_xlabel("Weeks after first visit")
left.legend(frameon=False, fontsize=10, loc="upper right")
left.yaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(lambda v, _: f"{v:.0f}%"))
left.set_ylim(0, None)
left.grid(axis="y", color=GRID); left.set_axisbelow(True)
for sp in ["top", "right", "left"]:
    left.spines[sp].set_visible(False)
left.spines["bottom"].set_color(GRID)
left.set_title("Weekly retention by first-visit month\n(engaged session in that week)", loc="left", fontsize=13, pad=12)

labels = {"add_to_cart_rate": "Add-to-cart rate", "checkout_rate": "Checkout rate",
          "conversion_rate": "Conversion rate", "revenue_per_user": "Revenue per user"}
for i, (metric, lift, lo, hi, p) in enumerate(readout):
    right.plot([lo * 100, hi * 100], [i, i], color="#0B5D3B", lw=2)
    right.scatter([lift * 100], [i], color="#0B5D3B", s=40, zorder=3, edgecolor="white", linewidth=1.5)
    right.text(hi * 100 + 1.5, i, f"p = {p:.2f}", va="center", fontsize=9.5, color=MUTED)
right.axvline(0, color=INK, lw=1)
right.set_yticks(range(len(readout))); right.set_yticklabels([labels[r[0]] for r in readout])
right.xaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(lambda v, _: f"{v:+.0f}%"))
right.set_xlabel("Treatment vs control, relative difference with 95% CI")
right.grid(axis="x", color=GRID); right.set_axisbelow(True)
for sp in ["top", "right", "left"]:
    right.spines[sp].set_visible(False)
right.spines["bottom"].set_color(GRID)
xmax = max(abs(r[2]) for r in readout) * 100 + 12
right.set_xlim(-xmax, xmax)
right.set_title("A/A test readout: every interval crosses zero\n(contaminated users excluded, split is balanced)", loc="left", fontsize=13, pad=12)

fig.text(0.01, 0.01, "product_analytics_dbt · dbt + DuckDB · GA4 export schema (stand-in data)", fontsize=9, color=MUTED)
plt.tight_layout(rect=(0, 0.03, 1, 1))
plt.savefig("docs/img/overview.png", dpi=160, facecolor="white")
