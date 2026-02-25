-- Proyecto: Olist E-commerce Analytics
-- Fase: 06 - RFM Segmentation & Approximate LTV
-- Base de datos: PostgreSQL
-- Autor: Alejandro Álvarez
--
-- Fuente: core
-- Outputs: analytics.rfm_customer, analytics.rfm_segment_summary
-- Definición de revenue: SUM(price + freight_value) en order_items para pedidos delivered (proxy GMV)

CREATE SCHEMA IF NOT EXISTS analytics;

DROP TABLE IF EXISTS analytics.rfm_customer;

CREATE TABLE analytics.rfm_customer AS
WITH delivered_orders AS (
    SELECT
        o.order_id,
        o.customer_sk,
        o.order_purchase_timestamp
    FROM core.fact_orders o
    WHERE o.order_status = 'delivered'
),
customer_map AS (
    SELECT
        c.customer_sk,
        c.customer_unique_id
    FROM core.dim_customers c
),
order_revenue AS (
    SELECT
        oi.order_id,
        SUM(oi.price + oi.freight_value) AS order_revenue
    FROM core.fact_order_items oi
    GROUP BY oi.order_id
),
customer_base AS (
    SELECT
        cm.customer_unique_id,
        MIN(dor.order_purchase_timestamp) AS first_order_ts,
        MAX(dor.order_purchase_timestamp) AS last_order_ts,
        COUNT(DISTINCT dor.order_id) AS frequency,
        SUM(orv.order_revenue) AS monetary_total
    FROM delivered_orders dor
    JOIN customer_map cm
        ON dor.customer_sk = cm.customer_sk
    JOIN order_revenue orv
        ON dor.order_id = orv.order_id
    GROUP BY cm.customer_unique_id
),
reference_date AS (
    SELECT MAX(order_purchase_timestamp) AS max_ts
    FROM delivered_orders
),
rfm_metrics AS (
    SELECT
        cb.customer_unique_id,
        cb.first_order_ts,
        cb.last_order_ts,
        cb.frequency,
        cb.monetary_total,
        (rd.max_ts::date - cb.last_order_ts::date) AS recency_days
    FROM customer_base cb
    CROSS JOIN reference_date rd
),
rfm_scoring AS (
    SELECT
        rm.*,

        -- Recency: menos días = mejor => score más alto
        NTILE(5) OVER (ORDER BY rm.recency_days DESC) AS r_score,

        -- Frequency: más pedidos = mejor
        NTILE(5) OVER (ORDER BY rm.frequency ASC) AS f_score,

        -- Monetary: más gasto = mejor
        NTILE(5) OVER (ORDER BY rm.monetary_total ASC) AS m_score
    FROM rfm_metrics rm
),
rfm_segmented AS (
    SELECT
        rs.*,
        (rs.r_score::text || rs.f_score::text || rs.m_score::text) AS rfm_score,
        CASE
            WHEN rs.r_score >= 4 AND rs.f_score >= 4 AND rs.m_score >= 4 THEN 'Champions'
            WHEN rs.r_score >= 4 AND rs.f_score >= 3 THEN 'Loyal Customers'
            WHEN rs.r_score = 5 AND rs.f_score <= 2 THEN 'New Customers'
            WHEN rs.r_score >= 3 AND rs.f_score >= 2 AND rs.m_score >= 3 THEN 'Potential Loyalist'
            WHEN rs.r_score = 3 AND rs.f_score = 1 THEN 'Need Attention'
            WHEN rs.r_score <= 2 AND rs.f_score >= 3 THEN 'At Risk'
            WHEN rs.r_score = 1 AND rs.f_score <= 2 THEN 'Hibernating'
            ELSE 'Others'
        END AS rfm_segment
    FROM rfm_scoring rs
),
ltv_calc AS (
    SELECT
        r.*,

        -- Meses activos (mínimo 1 para evitar división por 0)
        GREATEST(
            1,
            (DATE_PART('year', AGE(r.last_order_ts, r.first_order_ts)) * 12
             + DATE_PART('month', AGE(r.last_order_ts, r.first_order_ts))
            )::int
        ) AS lifespan_months,

        -- AOV por cliente
        (r.monetary_total / NULLIF(r.frequency, 0)) AS avg_order_value
    FROM rfm_segmented r
)
SELECT
    lc.customer_unique_id,
    lc.first_order_ts,
    lc.last_order_ts,
    lc.recency_days,
    lc.frequency,
    lc.monetary_total,
    lc.avg_order_value,
    lc.r_score,
    lc.f_score,
    lc.m_score,
    lc.rfm_score,
    lc.rfm_segment,
    lc.lifespan_months,

    -- LTV aproximado a 12 meses:
    -- pedidos/mes * AOV * 12
    ((lc.frequency::numeric / lc.lifespan_months) * lc.avg_order_value * 12) AS ltv_12m_approx,

    CURRENT_TIMESTAMP AS created_at
FROM ltv_calc lc;


-- VALIDATIONS (RFM)

-- 1) Row count
SELECT COUNT(*) AS total_customers_rfm
FROM analytics.rfm_customer;

-- 2) Segment distribution
SELECT
    rfm_segment,
    COUNT(*) AS customers
FROM analytics.rfm_customer
GROUP BY rfm_segment
ORDER BY customers DESC;

-- 3) Null checks
SELECT
    COUNT(*) FILTER (WHERE recency_days IS NULL) AS null_recency,
    COUNT(*) FILTER (WHERE frequency IS NULL) AS null_frequency,
    COUNT(*) FILTER (WHERE monetary_total IS NULL) AS null_monetary,
    COUNT(*) FILTER (WHERE r_score IS NULL OR f_score IS NULL OR m_score IS NULL) AS null_scores
FROM analytics.rfm_customer;

-- 4) Negative values check
SELECT
    COUNT(*) FILTER (WHERE recency_days < 0) AS negative_recency,
    COUNT(*) FILTER (WHERE frequency < 0) AS negative_frequency,
    COUNT(*) FILTER (WHERE monetary_total < 0) AS negative_monetary
FROM analytics.rfm_customer;

-- 5) Score ranges sanity check (min=1 y max=5)
SELECT
    MIN(r_score) AS min_r, MAX(r_score) AS max_r,
    MIN(f_score) AS min_f, MAX(f_score) AS max_f,
    MIN(m_score) AS min_m, MAX(m_score) AS max_m
FROM analytics.rfm_customer;

-- 6) Revenue reconciliation
SELECT
    SUM(monetary_total) AS total_rfm_revenue
FROM analytics.rfm_customer;

SELECT
    SUM(oi.price + oi.freight_value) AS total_core_revenue
FROM core.fact_orders o
JOIN core.fact_order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';


-- SEGMENT SUMMARY (Business-ready)

DROP TABLE IF EXISTS analytics.rfm_segment_summary;

CREATE TABLE analytics.rfm_segment_summary AS
SELECT
    rfm_segment,
    COUNT(*) AS customers,
    SUM(monetary_total) AS revenue_total,
    AVG(monetary_total) AS revenue_avg_per_customer,
    AVG(avg_order_value) AS avg_order_value,
    AVG(frequency) AS avg_orders_per_customer,
    AVG(recency_days) AS avg_recency_days,
    AVG(ltv_12m_approx) AS avg_ltv_12m_approx,
    ROUND(
        SUM(monetary_total)::numeric
        / NULLIF(SUM(SUM(monetary_total)) OVER (), 0),
        6
    ) AS revenue_share,
    CURRENT_TIMESTAMP AS created_at
FROM analytics.rfm_customer
GROUP BY rfm_segment;
