/*--------------------------------------------------------------
  Phase 8.6: Generate and store the executive summary
--------------------------------------------------------------*/

use role CORTEX_ECOMMERCE_ROLE;
use warehouse CORTEX_ECOMMERCE_WH;
use database CORTEX_ECOMMERCE;
use schema AI_GOVERNANCE;


/* Create the governed output table */

create table if not exists EXECUTIVE_SUMMARIES (

    summary_id varchar,
    period_start_date date,
    period_end_date date,

    model_name varchar,
    prompt_version varchar,
    input_version varchar,

    prompt_text varchar,
    generated_summary varchar,

    generated_at timestamp_ntz,
    review_status varchar

);


/* Build the prompt, call Cortex, and store the output */

insert into EXECUTIVE_SUMMARIES (

    summary_id,
    period_start_date,
    period_end_date,
    model_name,
    prompt_version,
    input_version,
    prompt_text,
    generated_summary,
    generated_at,
    review_status

)

with prompt_input as (

    select
        period_start_date,
        period_end_date,
        input_version,

        concat(
            'You are a senior ecommerce business intelligence analyst. ',
            'Prepare a concise executive performance summary using only ',
            'the supplied evidence. Do not invent facts or explanations. ',

            'The summary must include: ',
            '1. Overall performance, ',
            '2. Important KPI movements, ',
            '3. Detected anomalies, ',
            '4. Three recommended business actions. ',

            'Clearly distinguish observed evidence from recommendations. ',

            'Reporting period: ',
            period_start_date::varchar,
            ' through ',
            period_end_date::varchar,
            '. ',

            'KPI evidence: ',
            kpi_summary_text,
            '. ',

            'Anomaly evidence: ',
            anomaly_detail_text
        ) as prompt_text

    from EXECUTIVE_SUMMARY_INPUT

)

select
    uuid_string() as summary_id,
    period_start_date,
    period_end_date,

    'llama3.1-8b' as model_name,
    'v1.0' as prompt_version,
    input_version,

    prompt_text,

    AI_COMPLETE(
        'llama3.1-8b',
        prompt_text
    ) as generated_summary,

    current_timestamp()::timestamp_ntz as generated_at,
    'PENDING_REVIEW' as review_status

from prompt_input;