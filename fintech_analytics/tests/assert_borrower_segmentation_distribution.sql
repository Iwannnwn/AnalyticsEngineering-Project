
SELECT
    utilization_segment,

    (
        current_percentage
        + special_mention_percentage
        + substandard_percentage
        + doubtful_percentage
        + default_percentage
    ) AS total_status_percentage

FROM {{ ref('mart_borrower_segmentation') }}

WHERE ABS(
    (
        current_percentage
        + special_mention_percentage
        + substandard_percentage
        + doubtful_percentage
        + default_percentage
    ) - 100
) > 0.02
