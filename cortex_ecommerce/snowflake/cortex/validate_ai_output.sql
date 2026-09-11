/*--------------------------------------------------------------
  Phase 8.6: Validate Cortex executive-summary output
--------------------------------------------------------------*/

use role CORTEX_ECOMMERCE_ROLE;
use warehouse CORTEX_ECOMMERCE_WH;
use database CORTEX_ECOMMERCE;
use schema AI_GOVERNANCE;


/* 1. Inspect the latest generated summary */

select
    summary_id,
    period_start_date,
    period_end_date,
    model_name,
    prompt_version,
    input_version,
    generated_summary,
    generated_at,
    review_status
from EXECUTIVE_SUMMARIES
order by generated_at desc
limit 1;


/* 2. Check for missing or empty values */

select
    count(*) as total_summaries,

    count_if(summary_id is null)
        as missing_summary_ids,

    count_if(generated_summary is null)
        as null_summaries,

    count_if(trim(generated_summary) = '')
        as empty_summaries,

    count_if(prompt_text is null)
        as missing_prompts,

    count_if(model_name is null)
        as missing_model_names,

    count_if(prompt_version is null)
        as missing_prompt_versions,

    count_if(input_version is null)
        as missing_input_versions,

    count_if(generated_at is null)
        as missing_generation_timestamps,

    count_if(review_status is null)
        as missing_review_statuses

from EXECUTIVE_SUMMARIES;


/* 3. Validate reporting-period dates */

select
    count_if(period_start_date is null)
        as missing_start_dates,

    count_if(period_end_date is null)
        as missing_end_dates,

    count_if(period_start_date > period_end_date)
        as invalid_reporting_periods

from EXECUTIVE_SUMMARIES;


/* 4. Check summary ID uniqueness */

select
    summary_id,
    count(*) as duplicate_count
from EXECUTIVE_SUMMARIES
group by summary_id
having count(*) > 1;


/* 5. Check review-status values */

select
    review_status,
    count(*) as summary_count
from EXECUTIVE_SUMMARIES
group by review_status
order by review_status;


/* 6. Identify unexpected review statuses */

select *
from EXECUTIVE_SUMMARIES
where review_status not in (
    'PENDING_REVIEW',
    'APPROVED',
    'REJECTED'
)
or review_status is null;


/* 7. Compare stored metadata with the source input */

select
    summaries.summary_id,
    summaries.period_start_date,
    summaries.period_end_date,
    summaries.input_version,
    input.period_start_date as source_start_date,
    input.period_end_date as source_end_date,
    input.input_version as source_input_version,

    summaries.period_start_date =
        input.period_start_date
        as valid_start_date,

    summaries.period_end_date =
        input.period_end_date
        as valid_end_date,

    summaries.input_version =
        input.input_version
        as valid_input_version

from EXECUTIVE_SUMMARIES summaries
cross join EXECUTIVE_SUMMARY_INPUT input
order by summaries.generated_at desc;


/* 8. Inspect summary length */

select
    summary_id,
    length(generated_summary) as summary_character_count,
    generated_at
from EXECUTIVE_SUMMARIES
order by generated_at desc;