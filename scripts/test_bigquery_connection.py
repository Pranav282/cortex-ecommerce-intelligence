from google.cloud import bigquery


def main() -> None:
    client = bigquery.Client()

    query = """
        SELECT
            id,
            first_name,
            last_name,
            country,
            traffic_source,
            created_at
        FROM `bigquery-public-data.thelook_ecommerce.users`
        ORDER BY id
        LIMIT 10
    """

    dataframe = client.query(query).to_dataframe()

    print("BigQuery connection successful.")
    print(f"Rows returned: {len(dataframe)}")
    print(dataframe)


if __name__ == "__main__":
    main()