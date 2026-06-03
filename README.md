# Olist E-Commerce — End-to-End Data Analytics Project

![SQL Server](https://img.shields.io/badge/SQL%20Server-CC2927?style=flat&logo=microsoft-sql-server&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=flat&logo=power-bi&logoColor=black)
![SSIS](https://img.shields.io/badge/SSIS-CC2927?style=flat&logo=microsoft&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)

## Proje Özeti

Brezilya'nın en büyük e-ticaret platformu Olist'in gerçek satış verisini
kullanarak uçtan uca bir veri analitiği projesi. Ham CSV'den başlayıp
makine öğrenmesine kadar tüm pipeline tasarlandı ve uygulandı.

**Veri:** 100.000+ sipariş | 2016-2018 | Kaggle Olist Dataset

---

## Mimari

```
CSV Dosyaları
    ↓ SSIS
Olist_Project (Staging DB)
    ↓ ETL SP + SQL Agent Job
Olist_DWH (Star Schema)
    ↓ DirectQuery
Power BI Dashboard (4 sayfa)
    ↓
GitHub Portföy
```

---

## Faz Özeti

### ✅ Faz 1 — OLTP Staging (SQL Server)
- 9 CSV → SSIS ile yüklendi
- 9 tablo, 7 PK, 6 FK, 5 Index
- 11 View (data quality flag, aksan temizliği, financial reconciliation)

### ✅ Faz 2 — DWH (Star Schema)
- Olist_DWH veritabanı
- Fact_Sales + Dim_Date + Dim_Customers + Dim_Products + Dim_Sellers
- ETL_Log tablosu + TRY/CATCH hata yönetimi
- SQL Agent Job → her gece 02:00 otomatik yenileme

### ✅ Faz 3 — İleri SQL Analitiği
- RFM Analizi (NTILE, 7 segment)
- Retention & Churn (%12,43 / %87,57)
- Hareketli Ortalama (7 ve 30 günlük)
- Kategori ve Satıcı Scorecard
- 10 parametreli Stored Procedure

### ✅ Faz 4 — Power BI Dashboard
- 4 sayfa: Executive, Müşteri, Operasyon, Satış Analizi
- 8 DAX ölçüsü
- Koşullu renkler, navigasyon butonları

### ✅ Faz 5 — Analiz Derinleştirme
- Cohort Analizi
- CLV Segmentasyonu (Yüksek/Orta/Düşük Değerli)
- Mevsimsellik ve Kategori Büyüme Analizi
- Eyalet + Kategori Gecikme Analizi

### 🔄 Faz 6 — Python & Makine Öğrenmesi (Devam Ediyor)
- Churn Modeli: XGBoost + SHAP
- Satış Tahmini: Prophet
- Model çıktıları → SSMS'e geri yazılacak

---

## Temel Bulgular

| Metrik | Değer |
|--------|-------|
| Toplam Sipariş | 112.101 |
| Toplam Gelir | $15,84M |
| Geç Teslimat Oranı | %7,74 |
| Müşteri Tutma Oranı | %12,43 |
| En Büyük Kategori | health_beauty |
| En Hızlı Büyüyen | small_appliances (%5.402) |
| Champion Müşteri | %1,2 oranında, yüksek değerli |

---

## Klasör Yapısı

olist-ecommerce-analytics/
├── /sql
│   ├── 01_staging_setup.sql
│   ├── 02_dwh_setup.sql
│   ├── 03_views.sql
│   ├── 04_stored_procedures.sql
│   └── 05_analytics_views.sql
├── /python
│   ├── churn_model.py
│   └── sales_forecast.py
├── /powerbi
│   └── olist_dashboard.pbix
├── /docs
│   └── star_schema.png
└── README.md
---

## Kullanılan Teknolojiler

| Teknoloji | Kullanım Amacı |
|-----------|----------------|
| SQL Server 2019 | Veritabanı |
| SSMS | Sorgu geliştirme |
| SSIS | ETL pipeline |
| SQL Agent | Zamanlama |
| Power BI | Görselleştirme |
| DAX | BI hesaplamaları |
| Python (Faz 6) | ML modelleri |

---

## Kurulum

1. SQL Server ve SSMS kur
2. `sql/01_staging_setup.sql` çalıştır
3. SSIS ile CSV dosyalarını yükle
4. `sql/02_dwh_setup.sql` çalıştır
5. `sql/03_views.sql` çalıştır
6. `sql/04_stored_procedures.sql` çalıştır
7. `sql/05_analytics_views.sql` çalıştır
8. Power BI'da `powerbi/olist_dashboard.pbix` aç

---

## Veri Kaynağı

[Kaggle — Olist Brazilian E-Commerce Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

---

*Bu proje portföy amaçlı geliştirilmiştir.*

