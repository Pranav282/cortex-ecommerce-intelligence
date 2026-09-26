# Cortex Commerce Performance app

A read-only Streamlit presentation that automatically loads the latest approved executive summary from Snowflake. KPI observations and anomalies can be explored through optional CSV uploads.

## Before publishing

1. Identify the Snowflake table or view containing the reviewed summaries. It must expose `SUMMARY_TEXT`, `REVIEW_STATUS`, and `APPROVED_AT`. If your actual columns differ, adapt the query in `app.py` or create a view with these aliases. `APPROVED_AT` should be populated on approval.
2. Give a dedicated, read-only Snowflake role `SELECT` access to that table or view.
3. Confirm the period, counts, and insights against the final scoring run. Export only data you may share.
4. Optionally prepare KPI and anomaly CSV files. The app accepts any column set; columns named `channel`, `metric_name`, or `kpi_name` receive filters. Keep an `evidence_id` column in the anomaly export when available.

Create `.streamlit/secrets.toml` locally (it is ignored by Git):

```toml
[snowflake]
account = "your_account_identifier"
user = "your_read_only_user"
password = "your_password"
warehouse = "your_warehouse"
database = "your_database"
schema = "your_schema"
role = "your_read_only_role"
summary_table = "YOUR_DATABASE.YOUR_SCHEMA.YOUR_APPROVED_SUMMARIES_VIEW"
```

The app queries the latest row whose `REVIEW_STATUS` is `APPROVED`, ordered by `APPROVED_AT`. The summary refreshes at most every five minutes while the app is active. To show a specific reporting run instead, add a reporting-period condition to the query.

## Run locally

```bash
python -m venv .venv
pip install -r requirements.txt
streamlit run app.py
```

## Deploy

Push this folder's files to a GitHub repository. In Streamlit Community Cloud, create an app from that repository and choose `app.py` as its entry point. Copy your local secrets values into the app's Secrets settings; never commit `secrets.toml`. Set visibility appropriately before sharing its URL. The app connects to Snowflake on the server to retrieve approved text; visitors do not enter credentials.
