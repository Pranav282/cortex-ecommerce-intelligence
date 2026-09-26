# Cortex summary review

Review generated responses beside their stored prompt and evidence. Save an
APPROVED or REJECTED decision, reviewer name, timestamp, and notes to the
existing EXECUTIVE_SUMMARIES table. Generated response text is preserved.

## Setup

1. Use a role with warehouse/database/schema USAGE and SELECT and UPDATE on
   the summary history table. Target the table, not the approved-only view.
2. Create `streamlit/.streamlit/secrets.toml` (ignored by Git):

```toml
[snowflake]
account = "YOUR_ORG-YOUR_ACCOUNT"
user = "YOUR_USER"
authenticator = "externalbrowser"
warehouse = "YOUR_WAREHOUSE"
database = "CORTEX_ECOMMERCE"
schema = "AI_GOVERNANCE"
role = "YOUR_REVIEW_ROLE"
summary_table = "CORTEX_ECOMMERCE.AI_GOVERNANCE.EXECUTIVE_SUMMARIES"
```

External-browser authentication requires SSO configured for your account.
Alternatively remove `authenticator` and set `password`, or use
`private_key_file` and `private_key_file_pwd` for key-pair authentication.
Never commit credentials.

## Run from the repository root (PowerShell)

```powershell
.\.venv\Scripts\python.exe -m pip install -r streamlit/requirements.txt
Set-Location streamlit
..\.venv\Scripts\python.exe -m streamlit run app.py
```

Open http://localhost:8501. Select a pending summary, compare the response
with its evidence, enter your name and notes, choose a decision, confirm
you checked the evidence, and click **Save review to Snowflake**.
Use the status filter to revisit saved reviews. Concurrent changes cause a
save to fail so you can refresh before reviewing again.

Optional CSV uploads remain available for exploring supporting data.
The app reviews existing responses; it does not generate new ones.
The approved_executive_summaries dbt view reflects approvals automatically
once built. Run `dbt build --project-dir cortex_ecommerce --select
approved_executive_summaries` from the repository root if needed.

Run locally for a trusted reviewer. The reviewer name is self-reported;
add authenticated reviewer identity before hosting a shared instance.
