# 📊 Proyecto SQL E-Commerce Analytics (Olist)

Proyecto end-to-end de análisis de datos desarrollado íntegramente en **PostgreSQL**, utilizando el dataset público de Olist (e-commerce brasileño).

El objetivo del proyecto es simular el trabajo real de un **Data Analyst en una empresa de e-commerce**, construyendo desde cero:

- Carga y validación de datos
- Modelado dimensional tipo estrella
- Métricas de negocio
- Cohortes y retención
- Segmentación RFM
- Estimación de LTV
- Tests de calidad y reconciliaciones

Este repositorio está estructurado como lo estaría un proyecto real en entorno profesional.

---
## 🔗 Quick Links
- 📘 Data Dictionary: `data_dictionary.md`
- 🧪 QA Tests: `SQL/07_tests.sql`
- 📈 Business Metrics: `SQL/04_metrics.sql`
- 👥 Cohorts & Retention: `SQL/05_cohorts_retention.sql`
- 💎 RFM + LTV: `SQL/06_rfm_ltv.sql`

---

## 🎯 Objetivo del Proyecto

Demostrar capacidad real para:

- Trabajar con datos crudos (raw data)
- Validar calidad e integridad
- Diseñar un modelo dimensional
- Construir métricas accionables
- Aplicar análisis avanzado (cohortes, RFM, LTV)
- Garantizar consistencia mediante tests y reconciliaciones

El proyecto no busca únicamente ejecutar queries, sino reflejar pensamiento analítico y estructura profesional.

---

## 🛠 Stack Tecnológico

- PostgreSQL 17
- SQL puro (sin Python ni notebooks)
- VS Code (desarrollo)
- pgAdmin (ejecución)
- GitHub (versionado y documentación)

---

## 🗂 Arquitectura del Proyecto

Se implementa una arquitectura por capas:

### 1️⃣ staging (Raw Layer)

Contiene los datos importados directamente desde los CSV originales sin modificaciones.

Objetivo:
- Preservar los datos originales
- Permitir reproducibilidad
- Separar origen de transformación

---

### 2️⃣ core (Modelo Dimensional)

Modelo tipo estrella compuesto por:

Dimensiones:
- dim_customers
- dim_products
- dim_sellers

Tablas de hechos:
- fact_orders
- fact_order_items
- fact_payments
- fact_reviews

Incluye:
- Surrogate keys (BIGSERIAL)
- Validaciones de calidad
- Flags de consistencia temporal
- Normalización de categorías

---

### 3️⃣ analytics (Capa de Negocio)

Tablas derivadas orientadas a análisis:

- rfm_customer
- rfm_segment_summary

Contiene métricas y segmentaciones listas para consumo de negocio.

---

## 📦 Estructura del Repositorio

```text
SQL/
│
├── 01_staging.sql
├── 02_cleaning.sql
├── 03_modeling.sql
├── 04_metrics.sql
├── 05_cohorts_retention.sql
├── 06_rfm_ltv.sql
└── 07_tests.sql
```

## 🔁 Reproducibilidad

Para ejecutar el proyecto desde cero:

1. Crear base de datos en PostgreSQL.
2. Ejecutar 01_staging.sql.
3. Importar los CSV del dataset Olist en schema staging.
4. Ejecutar secuencialmente los archivos del 02 al 07.

El proyecto es completamente reproducible y modular.

## 📈 Principales Insights Obtenidos

- El revenue real debe analizarse sobre pedidos delivered.
- Existen inconsistencias temporales que deben tratarse mediante flags, no eliminación.
- La retención cae significativamente después de los primeros meses.
- El segmento "At Risk" concentra un volumen histórico de revenue relevante.
- La distribución de categorías muestra concentración en pocas verticales dominantes.

## 🔍 Fases del Proyecto

### 01 - Staging
- Creación de schemas
- Definición de tablas raw
- Importación controlada de CSV

### 02 - Data Quality
- Validación de duplicados
- Integridad referencial
- Checks temporales
- Detección de inconsistencias
- Identificación de categorías sin traducción

### 03 - Modelado Dimensional
- Diseño del modelo estrella
- Implementación de dimensiones y hechos
- Uso de surrogate keys
- Resolución de anomalías detectadas en staging

### 04 - Métricas de Negocio
- Revenue total vs delivered
- Clientes únicos
- AOV (media y mediana)
- Revenue mensual
- MoM growth
- Ranking de categorías
- Ranking de sellers

### 05 - Cohortes y Retención
- Cohorte basada en primera compra delivered
- Cálculo de months_since
- Retención no acumulativa
- Matriz tipo heatmap (m0–m12)

### 06 - Segmentación RFM + LTV
- Recency, Frequency, Monetary
- Scoring con NTILE
- Segmentación estratégica
- Estimación de LTV a 12 meses
- Reconciliación total de revenue

### 07 - Tests y Reconciliaciones
- Validaciones de unicidad
- Orphans
- Valores negativos
- Checks de scoring
- Reconciliación revenue analytics vs core


---

## 📊 Dataset

Olist E-commerce Public Dataset (Kaggle).

Incluye información sobre:
- Pedidos
- Clientes
- Productos
- Vendedores
- Pagos
- Reviews
- Geolocalización

---

## 👤 Autor

Alejandro Álvarez  
Proyecto orientado a portfolio profesional para posición de Data Analyst Junior.



