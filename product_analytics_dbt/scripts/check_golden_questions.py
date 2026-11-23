"""
Checks that the semantic layer answers a set of real business questions the same way an
independent SQL query against the marts does.

Needs: a built DuckDB warehouse (dbt build) and MetricFlow (`pip install "dbt-metricflow[dbt-duckdb]"`).
Run from the project root:  python scripts/check_golden_questions.py
"""

import csv
import subprocess
import sys
import tempfile
from pathlib import Path

import duckdb
import yaml

ROOT = Path(__file__).resolve().parents[1]
TOLERANCE = 0.005  # relative


def semantic_answer(q):
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "answer.csv"
        cmd = ["mf", "query", "--metrics", ",".join(q["metrics"]), "--where", q["where"], "--csv", str(out)]
        result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(f"mf query failed for {q['id']}:\n{result.stdout}\n{result.stderr}")
        with out.open() as f:
            rows = list(csv.DictReader(f))
    values = [r[q["metrics"][0]] for r in rows if r[q["metrics"][0]] not in ("", None)]
    return float(values[0]) if values else None


def main():
    questions = yaml.safe_load((ROOT / "evals" / "golden_questions.yml").read_text())["questions"]
    # Reference answers first, then release the DuckDB file so MetricFlow can open it.
    con = duckdb.connect(str(ROOT / "product_analytics.duckdb"), read_only=True)
    expected_by_id = {}
    for q in questions:
        value = con.execute(q["reference_sql"]).fetchall()[0][0]
        expected_by_id[q["id"]] = float(value) if value is not None else None
    con.close()

    failures = 0
    for q in questions:
        expected = expected_by_id[q["id"]]
        actual = semantic_answer(q)
        ok = (expected is None and actual is None) or (
            expected is not None and actual is not None
            and abs(actual - expected) <= TOLERANCE * max(abs(expected), 1e-9)
        )
        failures += not ok
        print(f"{'PASS' if ok else 'FAIL'}  {q['id']:<38} semantic={actual!s:<22} reference={expected}")
        print(f"      {q['question']}")
    print(f"\n{len(questions) - failures}/{len(questions)} golden questions agree")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
