"""
EL step: loads the raw files in data/raw into the DuckDB warehouse as raw_ga4.events and
raw_experiments.exposures, typed the way BigQuery exports them. In production this is the
GA4 → BigQuery export itself; dbt starts from the raw tables either way.

Run: python scripts/load_raw.py [path/to/warehouse.duckdb]
"""
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
db = sys.argv[1] if len(sys.argv) > 1 else str(ROOT / "product_analytics.duckdb")
raw = ROOT / "data" / "raw"

con = duckdb.connect(db)
con.execute("create schema if not exists raw_ga4")
con.execute("create schema if not exists raw_experiments")
con.execute(f"""
    create or replace table raw_ga4.events as
    select * from read_csv('{raw / "ga4_events.csv.gz"}', header = true, all_varchar = false, nullstr = '',
        types = {{
            'event_date': 'VARCHAR', 'event_timestamp': 'BIGINT', 'user_pseudo_id': 'VARCHAR', 'user_id': 'VARCHAR',
            'user_first_touch_timestamp': 'BIGINT', 'ga_session_id': 'BIGINT', 'ga_session_number': 'BIGINT',
            'engagement_time_msec': 'BIGINT', 'session_engaged': 'VARCHAR', 'transaction_id': 'VARCHAR',
            'purchase_revenue_usd': 'DOUBLE', 'item_count': 'BIGINT', 'event_bundle_sequence_id': 'BIGINT',
            'event_server_timestamp_offset': 'BIGINT'
        }})
""")
con.execute(f"""
    create or replace table raw_experiments.exposures as
    select * from read_csv('{raw / "experiment_exposures.csv.gz"}', header = true,
        types = {{'user_pseudo_id': 'VARCHAR', 'exposed_at': 'TIMESTAMP'}})
""")
for t in ("raw_ga4.events", "raw_experiments.exposures"):
    print(t, con.execute(f"select count(*) from {t}").fetchone()[0])
