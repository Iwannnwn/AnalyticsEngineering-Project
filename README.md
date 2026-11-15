# Fintech Analytics Engineering: Debt Dynamics & Credit Risk Analysis

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