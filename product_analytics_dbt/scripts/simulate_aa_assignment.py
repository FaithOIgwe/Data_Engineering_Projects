"""
Builds the assignment log for an A/A test on top of whatever events are in
data/raw/ga4_events.csv.gz (the real GA4 sample or the stand-in).

The public GA4 dataset has no experiments in it. An A/A test (both arms get the same
experience) is the honest thing to layer on real traffic: the true effect is zero by
construction, so the readout should show no significant difference and a balanced split.
That makes it a test of the experiment pipeline itself: bucketing, exposure logic,
contamination handling, sample-ratio checks and the statistics.

  - every user who views a product page between 1 Dec 2020 and 15 Jan 2021 is exposed
  - bucketing is a deterministic hash of the device id (like most assignment services)
  - the service logs an exposure on every product page load (capped at 3 per user here)
  - a caching bug re-exposes ~2% of users to the other arm, so they appear in both

Run: python scripts/simulate_aa_assignment.py
"""

import csv
import gzip
import io
import hashlib
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path

random.seed(77)
RAW = Path(__file__).resolve().parents[1] / "data" / "raw"
EXP_ID = "aa_pdp_layout_2020q4"
EXP_START = datetime(2020, 12, 1, tzinfo=timezone.utc)
EXP_END = datetime(2021, 1, 15, tzinfo=timezone.utc)

views = {}
with gzip.open(RAW / "ga4_events.csv.gz", "rt", newline="") as f:
    for r in csv.DictReader(f):
        if r["event_name"] != "view_item":
            continue
        ts = datetime.fromtimestamp(int(r["event_timestamp"]) / 1e6, tz=timezone.utc)
        if EXP_START <= ts < EXP_END:
            views.setdefault(r["user_pseudo_id"], []).append(ts)

exposures = []
for pseudo in sorted(views):
    ts_list = sorted(views[pseudo])
    bucket = int(hashlib.md5(f"{EXP_ID}:{pseudo}".encode()).hexdigest(), 16) % 2
    variant = "control" if bucket == 0 else "treatment"
    for ts in ts_list[:3]:
        exposures.append([EXP_ID, pseudo, variant, ts.strftime("%Y-%m-%d %H:%M:%S")])
    if random.random() < 0.02:
        other = "treatment" if variant == "control" else "control"
        exposures.append([EXP_ID, pseudo, other, (ts_list[0] + timedelta(hours=random.randint(1, 72))).strftime("%Y-%m-%d %H:%M:%S")])

exposures.sort(key=lambda e: (e[3], e[1]))
with open(RAW / "experiment_exposures.csv.gz", "wb") as raw_file, gzip.GzipFile(fileobj=raw_file, mode="wb", mtime=0, filename="") as gz, io.TextIOWrapper(gz, newline="") as f:  # mtime=0 keeps the file byte-identical across runs
    w = csv.writer(f, lineterminator="\n")
    w.writerow(["experiment_id", "user_pseudo_id", "variant", "exposed_at"])
    w.writerows(exposures)
print(f"experiment_exposures.csv.gz: {len(exposures):,} exposures, {len(views):,} users")
