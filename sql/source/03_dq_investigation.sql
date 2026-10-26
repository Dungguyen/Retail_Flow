-- DQ-010A: Investigate shipping before approval

SELECT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    (
        order_approved_at::TIMESTAMP
        - order_delivered_carrier_date::TIMESTAMP
    ) AS time_difference

FROM raw_olist.orders

WHERE order_delivered_carrier_date::TIMESTAMP
      < order_approved_at::TIMESTAMP

ORDER BY time_difference DESC
LIMIT 20;

-- DQ-010B: Distribution of shipping-before-approval anomalies

WITH anomalies AS (
    SELECT
        order_id,
        order_status,
        order_purchase_timestamp::TIMESTAMP AS purchase_at,
        order_approved_at::TIMESTAMP
            - order_delivered_carrier_date::TIMESTAMP AS time_diff
    FROM raw_olist.orders
    WHERE order_delivered_carrier_date::TIMESTAMP
          < order_approved_at::TIMESTAMP
)

SELECT
    CASE
        WHEN time_diff <= INTERVAL '1 hour' THEN '01. <= 1 hour'
        WHEN time_diff <= INTERVAL '1 day' THEN '02. <= 1 day'
        WHEN time_diff <= INTERVAL '7 days' THEN '03. <= 7 days'
        ELSE '04. > 7 days'
    END AS anomaly_group,
    COUNT(*) AS affected_orders,
    COUNT(DISTINCT order_id) AS unique_orders
FROM anomalies
GROUP BY 1
ORDER BY 1;

-- DQ-010C: Investigate delivery before carrier handoff

WITH anomalies AS (
    SELECT
        order_id,
        order_status,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        (
            order_delivered_carrier_date::TIMESTAMP
            - order_delivered_customer_date::TIMESTAMP
        ) AS time_difference
    FROM raw_olist.orders
    WHERE order_delivered_customer_date::TIMESTAMP
          < order_delivered_carrier_date::TIMESTAMP
)

SELECT
    order_id,
    order_status,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    time_difference
FROM anomalies
ORDER BY time_difference DESC;