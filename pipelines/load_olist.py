import csv
import os
import re
from pathlib import Path

import psycopg
from psycopg import sql
from dotenv import load_dotenv


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data" / "raw"
SCHEMA = "raw_olist"

load_dotenv(PROJECT_ROOT / ".env")

# Only load the nine expected Olist CSV files.
FILES = {
    "olist_customers_dataset.csv": "customers",
    "olist_orders_dataset.csv": "orders",
    "olist_order_items_dataset.csv": "order_items",
    "olist_order_payments_dataset.csv": "order_payments",
    "olist_products_dataset.csv": "products",
    "olist_sellers_dataset.csv": "sellers",
    "olist_order_reviews_dataset.csv": "order_reviews",
    "olist_geolocation_dataset.csv": "geolocation",
    "product_category_name_translation.csv": "category_translation",
}


def get_connection():
    return psycopg.connect(
        host=os.environ["SOURCE_DB_HOST"],
        port=os.environ["SOURCE_DB_PORT"],
        dbname=os.environ["SOURCE_DB_NAME"],
        user=os.environ["SOURCE_DB_USER"],
        password=os.environ["SOURCE_DB_PASSWORD"],
    )


def load_file(conn, filename, table_name):
    file_path = DATA_DIR / filename

    if not file_path.is_file():
        raise FileNotFoundError(file_path)

    with file_path.open("r", encoding="utf-8-sig", newline="") as file:
        reader = csv.reader(file)
        columns = next(reader)

    if (
        not columns
        or len(columns) != len(set(columns))
        or any(not re.fullmatch(r"[a-z][a-z0-9_]*", c) for c in columns)
    ):
        raise ValueError(f"Invalid CSV header: {filename}")

    table = sql.Identifier(SCHEMA, table_name)

    definitions = sql.SQL(", ").join(
        sql.SQL("{} TEXT").format(sql.Identifier(col))
        for col in columns
    )

    create_query = sql.SQL(
        "CREATE TABLE IF NOT EXISTS {} ({})"
    ).format(table, definitions)

    # Rebuild only the intended raw table during this initial seed.
    with conn.transaction():
        conn.execute(sql.SQL("DROP TABLE IF EXISTS {}").format(table))
        conn.execute(create_query)

        copy_query = sql.SQL(
            "COPY {} ({}) FROM STDIN WITH (FORMAT CSV, HEADER TRUE)"
        ).format(
            table,
            sql.SQL(", ").join(map(sql.Identifier, columns)),
        )

        with conn.cursor() as cur:
            with cur.copy(copy_query) as copy:
                with file_path.open("rb") as file:
                    while chunk := file.read(1024 * 1024):
                        copy.write(chunk)

        count = conn.execute(
            sql.SQL("SELECT COUNT(*) FROM {}").format(table)
        ).fetchone()[0]

    print(f"[PASS] {SCHEMA}.{table_name}: {count:,} rows")


def main():
    missing = [
        filename
        for filename in FILES
        if not (DATA_DIR / filename).is_file()
    ]

    if missing:
        raise FileNotFoundError(f"Missing CSV files: {missing}")

    with get_connection() as conn:
        conn.execute(
            sql.SQL("CREATE SCHEMA IF NOT EXISTS {}").format(
                sql.Identifier(SCHEMA)
            )
        )
        conn.commit()

        for filename, table_name in FILES.items():
            load_file(conn, filename, table_name)

    print("Olist raw ingestion completed.")


if __name__ == "__main__":
    main()