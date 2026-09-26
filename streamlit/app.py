import re

import pandas as pd
import streamlit as st
import snowflake.connector


st.set_page_config(page_title="Commerce Performance | Cortex", page_icon="📊", layout="wide")

st.title("Commerce Performance Intelligence")
st.caption("Snowflake analytics · anomaly detection · human reviewed executive summary")

@st.cache_data(ttl=300, show_spinner="Loading approved summary from Snowflake…")
def load_approved_summary():
    cfg = dict(st.secrets["snowflake"])
    table = cfg.pop("summary_table")
    # Table names cannot be bound as query parameters, so validate the configured identifier.
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*){0,2}", table):
        raise ValueError("summary_table must be a valid Snowflake table name")
    connection = snowflake.connector.connect(**cfg)
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                f"SELECT SUMMARY_TEXT, APPROVED_AT FROM {table} "
                "WHERE UPPER(REVIEW_STATUS) = %s AND SUMMARY_TEXT IS NOT NULL "
                "ORDER BY APPROVED_AT DESC LIMIT 1",
                ("APPROVED",),
            )
            return cursor.fetchone()
    finally:
        connection.close()


summary_row = None
try:
    summary_row = load_approved_summary()
except KeyError:
    st.error("Snowflake configuration is missing. Add the [snowflake] settings described in README.md.")
except Exception as exc:
    st.error(f"Could not load the approved summary: {exc}")

st.subheader("Executive summary")
if summary_row:
    st.caption(f"Approved: {summary_row[1]}")
    st.markdown(summary_row[0])
else:
    st.info("No approved summary is available. Confirm the table and review status in Snowflake.")

st.divider()
st.subheader("Explore supporting data")
st.caption("Upload exported, cleared CSVs to explore the results. Uploaded files are used only in this session.")

tab_kpi, tab_anomaly = st.tabs(["KPI observations", "Anomalies"])


def explore(upload, kind):
    if upload is None:
        st.info(f"Upload a {kind} CSV to show filters, metrics, and rows.")
        return
    try:
        df = pd.read_csv(upload)
    except Exception as exc:
        st.error(f"Could not read CSV: {exc}")
        return
    if df.empty:
        st.warning("The CSV has no rows.")
        return

    filtered = df.copy()
    for field in ("channel", "metric_name", "kpi_name"):
        matches = [col for col in df.columns if col.lower() == field]
        if matches:
            col = matches[0]
            choices = sorted(df[col].dropna().astype(str).unique().tolist())
            selected = st.multiselect(col.replace("_", " ").title(), choices, key=f"{kind}_{field}")
            if selected:
                filtered = filtered[filtered[col].astype(str).isin(selected)]
    st.metric("Rows shown", f"{len(filtered):,}")
    st.dataframe(filtered, use_container_width=True, hide_index=True)
    st.download_button("Download filtered CSV", filtered.to_csv(index=False).encode("utf-8"),
                       file_name=f"filtered_{kind}.csv", mime="text/csv", key=f"download_{kind}")


with tab_kpi:
    kpi_file = st.file_uploader("KPI observations CSV", type="csv", key="kpi")
    explore(kpi_file, "kpis")

with tab_anomaly:
    anomaly_file = st.file_uploader("Anomalies CSV", type="csv", key="anomalies")
    explore(anomaly_file, "anomalies")

st.divider()
st.caption("The narrative is loaded from the most recently approved Snowflake record. Uploaded data should match its reporting period and source run.")
