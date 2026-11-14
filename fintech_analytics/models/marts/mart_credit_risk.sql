
WITH borrower_risk AS (

    SELECT
        borrower_id,
        debt_service_ratio,
        credit_limit_utilization_ratio,
        financial_distress_index,
        twp90_default_status,

        CASE
            WHEN debt_service_ratio < 0.30
                THEN 'Low DSR'
            WHEN debt_service_ratio < 0.50
                THEN 'Moderate DSR'
            WHEN debt_service_ratio < 0.70
                THEN 'High DSR'
            ELSE 'Very High DSR'
        END AS dsr_segment,

        CASE
            WHEN credit_limit_utilization_ratio < 0.30
                THEN 'Low Utilization'
            WHEN credit_limit_utilization_ratio < 0.60
                THEN 'Moderate Utilization'
            WHEN credit_limit_utilization_ratio < 0.80
                THEN 'High Utilization'
            ELSE 'Very High Utilization'
        END AS utilization_segment

    FROM {{ ref('stg_borrowers') }}

),

risk_summary AS (

    SELECT
        dsr_segment,
        utilization_segment,

        COUNT(*) AS total_borrowers,

        COUNTIF(
            twp90_default_status = 'Default-Macet-TWP90'
        ) AS default_borrowers,

        AVG(debt_service_ratio) AS avg_dsr,

        AVG(credit_limit_utilization_ratio)
            AS avg_utilization,

        AVG(financial_distress_index)
            AS avg_distress_index

    FROM borrower_risk

    GROUP BY
        dsr_segment,
        utilization_segment

)

SELECT
    dsr_segment,
    utilization_segment,
    total_borrowers,
    default_borrowers,

    ROUND(
        SAFE_DIVIDE(
            default_borrowers * 100.0,
            total_borrowers
        ),
        2
    ) AS default_percentage,

    ROUND(avg_dsr, 3) AS avg_dsr,
    ROUND(avg_utilization, 3) AS avg_utilization,
    ROUND(avg_distress_index, 2) AS avg_distress_index

FROM risk_summary
