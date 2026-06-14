# ============================================================
# OLIST PROJECT — FAZ 6: SATIŞ TAHMİNİ
# Araç: Python + Prophet
# Açıklama: 3 aylık satış tahmini
# ============================================================

import pandas as pd
import numpy as np
import pyodbc
import matplotlib.pyplot as plt
from prophet import Prophet
import warnings
warnings.filterwarnings('ignore')

print("Kütüphaneler yüklendi!")

# ============================================================

conn = pyodbc.connect(
    'DRIVER={SQL Server};'
    'SERVER=DESKTOP-79S3HAN;'
    'DATABASE=Olist_DWH;'
    'Trusted_Connection=yes;'
)

query = """
SELECT
    d.full_date                     AS ds,
    ROUND(SUM(fs.total_revenue), 2) AS y
FROM Fact_Sales fs
JOIN Dim_Date d ON fs.date_id = d.date_id
WHERE fs.order_status NOT IN ('canceled', 'unavailable')
GROUP BY d.full_date
ORDER BY d.full_date
"""

df = pd.read_sql(query, conn)
conn.close()

df['ds'] = pd.to_datetime(df['ds'])
print(f"Veri çekildi: {df.shape[0]} gün")
print(f"Tarih aralığı: {df['ds'].min()} → {df['ds'].max()}")

# ============================================================

model = Prophet(
    yearly_seasonality=True,
    weekly_seasonality=True,
    daily_seasonality=False,
    changepoint_prior_scale=0.05
)

model.fit(df)
print("Model eğitildi!")

# 90 günlük tahmin (3 ay)
future = model.make_future_dataframe(periods=90)
forecast = model.predict(future)

print(f"90 günlük tahmin yapıldı!")

# ============================================================

# Tahmin grafiği
fig1 = model.plot(forecast)
plt.title('Günlük Gelir Tahmini — 90 Gün')
plt.xlabel('Tarih')
plt.ylabel('Gelir')
plt.tight_layout()
plt.savefig('sales_forecast.png')
plt.show()
print("Tahmin grafiği kaydedildi!")

# Mevsimsellik grafiği
fig2 = model.plot_components(forecast)
plt.tight_layout()
plt.savefig('seasonality.png')
plt.show()
print("Mevsimsellik grafiği kaydedildi!")

# ============================================================

forecast_son = forecast[['ds', 'yhat', 'yhat_lower', 'yhat_upper']].tail(90)
forecast_son.columns = ['tarih', 'tahmin', 'alt_sinir', 'ust_sinir']

conn2 = pyodbc.connect(
    'DRIVER={SQL Server};'
    'SERVER=DESKTOP-79S3HAN;'
    'DATABASE=Olist_DWH;'
    'Trusted_Connection=yes;'
)

cursor = conn2.cursor()

cursor.execute("""
IF OBJECT_ID('Sales_Forecast', 'U') IS NOT NULL
    DROP TABLE Sales_Forecast;

CREATE TABLE Sales_Forecast (
    tarih      DATE,
    tahmin     DECIMAL(10,2),
    alt_sinir  DECIMAL(10,2),
    ust_sinir  DECIMAL(10,2)
);
""")

for _, row in forecast_son.iterrows():
    cursor.execute(
        "INSERT INTO Sales_Forecast VALUES (?, ?, ?, ?)",
        str(row['tarih'].date()),
        round(float(row['tahmin']), 2),
        round(float(row['alt_sinir']), 2),
        round(float(row['ust_sinir']), 2)
    )

conn2.commit()
conn2.close()

print(f"90 günlük tahmin SSMS'e yazıldı!")

# ============================================================

print("\nTahmin Özeti:")
print(f"Ortalama günlük tahmin: ${forecast_son['tahmin'].mean():.2f}")
print(f"Maksimum tahmin: ${forecast_son['tahmin'].max():.2f}")
print(f"Minimum tahmin: ${forecast_son['tahmin'].min():.2f}")
print("\n Satış tahmini tamamlandı!")
