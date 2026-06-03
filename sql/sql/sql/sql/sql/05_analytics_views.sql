-- OLIST PROJECT — FAZ 3/5: ANALİTİK VIEW'LAR VE SP'LER
-- Araç: SQL Server / SSMS
-- Açıklama: RFM, Retention, CLV, Cohort, Mevsimsellik,
--           Kategori Büyüme, Gecikme Analizi

USE Olist_DWH;
GO

-- ============================================================
-- 1. RFM ANALİZİ
-- ============================================================
CREATE OR ALTER VIEW vw_RFM AS
WITH rfm_base AS (
    SELECT
        c.customer_unique_id,
        DATEDIFF(DAY, MAX(d.full_date), '2018-10-01') AS recency_days,
        COUNT(DISTINCT fs.order_id)                    AS frequency,
        SUM(fs.total_revenue)                          AS monetary
    FROM Fact_Sales fs
    JOIN Dim_Customers c ON fs.customer_id = c.customer_id
    JOIN Dim_Date d      ON fs.date_id     = d.date_id
    WHERE fs.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
),
rfm_scores AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency    ASC)  AS f_score,
        NTILE(5) OVER (ORDER BY monetary     ASC)  AS m_score
    FROM rfm_base
)
SELECT
    customer_unique_id,
    recency_days, frequency,
    ROUND(monetary, 2)          AS monetary,
    r_score, f_score, m_score,
    r_score + f_score + m_score AS rfm_toplam,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champion'
        WHEN r_score >= 3 AND f_score >= 3                  THEN 'Loyal Customer'
        WHEN r_score >= 4 AND f_score <= 2                  THEN 'Recent Customer'
        WHEN r_score <= 2 AND f_score >= 3                  THEN 'At Risk'
        WHEN r_score <= 2 AND m_score >= 4                  THEN 'Cannot Lose Them'
        WHEN r_score = 1  AND f_score = 1                   THEN 'Lost Customer'
        ELSE 'Potential Loyalist'
    END AS segment
FROM rfm_scores;
GO

-- ============================================================
-- 2. RETENTION & CHURN
-- ============================================================
CREATE OR ALTER VIEW vw_Retention AS
WITH musteri_siparis AS (
    SELECT
        c.customer_unique_id,
        d.full_date AS siparis_tarihi,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY d.full_date
        ) AS siparis_sira
    FROM Fact_Sales fs
    JOIN Dim_Customers c ON fs.customer_id = c.customer_id
    JOIN Dim_Date d      ON fs.date_id     = d.date_id
    WHERE fs.order_status NOT IN ('canceled', 'unavailable')
),
tekrar_musteriler AS (
    SELECT COUNT(DISTINCT customer_unique_id) AS geri_donen
    FROM musteri_siparis WHERE siparis_sira >= 2
),
toplam_musteriler AS (
    SELECT COUNT(DISTINCT customer_unique_id) AS toplam
    FROM musteri_siparis
)
SELECT
    t.toplam                                                AS toplam_musteri,
    r.geri_donen                                            AS geri_donen_musteri,
    t.toplam - r.geri_donen                                 AS tek_seferlik,
    ROUND(100.0 * r.geri_donen / t.toplam, 2)              AS retention_rate_pct,
    ROUND(100.0 * (t.toplam - r.geri_donen) / t.toplam, 2) AS churn_rate_pct
FROM toplam_musteriler t
CROSS JOIN tekrar_musteriler r;
GO

-- ============================================================
-- 3. HAREKETLİ ORTALAMA
-- ============================================================
CREATE OR ALTER VIEW vw_Moving_Average AS
WITH gunluk_satis AS (
    SELECT
        d.full_date                     AS satis_tarihi,
        d.year AS yil, d.month AS ay, d.month_name AS ay_adi,
        COUNT(DISTINCT fs.order_id)     AS siparis_sayisi,
        ROUND(SUM(fs.total_revenue), 2) AS gunluk_gelir
    FROM Fact_Sales fs
    JOIN Dim_Date d ON fs.date_id = d.date_id
    WHERE fs.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY d.full_date, d.year, d.month, d.month_name
)
SELECT
    satis_tarihi, yil, ay, ay_adi, siparis_sayisi, gunluk_gelir,
    ROUND(AVG(gunluk_gelir) OVER (
        ORDER BY satis_tarihi
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS hareketli_ort_7g,
    ROUND(AVG(gunluk_gelir) OVER (
        ORDER BY satis_tarihi
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 2) AS hareketli_ort_30g,
    ROUND(SUM(gunluk_gelir) OVER (
        PARTITION BY yil, ay
    ), 2) AS aylik_toplam_gelir
FROM gunluk_satis;
GO

-- ============================================================
-- 4. KATEGORİ ANALİZİ
-- ============================================================
CREATE OR ALTER VIEW vw_Kategori_Analiz AS
SELECT
    p.category                                         AS kategori,
    COUNT(DISTINCT fs.order_id)                        AS siparis_sayisi,
    COUNT(DISTINCT fs.customer_id)                     AS musteri_sayisi,
    ROUND(SUM(fs.total_revenue), 2)                    AS toplam_gelir,
    ROUND(AVG(fs.price), 2)                            AS ort_urun_fiyati,
    ROUND(AVG(fs.freight_value), 2)                    AS ort_kargo_ucreti,
    ROUND(AVG(fs.delivery_days), 0)                    AS ort_teslimat_gun,
    ROUND(AVG(CAST(fs.review_score AS FLOAT)), 2)      AS ort_puan,
    SUM(CAST(fs.is_late AS INT))                       AS gec_teslimat_sayisi,
    ROUND(100.0 * SUM(CAST(fs.is_late AS INT))
        / COUNT(*), 2)                                 AS gec_teslimat_pct
FROM Fact_Sales fs
JOIN Dim_Products p ON fs.product_id = p.product_id
WHERE fs.order_status NOT IN ('canceled', 'unavailable')
    AND p.category IS NOT NULL
GROUP BY p.category;
GO

-- ============================================================
-- 5. SATICI SCORECARD
-- ============================================================
CREATE OR ALTER VIEW vw_Satici_Scorecard AS
SELECT
    s.seller_id, s.seller_city, s.seller_state,
    COUNT(DISTINCT fs.order_id)                    AS toplam_siparis,
    ROUND(SUM(fs.total_revenue), 2)                AS toplam_gelir,
    ROUND(AVG(CAST(fs.review_score AS FLOAT)), 2)  AS ort_puan,
    ROUND(AVG(fs.delivery_days), 1)                AS ort_teslimat_gun,
    SUM(CAST(fs.is_late AS INT))                   AS gec_teslimat_sayisi,
    ROUND(100.0 * SUM(CAST(fs.is_late AS INT))
        / COUNT(*), 2)                             AS gec_teslimat_pct,
    CASE
        WHEN AVG(CAST(fs.review_score AS FLOAT)) >= 4.5
             AND (100.0 * SUM(CAST(fs.is_late AS INT)) / COUNT(*)) < 5
             THEN 'Yildiz Satici'
        WHEN AVG(CAST(fs.review_score AS FLOAT)) < 3
             OR  (100.0 * SUM(CAST(fs.is_late AS INT)) / COUNT(*)) > 20
             THEN 'Riskli Satici'
        ELSE 'Normal Satici'
    END AS satici_kategorisi
FROM Fact_Sales fs
JOIN Dim_Sellers s ON fs.seller_id = s.seller_id
WHERE fs.order_status NOT IN ('canceled', 'unavailable')
GROUP BY s.seller_id, s.seller_city, s.seller_state
HAVING COUNT(DISTINCT fs.order_id) >= 10;
GO

-- ============================================================
-- 6. COHORT ANALİZİ
-- ============================================================
CREATE OR ALTER VIEW vw_Cohort AS
WITH ilk_siparis AS (
    SELECT
        c.customer_unique_id,
        MIN(d.full_date) AS ilk_satin_alma,
        DATEFROMPARTS(YEAR(MIN(d.full_date)),
                      MONTH(MIN(d.full_date)), 1) AS cohort_ay
    FROM Fact_Sales fs
    JOIN Dim_Customers c ON fs.customer_id = c.customer_id
    JOIN Dim_Date d      ON fs.date_id     = d.date_id
    WHERE fs.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
),
siparis_detay AS (
    SELECT
        i.customer_unique_id,
        i.cohort_ay,
        DATEFROMPARTS(YEAR(d.full_date),
                      MONTH(d.full_date), 1) AS siparis_ay,
        DATEDIFF(MONTH, i.cohort_ay,
            DATEFROMPARTS(YEAR(d.full_date),
                          MONTH(d.full_date), 1)) AS ay_farki
    FROM Fact_Sales fs
    JOIN Dim_Customers c ON fs.customer_id = c.customer_id
    JOIN Dim_Date d      ON fs.date_id     = d.date_id
    JOIN ilk_siparis i   ON c.customer_unique_id = i.customer_unique_id
    WHERE fs.order_status NOT IN ('canceled', 'unavailable')
)
SELECT
    cohort_ay,
    ay_farki,
    COUNT(DISTINCT customer_unique_id) AS musteri_sayisi
FROM siparis_detay
GROUP BY cohort_ay, ay_farki;
GO

-- ============================================================
-- 7. CLV (CUSTOMER LIFETIME VALUE)
-- ============================================================
CREATE OR ALTER VIEW vw_CLV AS
WITH musteri_metrikleri AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT fs.order_id)     AS toplam_siparis,
        SUM(fs.total_revenue)           AS toplam_harcama,
        MIN(d.full_date)                AS ilk_siparis,
        MAX(d.full_date)                AS son_siparis,
        DATEDIFF(DAY,
            MIN(d.full_date),
            MAX(d.full_date))           AS musteri_omru_gun,
        AVG(fs.total_revenue)           AS ort_siparis_degeri
    FROM Fact_Sales fs
    JOIN Dim_Customers c ON fs.customer_id = c.customer_id
    JOIN Dim_Date d      ON fs.date_id     = d.date_id
    WHERE fs.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
)
SELECT
    customer_unique_id,
    toplam_siparis,
    ROUND(toplam_harcama, 2)     AS toplam_harcama,
    ilk_siparis, son_siparis,
    musteri_omru_gun,
    ROUND(ort_siparis_degeri, 2) AS ort_siparis_degeri,
    ROUND(ort_siparis_degeri * toplam_siparis, 2) AS tahmini_clv,
    CASE
        WHEN toplam_harcama >= 1000 THEN 'Yuksek Degerli'
        WHEN toplam_harcama >= 300  THEN 'Orta Degerli'
        ELSE 'Dusuk Degerli'
    END AS clv_segment
FROM musteri_metrikleri;
GO

-- ============================================================
-- 8. MEVSİMSELLİK
-- ============================================================
CREATE OR ALTER VIEW vw_Mevsimsellik AS
SELECT
    d.year                              AS yil,
    d.quarter                           AS ceyrek,
    d.month                             AS ay,
    CASE d.month
        WHEN 1  THEN '01-Ocak'
        WHEN 2  THEN '02-Subat'
        WHEN 3  THEN '03-Mart'
        WHEN 4  THEN '04-Nisan'
        WHEN 5  THEN '05-Mayis'
        WHEN 6  THEN '06-Haziran'
        WHEN 7  THEN '07-Temmuz'
        WHEN 8  THEN '08-Agustos'
        WHEN 9  THEN '09-Eylul'
        WHEN 10 THEN '10-Ekim'
        WHEN 11 THEN '11-Kasim'
        WHEN 12 THEN '12-Aralik'
    END                                 AS ay_adi,
    COUNT(DISTINCT fs.order_id)         AS siparis_sayisi,
    ROUND(SUM(fs.total_revenue), 2)     AS toplam_gelir,
    ROUND(AVG(fs.total_revenue), 2)     AS ort_siparis_degeri,
    COUNT(DISTINCT fs.customer_id)      AS musteri_sayisi
FROM Fact_Sales fs
JOIN Dim_Date d ON fs.date_id = d.date_id
WHERE fs.order_status NOT IN ('canceled', 'unavailable')
GROUP BY d.year, d.quarter, d.month;
GO

-- ============================================================
-- 9. KATEGORİ BÜYÜME ORANI
-- ============================================================
CREATE OR ALTER VIEW vw_Kategori_Buyume AS
WITH yillik_kategori AS (
    SELECT
        p.category                      AS kategori,
        d.year                          AS yil,
        ROUND(SUM(fs.total_revenue), 2) AS toplam_gelir
    FROM Fact_Sales fs
    JOIN Dim_Products p ON fs.product_id = p.product_id
    JOIN Dim_Date d     ON fs.date_id    = d.date_id
    WHERE fs.order_status NOT IN ('canceled', 'unavailable')
        AND d.year IN (2017, 2018)
        AND p.category IS NOT NULL
    GROUP BY p.category, d.year
),
pivot_data AS (
    SELECT
        kategori,
        MAX(CASE WHEN yil = 2017 THEN toplam_gelir ELSE 0 END) AS gelir_2017,
        MAX(CASE WHEN yil = 2018 THEN toplam_gelir ELSE 0 END) AS gelir_2018
    FROM yillik_kategori
    GROUP BY kategori
)
SELECT
    kategori, gelir_2017, gelir_2018,
    ROUND(gelir_2018 - gelir_2017, 2) AS gelir_farki,
    CASE
        WHEN gelir_2017 = 0 THEN NULL
        ELSE ROUND(100.0 * (gelir_2018 - gelir_2017) / gelir_2017, 2)
    END AS buyume_orani_pct
FROM pivot_data
WHERE gelir_2017 > 0 AND gelir_2018 > 0;
GO

-- ============================================================
-- 10. GECİKME ANALİZİ
-- ============================================================
CREATE OR ALTER VIEW vw_Gecikme_Analiz AS
SELECT
    c.customer_state                        AS eyalet,
    p.category                              AS kategori,
    COUNT(DISTINCT fs.order_id)             AS toplam_siparis,
    ROUND(AVG(fs.delivery_days), 1)         AS ort_teslimat_gun,
    SUM(CAST(fs.is_late AS INT))            AS gec_teslimat_sayisi,
    ROUND(100.0 * SUM(CAST(fs.is_late AS INT))
        / COUNT(*), 2)                      AS gec_teslimat_pct,
    ROUND(AVG(CAST(fs.review_score AS FLOAT)), 2) AS ort_puan
FROM Fact_Sales fs
JOIN Dim_Customers c ON fs.customer_id = c.customer_id
JOIN Dim_Products p  ON fs.product_id  = p.product_id
WHERE fs.order_status NOT IN ('canceled', 'unavailable')
    AND p.category IS NOT NULL
GROUP BY c.customer_state, p.category
HAVING COUNT(DISTINCT fs.order_id) >= 10;
GO

-- ============================================================
-- 11. ANALİTİK SP'LER
-- ============================================================

CREATE OR ALTER PROCEDURE sp_GetRFM_Analiz
    @min_harcama DECIMAL(10,2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT segment,
        COUNT(*)                    AS musteri_sayisi,
        ROUND(AVG(monetary), 2)     AS ort_harcama,
        ROUND(AVG(recency_days), 0) AS ort_recency
    FROM vw_RFM
    WHERE monetary >= @min_harcama
    GROUP BY segment
    ORDER BY musteri_sayisi DESC;
END;
GO

CREATE OR ALTER PROCEDURE sp_GetRetention
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM vw_Retention;
END;
GO

CREATE OR ALTER PROCEDURE sp_GetMovingAverage
    @baslangic_tarih DATE = '2017-01-01',
    @bitis_tarih     DATE = '2018-09-01'
AS
BEGIN
    SET NOCOUNT ON;
    SELECT satis_tarihi, gunluk_gelir,
        hareketli_ort_7g, hareketli_ort_30g, aylik_toplam_gelir
    FROM vw_Moving_Average
    WHERE satis_tarihi BETWEEN @baslangic_tarih AND @bitis_tarih
    ORDER BY satis_tarihi;
END;
GO

CREATE OR ALTER PROCEDURE sp_GetKategori_Analiz
    @min_siparis INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM vw_Kategori_Analiz
    WHERE siparis_sayisi >= @min_siparis
    ORDER BY toplam_gelir DESC;
END;
GO

CREATE OR ALTER PROCEDURE sp_GetSatici_Scorecard
    @kategori NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM vw_Satici_Scorecard
    WHERE (@kategori IS NULL OR satici_kategorisi = @kategori)
    ORDER BY toplam_gelir DESC;
END;
GO

CREATE OR ALTER PROCEDURE sp_GetCohort
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM vw_Cohort
    ORDER BY cohort_ay, ay_farki;
END;
GO

CREATE OR ALTER PROCEDURE sp_GetCLV
    @min_clv DECIMAL(10,2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT clv_segment,
        COUNT(*)                      AS musteri_sayisi,
        ROUND(AVG(tahmini_clv), 2)   AS ort_clv,
        ROUND(SUM(toplam_harcama), 2) AS toplam_gelir
    FROM vw_CLV
    WHERE tahmini_clv >= @min_clv
    GROUP BY clv_segment
    ORDER BY ort_clv DESC;
END;
GO

CREATE OR ALTER PROCEDURE sp_GetMevsimsellik
    @yil INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM vw_Mevsimsellik
    WHERE (@yil IS NULL OR yil = @yil)
    ORDER BY yil, ay;
END;
GO

CREATE OR ALTER PROCEDURE sp_GetKategoriBuyume
    @min_buyume DECIMAL(10,2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM vw_Kategori_Buyume
    WHERE buyume_orani_pct >= @min_buyume
    ORDER BY buyume_orani_pct DESC;
END;
GO

CREATE OR ALTER PROCEDURE sp_GetGecikmeAnaliz
    @eyalet   NVARCHAR(2)   = NULL,
    @kategori NVARCHAR(100) = NULL,
    @min_gec  DECIMAL(10,2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM vw_Gecikme_Analiz
    WHERE (@eyalet   IS NULL OR eyalet   = @eyalet)
      AND (@kategori IS NULL OR kategori = @kategori)
      AND gec_teslimat_pct >= @min_gec
    ORDER BY gec_teslimat_pct DESC;
END;
GO
