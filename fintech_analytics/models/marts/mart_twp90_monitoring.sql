
WITH borrower_summary AS (

    SELECT
        twp90_default_status,
        COUNT(*) AS total_borrowers,
        AVG(days_past_due) AS avg_days_past_due,
        MAX(days_past_due) AS max_days_past_due,
        AVG(total_loan_outstanding_idr) AS avg_outstanding_idr,
        SUM(total_loan_outstanding_idr) AS total_outstanding_idr,
        AVG(financial_distress_index) AS avg_financial_distress_index

    FROM {{ ref('stg_borrowers') }}

    GROUP BY twp90_default_status

)

SELECT
    twp90_default_status,
    total_borrowers,

    ROUND(
        SAFE_DIVIDE(
            total_borrowers * 100.0,
            SUM(total_borrowers) OVER ()
        ),
        2
    ) AS borrower_percentage,

    ROUND(avg_days_past_due, 2) AS avg_days_past_due,
    max_days_past_due,
    ROUND(avg_outstanding_idr, 2) AS avg_outstanding_idr,
    total_outstanding_idr,
    ROUND(avg_financial_distress_index, 4) AS avg_financial_distress_index

FROM borrower_summary
