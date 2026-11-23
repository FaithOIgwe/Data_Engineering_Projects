"""
Proves the incremental model handles late-arriving events.

1. Warehouse A: build with load_cutoff = 2021-01-20 (only what had arrived by then), then run
   again incrementally with everything. This is what production does day after day.
2. Warehouse B: one full refresh with everything.
3. Every mart in A must equal B exactly. Also reports how many events arrived after the cutoff
   for days *before* it: those are the events an incremental filter on event time would lose.

Run from the project root: python scripts/check_incremental.py
"""
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
CUTOFF = "2021-01-20 00:00:00"
MARTS = ["product.fct_sessions", "product.fct_orders", "product.dim_users", "product.fct_retention_weekly",
         "product.fct_feature_adoption_weekly", "experiments.rpt_experiment_readout"]


def dbt(db, *args):
    env = {**os.environ, "DUCKDB_PATH": db, "DBT_PROFILES_DIR": str(ROOT)}
    r = subprocess.run(["dbt", *args, "--target-path", f"target_{Path(db).stem}", "-q"], cwd=ROOT, env=env, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"dbt {' '.join(args)} failed:\n{r.stdout}\n{r.stderr}")


with tempfile.TemporaryDirectory() as tmp:
    a, b = str(Path(tmp) / "incremental.duckdb"), str(Path(tmp) / "full.duckdb")
    for db in (a, b):
        subprocess.run([sys.executable, str(ROOT / "scripts" / "load_raw.py"), db], check=True, capture_output=True)

    dbt(a, "run", "--full-refresh", "--vars", f"{{load_cutoff: '{CUTOFF}'}}")
    dbt(a, "run")
    dbt(b, "run", "--full-refresh")

    con = duckdb.connect(a)
    con.execute(f"attach '{b}' as full_db (read_only)")
    late = con.execute(f"""
        select count(*) from staging.base_ga4__events
        where received_at > timestamp '{CUTOFF}' and event_at < timestamp '{CUTOFF}'
    """).fetchone()[0]
    print(f"events that happened before the cutoff but arrived after it: {late}")

    failures = 0
    for table in MARTS:
        only_a = con.execute(f"select count(*) from (select * from {table} except all select * from full_db.{table})").fetchone()[0]
        only_b = con.execute(f"select count(*) from (select * from full_db.{table} except all select * from {table})").fetchone()[0]
        ok = only_a == 0 and only_b == 0
        failures += not ok
        print(f"{'PASS' if ok else 'FAIL'}  {table:<40} rows only in incremental: {only_a}, only in full refresh: {only_b}")
    for d in Path(ROOT).glob("target_*"):
        subprocess.run(["rm", "-rf", str(d)])
    sys.exit(1 if failures else 0)
