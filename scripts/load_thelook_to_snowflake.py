import json
import os
from pathlib import Path

import snowflake.connector


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
DATA_DIRECTORY = REPOSITORY_ROOT / "data" / "raw" / "thelook"
MANIFEST_PATH = DATA_DIRECTORY / "extraction_manifest.json"

DATABASE = "CORTEX_ECOMMERCE"
SCHEMA = "RAW"
WAREHOUSE = "CORTEX_ECOMMERCE_WH"
ROLE = "CORTEX_ECOMMERCE_ROLE"

FILE_FORMAT = "THELOOK_PARQUET_FORMAT"
STAGE = "THELOOK_STAGE"

TABLES = [
    "distribution_centers",
    "products",
    "users",
    "orders",
    "order_items",
    "inventory_items",
    "events",
]


def require_environment_variable(name: str) -> str:
    value = os.getenv(name)

    if not value:
        raise RuntimeError(
            f"Required environment variable is not set: {name}"
        )

    return value


def connect_to_snowflake():
    return snowflake.connector.connect(
        account=require_environment_variable("SNOWFLAKE_ACCOUNT"),
        user=require_environment_variable("SNOWFLAKE_USER"),
        password=require_environment_variable("SNOWFLAKE_PASSWORD"),
        role=ROLE,
        warehouse=WAREHOUSE,
        database=DATABASE,
        schema=SCHEMA,
    )


def load_manifest() -> dict:
    if not MANIFEST_PATH.exists():
        raise FileNotFoundError(
            f"Extraction manifest not found: {MANIFEST_PATH}"
        )

    with MANIFEST_PATH.open("r", encoding="utf-8") as manifest_file:
        return json.load(manifest_file)


def expected_row_counts(manifest: dict) -> dict[str, int]:
    return {
        table["table"]: table["rows"]
        for table in manifest["tables"]
    }


def ensure_snowflake_objects(cursor) -> None:
    cursor.execute(f"USE ROLE {ROLE}")
    cursor.execute(f"USE WAREHOUSE {WAREHOUSE}")
    cursor.execute(f"USE DATABASE {DATABASE}")
    cursor.execute(f"USE SCHEMA {SCHEMA}")

    cursor.execute(
        f"""
        CREATE FILE FORMAT IF NOT EXISTS {FILE_FORMAT}
            TYPE = PARQUET
            COMPRESSION = AUTO
        """
    )

    cursor.execute(
        f"""
        CREATE STAGE IF NOT EXISTS {STAGE}
            FILE_FORMAT = {FILE_FORMAT}
            DIRECTORY = (ENABLE = TRUE)
        """
    )


def upload_file(cursor, table_name: str, file_path: Path) -> None:
    file_uri = f"file://{file_path.resolve().as_posix()}"
    stage_path = f"@{STAGE}/{table_name}/"

    print(f"Uploading {file_path.name}...")

    cursor.execute(
        f"""
        PUT '{file_uri}'
        {stage_path}
        AUTO_COMPRESS = FALSE
        OVERWRITE = TRUE
        """
    )

    upload_results = cursor.fetchall()

    for result in upload_results:
        print(f"  Upload status: {result[-1]}")


def create_raw_table(cursor, table_name: str) -> None:
    print(f"Creating RAW.{table_name.upper()}...")

    cursor.execute(
        f"""
        CREATE OR REPLACE TABLE {table_name}
        USING TEMPLATE (
            SELECT ARRAY_AGG(
                OBJECT_CONSTRUCT(
                    'COLUMN_NAME', COLUMN_NAME,
                    'TYPE', TYPE,
                    'NULLABLE', NULLABLE,
                    'ORDER_ID', ORDER_ID
                )
            ) WITHIN GROUP (ORDER BY ORDER_ID)
            FROM TABLE(
                INFER_SCHEMA(
                    LOCATION => '@{STAGE}/{table_name}/',
                    FILE_FORMAT => '{FILE_FORMAT}',
                    IGNORE_CASE => TRUE
                )
            )
        )
        """
    )


def copy_into_table(cursor, table_name: str) -> None:
    print(f"Loading RAW.{table_name.upper()}...")

    cursor.execute(
        f"""
        COPY INTO {table_name}
        FROM @{STAGE}/{table_name}/
        FILE_FORMAT = (
            FORMAT_NAME = '{FILE_FORMAT}'
        )
        MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
        ON_ERROR = ABORT_STATEMENT
        """
    )

    copy_results = cursor.fetchall()

    for result in copy_results:
        print(
            f"  File: {result[0]}, "
            f"status: {result[1]}, "
            f"rows loaded: {result[3]}"
        )


def snowflake_row_count(cursor, table_name: str) -> int:
    cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
    return cursor.fetchone()[0]


def main() -> None:
    manifest = load_manifest()
    expected_counts = expected_row_counts(manifest)

    missing_files = [
        table_name
        for table_name in TABLES
        if not (DATA_DIRECTORY / f"{table_name}.parquet").exists()
    ]

    if missing_files:
        raise FileNotFoundError(
            f"Missing Parquet files: {missing_files}"
        )

    connection = connect_to_snowflake()

    try:
        cursor = connection.cursor()

        try:
            ensure_snowflake_objects(cursor)

            validation_results = []

            for table_name in TABLES:
                file_path = DATA_DIRECTORY / f"{table_name}.parquet"

                upload_file(cursor, table_name, file_path)
                create_raw_table(cursor, table_name)
                copy_into_table(cursor, table_name)

                expected = expected_counts[table_name]
                actual = snowflake_row_count(cursor, table_name)
                matches = expected == actual

                validation_results.append(
                    {
                        "table": table_name,
                        "expected": expected,
                        "actual": actual,
                        "matches": matches,
                    }
                )

                print(
                    f"  Validation: expected {expected:,}, "
                    f"loaded {actual:,}, match={matches}"
                )
                print()

            failures = [
                result
                for result in validation_results
                if not result["matches"]
            ]

            if failures:
                raise RuntimeError(
                    f"Row-count validation failed: {failures}"
                )

            print("All seven tables loaded and validated successfully.")

        finally:
            cursor.close()

    finally:
        connection.close()


if __name__ == "__main__":
    main()