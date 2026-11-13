from pathlib import Path

import pandas as pd
from google.cloud import bigquery

PROJECT_ID = "fintech-analytics-engineering"
DATASET_ID = "fintech_raw"
TABLE_ID = "borrower_data"

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_PATH = PROJECT_ROOT / "data" / "raw" / "fintech_dataset.csv"

FULL_TABLE_ID = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"


def main():
    print("FINTECH DATA INGESTION PIPELINE")

    # Check source file
    if not DATA_PATH.exists():
        raise FileNotFoundError(f"Dataset not found: {DATA_PATH}")

    print(f"\nSource file: {DATA_PATH.name}")

    # Read source data
    df = pd.read_csv(DATA_PATH)

    print(f"Records loaded locally: {len(df):,}")
    print(f"Columns: {len(df.columns)}")

    # Connect to BigQuery
    print("\nConnecting to BigQuery...")

    client = bigquery.Client(project=PROJECT_ID)

    print(f"Connected to project: {client.project}")

    # Configure BigQuery load job
    job_config = bigquery.LoadJobConfig(
        autodetect=True,
        source_format=bigquery.SourceFormat.PARQUET,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )

    # Upload DataFrame to BigQuery
    print(f"\nUploading data to: {FULL_TABLE_ID}")

    job = client.load_table_from_dataframe(
        df,
        FULL_TABLE_ID,
        job_config=job_config,
    )

    job.result()

    # Verify loaded table
    table = client.get_table(FULL_TABLE_ID)

    print("\nINGESTION RESULT")
    print(f"Destination table: {table.full_table_id}")
    print(f"Rows loaded: {table.num_rows:,}")
    print(f"Columns loaded: {len(table.schema)}")

    if table.num_rows != len(df):
        raise ValueError(
            f"Row count mismatch! "
            f"Source: {len(df)}, Destination: {table.num_rows}"
        )

    print("\nINGESTION SUCCESSFUL")


if __name__ == "__main__":
    main()
