# CortexEcommerce

CortexEcommerce is an end-to-end eCommerce analytics and AI-governance project built on Snowflake and dbt. It transforms TheLook event and transaction data into tested customer-lifecycle and go-to-market (GTM) marts, detects unusual KPI behavior with Snowflake ML, and generates traceable executive summaries with Snowflake Cortex.

## Project status

| Area | Status | Current implementation |
|---|---|---|
| Data ingestion | Complete | Python extraction from BigQuery and loading into Snowflake, using Parquet as the intermediate format |
| Analytics engineering | Complete | Staging, intermediate, core, customer-lifecycle, GTM, and monitoring models in dbt |
| Data quality | Complete | Source, relationship, uniqueness, accepted-value, range, and not-null tests |
| KPI anomaly detection | Complete | Multi-series Snowflake ML anomaly detection with persisted results and documented series exclusions |
| Cortex executive summaries | Complete | Evidence input, versioned prompt, generated output, model metadata, timestamp, and review status are persisted |
| Technical AI validation | Complete | SQL checks for completeness, identifiers, reporting periods, metadata, review statuses, and output length |
| Human grounding review | In progress | Approved-only dbt view is defined; review metadata provisioning and formal claim-by-claim review remain to be completed |
| Streamlit application | Planned | Interactive KPI, anomaly, evidence, and human-review interface |

## Business questions

The analytical layer is designed to answer questions such as:

- Which acquisition channels generate traffic, conversions, repeat customers, and revenue?
- Where do users drop out of the browse-to-purchase funnel?
- Which customer segments contribute the most value?
- How does retention change across acquisition cohorts?
- Which products, categories, brands, and geographies perform best?
- Which daily business KPIs fall outside their expected ranges?
- Can an executive summary be generated from controlled evidence and retained for review?

## Architecture

```mermaid
flowchart TD
    A["TheLook on BigQuery"] --> B["Python extraction"]
    B --> C["Parquet files"]
    C --> D["Snowflake raw tables"]
    D --> E["dbt staging and intermediate models"]
    E --> F["Customer lifecycle and GTM marts"]
    E --> G["Daily KPI monitoring mart"]
    G --> H["Snowflake ML anomaly detection"]
    H --> I["Controlled executive-summary evidence"]
    I --> J["Snowflake Cortex summary"]
    J --> K["Governed output and review status"]
    K --> L["Human evidence review"]
    L --> M["Approved-only summary view"]
```

## Data

The project uses the public TheLook eCommerce dataset, including users, orders, order items, products, inventory, distribution centers, and website events.

The source supports behavioral funnel analysis alongside transactional, customer, product, channel, cohort, and geographic analysis.

## Analytics layers

### Staging

Seven Snowflake source tables are cleaned and standardized through dbt staging models. Rejected order-item records are isolated explicitly instead of being silently discarded.

### Intermediate and core

- `int_customer_orders`: reusable customer-order metrics
- `int_session_funnel`: session-level funnel and abandonment behavior
- `dim_customer`: customer dimension enriched with lifecycle attributes

### Customer lifecycle marts

- `mart_customer_360`
- `mart_customer_rfm`
- `mart_customer_segment_summary`

### GTM marts

- `mart_acquisition_channel_performance`
- `mart_conversion_funnel`
- `mart_customer_cohort_retention`
- `mart_geographic_performance`
- `mart_gtm_channel_summary`
- `mart_product_performance`

### Monitoring and AI governance

- `mart_daily_business_kpis`: daily operational KPI layer
- `int_kpi_anomaly_input`: training/scoring input for multiple KPI series
- `KPI_ANOMALY_RESULTS`: persisted forecasts, prediction intervals, and anomaly flags
- `KPI_ANOMALY_EXCLUSIONS`: auditable list of KPI series skipped during scoring
- `EXECUTIVE_SUMMARY_INPUT`: controlled, non-PII evidence supplied to Cortex
- `EXECUTIVE_SUMMARIES`: incremental narrative history with input hash, prompt, model, version, timestamp, and review status
- `APPROVED_EXECUTIVE_SUMMARIES`: view exposing only rows marked `APPROVED`, including reviewer metadata

## AI and ML workflow

1. dbt produces the daily KPI monitoring mart.
2. The KPI input is separated into chronological training and scoring periods.
3. Snowflake ML fits a multi-series anomaly detector and scores future observations.
4. Scored anomalies and exclusions are persisted in the governance schema.
5. SQL assembles a constrained evidence package from KPIs and anomaly results.
6. The `executive_summaries` dbt model calls Snowflake Cortex with `llama3.3-70b` for inputs not already stored with the same input hash, model, and prompt version.
7. The prompt, response, model, versions, generation timestamp, and `PENDING_REVIEW` status are stored.
8. Technical SQL and dbt checks validate structure and metadata.
9. A human reviews claims against the evidence and records a review decision.
10. The `approved_executive_summaries` view exposes only approved outputs once its required review metadata columns are available.

The generated narrative is therefore treated as a reviewable analytical artifact, not automatically as verified truth.

## Technology stack

### Implemented

- Snowflake
- dbt Core with `dbt-snowflake` and `dbt-utils`
- SQL
- Python
- BigQuery client libraries
- Parquet
- Snowflake ML anomaly detection
- Snowflake Cortex AI functions
- Git and GitHub

### Planned extensions

- Streamlit for interactive analytics and human review
- Snowpark for application-side transformations or model workflows
- Purchase-propensity and customer-risk models
- Automated claim-to-evidence validation
- CI/CD and scheduled orchestration

## Repository structure

```text
.
├── cortex_ecommerce/
│   ├── macros/
│   ├── models/
│   │   ├── governance/
│   │   ├── intermediate/
│   │   ├── marts/
│   │   └── staging/
│   ├── snowflake/
│   │   ├── cortex/
│   │   └── ml/
│   ├── dbt_project.yml
│   └── packages.yml
├── scripts/
│   ├── extract_thelook.py
│   ├── load_thelook_to_snowflake.py
│   └── test_bigquery_connection.py
└── requirements.txt
```

## Running the project

### Prerequisites

- Python environment with the packages in `requirements.txt`
- Google Cloud credentials with access to the public TheLook dataset
- Snowflake account, warehouse, database, schemas, and project role
- dbt profile named `cortex_ecommerce`

Keep credentials outside Git. The repository does not require `profiles.yml`, passwords, private keys, or service-account files to be committed.

### Build and test the dbt project

```bash
cd cortex_ecommerce
dbt deps
dbt debug
dbt build --exclude tag:post_training
```

### Run Snowflake AI workflows

The initial dbt build creates the ML training and scoring inputs in `ML`.
Then run these steps in order from the dbt project directory:

1. Run `snowflake/ml/train_kpi_anomaly_detector.sql` in Snowflake to train `ML.KPI_ANOMALY_DETECTOR_V2`. Its grant step requires an administrative role.
2. Run `dbt build --select tag:post_training --exclude tag:summary_generation tag:summary_publication` to create `AI_GOVERNANCE.KPI_ANOMALY_RESULTS`, `KPI_ANOMALY_EXCLUSIONS`, and `EXECUTIVE_SUMMARY_INPUT` in dependency order.
3. Run `snowflake/ml/validate_anomaly_results.sql` manually in Snowflake.
4. Run `dbt run --select executive_summaries` to generate and store the executive summary.
5. Run `snowflake/cortex/validate_ai_output.sql` manually in Snowflake after generation.
6. After provisioning review metadata and recording human review decisions (see below), run `dbt build --select approved_executive_summaries` to create and test the approved-only view.

Training is external to dbt's model graph; the scoring model requires the trained
object in the target database's `ML` schema. The standalone Snowflake scripts
use `CORTEX_ECOMMERCE`, so use that database in the dbt target for this workflow.
Rebuild inputs and rerun training before scoring when refreshing the detector.
Validation scripts remain manual and are not executed by dbt.

`models/governance/executive_summaries.sql` serializes the input model's
`cortex_input` as JSON using prompt version `v2.0` and `llama3.3-70b`.
The prompt distinguishes model expectations from prior-period comparisons,
uses KPI `desired_direction`, and requires anomaly evidence citations.

The model appends new summaries and preserves earlier review statuses. On
incremental runs, it skips an input when its `input_hash`, `model_name`, and
`prompt_version` already exist. New rows use `PENDING_REVIEW`; full refresh is
disabled to preserve history. Bump `prompt_version` when changing the prompt
so existing inputs can be regenerated under the new version.

A general `dbt run` or `dbt build` includes generation and publication. Exclude
`tag:summary_generation tag:summary_publication` when building only upstream
models. To refresh the input and generate a summary together, run:

```bash
dbt run --select executive_summary_input executive_summaries
```

Run these commands from `cortex_ecommerce/`. From the repository root, add
`--project-dir cortex_ecommerce` to the dbt command. Credentials must be set
in the terminal running dbt. Validation SQL remains manual in `snowflake/`.

### Human review and approved publication

`approved_executive_summaries` is a view over `executive_summaries` filtered to
`review_status = 'APPROVED'`. Pending, rejected, and any other statuses are
excluded. The view does not approve summaries or perform grounding checks.
Reviewers must verify the narrative against the stored evidence before recording
approval. Once the view exists, changes to review status are reflected without
regenerating summaries.

The view selects `reviewed_by`, `reviewed_at`, and `review_notes`, but the current
`executive_summaries` model does not create those columns. Provision them on the
underlying history table through a schema migration before building the view;
a fresh build alone does not yet provide a complete review workflow. Existing
history tables also need `input_hash` before the incremental generation query
can use its deduplication check.

The review-status documentation currently includes `NEEDS_REVISION` in one
place, while the original accepted-values test and manual validation still
allow only `PENDING_REVIEW`, `APPROVED`, and `REJECTED`. Align those checks before
using `NEEDS_REVISION` as a stored status.

## Known limitations

- One KPI series was skipped during anomaly scoring after a series-specific Snowflake ML error; the exclusion is captured for auditability.
- Passing structural validation does not prove that every generated statement is supported by the evidence.
- The repository defines an approved-only view, but does not yet provide the review metadata migration or a complete human-review interface.
- The Streamlit presentation and review layer has not yet been built.
- The current workflow is manually executed rather than orchestrated on a production schedule.

## Next milestone

The next milestone is a governed human-review workflow that:

1. presents each generated claim beside its supporting KPI or anomaly evidence;
2. records reviewer notes and an `APPROVED` or `REJECTED` decision;
3. integrates the approved-only view into downstream consumption;
4. exposes the workflow through Streamlit.
