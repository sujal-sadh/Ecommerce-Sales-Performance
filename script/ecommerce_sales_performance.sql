/* ============================================================
   PROJECT: E-commerce Sales Performance & Operational Analysis

   DESCRIPTION:
   This project analyzes revenue trends, seller performance,
   product contribution, delivery efficiency, discount impact,
   and customer retention to uncover key business insights.

   DATA MODEL:
   - orders   → Fact Table
   - products → Dimension Table
   - sellers  → Dimension Table
   ============================================================ */


-- ============================================================
-- SECTION 1: DATA MODELING
-- ============================================================

-- ORDERS TABLE (Fact Table)
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    user_id TEXT,
    product_id TEXT,
    seller_id TEXT,
    discount DOUBLE PRECISION,
    final_price DOUBLE PRECISION,
    purchase_date DATE,
    shipping_time_days INT,
    location TEXT,
    device TEXT,
    payment_method TEXT,
    delivery_status TEXT,
    is_returned BOOLEAN
);

-- PRODUCTS TABLE (Dimension Table)
CREATE TABLE products (
    product_id TEXT PRIMARY KEY,
    category TEXT,
    subcategory TEXT,
    brand TEXT,
    price DOUBLE PRECISION,
    final_price DOUBLE PRECISION,
    rating DOUBLE PRECISION
);

-- SELLERS TABLE (Dimension Table)
CREATE TABLE sellers (
    seller_id TEXT PRIMARY KEY,
    seller_rating DOUBLE PRECISION
);

-- RELATIONSHIPS
ALTER TABLE orders
ADD CONSTRAINT fk_product
FOREIGN KEY (product_id) REFERENCES products(product_id);

ALTER TABLE orders
ADD CONSTRAINT fk_seller
FOREIGN KEY (seller_id) REFERENCES sellers(seller_id);



-- ============================================================
-- SECTION 2: DATA IMPORT
-- ============================================================

-- NOTE: Update file paths according to your system

COPY orders
FROM 'C:/your_path/orders.csv'
WITH ("C:\orders.csv", HEADER true);

COPY products
FROM 'C:/your_path/products.csv'
WITH ("C:\products.csv", HEADER true);

COPY sellers
FROM 'C:/your_path/sellers.csv'
WITH ("C:\sellers.csv", HEADER true);



-- ============================================================
-- SECTION 3: ANALYSIS
-- ============================================================


-- ============================================================
-- 1. Top 20% Customer Revenue Contribution
-- Insight: A small group of customers contributes majority of revenue
-- ============================================================

WITH customer_revenue AS (
    SELECT user_id, SUM(final_price) AS revenue
    FROM orders
    GROUP BY user_id
),
ranked AS (
    SELECT *,
           PERCENT_RANK() OVER (ORDER BY revenue DESC) AS rnk
    FROM customer_revenue
)
SELECT 
    ROUND(SUM(CASE WHEN rnk <= 0.2 THEN revenue END)::numeric, 2) AS top_20_revenue,
    ROUND(SUM(revenue)::numeric, 2) AS total_revenue,
    ROUND(
        (100.0 * SUM(CASE WHEN rnk <= 0.2 THEN revenue END) 
        / SUM(revenue))::numeric,
    2) AS top_20_contribution_percentage
FROM ranked;



-- ============================================================
-- 2. Repeat vs One-Time Customers
-- Insight: Measures customer retention behavior
-- ============================================================

SELECT 
    CASE 
        WHEN order_count = 1 THEN 'One-time'
        ELSE 'Repeat'
    END AS customer_type,
    COUNT(*) AS total_customers
FROM (
    SELECT user_id, COUNT(order_id) AS order_count
    FROM orders
    GROUP BY user_id
) t
GROUP BY customer_type;



-- ============================================================
-- 3. Monthly Revenue Trend
-- Insight: Identifies revenue growth patterns over time
-- ============================================================

SELECT
    DATE_TRUNC('month', purchase_date::date) AS month,
    ROUND(SUM(final_price)::numeric, 2) AS revenue
FROM orders
GROUP BY month
ORDER BY month DESC;



-- ============================================================
-- 4. Category Contribution to Revenue
-- Insight: Highlights top revenue-generating categories
-- ============================================================

SELECT 
    p.category,
    ROUND(SUM(o.final_price)::numeric, 2) AS revenue,
    ROUND(
        (100.0 * SUM(o.final_price) 
        / SUM(SUM(o.final_price)) OVER ())::numeric,
    2) AS percentage
FROM orders o
JOIN products p 
    ON o.product_id = p.product_id
GROUP BY p.category
ORDER BY revenue DESC;



-- ============================================================
-- 5. Top Performing Sellers
-- Insight: Identifies highest revenue-generating sellers
-- ============================================================

SELECT 
    s.seller_id,
    COUNT(o.order_id) AS total_orders,
    ROUND(SUM(o.final_price)::numeric, 2) AS revenue
FROM sellers s
JOIN orders o 
    ON s.seller_id = o.seller_id
GROUP BY s.seller_id
ORDER BY revenue DESC
LIMIT 10;



-- ============================================================
-- 6. Delivery Performance Impact
-- Insight: Evaluates delivery efficiency
-- ============================================================

SELECT 
    delivery_status,
    ROUND(AVG(shipping_time_days)::numeric, 2) AS avg_delivery_time,
    COUNT(*) AS total_orders
FROM orders
GROUP BY delivery_status;



-- ============================================================
-- 7. Discount Impact on Sales
-- Insight: Analyzes how discounts affect revenue
-- ============================================================

SELECT 
    CASE 
        WHEN discount = 0 THEN 'No Discount'
        WHEN discount <= 20 THEN 'Low Discount'
        ELSE 'High Discount'
    END AS discount_group,
    COUNT(*) AS total_orders,
    ROUND(SUM(final_price)::numeric, 2) AS revenue
FROM orders
GROUP BY discount_group;



-- ============================================================
-- 8. Product Performance (Revenue + Rating)
-- Insight: Compares product revenue with ratings
-- ============================================================

SELECT 
    p.product_id,
    p.rating,
    ROUND(SUM(o.final_price)::numeric, 2) AS revenue
FROM products p
JOIN orders o 
    ON p.product_id = o.product_id
GROUP BY p.product_id, p.rating
ORDER BY revenue DESC;



-- ============================================================
-- 9. Customer Cohort Analysis (Retention)
-- Insight: Tracks customer retention over time
-- ============================================================

WITH first_purchase AS (
    SELECT 
        user_id,
        DATE_TRUNC('month', MIN(purchase_date::date)) AS cohort_month
    FROM orders
    GROUP BY user_id
),
activity AS (
    SELECT 
        o.user_id,
        DATE_TRUNC('month', o.purchase_date::date) AS activity_month,
        f.cohort_month
    FROM orders o
    JOIN first_purchase f 
        ON o.user_id = f.user_id
),
cohort_data AS (
    SELECT 
        cohort_month,
        activity_month,
        COUNT(DISTINCT user_id) AS active_users
    FROM activity
    GROUP BY cohort_month, activity_month
)
SELECT 
    cohort_month,
    activity_month,
    active_users,
    ROUND(
        (100.0 * active_users /
        FIRST_VALUE(active_users) OVER (
            PARTITION BY cohort_month 
            ORDER BY activity_month
        ))::numeric,
    2) AS retention_rate
FROM cohort_data
ORDER BY cohort_month, activity_month;