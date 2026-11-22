export DBT_PROFILES_DIR := .

.PHONY: setup data build questions docs chart all clean

setup:          ## install dependencies into the current Python env
	pip install -r requirements.txt

data:           ## regenerate the synthetic raw data (deterministic)
	python scripts/generate_data.py

build:          ## load raw data, build every model, run every test, take the snapshot
	dbt seed
	dbt build --exclude resource_type:seed

questions:      ## check the semantic layer answers the golden questions correctly
	mf validate-configs
	python scripts/check_golden_questions.py

chart:
	python scripts/plot_overview.py

docs:
	dbt docs generate && dbt docs serve

all: build questions

clean:
	dbt clean && rm -f sales_pipeline.duckdb
