-- OLIST PROJECT — FAZ 1: STAGING DATABASE SETUP
-- Araç: SQL Server / SSMS
-- Açıklama: Ham CSV verilerinin yüklendiği staging veritabanı

-- 1. Veritabanı oluştur
CREATE DATABASE Olist_Project;
GO

USE Olist_Project;
GO

-- 2. Tablolar
CREATE TABLE Fact_Orders (
    order_id                      NVARCHAR(50)  NOT NULL,
    customer_id                   NVARCHAR(50)  NOT NULL,
    order_status                  NVARCHAR(20)  NOT NULL,
    order_purchase_timestamp      DATETIME2     NOT NULL,
    order_approved_at             DATETIME2     NULL,
    order_delivered_carrier_date  DATETIME2     NULL,
    order_delivered_customer_date DATETIME2     NULL,
    order_estimated_delivery_date DATETIME2     NOT NULL,
    CONSTRAINT PK_Fact_Orders PRIMARY KEY (order_id)
);

CREATE TABLE Fact_Order_Items (
    order_id            NVARCHAR(50)   NOT NULL,
    order_item_id       TINYINT        NOT NULL,
    product_id          NVARCHAR(50)   NOT NULL,
    seller_id           NVARCHAR(50)   NOT NULL,
    shipping_limit_date DATETIME2      NULL,
    price               DECIMAL(10,2)  NOT NULL,
    freight_value       DECIMAL(10,2)  NOT NULL,
    CONSTRAINT PK_Fact_Order_Items PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE Fact_Order_Payments (
    order_id             NVARCHAR(50)   NOT NULL,
    payment_sequential   TINYINT        NOT NULL,
    payment_type         NVARCHAR(20)   NOT NULL,
    payment_installments TINYINT        NOT NULL,
    payment_value        DECIMAL(10,2)  NOT NULL,
    CONSTRAINT PK_Fact_Order_Payments PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE Fact_Order_Reviews (
    review_id               NVARCHAR(50)  NOT NULL,
    order_id                NVARCHAR(50)  NOT NULL,
    review_score            TINYINT       NOT NULL,
    review_comment_title    NVARCHAR(100) NULL,
    review_comment_message  NVARCHAR(MAX) NULL,
    review_creation_date    DATETIME2     NOT NULL,
    review_answer_timestamp DATETIME2     NULL,
    CONSTRAINT PK_Fact_Order_Reviews PRIMARY KEY (review_id)
);

CREATE TABLE Dim_Customers (
    customer_id              NVARCHAR(50)  NOT NULL,
    customer_unique_id       NVARCHAR(50)  NOT NULL,
    customer_zip_code_prefix INT           NOT NULL,
    customer_city            NVARCHAR(100) NOT NULL,
    customer_state           NCHAR(2)      NOT NULL,
    CONSTRAINT PK_Dim_Customers PRIMARY KEY (customer_id)
);

CREATE TABLE Dim_Products (
    product_id                 NVARCHAR(50)  NOT NULL,
    product_category_name      NVARCHAR(100) NULL,
    product_name_lenght        SMALLINT      NULL,
    product_description_lenght INT           NULL,
    product_photos_qty         TINYINT       NULL,
    product_weight_g           INT           NULL,
    product_length_cm          SMALLINT      NULL,
    product_height_cm          SMALLINT      NULL,
    product_width_cm           SMALLINT      NULL,
    CONSTRAINT PK_Dim_Products PRIMARY KEY (product_id)
);

CREATE TABLE Dim_Sellers (
    seller_id              NVARCHAR(50)  NOT NULL,
    seller_zip_code_prefix INT           NOT NULL,
    seller_city            NVARCHAR(100) NOT NULL,
    seller_state           NCHAR(2)      NOT NULL,
    CONSTRAINT PK_Dim_Sellers PRIMARY KEY (seller_id)
);

CREATE TABLE Dim_Geolocation (
    geolocation_zip_code_prefix INT          NOT NULL,
    geolocation_lat             DECIMAL(9,6) NULL,
    geolocation_lng             DECIMAL(9,6) NULL,
    geolocation_city            NVARCHAR(100)NULL,
    geolocation_state           NCHAR(2)     NULL
);

CREATE TABLE Dim_Product_Category_Translation (
    product_category_name         NVARCHAR(100) NOT NULL,
    product_category_name_english NVARCHAR(100) NULL,
    CONSTRAINT PK_Dim_Category_Translation
        PRIMARY KEY (product_category_name)
);
GO

-- 3. Foreign Keys
ALTER TABLE Fact_Orders
    ADD CONSTRAINT FK_Orders_Customers
    FOREIGN KEY (customer_id) REFERENCES Dim_Customers(customer_id);

ALTER TABLE Fact_Order_Items
    ADD CONSTRAINT FK_Items_Orders
    FOREIGN KEY (order_id) REFERENCES Fact_Orders(order_id);

ALTER TABLE Fact_Order_Items
    ADD CONSTRAINT FK_Items_Products
    FOREIGN KEY (product_id) REFERENCES Dim_Products(product_id);

ALTER TABLE Fact_Order_Items
    ADD CONSTRAINT FK_Items_Sellers
    FOREIGN KEY (seller_id) REFERENCES Dim_Sellers(seller_id);

ALTER TABLE Fact_Order_Payments
    ADD CONSTRAINT FK_Payments_Orders
    FOREIGN KEY (order_id) REFERENCES Fact_Orders(order_id);

ALTER TABLE Fact_Order_Reviews
    ADD CONSTRAINT FK_Reviews_Orders
    FOREIGN KEY (order_id) REFERENCES Fact_Orders(order_id);
GO

-- 4. Index
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId  ON Fact_Orders(customer_id);
CREATE NONCLUSTERED INDEX IX_Items_ProductId    ON Fact_Order_Items(product_id);
CREATE NONCLUSTERED INDEX IX_Items_SellerId     ON Fact_Order_Items(seller_id);
CREATE NONCLUSTERED INDEX IX_Payments_OrderId   ON Fact_Order_Payments(order_id);
CREATE NONCLUSTERED INDEX IX_Reviews_OrderId    ON Fact_Order_Reviews(order_id);
GO
