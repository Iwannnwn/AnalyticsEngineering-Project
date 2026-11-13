
from pathlib import Path
import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_PATH = PROJECT_ROOT / "data" / "raw" / "fintech_dataset.csv"


def main():
    df = pd.read_csv(DATA_PATH)
    print("FINTECH DATASET - DATA QUALITY CHECKS")

    # Primary key check
    print("\nBORROWER ID CHECK")
    print(f"Unique borrower IDs : {df['borrower_id'].nunique():,}")
    print(f"Duplicate borrower IDs: {df['borrower_id'].duplicated().sum():,}")

    # Numeric value ranges
    numeric_columns = [
        "age",
        "monthly_income_idr",
        "total_loan_outstanding_idr",
        "credit_limit_granted_idr",
        "days_past_due",
        "confidence_score",
    ]

    print("\nNUMERIC VALUE RANGES")
    print(df[numeric_columns].describe().loc[["min", "max"]].to_string())

    # Ratio ranges
    ratio_columns = [
        "debt_to_income_ratio",
        "income_to_umr_ratio",
        "credit_limit_utilization_ratio",
        "debt_service_ratio",
    ]

    print("\nRATIO VALUE RANGES")
    print(df[ratio_columns].describe().loc[["min", "max"]].to_string())

    # Categorical values
    categorical_columns = [
        "gender",
        "employment_status",
        "twp90_default_status",
    ]

    print("\nCATEGORY DISTRIBUTIONS")
    for column in categorical_columns:
        print(f"\n{column}:")
        print(df[column].value_counts(dropna=False).to_string())

    # Basic business rule checks
    print("\nBASIC VALIDATION")

    checks = {
        "Age below 18": (df["age"] < 18).sum(),
        "Negative income": (df["monthly_income_idr"] < 0).sum(),
        "Negative loan outstanding": (
            df["total_loan_outstanding_idr"] < 0
        ).sum(),
        "Negative days past due": (df["days_past_due"] < 0).sum(),
        "Confidence outside 0-1": (
            ~df["confidence_score"].between(0, 1)
        ).sum(),
    }

    for check_name, failed_count in checks.items():
        status = "PASS" if failed_count == 0 else "REVIEW"
        print(f"{check_name}: {failed_count} [{status}]")


    # DPD and TWP90 status consistency
    print("\nDPD BY TWP90 STATUS")

    dpd_summary = (
        df.groupby("twp90_default_status")["days_past_due"]
        .agg(["count", "min", "max", "mean"])
        .round(2)
    )

    print(dpd_summary.to_string())

    print("\n--- STATUS VS DPD DISTRIBUTION ---")

    status_dpd = pd.crosstab(
        df["twp90_default_status"],
        pd.cut(
            df["days_past_due"],
            bins=[-1, 0, 30, 60, 90, float("inf")],
            labels=["0", "1-30", "31-60", "61-90", ">90"]
        )
    )

    print(status_dpd.to_string())

if __name__ == "__main__":
    main()
