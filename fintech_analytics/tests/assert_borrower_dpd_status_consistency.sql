
SELECT
    borrower_id,
    days_past_due,
    twp90_default_status

FROM {{ ref('stg_borrowers') }}

WHERE
    CASE
        WHEN twp90_default_status = 'Current-Performing'
            THEN days_past_due = 0

        WHEN twp90_default_status = 'Special-Mention-DPD1-30'
            THEN days_past_due BETWEEN 1 AND 30

        WHEN twp90_default_status = 'Substandard-DPD31-60'
            THEN days_past_due BETWEEN 31 AND 60

        WHEN twp90_default_status = 'Doubtful-DPD61-90'
            THEN days_past_due BETWEEN 61 AND 90

        WHEN twp90_default_status = 'Default-Macet-TWP90'
            THEN days_past_due BETWEEN 91 AND 180

        ELSE FALSE
    END IS NOT TRUE
