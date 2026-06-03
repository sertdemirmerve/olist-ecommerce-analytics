-- OLIST PROJECT — FAZ 2: STORED PROCEDURES
-- Araç: SQL Server / SSMS
-- Açıklama: ETL log SP'leri + ana ETL SP'si

USE Olist_Project;
GO

-- 1. ETL Log Başlat
CREATE OR ALTER PROCEDURE sp_ETL_Log_Baslat
    @paket_adi NVARCHAR(100),
    @tablo_adi NVARCHAR(100),
    @log_id    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO ETL_Log (paket_adi, tablo_adi, baslangic_zamani, durum)
    VALUES (@paket_adi, @tablo_adi, GETDATE(), 'DEVAM_EDIYOR');
    SET @log_id = SCOPE_IDENTITY();
END;
GO

-- 2. ETL Log Bitir
CREATE OR ALTER PROCEDURE sp_ETL_Log_Bitir
    @log_id           INT,
    @yuklenen_satir   INT,
    @reddedilen_satir INT,
    @durum            NVARCHAR(20),
    @hata_mesaji      NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE ETL_Log
    SET
        bitis_zamani     = GETDATE(),
        yuklenen_satir   = @yuklened_satir,
        reddedilen_satir = @reddedilen_satir,
        durum            = @durum,
        hata_mesaji      = @hata_mesaji
    WHERE log_id = @log_id;
END;
GO

USE Olist_DWH;
GO

-- 3. ETL Log Başlat (DWH)
CREATE OR ALTER PROCEDURE sp_ETL_Log_Baslat
    @paket_adi NVARCHAR(100),
    @tablo_adi NVARCHAR(100),
    @log_id    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO ETL_Log (paket_adi, tablo_adi, baslangic_zamani, durum)
    VALUES (@paket_adi, @tablo_adi, GETDATE(), 'DEVAM_EDIYOR');
    SET @log_id = SCOPE_IDENTITY();
END;
GO

-- 4. ETL Log Bitir (DWH)
CREATE OR ALTER PROCEDURE sp_ETL_Log_Bitir
    @log_id           INT,
    @yuklenen_satir   INT,
    @reddedilen_satir INT,
    @durum            NVARCHAR(20),
    @hata_mesaji      NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE ETL_Log
    SET
        bitis_zamani     = GETDATE(),
        yuklenen_satir   = @yuklenen_satir,
        reddedilen_satir = @reddedilen_satir,
        durum            = @durum,
        hata_mesaji      = @hata_mesaji
    WHERE log_id = @log_id;
END;
GO

-- 5. Ana ETL SP — Fact_Sales Yükle
CREATE OR ALTER PROCEDURE sp_DWH_Fact_Sales_Yukle
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @log_id INT;
    DECLARE @satir  INT;
    DECLARE @hata   NVARCHAR(1000);

    EXEC sp_ETL_Log_Baslat
        @paket_adi = 'Olist_DWH_Job',
        @tablo_adi = 'Fact_Sales',
        @log_id    = @log_id OUTPUT;

    BEGIN TRY
        TRUNCATE TABLE Olist_DWH.dbo.Fact_Sales;

        INSERT INTO Olist_DWH.dbo.Fact_Sales (
            order_id, order_item_id, date_id,
            customer_id, product_id, seller_id,
            order_status, price, freight_value, total_revenue,
            payment_value, review_score, delivery_days, is_late
        )
        SELECT
            oi.order_id,
            oi.order_item_id,
            CONVERT(INT, CONVERT(VARCHAR(8),
                o.order_purchase_timestamp, 112)),
            o.customer_id,
            oi.product_id,
            oi.seller_id,
            o.order_status,
            oi.price,
            oi.freight_value,
            oi.price + oi.freight_value,
            pay.total_payment_value,
            r.avg_score,
            DATEDIFF(DAY,
                o.order_purchase_timestamp,
                o.order_delivered_customer_date),
            CASE
                WHEN o.order_delivered_customer_date >
                     o.order_estimated_delivery_date
                THEN 1 ELSE 0
            END
        FROM Olist_Project.dbo.Fact_Order_Items oi
        JOIN Olist_Project.dbo.Fact_Orders o
            ON oi.order_id = o.order_id
        LEFT JOIN (
            SELECT order_id,
                   SUM(payment_value) AS total_payment_value
            FROM Olist_Project.dbo.Fact_Order_Payments
            GROUP BY order_id
        ) pay ON oi.order_id = pay.order_id
        LEFT JOIN (
            SELECT order_id,
                   CAST(AVG(CAST(review_score AS FLOAT))
                        AS TINYINT) AS avg_score
            FROM Olist_Project.dbo.Fact_Order_Reviews
            WHERE ISNUMERIC(review_score) = 1
            GROUP BY order_id
        ) r ON oi.order_id = r.order_id
        WHERE CONVERT(INT, CONVERT(VARCHAR(8),
              o.order_purchase_timestamp, 112))
              IN (SELECT date_id FROM Olist_DWH.dbo.Dim_Date);

        SET @satir = @@ROWCOUNT;

        EXEC sp_ETL_Log_Bitir
            @log_id           = @log_id,
            @yuklenen_satir   = @satir,
            @reddedilen_satir = 0,
            @durum            = 'BASARILI';

    END TRY
    BEGIN CATCH
        SET @hata = ERROR_MESSAGE();
        EXEC sp_ETL_Log_Bitir
            @log_id           = @log_id,
            @yuklenen_satir   = 0,
            @reddedilen_satir = 0,
            @durum            = 'HATA',
            @hata_mesaji      = @hata;
    END CATCH;
END;
GO
