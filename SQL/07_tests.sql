-- Proyecto: Olist E-commerce Analytics
-- Fase: 07 - Data Quality & Consistency Tests
-- Base de datos: PostgreSQL
-- Autor: Alejandro Álvarez
--
-- Un test pasa si:
-- - Devuelve 0 filas
-- - O devuelve status = 'PASS' cuando se indica


-- 1) STAGING - sanity checks

-- 1.1 Row counts > 0
WITH counts AS (
  SELECT 'staging.orders' AS table_name, COUNT(*) AS row_count FROM staging.orders
  UNION ALL SELECT 'staging.customers', COUNT(*) FROM staging.customers
  UNION ALL SELECT 'staging.order_items', COUNT(*) FROM staging.order_items
  UNION ALL SELECT 'staging.order_payments', COUNT(*) FROM staging.order_payments
  UNION ALL SELECT 'staging.order_reviews', COUNT(*) FROM staging.order_reviews
  UNION ALL SELECT 'staging.products', COUNT(*) FROM staging.products
  UNION ALL SELECT 'staging.sellers', COUNT(*) FROM staging.sellers
)
SELECT
  table_name,
  row_count,
  CASE WHEN row_count > 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts
ORDER BY table_name;


-- 2) CORE - model integrity checks

-- 2.1 Unicidad PK fact_orders
SELECT order_id, COUNT(*)
FROM core.fact_orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- 2.2 Unicidad surrogate keys en dimensiones
SELECT customer_sk, COUNT(*)
FROM core.dim_customers
GROUP BY customer_sk
HAVING COUNT(*) > 1;

SELECT product_sk, COUNT(*)
FROM core.dim_products
GROUP BY product_sk
HAVING COUNT(*) > 1;

SELECT seller_sk, COUNT(*)
FROM core.dim_sellers
GROUP BY seller_sk
HAVING COUNT(*) > 1;

-- 2.3 Unicidad PK compuesta fact_order_items
SELECT order_id, order_item_id, COUNT(*)
FROM core.fact_order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

-- 2.4 Orphans
SELECT fo.order_id
FROM core.fact_orders fo
LEFT JOIN core.dim_customers dc
  ON fo.customer_sk = dc.customer_sk
WHERE dc.customer_sk IS NULL
LIMIT 50;

SELECT foi.order_id, foi.order_item_id
FROM core.fact_order_items foi
LEFT JOIN core.dim_products dp
  ON foi.product_sk = dp.product_sk
WHERE dp.product_sk IS NULL
LIMIT 50;

SELECT foi.order_id, foi.order_item_id
FROM core.fact_order_items foi
LEFT JOIN core.dim_sellers ds
  ON foi.seller_sk = ds.seller_sk
WHERE ds.seller_sk IS NULL
LIMIT 50;

-- 2.5 Valores no negativos
SELECT *
FROM core.fact_order_items
WHERE price < 0 OR freight_value < 0
LIMIT 50;

SELECT *
FROM core.fact_payments
WHERE payment_value < 0
LIMIT 50;


-- 3) ANALYTICS - RFM checks

-- 3.1 Unicidad customer_unique_id
SELECT customer_unique_id, COUNT(*)
FROM analytics.rfm_customer
GROUP BY customer_unique_id
HAVING COUNT(*) > 1;

-- 3.2 Null checks
SELECT
  COUNT(*) FILTER (WHERE recency_days IS NULL) AS null_recency,
  COUNT(*) FILTER (WHERE frequency IS NULL) AS null_frequency,
  COUNT(*) FILTER (WHERE monetary_total IS NULL) AS null_monetary
FROM analytics.rfm_customer;

-- 3.3 Score ranges
SELECT
  MIN(r_score) AS min_r, MAX(r_score) AS max_r,
  MIN(f_score) AS min_f, MAX(f_score) AS max_f,
  MIN(m_score) AS min_m, MAX(m_score) AS max_m
FROM analytics.rfm_customer;


-- 4) Revenue reconciliation

WITH rfm AS (
  SELECT SUM(monetary_total) AS total_rfm_revenue
  FROM analytics.rfm_customer
),
core_rev AS (
  SELECT SUM(oi.price + oi.freight_value) AS total_core_revenue
  FROM core.fact_orders o
  JOIN core.fact_order_items oi ON o.order_id = oi.order_id
  WHERE o.order_status = 'delivered'
),
diffs AS (
  SELECT
    rfm.total_rfm_revenue,
    core_rev.total_core_revenue,
    (rfm.total_rfm_revenue - core_rev.total_core_revenue) AS diff
  FROM rfm
  CROSS JOIN core_rev
)
SELECT
  total_rfm_revenue,
  total_core_revenue,
  diff,
  CASE WHEN diff = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM diffs;
