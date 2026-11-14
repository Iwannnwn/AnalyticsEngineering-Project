
WITH borrower_segmentation AS (

    SELECT
        borrower_id,
        monthly_income_idr,
        total_loan_outstanding_idr,
        credit_limit_utilization_ratio,
        debt_service_ratio,
        financial_distress_index,
        twp90_default_status,

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

segment_summary AS (

    SELECT
        utilization_segment,

        COUNT(*) AS total_borrowers,

        AVG(credit_limit_utilization_ratio) AS avg_utilization,
        AVG(monthly_income_idr) AS avg_monthly_income_idr,
        AVG(total_loan_outstanding_idr) AS avg_outstanding_idr,
        AVG(debt_service_ratio) AS avg_dsr,
        AVG(financial_distress_index) AS avg_distress_index,

        COUNTIF(twp90_default_status = 'Current-Performing')
            AS current_borrowers,

        COUNTIF(twp90_default_status = 'Special-Mention-DPD1-30')
            AS special_mention_borrowers,

        COUNTIF(twp90_default_status = 'Substandard-DPD31-60')
            AS substandard_borrowers,

        COUNTIF(twp90_default_status = 'Doubtful-DPD61-90')
            AS doubtful_borrowers,

        COUNTIF(twp90_default_status = 'Default-Macet-TWP90')
            AS default_borrowers

    FROM borrower_segmentation

    GROUP BY utilization_segment

)

SELECT
    utilization_segment,
    total_borrowers,

    ROUND(avg_utilization, 3) AS avg_utilization,
    ROUND(avg_monthly_income_idr, 2) AS avg_monthly_income_idr,
    ROUND(avg_outstanding_idr, 2) AS avg_outstanding_idr,
    ROUND(avg_dsr, 2) AS avg_dsr,
    ROUND(avg_distress_index, 2) AS avg_distress_index,

    ROUND(SAFE_DIVIDE(current_borrowers * 100.0, total_borrowers), 2)
        AS current_percentage,

    ROUND(SAFE_DIVIDE(special_mention_borrowers * 100.0, total_borrowers), 2)
        AS special_mention_percentage,

    ROUND(SAFE_DIVIDE(substandard_borrowers * 100.0, total_borrowers), 2)
        AS substandard_percentage,

    ROUND(SAFE_DIVIDE(doubtful_borrowers * 100.0, total_borrowers), 2)
        AS doubtful_percentage,

    ROUND(SAFE_DIVIDE(default_borrowers * 100.0, total_borrowers), 2)
        AS default_percentage

FROM segment_summary
