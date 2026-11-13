
from pathlib import Path
import pandas as pd

# Dataset Path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_PATH = PROJECT_ROOT / "data" / "raw" / "fintech_dataset.csv"

def main():
    print("FINTECH DATASET - SOURCE PROFILING")
    df = pd.read_csv(DATA_PATH)
    print(f"\nFile       : {DATA_PATH.name}")
    print(f"Total rows : {df.shape[0]:,}")
    print(f"Total cols : {df.shape[1]}")

    # Column information
    print("\nCOLUMN INFORMATION")
    print(df.dtypes.to_string())

    # Missing values
    print("\nMISSING VALUES")
    missing = df.isnull().sum()
    missing_pct = (missing / len(df) * 100).round(2)

    missing_report = pd.DataFrame({
        "missing_count": missing,
        "missing_percentage": missing_pct
    })

    print(missing_report.to_string())

    # Duplikasi
    print("\nDUPLICATE RECORDS")
    print(f"Duplicate rows: {df.duplicated().sum():,}")


if __name__ == "__main__":
    main()
