# Fintech Analytics Engineering: Debt Dynamics & Credit Risk Analysis

<p align="center">
  <img src="D:/Project Data/Project/Analytics Engineering/docs/Architecture.jpg"
       alt="System Architecture"
       width="900">
</p>

An end-to-end Analytics Engineering project focused on transforming Indonesian fintech lending data into reliable, analytics-ready datasets using **Python, Google BigQuery, and dbt Core**.

The project implements a Medallion Architecture (Bronze, Silver, and Gold) to build a structured data transformation pipeline and develop analytical data marts for monitoring borrower repayment performance and credit risk.

---

## 1. Project Overview

The growth of fintech lending and Paylater services creates new challenges in monitoring borrower financial conditions and repayment performance.

This project explores borrower-level lending data to understand the relationship between financial indicators, credit utilization, debt service obligations, and TWP90 default status.

Rather than performing analysis directly on raw data, this project focuses on building a maintainable analytical data pipeline that transforms raw records into structured datasets ready for business intelligence and further analysis.

**Key objectives:**
- Build an end-to-end data ingestion pipeline from CSV to Google BigQuery.
- Implement Medallion Architecture using Bronze, Silver, and Gold layers.
- Use dbt Core to manage SQL transformations and model dependencies.
- Implement data quality checks and automated testing.
- Develop analytical data marts for credit risk monitoring.
- Generate project documentation and data lineage using dbt.

## 2. Dataset

**Dataset:** Indonesia Fintech P2P Lending & Paylater Default Dynamics 2026  
**Source:** Kaggle  
**Records:** 10,000 borrowers  
**Columns:** 26 attributes

The dataset contains borrower profiles, financial conditions, loan characteristics, and repayment information.

### Data Categories

| Category | Relevant Attributes |
|---|---|
| Borrower Profile | Age, gender, province, education, employment status |
| Financial Condition | Monthly income, outstanding debt, DTI, DSR, disposable income |
| Loan Characteristics | Active lending apps, credit limit, loan tenor, interest rate, utilization |
| Repayment & Risk | DPD, TWP90 status, financial distress index, default root cause |

### Target Business Indicator

The primary repayment indicator is `twp90_default_status`, which contains five borrower categories:

- Current-Performing
- Special-Mention-DPD1-30
- Substandard-DPD31-60
- Doubtful-DPD61-90
- Default-Macet-TWP90

## 3. Technology Stack

| Technology | Purpose |
|---|---|
| Python | Data ingestion and initial validation |
| Pandas | CSV processing |
| Google BigQuery | Cloud data warehouse |
| dbt Core | SQL transformation, testing, and documentation |
| dbt-bigquery | BigQuery adapter |
| SQL | Data modeling and analytical transformations |
| Git & GitHub | Version control |

**Environment:**
- Python 3.11
- dbt Core 1.12.7
- dbt-bigquery 1.12.3
- BigQuery Sandbox
- Google Cloud SDK

## 4. Data Architecture

This project follows the Medallion Architecture.

```text
                  SOURCE DATA
                       |
                       v
              fintech_dataset.csv
                       |
                       v
              Python Ingestion
                       |
                       v
+---------------------------------------------+
|              BRONZE LAYER                   |
|                                             |
| BigQuery: fintech_raw                       |
| Table: borrower_data                        |
|                                             |
| Raw data ingestion from CSV                 |
+---------------------------------------------+
                       |
                       v
+---------------------------------------------+
|              SILVER LAYER                   |
|                                             |
| dbt Model: stg_borrowers                    |
| BigQuery: fintech_staging                   |
|                                             |
| - Explicit column selection                 |
| - Source configuration                       |
| - Data quality validation                   |
+---------------------------------------------+
                       |
                       v
+---------------------------------------------+
|               GOLD LAYER                    |
|                                             |
| BigQuery: fintech_marts                     |
|                                             |
| 1. mart_twp90_monitoring                    |
| 2. mart_borrower_segmentation               |
| 3. mart_credit_risk                         |
|                                             |
| Business-oriented analytical data marts     |
+---------------------------------------------+
```

### Bronze Layer — Raw Data

The original CSV dataset is ingested into BigQuery using Python and the BigQuery client library.

**Destination:**
`fintech_raw.borrower_data`

The ingestion process includes:
- Reading the source CSV file.
- Connecting to Google BigQuery.
- Loading data using the BigQuery DataFrame loading method.
- Validating the destination row count against the source.

### Silver Layer — Staging

The staging model standardizes the raw data structure and establishes a consistent foundation for downstream transformations.

**Model:** `stg_borrowers`

Key implementation:
- Explicit column selection instead of `SELECT *`.
- dbt source configuration using `source()`.
- Data quality tests for borrower identifiers and repayment status.
- Business consistency checks for DPD and financial ratios.

The staging model is materialized as a BigQuery view.

### Gold Layer — Analytical Marts

The Gold layer contains three analytical models designed for different business questions.

#### A. mart_twp90_monitoring

**Grain:** One row per TWP90 repayment status.

Purpose:
- Monitor borrower distribution across repayment categories.
- Analyze average and maximum Days Past Due.
- Monitor outstanding loan exposure.
- Compare average financial distress index across repayment statuses.

Key metrics:
- Total borrowers
- Borrower percentage
- Average DPD
- Maximum DPD
- Average outstanding balance
- Total outstanding balance
- Average financial distress index

#### B. mart_borrower_segmentation

**Grain:** One row per credit utilization segment.

Borrowers are grouped using the following thresholds:

| Segment | Credit Utilization |
|---|---|
| Low | Below 30% |
| Moderate | 30% to below 60% |
| High | 60% to below 80% |
| Very High | 80% or higher |

Purpose:
- Analyze borrower characteristics across utilization segments.
- Compare outstanding balances and debt service ratios.
- Monitor repayment status distribution.
- Identify segments with elevated default percentages.

#### C. mart_credit_risk

**Grain:** One row per combination of DSR and credit utilization segments.

This model combines two financial risk dimensions:

**Debt Service Ratio (DSR)**

| Segment | DSR |
|---|---|
| Low | Below 0.30 |
| Moderate | 0.30 to below 0.50 |
| High | 0.50 to below 0.70 |
| Very High | 0.70 or higher |

**Credit Utilization**

| Segment | Utilization |
|---|---|
| Low | Below 0.30 |
| Moderate | 0.30 to below 0.60 |
| High | 0.60 to below 0.80 |
| Very High | 0.80 or higher |

Purpose:
- Analyze the interaction between debt service obligations and credit utilization.
- Identify borrower groups with elevated default percentages.
- Compare financial distress indicators across risk combinations.

The model produces up to 16 segment combinations.

## 5. Data Quality & Testing

Data quality is validated at different stages of the pipeline.

### Initial Data Profiling

Initial profiling using Python identified:

| Check | Result |
|---|---:|
| Total records | 10,000 |
| Total columns | 26 |
| Missing values | 0 |
| Exact duplicate rows | 0 |
| Duplicate borrower IDs | 0 |

Additional validation included:
- Age range validation.
- Non-negative financial value checks.
- DPD and repayment status consistency.
- Categorical value inspection.
- Financial ratio consistency checks.

### dbt Data Tests

The project uses both generic and singular tests.

**Generic tests:**
- `not_null`
- `unique`
- `accepted_values`

**Singular tests:**
- `assert_borrower_dpd_status_consistency`
- `assert_non_negative_financial_values`
- `assert_financial_ratios_consistency`
- `assert_twp90_monitoring_aggregation`
- `assert_borrower_segmentation_distribution`
- `assert_credit_risk_unique_segments`

Additional schema tests are defined for the analytical models.

**Testing summary:**

| Model | Tests |
|---|---:|
| Staging | 7 |
| mart_twp90_monitoring | 6 |
| mart_borrower_segmentation | 7 |
| mart_credit_risk | 8 |
| **Total** | **28** |

All 28 defined tests passed during the project's validation process.

## 6. Key Analytical Findings

The following findings were obtained from exploratory SQL analysis and the resulting Gold models.

### A. TWP90 Distribution

The dataset contains 10,000 borrowers, with 2,538 classified as Default-Macet-TWP90.

| Repayment Status | Borrowers | Percentage |
|---|---:|---:|
| Current-Performing | 3,508 | 35.08% |
| Special-Mention-DPD1-30 | 1,731 | 17.31% |
| Substandard-DPD31-60 | 1,367 | 13.67% |
| Doubtful-DPD61-90 | 856 | 8.56% |
| Default-Macet-TWP90 | 2,538 | 25.38% |

### B. Credit Utilization and Default

Default percentages increase across the credit utilization segments.

| Utilization Segment | Borrowers | Default Percentage |
|---|---:|---:|
| Low | 1,155 | 0.00% |
| Moderate | 4,456 | 6.37% |
| High | 2,162 | 23.36% |
| Very High | 2,227 | 78.54% |

The Very High Utilization segment has the highest observed default percentage.

### C. Debt Service Ratio and Default

| DSR Segment | Borrowers | Default Percentage |
|---|---:|---:|
| Low | 2,735 | 1.13% |
| Moderate | 2,026 | 8.64% |
| High | 1,281 | 20.92% |
| Very High | 3,958 | 52.15% |

The Very High DSR segment also shows an elevated default percentage.

### D. Combined Credit Risk Analysis

The combination of DSR and credit utilization provides another perspective on borrower risk.

| DSR | Utilization | Borrowers | Default Percentage |
|---|---|---:|---:|
| Very High | Very High | 1,413 | 92.64% |
| High | Very High | 347 | 72.05% |
| Moderate | Very High | 324 | 50.93% |
| Very High | High | 1,027 | 45.96% |
| Very High | Moderate | 1,371 | 20.64% |
| Low | Very High | 143 | 17.48% |

The combination of Very High DSR and Very High Utilization has the highest observed default percentage at 92.64%.

These findings indicate strong associations within this dataset. They should not be interpreted as evidence of causation or as a validated credit scoring model.

## 7. Project Structure

```text
Analytics Engineering/
│
├── data/
│   └── raw/
│       └── fintech_dataset.csv
│
├── scripts/
│   ├── profile_data.py
│   ├── validate_data.py
│   └── ingest_to_bigquery.py
│
├── sql/
│
├── docs/
│
├── fintech_analytics/
│   ├── analyses/
│   ├── macros/
│   │   └── generate_schema_name.sql
│   │
│   ├── models/
│   │   ├── staging/
│   │   │   ├── sources.yml
│   │   │   ├── schema.yml
│   │   │   └── stg_borrowers.sql
│   │   │
│   │   └── marts/
│   │       ├── schema.yml
│   │       ├── mart_twp90_monitoring.sql
│   │       ├── mart_borrower_segmentation.sql
│   │       └── mart_credit_risk.sql
│   │
│   ├── tests/
│   │   ├── assert_borrower_dpd_status_consistency.sql
│   │   ├── assert_non_negative_financial_values.sql
│   │   ├── assert_financial_ratios_consistency.sql
│   │   ├── assert_twp90_monitoring_aggregation.sql
│   │   ├── assert_borrower_segmentation_distribution.sql
│   │   └── assert_credit_risk_unique_segments.sql
│   │
│   ├── dbt_project.yml
│   └── README.md
│
├── .gitignore
└── .venv/
```

## 8. How to Run the Project

### Prerequisites

- Python 3.11
- Git
- Google Cloud account
- BigQuery project
- Google Cloud SDK
- dbt Core and dbt-bigquery

### Step 1 — Clone the Repository

```bash
# Clone repository
git clone https://github.com/Iwannnwn/AnalyticsEngineering-Project.git

# Navigate to project directory
cd AnalyticsEngineering-Project
```

### Step 2 — Create a Virtual Environment

```bash
python -m venv .venv
```

Activate it on Windows PowerShell:

```powershell
.\.venv\Scripts\Activate.ps1
```

Install dependencies:

```bash
pip install pandas google-cloud-bigquery pyarrow db-dtypes dbt-core dbt-bigquery
```

### Step 3 — Configure Google Cloud Authentication

Authenticate using Google Cloud SDK:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <YOUR_GCP_PROJECT_ID>
```

Create a BigQuery dataset for the raw data in your chosen region.

### Step 4 — Configure dbt Profile

Create or update:

`~/.dbt/profiles.yml`

Example configuration:

```yaml
fintech_analytics:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: YOUR_GCP_PROJECT_ID
      dataset: fintech_staging
      threads: 4
      location: YOUR_BIGQUERY_REGION
      job_execution_timeout_seconds: 300
```

Update the project ID and region to match your own BigQuery environment.

### Step 5 — Ingest Raw Data

Place the source CSV at:

`data/raw/fintech_dataset.csv`

Run:

```bash
python scripts/ingest_to_bigquery.py
```

### Step 6 — Validate dbt Configuration

Navigate to the dbt project:

```bash
cd fintech_analytics
```

Check the connection:

```bash
dbt debug
```

### Step 7 — Run Transformations

```bash
dbt run
```

### Step 8 — Run Data Quality Tests

```bash
dbt test
```

### Step 9 — Generate Documentation

```bash
dbt docs generate
dbt docs serve
```

The documentation interface provides model descriptions, source information, database metadata, and lineage exploration.

## 9. Key Engineering Decisions

Several implementation decisions were made throughout the project:

- **Medallion Architecture:** separates raw ingestion, standardized staging, and business-oriented analytical models.
- **Explicit column selection:** provides better schema control and prevents unintended columns from propagating downstream.
- **dbt source and ref:** establishes explicit dependencies between data sources and transformation models.
- **Custom schema generation macro:** allows staging and marts models to resolve to their intended BigQuery schemas.
- **Table materialization for Gold:** stores aggregated analytical models as tables, while staging uses views.
- **Data quality testing:** validates uniqueness, nullability, accepted values, financial consistency, and aggregation logic.
- **Model documentation and lineage:** improves transparency and maintainability.

## 10. Limitations & Considerations

- The analysis uses a single borrower-level dataset and does not represent a longitudinal repayment history.
- Observed relationships between financial indicators and default status do not establish causality.
- Financial ratio definitions were checked for consistency against the provided dataset; they should not automatically be treated as official regulatory definitions.
- Segment thresholds are analytical choices used for this project, not official credit risk classifications.
- The dataset's internal consistency does not independently establish real-world validity.
- The project currently focuses on data ingestion, transformation, testing, and analytical data marts. It does not implement a production orchestration or automated deployment pipeline.

## 11. Future Improvements

Potential extensions include:

- Implementing automated orchestration with Apache Airflow or another workflow scheduler.
- Adding incremental models and partitioning strategies.
- Integrating CI/CD for dbt model validation.
- Developing interactive dashboards using Power BI or Tableau.
- Adding more advanced credit risk analysis and monitoring metrics.
- Implementing automated data freshness and pipeline monitoring.

---

## Project Summary

This project demonstrates an end-to-end Analytics Engineering workflow, from raw data ingestion to analytics-ready data marts.

By combining Python, Google BigQuery, SQL, and dbt Core, the project establishes a structured transformation pipeline with documented dependencies and data quality validation.

**Core technologies:** Python | SQL | Google BigQuery | dbt Core | Medallion Architecture

**Focus areas:** Data Ingestion | Data Transformation | Data Modeling | Data Quality | Analytics Engineering