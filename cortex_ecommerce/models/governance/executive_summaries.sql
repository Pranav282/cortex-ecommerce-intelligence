{{ config(
    materialized='incremental',
    incremental_strategy='append',
    full_refresh=false,
    tmp_relation_type='table',
    tags=['summary_generation']
) }}

/* Each run appends a new summary using the current input.
   Preserve existing summaries and human review statuses, even on full refresh.
   Materialize intermediate results as a table to avoid reevaluating Cortex.
*/

with prompt_input as (

    select
        period_start_date,
        period_end_date,
        input_version,

        sha2(
            to_json(cortex_input),
            256
        ) as input_hash,

        concat(
            'You are a senior eCommerce business intelligence analyst preparing ',
            'an executive performance summary for business stakeholders. ',

            'Use only the supplied JSON evidence. Write in clear business language ',
            'and focus on material insights, business implications, and recommended ',
            'actions. The summary must be concise enough to read in approximately ',
            'two minutes. ',

            'GROUNDING RULES: ',

            '1. Do not invent facts, values, events, or confirmed causes. ',

            '2. Variance from expected compares the period average_actual with the ',
            'model average_expected. It is not a comparison with a previous period. ',

            '3. When describing a period-level KPI movement, use only channel, ',
            'metric_name, average_actual, average_expected, ',
            'variance_from_expected_pct, and desired_direction. ',

            '4. Copy variance_from_expected_pct exactly as supplied after rounding ',
            'it to two decimal places. Do not calculate another percentage. ',

            '5. Do not combine average values and latest values in the same ',
            'comparison. ',

            '6. Use desired_direction to interpret the business signal. ',
            'For HIGHER_IS_BETTER, above expected is potentially favorable and ',
            'below expected is potentially unfavorable. ',
            'For LOWER_IS_BETTER, below expected is potentially favorable and ',
            'above expected is potentially unfavorable. ',
            'For CONTEXT_DEPENDENT, describe the movement without judging it. ',

            '7. ABOVE_EXPECTED_RANGE means actual_value exceeded upper_bound. ',
            'BELOW_EXPECTED_RANGE means actual_value fell below lower_bound. ',

            '8. Do not claim that an anomaly caused a business outcome. ',

            '9. Potential explanations may only be presented as hypotheses requiring ',
            'investigation. Use language such as potential drivers to investigate, ',
            'this may warrant reviewing, or the available evidence does not ',
            'establish the cause. ',

            '10. Every anomaly discussed must cite exactly one supplied evidence_id. ',

            '11. Each evidence_id represents exactly one anomaly. Never reuse an ',
            'evidence_id for another channel, metric, or date. ',

            '12. Never create evidence-ID ranges such as ANOM-0001 to ANOM-0020. ',

            '13. When discussing an anomaly, copy its evidence_id, channel, ',
            'metric_name, metric_date, actual_value, expected_value, lower_bound, ',
            'upper_bound, and direction from the same anomaly object. ',

            '14. Use total_anomalies for the overall anomaly count. The ',
            'top_anomaly_facts array contains only the highest-severity anomalies ',
            'and may contain fewer records than total_anomalies. ',

            '15. Do not list every anomaly. Prioritize no more than five anomalies ',
            'based on severity_rank and likely business relevance. ',

            '16. Recommendations must describe verification or investigation steps. ',
            'Do not present a possible explanation as a confirmed cause. ',

            'OUTPUT FORMAT: ',

            'Executive Performance Summary. ',

            '1. Executive Overview: Write two or three sentences summarizing the ',
            'reporting period, scored_observations, scored_kpis, total_anomalies, ',
            'and the most material business signals. Do not claim that performance ',
            'changed relative to a previous period. ',

            '2. Key Business Insights: Provide three to five concise bullets. ',
            'Each bullet must identify the channel and KPI, describe the observed ',
            'movement, explain the business interpretation using desired_direction, ',
            'and cite the relevant evidence_id when discussing an anomaly. ',

            '3. Recommended Actions: Provide exactly three prioritized actions. ',
            'Each action must identify what the business team should investigate, ',
            'name the relevant channel and KPI, cite the related evidence_id, ',
            'and avoid presenting a hypothesis as a confirmed cause. ',

            '4. Data and Model Note: State briefly that expected values are model ',
            'predictions and detected anomalies represent unusual observations, ',
            'not confirmed business causes. ',

            'If total_anomalies is zero, state that no anomalies were detected and ',
            'do not create anomaly findings or evidence citations. ',

            'Structured KPI and anomaly evidence: ',
            to_json(cortex_input)
        ) AS prompt_text

    from {{ ref('executive_summary_input') }}

)

select
    uuid_string() as summary_id,
    period_start_date,
    period_end_date,

    'llama3.3-70b' as model_name,
    'v2.0' as prompt_version,
    input_version,

    input_hash,

    prompt_text,

    AI_COMPLETE(
        'llama3.3-70b',
        prompt_text
    ) as generated_summary,

    current_timestamp()::timestamp_ntz as generated_at,
    'PENDING_REVIEW' as review_status

from prompt_input

{% if is_incremental() %}

where not exists (

    select 1
    from {{ this }} existing

    where existing.input_hash = prompt_input.input_hash
      and existing.model_name = 'llama3.3-70b'
      and existing.prompt_version = 'v2.0'

)

{% endif %}