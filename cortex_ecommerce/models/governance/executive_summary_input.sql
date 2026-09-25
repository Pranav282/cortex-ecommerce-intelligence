/*--------------------------------------------------------------
  Phase 8.6: Prepare structured KPI context for Cortex

  Purpose:
  - Read the Snowflake ML anomaly-detection results.
  - Separate the channel and KPI name.
  - Calculate KPI-level summary statistics.
  - Rank anomalies by severity.
  - Assign evidence IDs to anomalies.
  - Create structured JSON input for Cortex.
--------------------------------------------------------------*/


WITH


/*--------------------------------------------------------------
  CTE 1: Standardize the anomaly-result columns

  The anomaly model returns columns such as:
  - SERIES
  - TS
  - Y
  - FORECAST
  - LOWER_BOUND
  - UPPER_BOUND
  - IS_ANOMALY
  - PERCENTILE
  - DISTANCE

  SERIES contains a value such as:
      Search|AVERAGE_ORDER_VALUE

  SPLIT_PART separates this into:
      channel     = Search
      metric_name = AVERAGE_ORDER_VALUE
--------------------------------------------------------------*/

anomaly_results AS (

    SELECT
        series::varchar AS series_key,

        /* Extract the channel from the series identifier. */
        split_part(series::varchar, '|', 1) AS channel,

        /* Extract the KPI name from the series identifier. */
        split_part(series::varchar, '|', 2) AS metric_name,

        /* Date or timestamp of the KPI observation. */
        ts AS metric_timestamp,

        /* Actual observed KPI value. */
        y::float AS actual_value,

        /* Value predicted by the anomaly-detection model. */
        forecast::float AS expected_value,

        /* Lower boundary of the expected range. */
        lower_bound::float AS lower_bound,

        /* Upper boundary of the expected range. */
        upper_bound::float AS upper_bound,

        /* Indicates whether Snowflake classified the row as anomalous. */
        is_anomaly::boolean AS is_anomaly,

        /* Position of the observation within the predicted distribution. */
        percentile::float AS percentile,

        /* Standardized distance between actual and expected values. */
        distance::float AS distance

    FROM {{ ref('kpi_anomaly_results') }}

),


/*--------------------------------------------------------------
  CTE 2: Calculate reporting-period statistics

  This produces one row containing:
  - Beginning of the scoring period.
  - End of the scoring period.
  - Number of observations scored.
  - Number of distinct KPIs scored.
  - Total number of detected anomalies.
--------------------------------------------------------------*/

reporting_period AS (

    SELECT
        min(metric_timestamp)::date AS period_start_date,
        max(metric_timestamp)::date AS period_end_date,
        count(*) AS scored_observations,
        count(DISTINCT series_key) AS scored_kpis,
        count_if(is_anomaly = TRUE) AS total_anomalies

    FROM anomaly_results

),


/*--------------------------------------------------------------
  CTE 3: Create one summary row for each channel and KPI

  The calculations include:
  - Average actual value.
  - Average expected value.
  - Percentage variance from expected.
  - Latest actual value.
  - Latest expected value.
  - Latest available date.
  - Number of detected anomalies.
--------------------------------------------------------------*/

kpi_rollup AS (

    SELECT
        series_key,
        channel,
        metric_name,

        /* Average observed value during the reporting period. */
        round(
            avg(actual_value),
            2
        ) AS average_actual_value,

        /* Average model-expected value during the reporting period. */
        round(
            avg(expected_value),
            2
        ) AS average_expected_value,

        /*
          Percentage difference between average actual and expected values.

          NULLIF prevents division by zero when the average expected
          value is zero.
        */
        round(
            100 * (
                avg(actual_value) - avg(expected_value)
            ) / nullif(abs(avg(expected_value)), 0),
            2
        ) AS variance_from_expected_pct,

        /*
          MAX_BY returns the actual value associated with the latest
          metric timestamp.
        */
        round(
            max_by(actual_value, metric_timestamp),
            2
        ) AS latest_actual_value,

        /*
          Return the expected value associated with the latest
          metric timestamp.
        */
        round(
            max_by(expected_value, metric_timestamp),
            2
        ) AS latest_expected_value,

        /* Most recent observation date for the KPI. */
        max(metric_timestamp)::date AS latest_metric_date,

        /* Number of anomalies detected for this KPI. */
        count_if(is_anomaly = TRUE) AS anomaly_count,

        CASE
            WHEN metric_name = 'CART_ABANDONMENT_RATE'
                THEN 'LOWER_IS_BETTER'

            WHEN metric_name IN (
                'AVERAGE_ORDER_VALUE',
                'COMPLETED_REVENUE',
                'SESSION_CONVERSION_RATE',
                'TOTAL_ORDERS'
            )
                THEN 'HIGHER_IS_BETTER'

            ELSE 'CONTEXT_DEPENDENT'
        END AS desired_direction

    FROM anomaly_results

    GROUP BY
        series_key,
        channel,
        metric_name

),


/*--------------------------------------------------------------
  CTE 4: Convert the KPI summaries into structured objects

  Each KPI becomes a separate JSON-like Snowflake OBJECT.

  ARRAY_AGG combines the KPI objects into a single array while
  preserving the separation between channels and metrics.
--------------------------------------------------------------*/

kpi_context AS (

    SELECT
        array_agg(
            object_construct_keep_null(
                'series_key', series_key,
                'channel', channel,
                'metric_name', metric_name,
                'average_actual', average_actual_value,
                'average_expected', average_expected_value,
                'variance_from_expected_pct', variance_from_expected_pct,
                'latest_actual', latest_actual_value,
                'latest_expected', latest_expected_value,
                'latest_metric_date', latest_metric_date,
                'anomaly_count', anomaly_count,
                'desired_direction', desired_direction
            )
        ) WITHIN GROUP (
            ORDER BY channel, metric_name
        ) AS kpi_facts

    FROM kpi_rollup

),


/*--------------------------------------------------------------
  CTE 5: Rank detected anomalies by severity

  Only rows marked as anomalies are included.

  Severity is based on the absolute DISTANCE value:
  - Larger absolute distance = more unusual observation.
  - The strongest anomaly receives severity rank 1.

  Each anomaly also receives an evidence ID such as:
      ANOM-0001
      ANOM-0002

  Cortex can cite these IDs in the generated summary.
--------------------------------------------------------------*/

ranked_anomalies AS (

    SELECT

        /*
          Generate a stable-looking evidence ID based on the anomaly's
          severity ranking.
        */
        concat(
            'ANOM-',
            lpad(
                row_number() OVER (
                    ORDER BY
                        abs(distance) DESC,
                        metric_timestamp DESC,
                        series_key
                )::varchar,
                4,
                '0'
            )
        ) AS evidence_id,

        series_key,
        channel,
        metric_name,

        /* Convert the timestamp to a reporting date. */
        metric_timestamp::date AS metric_date,

        /* Actual observed value for the anomaly. */
        round(
            actual_value,
            2
        ) AS actual_value,

        /* Model-predicted value for the same observation. */
        round(
            expected_value,
            2
        ) AS expected_value,

        /* Lower edge of the model's expected range. */
        round(
            lower_bound,
            2
        ) AS lower_bound,

        /* Upper edge of the model's expected range. */
        round(
            upper_bound,
            2
        ) AS upper_bound,

        /* Standardized anomaly distance. */
        round(
            distance,
            4
        ) AS distance,

        /* Model-calculated percentile. */
        round(
            percentile,
            6
        ) AS percentile,

        /*
          Describe whether the actual value was above or below
          the model's expected range.
        */
        CASE
            WHEN actual_value > upper_bound
                THEN 'ABOVE_EXPECTED_RANGE'

            WHEN actual_value < lower_bound
                THEN 'BELOW_EXPECTED_RANGE'

            ELSE 'WITHIN_EXPECTED_RANGE'
        END AS anomaly_direction,

        /*
          Rank anomalies from the most severe to the least severe.
          SERIES_KEY is included as a final tie-breaker.
        */
        row_number() OVER (
            ORDER BY
                abs(distance) DESC,
                metric_timestamp DESC,
                series_key
        ) AS severity_rank

    FROM anomaly_results

    WHERE is_anomaly = TRUE

),


/*--------------------------------------------------------------
  CTE 6: Build the anomaly evidence array

  Only the 20 most severe anomalies are included in the Cortex
  prompt. This limits prompt size and focuses the executive
  summary on the most material observations.

  If there are no anomalies, ARRAY_CONSTRUCT returns an empty
  array instead of NULL.
--------------------------------------------------------------*/

top_anomaly_context AS (

    SELECT
        coalesce(
            array_agg(
                object_construct_keep_null(
                    'evidence_id', evidence_id,
                    'severity_rank', severity_rank,
                    'series_key', series_key,
                    'channel', channel,
                    'metric_name', metric_name,
                    'metric_date', metric_date,
                    'actual_value', actual_value,
                    'expected_value', expected_value,
                    'lower_bound', lower_bound,
                    'upper_bound', upper_bound,
                    'distance', distance,
                    'percentile', percentile,
                    'direction', anomaly_direction
                )
            ) WITHIN GROUP (
                ORDER BY severity_rank
            ),
            array_construct()
        ) AS anomaly_facts

    FROM ranked_anomalies

    WHERE severity_rank <= 20

)


/*--------------------------------------------------------------
  Final output

  Each preceding CTE returns one row at this stage:
  - REPORTING_PERIOD provides reporting metadata.
  - KPI_CONTEXT provides the complete KPI summary array.
  - TOP_ANOMALY_CONTEXT provides the top anomaly array.

  CROSS JOIN combines them into one row for Cortex.
--------------------------------------------------------------*/

SELECT
    reporting_period.period_start_date,
    reporting_period.period_end_date,
    reporting_period.scored_observations,
    reporting_period.scored_kpis,
    reporting_period.total_anomalies,

    /* Structured array containing one object per KPI. */
    kpi_context.kpi_facts,

    /* Structured array containing the 20 strongest anomalies. */
    top_anomaly_context.anomaly_facts,

    /*
      Combine the reporting metadata, KPI summaries and anomaly
      evidence into one structured Cortex input object.
    */
    object_construct(
        'period_start_date',
        reporting_period.period_start_date,

        'period_end_date',
        reporting_period.period_end_date,

        'scored_observations',
        reporting_period.scored_observations,

        'scored_kpis',
        reporting_period.scored_kpis,

        'total_anomalies',
        reporting_period.total_anomalies,

        'kpi_facts',
        kpi_context.kpi_facts,

        'top_anomaly_facts',
        top_anomaly_context.anomaly_facts
    ) AS cortex_input,

    /* Version identifier for tracking changes to the input structure. */
    'v2.0' AS input_version,

    /*
      Time at which dbt materialized this input table.
    */
    current_timestamp() AS input_generated_at

FROM reporting_period

CROSS JOIN kpi_context

CROSS JOIN top_anomaly_context
