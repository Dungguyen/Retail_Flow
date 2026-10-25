SELECT COUNT(*) AS total_orders
FROM raw_olist.orders;

-- 2. Duplicate order IDs
SELECT
    order_id,
    COUNT(*) AS duplicate_count
FROM raw_olist.orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- 3. Missing customer IDs
SELECT COUNT(*) AS missing_customers
FROM raw_olist.orders
WHERE customer_id IS NULL
   OR TRIM(customer_id) = '';