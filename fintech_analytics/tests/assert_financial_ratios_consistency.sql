SELECT
    borrower_id

FROM {{ ref('stg_borrowers') }}

WHERE
    ABS(
        income_to_umr_ratio -
        SAFE_DIVIDE(
            monthly_income_idr,
            regional_minimum_wage_umr_idr
        )
    ) > 0.01

    OR ABS(
        debt_to_income_ratio -
        SAFE_DIVIDE(
            total_loan_outstanding_idr,
            monthly_income_idr
        )
    ) > 0.01

    OR ABS(
        credit_limit_utilization_ratio -
        SAFE_DIVIDE(
            total_loan_outstanding_idr,
            credit_limit_granted_idr
        )
    ) > 0.01

    OR ABS(
        debt_service_ratio -
        SAFE_DIVIDE(
            monthly_installment_estimate_idr,
            monthly_income_idr
        )
    ) > 0.01