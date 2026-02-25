-- Proyecto: Olist E-commerce Analytics
-- Fase: 02 - Data Quality Checks
-- Base de datos: PostgreSQL
-- Autor: Alejandro Álvarez

-- 02_cleaning.sql
-- Objetivo: validaciones de calidad sobre staging

-- 1. Comprobación de claves duplicadas

-- orders: order_id debería ser único
SELECT order_id, COUNT(*)
FROM staging.orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- customers: customer_id debería ser único
SELECT customer_id, COUNT(*)
FROM staging.customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- sellers: seller_id debería ser único
SELECT seller_id, COUNT(*)
FROM staging.sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;

-- products: product_id debería ser único
SELECT product_id, COUNT(*)
FROM staging.products
GROUP BY product_id
HAVING COUNT(*) > 1;


-- 1.2. Comprobación clave compuesta order_items

SELECT order_id, order_item_id, COUNT(*)
FROM staging.order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;


-- 2. Nulos en claves principales

SELECT COUNT(*) AS null_order_id
FROM staging.orders
WHERE order_id IS NULL;

SELECT COUNT(*) AS null_customer_id
FROM staging.customers
WHERE customer_id IS NULL;

SELECT COUNT(*) AS null_product_id
FROM staging.products
WHERE product_id IS NULL;

SELECT COUNT(*) AS null_seller_id
FROM staging.sellers
WHERE seller_id IS NULL;


-- 3. Consistencia entre tablas (integridad referencial)

-- Orders sin customer existente
SELECT COUNT(*) AS orders_without_customer
FROM staging.orders o
LEFT JOIN staging.customers c
  ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Order_items sin order existente
SELECT COUNT(*) AS order_items_without_order
FROM staging.order_items oi
LEFT JOIN staging.orders o
  ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Order_items sin product existente
SELECT COUNT(*) AS order_items_without_product
FROM staging.order_items oi
LEFT JOIN staging.products p
  ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Order_items sin seller existente
SELECT COUNT(*) AS order_items_without_seller
FROM staging.order_items oi
LEFT JOIN staging.sellers s
  ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;


-- 4. Checks de coherencia (fechas y dinero)

-- Checks de fechas inconsistentes en orders
SELECT COUNT(*) AS approved_before_purchase
FROM staging.orders
WHERE order_approved_at < order_purchase_timestamp;

SELECT COUNT(*) AS delivered_before_carrier
FROM staging.orders
WHERE order_delivered_customer_date < order_delivered_carrier_date;

SELECT COUNT(*) AS estimated_before_purchase
FROM staging.orders
WHERE order_estimated_delivery_date < order_purchase_timestamp;

-- Checks de valores monetarios negativos
SELECT COUNT(*) AS negative_price
FROM staging.order_items
WHERE price < 0;

SELECT COUNT(*) AS negative_freight
FROM staging.order_items
WHERE freight_value < 0;

SELECT COUNT(*) AS negative_payment
FROM staging.order_payments
WHERE payment_value < 0;



-- 5. Distribución de columnas categóricas

-- Order status
SELECT order_status, COUNT(*)
FROM staging.orders
GROUP BY order_status
ORDER BY COUNT(*) DESC;


-- Payment type
SELECT payment_type, COUNT(*)
FROM staging.order_payments
GROUP BY payment_type
ORDER BY COUNT(*) DESC;


-- Customer state
SELECT customer_state, COUNT(*)
FROM staging.customers
GROUP BY customer_state
ORDER BY COUNT(*) DESC;


-- Seller state
SELECT seller_state, COUNT(*)
FROM staging.sellers
GROUP BY seller_state
ORDER BY COUNT(*) DESC;


-- Product category
SELECT product_category_name, COUNT(*)
FROM staging.products
GROUP BY product_category_name
ORDER BY COUNT(*) DESC;


-- 6. Categorías de productos sin traducción (LEFT JOIN con tabla de translation)
-- Hallazgo: 13 productos con categoría sin mapping a inglés (2 categorías)
SELECT COUNT(*) AS products_with_unmapped_category
FROM staging.products p
LEFT JOIN staging.product_category_name_translation t
  ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL;

SELECT p.product_category_name, COUNT(*) AS n_products
FROM staging.products p
LEFT JOIN staging.product_category_name_translation t
  ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL
GROUP BY p.product_category_name
ORDER BY n_products DESC;

-- Nota para core:
-- En core.dim_products se hará LEFT JOIN a translation y se añadirá:
-- 1) product_category_name_english = 'unknown' cuando no haya match
-- 2) flag is_category_unmapped


-- Fechas inconsistentes detectadas en orders
-- Hallazgo: 23 pedidos con delivered_customer_date < delivered_carrier_date (sin NULLs)

-- Nota para core:
-- En core.fact_orders se añadirá flag is_delivery_date_inconsistent
-- para poder excluir/analizar estos pedidos sin borrar ni inventar datos.


-- Estrategia de calidad de datos (definida para CORE)

-- Se crearán los siguientes flags en el modelo CORE:

-- core.fact_orders:
-- is_delivery_date_inconsistent
-- is_approved_before_purchase
-- is_estimated_before_purchase

-- core.dim_products:
-- is_category_unmapped
