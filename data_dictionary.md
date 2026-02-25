# 📘 Data Dictionary – Proyecto SQL E-Commerce (Olist)

Este documento describe la estructura del modelo de datos implementado en PostgreSQL.

El proyecto sigue una arquitectura por capas:

- staging → datos crudos importados desde CSV
- core → modelo dimensional tipo estrella
- analytics → tablas derivadas orientadas a negocio

---

# 🗂 Schema: staging (Raw Layer)

Contiene los datos originales sin transformación.

## staging.orders

| Columna | Tipo | Descripción |
|----------|------|-------------|
| order_id | text | Identificador único del pedido |
| customer_id | text | Identificador del cliente (relaciona con customers) |
| order_status | text | Estado del pedido |
| order_purchase_timestamp | timestamp | Fecha de compra |
| order_approved_at | timestamp | Fecha de aprobación |
| order_delivered_carrier_date | timestamp | Fecha de entrega al transportista |
| order_delivered_customer_date | timestamp | Fecha de entrega al cliente |
| order_estimated_delivery_date | timestamp | Fecha estimada de entrega |

## staging.customers

| Columna | Tipo | Descripción |
|----------|------|-------------|
| customer_id | text | Identificador único del cliente |
| customer_unique_id | text | Identificador único de persona |
| customer_zip_code_prefix | text | Prefijo código postal |
| customer_city | text | Ciudad |
| customer_state | text | Estado |

## staging.order_items

| Columna | Tipo | Descripción |
|----------|------|-------------|
| order_id | text | Pedido asociado |
| order_item_id | integer | Línea del pedido |
| product_id | text | Producto asociado |
| seller_id | text | Vendedor |
| shipping_limit_date | timestamp | Fecha límite de envío |
| price | numeric | Precio del producto |
| freight_value | numeric | Coste de envío |

## staging.order_payments

| Columna | Tipo | Descripción |
|----------|------|-------------|
| order_id | text | Pedido asociado |
| payment_sequential | integer | Secuencia del pago |
| payment_type | text | Tipo de pago |
| payment_installments | integer | Número de cuotas |
| payment_value | numeric | Importe pagado |

## staging.order_reviews

| Columna | Tipo | Descripción |
|----------|------|-------------|
| review_id | text | Identificador de review |
| order_id | text | Pedido asociado |
| review_score | integer | Puntuación (1–5) |
| review_comment_title | text | Título del comentario |
| review_comment_message | text | Mensaje |
| review_creation_date | timestamp | Fecha de creación |
| review_answer_timestamp | timestamp | Fecha de respuesta |

## staging.products

| Columna | Tipo | Descripción |
|----------|------|-------------|
| product_id | text | Identificador único del producto |
| product_category_name | text | Categoría original |
| product_name_length | integer | Longitud nombre |
| product_description_length | integer | Longitud descripción |
| product_photos_qty | integer | Número de fotos |
| product_weight_g | integer | Peso en gramos |
| product_length_cm | integer | Largo |
| product_height_cm | integer | Alto |
| product_width_cm | integer | Ancho |

## staging.sellers

| Columna | Tipo | Descripción |
|----------|------|-------------|
| seller_id | text | Identificador del vendedor |
| seller_zip_code_prefix | text | Prefijo postal |
| seller_city | text | Ciudad |
| seller_state | text | Estado |

---

# ⭐ Schema: core (Modelo Dimensional)

## core.dim_customers

Dimensión de clientes.

| Columna | Tipo | Descripción |
|----------|------|-------------|
| customer_sk | bigserial | Surrogate key |
| customer_id | text | ID original |
| customer_unique_id | text | ID persona |
| customer_zip_code_prefix | text | Prefijo postal |
| customer_city | text | Ciudad |
| customer_state | text | Estado |
| created_at | timestamp | Fecha de carga |

## core.dim_products

Dimensión de productos.

| Columna | Tipo | Descripción |
|----------|------|-------------|
| product_sk | bigserial | Surrogate key |
| product_id | text | ID original |
| product_category_name | text | Categoría original |
| product_category_name_english | text | Categoría traducida |
| is_category_unmapped | boolean | Flag categoría sin traducción |
| created_at | timestamp | Fecha de carga |

## core.dim_sellers

Dimensión de vendedores.

| Columna | Tipo | Descripción |
|----------|------|-------------|
| seller_sk | bigserial | Surrogate key |
| seller_id | text | ID original |
| seller_city | text | Ciudad |
| seller_state | text | Estado |
| created_at | timestamp | Fecha de carga |

## core.fact_orders

Tabla de hechos principal de pedidos.

| Columna | Tipo | Descripción |
|----------|------|-------------|
| order_id | text | Identificador del pedido |
| customer_sk | bigint | FK a dim_customers |
| order_status | text | Estado del pedido |
| order_purchase_timestamp | timestamp | Fecha compra |
| is_delivery_date_inconsistent | boolean | Flag inconsistencia entrega |
| is_approved_before_purchase | boolean | Flag aprobación inválida |
| is_estimated_before_purchase | boolean | Flag fecha estimada inválida |
| created_at | timestamp | Fecha carga |

## core.fact_order_items

Detalle de líneas de pedido.

| Columna | Tipo | Descripción |
|----------|------|-------------|
| order_id | text | Pedido |
| order_item_id | integer | Línea |
| product_sk | bigint | FK dim_products |
| seller_sk | bigint | FK dim_sellers |
| price | numeric | Precio |
| freight_value | numeric | Envío |
| created_at | timestamp | Fecha carga |

## core.fact_payments

Pagos asociados a pedidos.

| Columna | Tipo | Descripción |
|----------|------|-------------|
| order_id | text | Pedido |
| payment_sequential | integer | Secuencia |
| payment_type | text | Tipo |
| payment_installments | integer | Cuotas |
| payment_value | numeric | Importe |
| created_at | timestamp | Fecha carga |

## core.fact_reviews

Reviews asociadas a pedidos (1 por pedido).

| Columna | Tipo | Descripción |
|----------|------|-------------|
| order_id | text | Pedido |
| review_score | integer | Score |
| created_at | timestamp | Fecha carga |

---

# 📊 Schema: analytics (Capa de Negocio)

## analytics.rfm_customer

Tabla de segmentación RFM por cliente.

| Columna | Tipo | Descripción |
|----------|------|-------------|
| customer_unique_id | text | Cliente |
| recency_days | integer | Días desde última compra |
| frequency | integer | Número de pedidos |
| monetary_total | numeric | Gasto total |
| r_score | integer | Score recency (1–5) |
| f_score | integer | Score frequency (1–5) |
| m_score | integer | Score monetary (1–5) |
| rfm_segment | text | Segmento asignado |
| ltv_12m_approx | numeric | LTV estimado 12 meses |
| created_at | timestamp | Fecha generación |

## analytics.rfm_segment_summary

Resumen agregado por segmento RFM.

| Columna | Tipo | Descripción |
|----------|------|-------------|
| rfm_segment | text | Segmento |
| customers | integer | Número de clientes |
| revenue_total | numeric | Revenue total segmento |
| revenue_share | numeric | % sobre total |
| avg_ltv_12m_approx | numeric | LTV medio |
| created_at | timestamp | Fecha generación |

---

Este data dictionary permite comprender la estructura del modelo sin necesidad de inspeccionar directamente las tablas.
