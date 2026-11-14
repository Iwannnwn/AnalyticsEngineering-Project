
SELECT
    dsr_segment,
    utilization_segment,
    COUNT(*) AS total_records

FROM {{ ref('mart_credit_risk') }}

GROUP BY
    dsr_segment,
    utilization_segment

HAVING COUNT(*) > 1
