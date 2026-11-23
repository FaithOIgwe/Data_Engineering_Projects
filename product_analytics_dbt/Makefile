export DBT_PROFILES_DIR := .

.PHONY: setup data load build incremental questions chart docs all clean

setup:          ## install dependencies into the current Python env
	pip install -r requirements.txt

data:           ## regenerate the stand-in events and the A/A assignment log (deterministic)
	python scripts/generate_standin_events.py
	python scripts/simulate_aa_assignment.py

load:           ## EL: load data/raw into the DuckDB warehouse
	python scripts/load_raw.py

build: load     ## build every model, run unit tests and data tests
	dbt build --full-refresh

incremental:    ## prove a two-step incremental build equals a full refresh (late-arriving events)
	python scripts/check_incremental.py

questions:      ## check the semantic layer answers the golden questions correctly
	mf validate-configs
	python scripts/check_golden_questions.py

chart:
	python scripts/plot_overview.py

docs:
	dbt docs generate && dbt docs serve

all: build incremental questions

clean:
	dbt clean && rm -f product_analytics.duckdb
