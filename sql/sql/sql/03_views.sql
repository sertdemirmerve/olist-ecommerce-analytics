-- OLIST PROJECT — FAZ 1: STAGING VIEWS
-- Araç: SQL Server / SSMS
-- Açıklama: Veri temizleme ve analiz view'ları

USE Olist_Project;
GO

-- 1. Orders
CREATE OR ALTER VIEW View_Orders_Cleaned AS
WITH Date_Validation AS (
    SELECT
        order_id, customer_id, order_status,
        TRY_CAST(order_purchase_timestamp      AS DATETIME2) AS purchase_date,
        TRY_CAST(order_approved_at             AS DATETIME2) AS approved_date,
        TRY_CAST(order_delivered_carrier_date  AS DATETIME2) AS carrier_date,
        TRY_CAST(order_delivered_customer_date AS DATETIME2) AS delivery_date,
        TRY_CAST(order_estimated_delivery_date AS DATETIME2) AS estimated_date
    FROM Fact_Orders
)
SELECT *,
    CASE
        WHEN delivery_date < purchase_date
            THEN 'Hata: Teslimat Siparisten Once'
        WHEN delivery_date IS NULL AND order_status = 'delivered'
            THEN 'Hata: Teslimat Tarihi Eksik'
        WHEN order_status = 'canceled' AND delivery_date IS NOT NULL
            THEN 'Hata: Iptal Edilen Urun Teslim Edilmis'
        ELSE 'Guvenli'
    END AS data_quality_flag
FROM Date_Validation;
GO

-- 2. Order Items
CREATE OR ALTER VIEW View_Order_Items_Cleaned AS
SELECT
    TRIM(order_id)   AS order_id,
    TRIM(product_id) AS product_id,
    TRIM(seller_id)  AS seller_id,
    TRY_CAST(price         AS DECIMAL(18,2)) AS price,
    TRY_CAST(freight_value AS DECIMAL(18,2)) AS freight_value,
    CASE
        WHEN TRY_CAST(price AS DECIMAL(18,2)) <= 0
            THEN 'Hata: Bedelsiz Urun'
        ELSE 'Guvenli'
    END AS financial_quality_flag
FROM Fact_Order_Items;
GO

-- 3. Order Payments
CREATE OR ALTER VIEW View_Order_Payments_Cleaned AS
SELECT
    order_id,
    MAX(payment_type) AS primary_payment_type,
    SUM(TRY_CAST(payment_value AS DECIMAL(18,2))) AS payment_total
FROM Fact_Order_Payments
GROUP BY order_id;
GO

-- 4. Order Reviews
CREATE OR ALTER VIEW View_Order_Reviews_Cleaned AS
SELECT
    order_id,
    ISNULL(TRY_CAST(review_score AS INT), 3) AS score,
    ISNULL(review_comment_message, 'No Comment') AS comment
FROM Fact_Order_Reviews;
GO

-- 5. Customers
CREATE OR ALTER VIEW View_Customers_Cleaned AS
SELECT DISTINCT
    customer_id,
    customer_unique_id,
    UPPER(TRIM(
        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        REPLACE(customer_city,
        'a','a'),'a','a'),'a','a'),
        'o','o'),'o','o'),'o','o'),
        'e','e'),'e','e'),'i','i'),
        'u','u'),'c','c')
    )) AS city_cleaned,
    UPPER(TRIM(customer_state)) AS state_code,
    customer_zip_code_prefix    AS zip_code
FROM Dim_Customers;
GO

-- 6. Products
CREATE OR ALTER VIEW View_Products_Cleaned AS
SELECT
    TRIM(p.product_id) AS product_id,
    UPPER(ISNULL(
        t.product_category_name_english,
        ISNULL(p.product_category_name, 'UNCATEGORIZED')
    )) AS category_name,
    p.product_weight_g AS weight_g
FROM Dim_Products p
LEFT JOIN View_Category_Translation_Cleaned t
    ON TRIM(p.product_category_name) = t.product_category_name;
GO

-- 7. Sellers
CREATE OR ALTER VIEW View_Sellers_Cleaned AS
SELECT DISTINCT
    TRIM(seller_id) AS seller_id,
    UPPER(TRIM(seller_city))  AS city_cleaned,
    UPPER(TRIM(seller_state)) AS state_code,
    seller_zip_code_prefix    AS zip_code
FROM Dim_Sellers;
GO

-- 8. Geolocation
CREATE OR ALTER VIEW View_Geolocation_Cleaned AS
SELECT
    geolocation_zip_code_prefix AS zip_code,
    AVG(TRY_CAST(geolocation_lat AS DECIMAL(18,15))) AS avg_lat,
    AVG(TRY_CAST(geolocation_lng AS DECIMAL(18,15))) AS avg_lng,
    UPPER(TRIM(MAX(geolocation_city)))  AS city_cleaned,
    UPPER(TRIM(MAX(geolocation_state))) AS state_code
FROM Dim_Geolocation
GROUP BY geolocation_zip_code_prefix;
GO

-- 9. Category Translation
CREATE OR ALTER VIEW View_Category_Translation_Cleaned AS
SELECT
    TRIM(product_category_name)         AS product_category_name,
    TRIM(product_category_name_english) AS product_category_name_english
FROM Dim_Product_Category_Translation;
GO

-- 10. Financial Reconciliation
CREATE OR ALTER VIEW View_Financial_Reconciliation AS
WITH Order_Totals AS (
    SELECT order_id,
        SUM(price + freight_value) AS expected_total
    FROM View_Order_Items_Cleaned
    GROUP BY order_id
),
Payment_Totals AS (
    SELECT order_id,
        SUM(payment_total) AS actual_paid
    FROM View_Order_Payments_Cleaned
    GROUP BY order_id
)
SELECT
    ot.order_id,
    ot.expected_total,
    pt.actual_paid,
    (ot.expected_total - pt.actual_paid) AS difference,
    CASE
        WHEN ABS(ot.expected_total - pt.actual_paid) < 1
            THEN 'Tam Esleme'
        WHEN ot.expected_total > pt.actual_paid
            THEN 'Indirim/Voucher Kullanilmis'
        WHEN ot.expected_total < pt.actual_paid
            THEN 'Hatali Fazla Odeme'
        ELSE 'Veri Eksik'
    END AS payment_status_flag
FROM Order_Totals ot
FULL OUTER JOIN Payment_Totals pt ON ot.order_id = pt.order_id;
GO

-- 11. Master Sales Analysis
CREATE OR ALTER VIEW View_Master_Sales_Analysis AS
SELECT
    o.*,
    oi.product_id,
    oi.seller_id,
    oi.price,
    oi.freight_value,
    (ISNULL(oi.price, 0) + ISNULL(oi.freight_value, 0)) AS total_item_value,
    oi.financial_quality_flag,
    c.customer_unique_id,
    c.city_cleaned  AS customer_city,
    c.state_code    AS customer_state,
    p.category_name,
    s.city_cleaned  AS seller_city,
    s.state_code    AS seller_state
FROM View_Orders_Cleaned o
LEFT JOIN View_Order_Items_Cleaned oi ON o.order_id    = oi.order_id
LEFT JOIN View_Customers_Cleaned   c  ON o.customer_id = c.customer_id
LEFT JOIN View_Products_Cleaned    p  ON oi.product_id = p.product_id
LEFT JOIN View_Sellers_Cleaned     s  ON oi.seller_id  = s.seller_id;
GO
