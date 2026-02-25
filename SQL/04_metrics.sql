-- Proyecto: Olist E-commerce Analytics
-- Fase: 04 - Business Metrics (Core)
-- Base de datos: PostgreSQL
-- Autor: Alejandro Álvarez
--
-- Definición de revenue:
-- revenue = SUM(price + freight_value) a nivel order_items (proxy de GMV).
-- Para ventas reales usamos solo pedidos con order_status = 'delivered'.


-- 0) SANITY CHECKS

-- Mix de pedidos por estado
WITH status_counts AS (
    SELECT
        o.order_status,
        COUNT(*) AS orders
    FROM core.fact_orders o
    GROUP BY 1
),
tot AS (
    SELECT SUM(orders) AS total_orders FROM status_counts
)
SELECT
    sc.order_status,
    sc.orders,
    ROUND(sc.orders::numeric / t.total_orders * 100, 2) AS pct_orders
FROM status_counts sc
CROSS JOIN tot t
ORDER BY sc.orders DESC;


-- 1) REVENUE: total vs delivered

WITH revenue_per_order AS (
    SELECT
        oi.order_id,
        SUM(oi.price + oi.freight_value) AS order_revenue
    FROM core.fact_order_items oi
    GROUP BY oi.order_id
)
SELECT
    SUM(rpo.order_revenue) AS revenue_all_orders,
    SUM(
        CASE WHEN o.order_status = 'delivered'
             THEN rpo.order_revenue
             ELSE 0
        END
    ) AS revenue_delivered_only
FROM core.fact_orders o
JOIN revenue_per_order rpo
  ON o.order_id = rpo.order_id;


-- 2) CLIENTES ÚNICOS (delivered)

SELECT
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers_delivered
FROM core.fact_orders o
JOIN core.dim_customers c
  ON o.customer_sk = c.customer_sk
WHERE o.order_status = 'delivered';


-- 3) AOV (Ticket medio) delivered: media y mediana

WITH revenue_per_order AS (
    SELECT
        oi.order_id,
        SUM(oi.price + oi.freight_value) AS order_revenue
    FROM core.fact_order_items oi
    GROUP BY oi.order_id
),
delivered_orders AS (
    SELECT
        rpo.order_revenue
    FROM core.fact_orders o
    JOIN revenue_per_order rpo
      ON o.order_id = rpo.order_id
    WHERE o.order_status = 'delivered'
)
SELECT
    AVG(order_revenue) AS avg_aov_delivered,
    PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY order_revenue) AS median_aov_delivered
FROM delivered_orders;


-- 4) MONTHLY DELIVERED REVENUE + Running total + MoM change

WITH revenue_per_order AS (
    SELECT
        oi.order_id,
        SUM(oi.price + oi.freight_value) AS order_revenue
    FROM core.fact_order_items oi
    GROUP BY oi.order_id
),
monthly AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS month,
        SUM(rpo.order_revenue) AS revenue_delivered
    FROM core.fact_orders o
    JOIN revenue_per_order rpo
      ON o.order_id = rpo.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY 1
)
SELECT
    month,
    revenue_delivered,
    SUM(revenue_delivered)
        OVER (ORDER BY month) AS revenue_running_total,
    revenue_delivered
        - LAG(revenue_delivered)
          OVER (ORDER BY month) AS mom_abs_change,
    ROUND(
        (
            revenue_delivered
            / NULLIF(
                LAG(revenue_delivered)
                OVER (ORDER BY month), 0
            ) - 1
        ) * 100,
        2
    ) AS mom_pct_change
FROM monthly
ORDER BY month;


-- 5) CATEGORY PERFORMANCE (delivered)

WITH category_revenue AS (
    SELECT
        p.product_category_name_english AS category,
        SUM(oi.price + oi.freight_value) AS revenue
    FROM core.fact_order_items oi
    JOIN core.fact_orders o
      ON oi.order_id = o.order_id
    JOIN core.dim_products p
      ON oi.product_sk = p.product_sk
    WHERE o.order_status = 'delivered'
    GROUP BY 1
),
tot AS (
    SELECT SUM(revenue) AS total_revenue
    FROM category_revenue
)
SELECT
    RANK() OVER (ORDER BY cr.revenue DESC) AS category_rank,
    cr.category,
    cr.revenue,
    ROUND(
        cr.revenue / t.total_revenue * 100,
        2
    ) AS pct_of_delivered_revenue
FROM category_revenue cr
CROSS JOIN tot t
ORDER BY cr.revenue DESC;


-- 6) SELLER PERFORMANCE (Top 20 delivered)

WITH seller_revenue AS (
    SELECT
        s.seller_id,
        s.seller_state,
        SUM(oi.price + oi.freight_value) AS revenue
    FROM core.fact_order_items oi
    JOIN core.fact_orders o
      ON oi.order_id = o.order_id
    JOIN core.dim_sellers s
      ON oi.seller_sk = s.seller_sk
    WHERE o.order_status = 'delivered'
    GROUP BY 1, 2
),
tot AS (
    SELECT SUM(revenue) AS total_revenue
    FROM seller_revenue
)
SELECT
    RANK() OVER (ORDER BY sr.revenue DESC) AS seller_rank,
    sr.seller_id,
    sr.seller_state,
    sr.revenue,
    ROUND(
        sr.revenue / t.total_revenue * 100,
        2
    ) AS pct_of_delivered_revenue
FROM seller_revenue sr
CROSS JOIN tot t
ORDER BY sr.revenue DESC
LIMIT 20;
