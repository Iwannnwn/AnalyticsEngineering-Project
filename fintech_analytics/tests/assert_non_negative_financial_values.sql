SELECT
    borrower_id,
    monthly_income_idr,
    total_loan_outstanding_idr,
    credit_limit_granted_idr,
    monthly_installment_estimate_idr

FROM {{ ref('stg_borrowers') }}

WHERE
    monthly_income_idr < 0
    OR total_loan_outstanding_idr < 0
    OR credit_limit_granted_idr < 0
    OR monthly_installment_estimate_idr < 0