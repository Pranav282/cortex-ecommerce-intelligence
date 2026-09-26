from contextlib import closing

import pandas as pd
import snowflake.connector
import streamlit as st

st.set_page_config(page_title="Cortex summary review", layout="wide")
st.title("Executive summary review")
st.caption("Compare responses with stored evidence and save your review to Snowflake.")


def load_summaries(cfg, table):
    with closing(snowflake.connector.connect(**cfg)) as connection:
        with connection.cursor(snowflake.connector.DictCursor) as cursor:
            cursor.execute(
                "SELECT SUMMARY_ID, GENERATED_SUMMARY, PROMPT_TEXT, GENERATED_AT, "
                "PERIOD_START_DATE, PERIOD_END_DATE, REVIEW_STATUS, REVIEWED_BY, "
                "REVIEWED_AT, REVIEW_NOTES FROM IDENTIFIER(%s) ORDER BY GENERATED_AT DESC",
                (table,),
            )
            return cursor.fetchall()


def save_review(cfg, table, row, decision, reviewer, notes):
    with closing(snowflake.connector.connect(**cfg, autocommit=False)) as connection:
        try:
            with connection.cursor() as cursor:
                cursor.execute(
                    "UPDATE IDENTIFIER(%s) SET REVIEW_STATUS = %s, REVIEWED_BY = %s, "
                    "REVIEWED_AT = CURRENT_TIMESTAMP()::TIMESTAMP_NTZ, REVIEW_NOTES = %s "
                    "WHERE SUMMARY_ID = %s AND REVIEW_STATUS = %s "
                    "AND EQUAL_NULL(REVIEWED_AT, %s)",
                    (table, decision, reviewer, notes, row["SUMMARY_ID"],
                     row["REVIEW_STATUS"], row["REVIEWED_AT"]),
                )
                if cursor.rowcount != 1:
                    raise ValueError("Record changed or ID is not unique. Refresh before reviewing again.")
            connection.commit()
        except Exception:
            connection.rollback()
            raise


if "saved_review" in st.session_state:
    st.success(st.session_state.pop("saved_review"))
try:
    cfg = dict(st.secrets["snowflake"])
    table = cfg.pop("summary_table", "CORTEX_ECOMMERCE.AI_GOVERNANCE.EXECUTIVE_SUMMARIES")
except (KeyError, FileNotFoundError, st.errors.StreamlitSecretNotFoundError):
    st.info("Add your Snowflake connection to streamlit/.streamlit/secrets.toml. See streamlit/README.md for setup.")
    st.stop()

st.caption(f"Review table: {table}")
st.button("Refresh records")
try:
    rows = load_summaries(cfg, table)
except Exception:
    st.error("Could not load summaries. Check Snowflake credentials, SELECT permission, and the review-column migration in README.md.")
    st.stop()

status = st.selectbox("Show status", ["PENDING_REVIEW", "APPROVED", "REJECTED", "All"])
visible = [row for row in rows if status == "All" or row["REVIEW_STATUS"] == status]
if not visible:
    st.info("No summaries match this status.")
    st.stop()
by_id = {row["SUMMARY_ID"]: row for row in visible}
selected = st.selectbox("Summary", list(by_id), format_func=lambda key:
    f"{by_id[key]['PERIOD_START_DATE']} to {by_id[key]['PERIOD_END_DATE']} | {key}")
row = by_id[selected]
st.caption(f"Generated: {row['GENERATED_AT']} | Status: {row['REVIEW_STATUS']}")
response, evidence = st.columns(2)
with response:
    st.subheader("Generated response")
    st.markdown(row["GENERATED_SUMMARY"] or "No response text.")
with evidence:
    st.subheader("Stored prompt and evidence")
    st.text(row["PROMPT_TEXT"] or "No stored evidence.")
if row["REVIEWED_AT"]:
    st.caption(f"Last review: {row['REVIEWED_BY']} at {row['REVIEWED_AT']}")

with st.form(f"review_{selected}_{row['REVIEWED_AT']}"):
    reviewer = st.text_input("Reviewer name", value=row["REVIEWED_BY"] or "")
    decision = st.radio("Decision", ["APPROVED", "REJECTED"], index=None)
    notes = st.text_area("Review notes", value=row["REVIEW_NOTES"] or "")
    checked = st.checkbox("I checked the response against the stored evidence.")
    submitted = st.form_submit_button("Save review to Snowflake", type="primary")
if submitted:
    if not reviewer.strip() or not notes.strip() or not decision or not checked:
        st.warning("Enter your name and notes, choose a decision, and confirm the evidence review.")
    else:
        try:
            save_review(cfg, table, row, decision, reviewer.strip(), notes.strip())
        except ValueError as exc:
            st.error(str(exc))
        except Exception:
            st.error("Save failed. Check connection and UPDATE permission. Refresh to verify the record before retrying.")
        else:
            st.session_state["saved_review"] = f"Saved {decision} for summary {selected}."
            st.rerun()

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
st.caption("Uploaded supporting data should match the selected summary reporting period and source run.")


