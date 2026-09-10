import json
import os
from datetime import date, datetime, timezone
from pathlib import Path

from google.cloud import bigquery


SOURCE_PROJECT = "bigquery-public-data"
SOURCE_DATASET = "thelook_ecommerce"
DEFAULT_CUTOFF_DATE = "2026-01-01"
OUTPUT_DIRECTORY = Path("data/raw/thelook")

# Reference tables do not contain created_at.
# Transactional tables are frozen at the cutoff date for reproducibility.
TABLES = {
    "distribution_centers": None,
    "products": None,
    "users": "created_at",
    "orders": "created_at",
    "order_items": "created_at",
    "inventory_items": None,
    "events": "created_at",
}


def extract_table(
    client: bigquery.Client,
    table_name: str,
    timestamp_column: str | None,
    cutoff_date: date,
) -> dict:
    source_table = (
        f"`{SOURCE_PROJECT}.{SOURCE_DATASET}.{table_name}`"
    )

    if timestamp_column:
        query = f"""
            SELECT *
            FROM {source_table}
            WHERE DATE({timestamp_column}) < @cutoff_date
        """

        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter(
                    "cutoff_date",
                    "DATE",
                    cutoff_date,
                )
            ]
        )
    else:
        query = f"SELECT * FROM {source_table}"
        job_config = None

    print(f"Extracting {table_name}...")

    dataframe = client.query(
        query,
        job_config=job_config,
    ).to_dataframe(create_bqstorage_client=True)

    output_path = OUTPUT_DIRECTORY / f"{table_name}.parquet"

    dataframe.to_parquet(
        output_path,
        index=False,
        engine="pyarrow",
        compression="snappy",
    )

    file_size_bytes = output_path.stat().st_size

    print(
        f"Completed {table_name}: "
        f"{len(dataframe):,} rows, "
        f"{file_size_bytes / 1_048_576:.2f} MB"
    )

    return {
        "table": table_name,
        "rows": len(dataframe),
        "columns": list(dataframe.columns),
        "file": str(output_path),
        "file_size_bytes": file_size_bytes,
    }


def main() -> None:
    cutoff_value = os.getenv(
        "THELOOK_CUTOFF_DATE",
        DEFAULT_CUTOFF_DATE,
    )
    cutoff_date = date.fromisoformat(cutoff_value)

    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)

    client = bigquery.Client()
    results = []

    print(f"Using BigQuery project: {client.project}")
    print(f"Snapshot cutoff date: {cutoff_date}")
    print()

    for table_name, timestamp_column in TABLES.items():
        result = extract_table(
            client=client,
            table_name=table_name,
            timestamp_column=timestamp_column,
            cutoff_date=cutoff_date,
        )
        results.append(result)

    manifest = {
        "source": f"{SOURCE_PROJECT}.{SOURCE_DATASET}",
        "cutoff_date": str(cutoff_date),
        "extracted_at_utc": datetime.now(timezone.utc).isoformat(),
        "tables": results,
    }

    manifest_path = OUTPUT_DIRECTORY / "extraction_manifest.json"

    with manifest_path.open("w", encoding="utf-8") as manifest_file:
        json.dump(manifest, manifest_file, indent=2)

    print()
    print("Extraction completed successfully.")
    print(f"Manifest: {manifest_path}")


if __name__ == "__main__":
    main()