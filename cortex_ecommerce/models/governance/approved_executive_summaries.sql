{{ config(
    materialized='view',
    tags=['summary_publication']
) }}

/*
  Exposes only summaries that have passed human review.
  Pending, rejected and needs-revision outputs remain hidden.
*/

select
    summary_id,
    period_start_date,
    period_end_date,
    model_name,
    prompt_version,
    input_version,
    generated_summary,
    generated_at,
    reviewed_by,
    reviewed_at,
    review_notes

from {{ ref('executive_summaries') }}

where review_status = 'APPROVED'