-- Proyecto: Olist E-commerce Analytics
-- Fase: 01 - Staging
-- Base de datos: PostgreSQL
-- Autor: Alejandro Álvarez

-- 01_staging.sql
-- Objetivo: crear esquema staging y preparar tablas crudas (raw) para importar los CSV de Olist.

CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS analytics;

-- Tabla staging.orders

DROP TABLE IF EXISTS staging.orders;

CREATE TABLE staging.orders (
  order_id text,
  customer_id text,
  order_status text,
  order_purchase_timestamp timestamp,
  order_approved_at timestamp,
  order_delivered_carrier_date timestamp,
  order_delivered_customer_date timestamp,
  order_estimated_delivery_date timestamp
);

-- NOTA:
-- El archivo olist_orders_dataset.csv fue importado
-- manualmente desde pgAdmin (Import/Export Data).

-- Tabla staging.customers
DROP TABLE IF EXISTS staging.customers;

CREATE TABLE staging.customers (
  customer_id text,
  customer_unique_id text,
  customer_zip_code_prefix text,
  customer_city text,
  customer_state text
);

-- Tabla staging.order_items
DROP TABLE IF EXISTS staging.order_items;

CREATE TABLE staging.order_items (
  order_id text,
  order_item_id integer,
  product_id text,
  seller_id text,
  shipping_limit_date timestamp,
  price numeric,
  freight_value numeric
);

-- Tabla staging.sellers
DROP TABLE IF EXISTS staging.sellers;

CREATE TABLE staging.sellers (
  seller_id text,
  seller_zip_code_prefix text,
  seller_city text,
  seller_state text
);

-- Tabla staging.products
DROP TABLE IF EXISTS staging.products;

CREATE TABLE staging.products (
  product_id text,
  product_category_name text,
  product_name_length integer,
  product_description_length integer,
  product_photos_qty integer,
  product_weight_g integer,
  product_length_cm integer,
  product_height_cm integer,
  product_width_cm integer
);

-- Tabla staging.order_payments
DROP TABLE IF EXISTS staging.order_payments;

CREATE TABLE staging.order_payments (
  order_id text,
  payment_sequential integer,
  payment_type text,
  payment_installments integer,
  payment_value numeric
);

-- Tabla staging.order_reviews
DROP TABLE IF EXISTS staging.order_reviews;

CREATE TABLE staging.order_reviews (
  review_id text,
  order_id text,
  review_score integer,
  review_comment_title text,
  review_comment_message text,
  review_creation_date timestamp,
  review_answer_timestamp timestamp
);

-- Tabla staging.geolocation
DROP TABLE IF EXISTS staging.geolocation;

CREATE TABLE staging.geolocation (
  geolocation_zip_code_prefix text,
  geolocation_lat numeric,
  geolocation_lng numeric,
  geolocation_city text,
  geolocation_state text
);

-- Tabla staging.product_category_name_translation
DROP TABLE IF EXISTS staging.product_category_name_translation;

CREATE TABLE staging.product_category_name_translation (
  product_category_name text,
  product_category_name_english text
);
