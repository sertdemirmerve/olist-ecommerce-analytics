-- OLIST PROJECT — FAZ 2: DATA WAREHOUSE SETUP
-- Araç: SQL Server / SSMS
-- Açıklama: Star Schema DWH + ETL Log + SQL Agent Job

-- 1. DWH Veritabanı
CREATE DATABASE Olist_DWH;
GO

USE Olist_DWH;
GO

-- 2. Dim_Date
CREATE TABLE Dim_Date (
    date_id     INT           NOT NULL,
    full_date   DATE          NOT NULL,
    year        SMALLINT      NOT NULL,
    quarter     TINYINT       NOT NULL,
    month       TINYINT       NOT NULL,
    month_name  NVARCHAR(10)  NOT NULL,
    week        TINYINT       NOT NULL,
    day_of_week TINYINT       NOT NULL,
    day_name    NVARCHAR(10)  NOT NULL,
    is_weekend  BIT           NOT NULL,
    CONSTRAINT PK_Dim_Date PRIMARY KEY (date_id)
);

-- 3. Dim_Customers
CREATE TABLE Dim_Customers (
    customer_id        NVARCHAR(50)  NOT NULL,
    customer_unique_id NVARCHAR(50)  NOT NULL,
    customer_city      NVARCHAR(100) NOT NULL,
    customer_state     NCHAR(2)      NOT NULL,
    CONSTRAINT PK_Dim_Customers PRIMARY KEY (customer_id)
);

-- 4. Dim_Products
CREATE TABLE Dim_Products (
    product_id NVARCHAR(50)  NOT NULL,
    category   NVARCHAR(100) NULL,
    weight_g   INT           NULL,
    length_cm  SMALLINT      NULL,
    height_cm  SMALLINT      NULL,
    width_cm   SMALLINT      NULL,
    CONSTRAINT PK_Dim_Products PRIMARY KEY (product_id)
);

-- 5. Dim_Sellers
CREATE TABLE Dim_Sellers (
    seller_id    NVARCHAR(50)  NOT NULL,
    seller_city  NVARCHAR(100) NOT NULL,
    seller_state NCHAR(2)      NOT NULL,
    CONSTRAINT PK_Dim_Sellers PRIMARY KEY (seller_id)
);

-- 6. Fact_Sales
CREATE TABLE Fact_Sales (
    order_id      NVARCHAR(50)  NOT NULL,
    order_item_id TINYINT       NOT NULL,
    date_id       INT           NOT NULL,
    customer_id   NVARCHAR(50)  NOT NULL,
    product_id    NVARCHAR(50)  NOT NULL,
    seller_id     NVARCHAR(50)  NOT NULL,
    order_status  NVARCHAR(20)  NOT NULL,
    price         DECIMAL(10,2) NOT NULL,
    freight_value DECIMAL(10,2) NOT NULL,
    total_revenue DECIMAL(10,2) NOT NULL,
    payment_value DECIMAL(10,2) NULL,
    review_score  TINYINT       NULL,
    delivery_days INT           NULL,
    is_late       BIT           NULL,
    CONSTRAINT PK_Fact_Sales
        PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT FK_Sales_Date
        FOREIGN KEY (date_id)     REFERENCES Dim_Date(date_id),
    CONSTRAINT FK_Sales_Customer
        FOREIGN KEY (customer_id) REFERENCES Dim_Customers(customer_id),
    CONSTRAINT FK_Sales_Product
        FOREIGN KEY (product_id)  REFERENCES Dim_Products(product_id),
    CONSTRAINT FK_Sales_Seller
        FOREIGN KEY (seller_id)   REFERENCES Dim_Sellers(seller_id)
);
GO

-- 7. ETL Log Tablosu
CREATE TABLE dbo.ETL_Log (
    log_id           INT IDENTITY(1,1) NOT NULL,
    paket_adi        NVARCHAR(100)     NOT NULL,
    tablo_adi        NVARCHAR(100)     NOT NULL,
    baslangic_zamani DATETIME2         NOT NULL,
    bitis_zamani     DATETIME2         NULL,
    okunan_satir     INT               NULL,
    yuklenen_satir   INT               NULL,
    reddedilen_satir INT               NULL,
    durum            NVARCHAR(20)      NOT NULL,
    hata_mesaji      NVARCHAR(1000)    NULL,
    CONSTRAINT PK_ETL_Log PRIMARY KEY (log_id)
);
GO

-- 8. Dim_Date Doldurma (2016-2019)
WITH DateCTE AS (
    SELECT CAST('2016-01-01' AS DATE) AS dt
    UNION ALL
    SELECT DATEADD(DAY, 1, dt)
    FROM DateCTE
    WHERE dt < '2019-12-31'
)
INSERT INTO Dim_Date (
    date_id, full_date, year, quarter, month,
    month_name, week, day_of_week, day_name, is_weekend
)
SELECT
    CAST(FORMAT(dt, 'yyyyMMdd') AS INT),
    dt,
    YEAR(dt),
    DATEPART(QUARTER, dt),
    MONTH(dt),
    DATENAME(MONTH, dt),
    DATEPART(WEEK, dt),
    DATEPART(WEEKDAY, dt),
    DATENAME(WEEKDAY, dt),
    CASE WHEN DATEPART(WEEKDAY, dt) IN (1,7) THEN 1 ELSE 0 END
FROM DateCTE
OPTION (MAXRECURSION 2000);
GO

-- 9. Dim Tablolarını Doldur
INSERT INTO Olist_DWH.dbo.Dim_Customers
SELECT customer_id, customer_unique_id, customer_city, customer_state
FROM Olist_Project.dbo.Dim_Customers;

INSERT INTO Olist_DWH.dbo.Dim_Products
SELECT p.product_id,
    ISNULL(t.product_category_name_english, 'uncategorized'),
    p.product_weight_g, p.product_length_cm,
    p.product_height_cm, p.product_width_cm
FROM Olist_Project.dbo.Dim_Products p
LEFT JOIN Olist_Project.dbo.Dim_Product_Category_Translation t
    ON p.product_category_name = t.product_category_name;

INSERT INTO Olist_DWH.dbo.Dim_Sellers
SELECT seller_id, seller_city, seller_state
FROM Olist_Project.dbo.Dim_Sellers;
GO

-- 10. SQL Agent Job
USE msdb;
GO

EXEC sp_add_job @job_name = N'Olist_DWH_Gece_Yukleme';

EXEC sp_add_jobstep
    @job_name      = N'Olist_DWH_Gece_Yukleme',
    @step_name     = N'Fact_Sales_Yukle',
    @subsystem     = N'TSQL',
    @database_name = N'Olist_DWH',
    @command       = N'EXEC sp_DWH_Fact_Sales_Yukle;';

EXEC sp_add_schedule
    @schedule_name     = N'Her_Gece_Saat_02',
    @freq_type         = 4,
    @freq_interval     = 1,
    @active_start_time = 020000;

EXEC sp_attach_schedule
    @job_name      = N'Olist_DWH_Gece_Yukleme',
    @schedule_name = N'Her_Gece_Saat_02';

EXEC sp_add_jobserver
    @job_name = N'Olist_DWH_Gece_Yukleme';
GO
