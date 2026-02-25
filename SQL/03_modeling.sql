-- Proyecto: Olist E-commerce Analytics
-- Fase: 03 - Core Dimensional Model (Star Schema)
-- Base de datos: PostgreSQL
-- Autor: Alejandro Álvarez

-- 03_modeling.sql
-- Objetivo: construir el modelo dimensional (core) a partir de staging, aplicando decisiones de calidad.

-- Aseguramos schemas
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS analytics;

------------------------------------------------------------
-- DIMENSION: core.dim_customers
------------------------------------------------------------

DROP TABLE IF EXISTS core.dim_customers;

CREATE TABLE core.dim_customers (
    customer_sk BIGSERIAL PRIMARY KEY,
    customer_id TEXT NOT NULL UNIQUE,
    customer_unique_id TEXT NOT NULL,
    customer_zip_code_prefix TEXT,
    customer_city TEXT,
    customer_state TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO core.dim_customers (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT
    c.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state
FROM staging.customers c;

------------------------------------------------------------
-- DIMENSION: core.dim_products
------------------------------------------------------------

DROP TABLE IF EXISTS core.dim_products;

CREATE TABLE core.dim_products (
    product_sk BIGSERIAL PRIMARY KEY,
    product_id TEXT NOT NULL UNIQUE,
    product_category_name TEXT,
    product_category_name_english TEXT NOT NULL,
    is_category_unmapped BOOLEAN NOT NULL,
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO core.dim_products (
    product_id,
    product_category_name,
    product_category_name_english,
    is_category_unmapped,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT
    p.product_id,
    p.product_category_name,
    COALESCE(t.product_category_name_english, 'unknown') AS product_category_name_english,
    (p.product_category_name IS NOT NULL AND t.product_category_name_english IS NULL) AS is_category_unmapped,
    p.product_name_length,
    p.product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM staging.products p
LEFT JOIN staging.product_category_name_translation t
    ON p.product_category_name = t.product_category_name;

------------------------------------------------------------
-- DIMENSION: core.dim_sellers
------------------------------------------------------------

DROP TABLE IF EXISTS core.dim_sellers;

CREATE TABLE core.dim_sellers (
    seller_sk BIGSERIAL PRIMARY KEY,
    seller_id TEXT NOT NULL UNIQUE,
    seller_zip_code_prefix TEXT,
    seller_city TEXT,
    seller_state TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO core.dim_sellers (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
SELECT
    s.seller_id,
    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state
FROM staging.sellers s;

------------------------------------------------------------
-- FACT: core.fact_orders
------------------------------------------------------------

DROP TABLE IF EXISTS core.fact_orders;

CREATE TABLE core.fact_orders (
    order_id TEXT PRIMARY KEY,
    customer_sk BIGINT NOT NULL,
    order_status TEXT,
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    is_delivery_date_inconsistent BOOLEAN NOT NULL DEFAULT FALSE,
    is_approved_before_purchase BOOLEAN NOT NULL DEFAULT FALSE,
    is_estimated_before_purchase BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO core.fact_orders (
    order_id,
    customer_sk,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    is_delivery_date_inconsistent,
    is_approved_before_purchase,
    is_estimated_before_purchase
)
SELECT
    o.order_id,
    c.customer_sk,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    (
      o.order_delivered_customer_date IS NOT NULL
      AND o.order_delivered_carrier_date IS NOT NULL
      AND o.order_delivered_customer_date < o.order_delivered_carrier_date
    ) AS is_delivery_date_inconsistent,
    (
      o.order_approved_at IS NOT NULL
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_approved_at < o.order_purchase_timestamp
    ) AS is_approved_before_purchase,
    (
      o.order_estimated_delivery_date IS NOT NULL
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_estimated_delivery_date < o.order_purchase_timestamp
    ) AS is_estimated_before_purchase
FROM staging.orders o
JOIN core.dim_customers c
    ON o.customer_id = c.customer_id;

------------------------------------------------------------
-- FACT: core.fact_order_items
------------------------------------------------------------

DROP TABLE IF EXISTS core.fact_order_items;

CREATE TABLE core.fact_order_items (
    order_id TEXT NOT NULL,
    order_item_id INT NOT NULL,
    product_sk BIGINT NOT NULL,
    seller_sk BIGINT NOT NULL,
    price NUMERIC(10,2),
    freight_value NUMERIC(10,2),
    shipping_limit_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (order_id, order_item_id)
);

INSERT INTO core.fact_order_items (
    order_id,
    order_item_id,
    product_sk,
    seller_sk,
    price,
    freight_value,
    shipping_limit_date
)
SELECT
    oi.order_id,
    oi.order_item_id,
    p.product_sk,
    s.seller_sk,
    oi.price,
    oi.freight_value,
    oi.shipping_limit_date
FROM staging.order_items oi
JOIN core.dim_products p
    ON oi.product_id = p.product_id
JOIN core.dim_sellers s
    ON oi.seller_id = s.seller_id;

------------------------------------------------------------
-- FACT: core.fact_payments
------------------------------------------------------------

DROP TABLE IF EXISTS core.fact_payments;

CREATE TABLE core.fact_payments (
    order_id TEXT NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type TEXT,
    payment_installments INT,
    payment_value NUMERIC(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (order_id, payment_sequential)
);

INSERT INTO core.fact_payments (
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
)
SELECT
    op.order_id,
    op.payment_sequential,
    op.payment_type,
    op.payment_installments,
    op.payment_value
FROM staging.order_payments op;

------------------------------------------------------------
-- FACT: core.fact_reviews
-- review_id no es único; nos quedamos con 1 review por order_id (la más reciente)
------------------------------------------------------------

DROP TABLE IF EXISTS core.fact_reviews;

CREATE TABLE core.fact_reviews (
    order_id TEXT PRIMARY KEY,
    review_id TEXT,
    review_score INT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO core.fact_reviews (
    order_id,
    review_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
)
SELECT
    x.order_id,
    x.review_id,
    x.review_score,
    x.review_comment_title,
    x.review_comment_message,
    x.review_creation_date,
    x.review_answer_timestamp
FROM (
    SELECT
        r.*,
        ROW_NUMBER() OVER (
            PARTITION BY r.order_id
            ORDER BY r.review_creation_date DESC NULLS LAST,
                     r.review_answer_timestamp DESC NULLS LAST
        ) AS rn
    FROM staging.order_reviews r
) x
WHERE x.rn = 1;
