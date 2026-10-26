-- DQ-001: Detect orders referencing missing customers
SELECT 
    COUNT(*) AS orphan_orders
FROM raw_olist.orders o
LEFT JOIN raw_olist.customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- DQ-002: Detect order items referencing missing orders

SELECT
    COUNT(*) AS orphan_order_items
FROM raw_olist.order_items AS oi
LEFT JOIN raw_olist.orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- DQ-003: Detect order items referencing missing products

SELECT
    COUNT(*) AS orphan_products
FROM raw_olist.order_items AS oi
LEFT JOIN raw_olist.products AS p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- DQ-004: Detect order items referencing missing sellers

SELECT
    COUNT(*) AS orphan_sellers
FROM raw_olist.order_items AS oi
LEFT JOIN raw_olist.sellers AS s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- DQ-005: Check missing required fields in orders

SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_id), '') IS NULL
    ) AS missing_order_id,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(customer_id), '') IS NULL
    ) AS missing_customer_id,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_status), '') IS NULL
    ) AS missing_order_status,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_purchase_timestamp), '') IS NULL
    ) AS missing_purchase_timestamp

FROM raw_olist.orders;

-- DQ-006: Check duplicate business keys

SELECT
    'customers' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS unique_keys,
    COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_or_null_keys
FROM raw_olist.customers

UNION ALL

SELECT
    'orders',
    COUNT(*),
    COUNT(DISTINCT order_id),
    COUNT(*) - COUNT(DISTINCT order_id)
FROM raw_olist.orders

UNION ALL

SELECT
    'products',
    COUNT(*),
    COUNT(DISTINCT product_id),
    COUNT(*) - COUNT(DISTINCT product_id)
FROM raw_olist.products

UNION ALL

SELECT
    'sellers',
    COUNT(*),
    COUNT(DISTINCT seller_id),
    COUNT(*) - COUNT(DISTINCT seller_id)
FROM raw_olist.sellers;

-- DQ-007: Check composite key uniqueness in order_items

SELECT
    COUNT(*) AS total_rows,

    COUNT(DISTINCT (order_id, order_item_id)) AS unique_keys,

    COUNT(*) - COUNT(DISTINCT (order_id, order_item_id))
        AS duplicate_composite_keys,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_id), '') IS NULL
           OR NULLIF(TRIM(order_item_id), '') IS NULL
    ) AS missing_key_fields

FROM raw_olist.order_items;

-- DQ-008: Validate price and freight_value

WITH validated AS (
    SELECT
        price,
        freight_value,
        CASE
            WHEN TRIM(price) ~ '^-?[0-9]+(\.[0-9]+)?$'
            THEN price::NUMERIC
        END AS price_num,
        CASE
            WHEN TRIM(freight_value) ~ '^-?[0-9]+(\.[0-9]+)?$'
            THEN freight_value::NUMERIC
        END AS freight_num
    FROM raw_olist.order_items
)

SELECT
    COUNT(*) AS total_rows,

    COUNT(*) FILTER (
        WHERE price_num IS NULL
    ) AS invalid_price,

    COUNT(*) FILTER (
        WHERE freight_num IS NULL
    ) AS invalid_freight,

    COUNT(*) FILTER (
        WHERE price_num < 0
    ) AS negative_price,

    COUNT(*) FILTER (
        WHERE freight_num < 0
    ) AS negative_freight

FROM validated;

-- DQ-009: Validate order purchase timestamps

WITH validated AS (
    SELECT
        order_purchase_timestamp,

        CASE
            WHEN TRIM(order_purchase_timestamp)
                ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$'
            THEN TRUE
            ELSE FALSE
        END AS valid_format

    FROM raw_olist.orders
)

SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(order_purchase_timestamp), '') IS NULL
    ) AS missing_timestamp,

    COUNT(*) FILTER (
        WHERE valid_format = FALSE
    ) AS invalid_format

FROM validated;

-- DQ-010: Check chronological order of order events

SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE order_approved_at::TIMESTAMP
              < order_purchase_timestamp::TIMESTAMP
    ) AS approved_before_purchase,

    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date::TIMESTAMP
              < order_approved_at::TIMESTAMP
    ) AS shipped_before_approval,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date::TIMESTAMP
              < order_delivered_carrier_date::TIMESTAMP
    ) AS delivered_before_shipping

FROM raw_olist.orders;