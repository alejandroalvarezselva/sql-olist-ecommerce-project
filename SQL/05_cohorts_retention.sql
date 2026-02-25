-- Proyecto: Olist E-commerce Analytics
-- Fase: 05 - Cohorts & Retention
-- Base de datos: PostgreSQL
-- Autor: Alejandro Álvarez
--
-- Reglas del análisis:
-- - Usar SOLO core
-- - Cohorte = mes de primera compra DELIVERED por customer_unique_id
-- - order_month = DATE_TRUNC('month', order_purchase_timestamp)
-- - Retención = % de clientes de la cohorte que vuelven a comprar en meses posteriores


-- 1) Base: pedidos DELIVERED con customer_unique_id y order_month
--    Nota: esta CTE será la base de todo el análisis de cohortes.
--    Nivel: 1 fila por pedido delivered (order_id).
WITH delivered_orders AS (
    SELECT
        fo.order_id,
        dc.customer_unique_id,
        fo.order_purchase_timestamp,
        DATE_TRUNC('month', fo.order_purchase_timestamp)::date AS order_month
    FROM core.fact_orders fo
    JOIN core.dim_customers dc
      ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
)
SELECT *
FROM delivered_orders
LIMIT 10;


-- 1.1) Check de volumen: número total de pedidos delivered
WITH delivered_orders AS (
    SELECT
        fo.order_id,
        dc.customer_unique_id,
        fo.order_purchase_timestamp,
        DATE_TRUNC('month', fo.order_purchase_timestamp)::date AS order_month
    FROM core.fact_orders fo
    JOIN core.dim_customers dc
      ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
)
SELECT
    COUNT(*) AS delivered_orders_cnt
FROM delivered_orders;


-- 1.2) Validación: asegurar 1 fila por pedido (el JOIN no debe duplicar order_id)
WITH delivered_orders AS (
    SELECT
        fo.order_id,
        dc.customer_unique_id,
        fo.order_purchase_timestamp,
        DATE_TRUNC('month', fo.order_purchase_timestamp)::date AS order_month
    FROM core.fact_orders fo
    JOIN core.dim_customers dc
      ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
)
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicated_rows
FROM delivered_orders;


-- 1.3) Validación: nulos en campos críticos (no deberían existir)
WITH delivered_orders AS (
    SELECT
        fo.order_id,
        dc.customer_unique_id,
        fo.order_purchase_timestamp,
        DATE_TRUNC('month', fo.order_purchase_timestamp)::date AS order_month
    FROM core.fact_orders fo
    JOIN core.dim_customers dc
      ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
)
SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN customer_unique_id IS NULL THEN 1 ELSE 0 END) AS null_customer_unique_id,
    SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END) AS null_purchase_ts,
    SUM(CASE WHEN order_month IS NULL THEN 1 ELSE 0 END) AS null_order_month
FROM delivered_orders;


-- 1.4) Validación: rango temporal (sanity check del periodo de datos)
WITH delivered_orders AS (
    SELECT
        fo.order_id,
        dc.customer_unique_id,
        fo.order_purchase_timestamp,
        DATE_TRUNC('month', fo.order_purchase_timestamp)::date AS order_month
    FROM core.fact_orders fo
    JOIN core.dim_customers dc
      ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
)
SELECT
    MIN(order_purchase_timestamp) AS min_purchase_ts,
    MAX(order_purchase_timestamp) AS max_purchase_ts
FROM delivered_orders;


-- 2) Cohort assignment: primer mes de compra DELIVERED por customer_unique_id
--    Resultado esperado: 1 fila por customer_unique_id con su cohort_month (YYYY-MM-01)

WITH delivered_orders AS (
    SELECT
        fo.order_id,
        dc.customer_unique_id,
        fo.order_purchase_timestamp,
        DATE_TRUNC('month', fo.order_purchase_timestamp)::date AS order_month
    FROM core.fact_orders fo
    JOIN core.dim_customers dc
      ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
),
customer_cohorts AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM delivered_orders
    GROUP BY 1
)
SELECT *
FROM customer_cohorts
ORDER BY cohort_month, customer_unique_id
LIMIT 20;

-- 2.1) Validación: 1 fila por customer_unique_id + cohort_month no nulo
WITH delivered_orders AS (
    SELECT
        dc.customer_unique_id,
        DATE_TRUNC('month', fo.order_purchase_timestamp)::date AS order_month
    FROM core.fact_orders fo
    JOIN core.dim_customers dc
      ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
),
customer_cohorts AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM delivered_orders
    GROUP BY 1
)
SELECT
    COUNT(*) AS cohort_rows,
    COUNT(DISTINCT customer_unique_id) AS distinct_customers,
    COUNT(*) - COUNT(DISTINCT customer_unique_id) AS duplicated_customers,
    SUM(CASE WHEN cohort_month IS NULL THEN 1 ELSE 0 END) AS null_cohort_month
FROM customer_cohorts;

-- 2.2) Tamaño de cohorte por mes (nuevos clientes delivered por mes)
WITH delivered_orders AS (
    SELECT
        dc.customer_unique_id,
        DATE_TRUNC('month', fo.order_purchase_timestamp)::date AS order_month
    FROM core.fact_orders fo
    JOIN core.dim_customers dc
      ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
),
customer_cohorts AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM delivered_orders
    GROUP BY 1
)
SELECT
    cohort_month,
    COUNT(*) AS customers_in_cohort
FROM customer_cohorts
GROUP BY 1
ORDER BY 1;


-- 3) Cohort activity: calcular months_since (meses desde la primera compra)

WITH delivered_orders AS (
    SELECT
        dc.customer_unique_id,
        DATE_TRUNC('month', fo.order_purchase_timestamp)::date AS order_month
    FROM core.fact_orders fo
    JOIN core.dim_customers dc
      ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
),

customer_cohorts AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM delivered_orders
    GROUP BY 1
),

cohort_activity AS (
    SELECT
        d.customer_unique_id,
        c.cohort_month,
        d.order_month,
        (
          (EXTRACT(YEAR FROM d.order_month)::int - EXTRACT(YEAR FROM c.cohort_month)::int) * 12
          +
          (EXTRACT(MONTH FROM d.order_month)::int - EXTRACT(MONTH FROM c.cohort_month)::int)
        ) AS months_since
    FROM delivered_orders d
    JOIN customer_cohorts c
      ON d.customer_unique_id = c.customer_unique_id
)

SELECT *
FROM cohort_activity
ORDER BY cohort_month, customer_unique_id, order_month
LIMIT 30;


-- 4) Cohort aggregation: clientes activos por cohorte y months_since
--    Objetivo: contar cuántos clientes de cada cohorte están activos en cada mes

WITH delivered_orders AS (
    SELECT
        dc.customer_unique_id,
        DATE_TRUNC('month', fo.order_purchase_timestamp)::date AS order_month
    FROM core.fact_orders fo
    JOIN core.dim_customers dc
      ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
),

customer_cohorts AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM delivered_orders
    GROUP BY 1
),

cohort_activity AS (
    SELECT
        d.customer_unique_id,
        c.cohort_month,
        d.order_month,
        (
          (EXTRACT(YEAR FROM d.order_month)::int - EXTRACT(YEAR FROM c.cohort_month)::int) * 12
          +
          (EXTRACT(MONTH FROM d.order_month)::int - EXTRACT(MONTH FROM c.cohort_month)::int)
        ) AS months_since
    FROM delivered_orders d
    JOIN customer_cohorts c
      ON d.customer_unique_id = c.customer_unique_id
)

SELECT
    cohort_month,
    months_since,
    COUNT(DISTINCT customer_unique_id) AS active_customers
FROM cohort_activity
GROUP BY 1, 2
ORDER BY cohort_month, months_since;


-- 5) Retention calculation: cálculo del retention_rate (%)

WITH delivered_orders AS (
    SELECT
        dc.customer_unique_id,
        DATE_TRUNC('month', fo.order_purchase_timestamp)::date AS order_month
    FROM core.fact_orders fo
    JOIN core.dim_customers dc
      ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
),

customer_cohorts AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM delivered_orders
    GROUP BY 1
),

cohort_activity AS (
    SELECT
        d.customer_unique_id,
        c.cohort_month,
        d.order_month,
        (
          (EXTRACT(YEAR FROM d.order_month)::int - EXTRACT(YEAR FROM c.cohort_month)::int) * 12
          +
          (EXTRACT(MONTH FROM d.order_month)::int - EXTRACT(MONTH FROM c.cohort_month)::int)
        ) AS months_since
    FROM delivered_orders d
    JOIN customer_cohorts c
      ON d.customer_unique_id = c.customer_unique_id
),

cohort_counts AS (
    SELECT
        cohort_month,
        months_since,
        COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM cohort_activity
    GROUP BY 1, 2
),

cohort_sizes AS (
    SELECT
        cohort_month,
        active_customers AS cohort_size
    FROM cohort_counts
    WHERE months_since = 0
)

SELECT
    cc.cohort_month,
    cc.months_since,
    cc.active_customers,
    cs.cohort_size,
    ROUND(
        cc.active_customers::numeric / NULLIF(cs.cohort_size, 0),
        4
    ) AS retention_rate
FROM cohort_counts cc
JOIN cohort_sizes cs
  ON cc.cohort_month = cs.cohort_month
WHERE cc.months_since BETWEEN 0 AND 12
ORDER BY cc.cohort_month, cc.months_since;


-- 6) Cohort matrix (pivot 0–12 meses)
--    Formato tipo heatmap: una fila por cohorte, columnas m0...m12

WITH delivered_orders AS (
    SELECT
        dc.customer_unique_id,
        DATE_TRUNC('month', fo.order_purchase_timestamp)::date AS order_month
    FROM core.fact_orders fo
    JOIN core.dim_customers dc
      ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
),

customer_cohorts AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM delivered_orders
    GROUP BY 1
),

cohort_activity AS (
    SELECT
        d.customer_unique_id,
        c.cohort_month,
        d.order_month,
        (
          (EXTRACT(YEAR FROM d.order_month)::int - EXTRACT(YEAR FROM c.cohort_month)::int) * 12
          +
          (EXTRACT(MONTH FROM d.order_month)::int - EXTRACT(MONTH FROM c.cohort_month)::int)
        ) AS months_since
    FROM delivered_orders d
    JOIN customer_cohorts c
      ON d.customer_unique_id = c.customer_unique_id
),

cohort_counts AS (
    SELECT
        cohort_month,
        months_since,
        COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM cohort_activity
    GROUP BY 1, 2
),

cohort_sizes AS (
    SELECT
        cohort_month,
        active_customers AS cohort_size
    FROM cohort_counts
    WHERE months_since = 0
),

retention AS (
    SELECT
        cc.cohort_month,
        cc.months_since,
        ROUND(
            cc.active_customers::numeric / NULLIF(cs.cohort_size, 0),
            4
        ) AS retention_rate
    FROM cohort_counts cc
    JOIN cohort_sizes cs
      ON cc.cohort_month = cs.cohort_month
    WHERE cc.months_since BETWEEN 0 AND 12
)

SELECT
    cohort_month,
    MAX(CASE WHEN months_since = 0  THEN retention_rate END) AS m0,
    MAX(CASE WHEN months_since = 1  THEN retention_rate END) AS m1,
    MAX(CASE WHEN months_since = 2  THEN retention_rate END) AS m2,
    MAX(CASE WHEN months_since = 3  THEN retention_rate END) AS m3,
    MAX(CASE WHEN months_since = 4  THEN retention_rate END) AS m4,
    MAX(CASE WHEN months_since = 5  THEN retention_rate END) AS m5,
    MAX(CASE WHEN months_since = 6  THEN retention_rate END) AS m6,
    MAX(CASE WHEN months_since = 7  THEN retention_rate END) AS m7,
    MAX(CASE WHEN months_since = 8  THEN retention_rate END) AS m8,
    MAX(CASE WHEN months_since = 9  THEN retention_rate END) AS m9,
    MAX(CASE WHEN months_since = 10 THEN retention_rate END) AS m10,
    MAX(CASE WHEN months_since = 11 THEN retention_rate END) AS m11,
    MAX(CASE WHEN months_since = 12 THEN retention_rate END) AS m12
FROM retention
GROUP BY 1
ORDER BY 1;

-- Validación final A: cohorte size (active_customers en months_since=0)
WITH delivered_orders AS (
    SELECT
        dc.customer_unique_id,
        DATE_TRUNC('month', fo.order_purchase_timestamp)::date AS order_month
    FROM core.fact_orders fo
    JOIN core.dim_customers dc
      ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
),
customer_cohorts AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM delivered_orders
    GROUP BY 1
)
SELECT
    cohort_month,
    COUNT(*) AS cohort_size
FROM customer_cohorts
GROUP BY 1
ORDER BY 1;

-- Validación final B: months_since nunca negativo
WITH delivered_orders AS (
    SELECT
        dc.customer_unique_id,
        DATE_TRUNC('month', fo.order_purchase_timestamp)::date AS order_month
    FROM core.fact_orders fo
    JOIN core.dim_customers dc
      ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
),
customer_cohorts AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM delivered_orders
    GROUP BY 1
),
cohort_activity AS (
    SELECT
        d.customer_unique_id,
        c.cohort_month,
        d.order_month,
        (
          (EXTRACT(YEAR FROM d.order_month)::int - EXTRACT(YEAR FROM c.cohort_month)::int) * 12
          +
          (EXTRACT(MONTH FROM d.order_month)::int - EXTRACT(MONTH FROM c.cohort_month)::int)
        ) AS months_since
    FROM delivered_orders d
    JOIN customer_cohorts c
      ON d.customer_unique_id = c.customer_unique_id
)
SELECT
    MIN(months_since) AS min_months_since
FROM cohort_activity;
