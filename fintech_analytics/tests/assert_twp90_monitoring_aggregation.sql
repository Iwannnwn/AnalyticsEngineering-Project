WITH source_summary AS (

    SELECT
        twp90_default_status,
        COUNT(*) AS total_borrowers

    FROM {{ ref('stg_borrowers') }}

    GROUP BY twp90_default_status

)

SELECT
    gold.twp90_default_status,
    gold.total_borrowers,
    source.total_borrowers AS expected_borrowers

FROM {{ ref('mart_twp90_monitoring') }} AS gold

LEFT JOIN source_summary AS source
    ON gold.twp90_default_status = source.twp90_default_status

WHERE
    source.total_borrowers IS NULL
    OR gold.total_borrowers != source.total_borrowers