# ============================================================
# OLIST PROJECT — FAZ 6: CHURN MODELİ
# Araç: Python + XGBoost + SHAP
# ============================================================

import pandas as pd
import numpy as np
import pyodbc
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score
import xgboost as xgb
import shap
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
    c.customer_unique_id,
    COUNT(DISTINCT fs.order_id)                    AS siparis_sayisi,
    SUM(fs.total_revenue)                          AS toplam_harcama,
    AVG(fs.total_revenue)                          AS ort_siparis_degeri,
    DATEDIFF(DAY, MAX(d.full_date), '2018-10-01')  AS recency_days,
    AVG(CAST(fs.review_score AS FLOAT))            AS ort_puan,
    AVG(fs.delivery_days)                          AS ort_teslimat_gun,
    SUM(CAST(fs.is_late AS INT))                   AS gec_teslimat_sayisi,
    CASE
        WHEN COUNT(DISTINCT fs.order_id) > 1 THEN 0
        ELSE 1
    END AS churn
FROM Fact_Sales fs
JOIN Dim_Customers c ON fs.customer_id = c.customer_id
JOIN Dim_Date d      ON fs.date_id     = d.date_id
WHERE fs.order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_unique_id
"""

df = pd.read_sql(query, conn)
conn.close()

print(f" Veri çekildi: {df.shape[0]} müşteri, {df.shape[1]} kolon")
print(f"Churn oranı: %{df['churn'].mean()*100:.2f}")

# ============================================================
features = [
    'siparis_sayisi', 'toplam_harcama', 'ort_siparis_degeri',
    'recency_days', 'ort_puan', 'ort_teslimat_gun', 'gec_teslimat_sayisi'
]

X = df[features].fillna(0)
y = df['churn']

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

print(f"Train: {X_train.shape[0]} | Test: {X_test.shape[0]}")

# ============================================================
model = xgb.XGBClassifier(
    n_estimators=100,
    max_depth=4,
    learning_rate=0.1,
    random_state=42,
    eval_metric='logloss'
)

model.fit(X_train, y_train)
print("Model eğitildi!")

# ============================================================
y_pred = model.predict(X_test)
y_prob = model.predict_proba(X_test)[:, 1]

print("\n📊 Model Performansı:")
print(classification_report(y_test, y_pred))
print(f"ROC-AUC Skoru: {roc_auc_score(y_test, y_prob):.4f}")

# Confusion Matrix
plt.figure(figsize=(6, 4))
cm = confusion_matrix(y_test, y_pred)
sns.heatmap(cm, annot=True, fmt='d', cmap='Greens',
            xticklabels=['Kalmış', 'Churn'],
            yticklabels=['Kalmış', 'Churn'])
plt.title('Confusion Matrix')
plt.ylabel('Gerçek')
plt.xlabel('Tahmin')
plt.tight_layout()
plt.savefig('confusion_matrix.png')
plt.show()
print("Confusion matrix kaydedildi!")

# ============================================================
explainer = shap.TreeExplainer(model)
shap_values = explainer.shap_values(X_test)

plt.figure()
shap.summary_plot(shap_values, X_test, plot_type="bar", show=False)
plt.tight_layout()
plt.savefig('shap_importance.png')
plt.show()
print("SHAP feature importance kaydedildi!")

# ============================================================

df['churn_probability'] = model.predict_proba(X[features].fillna(0))[:, 1]
df['churn_prediction'] = model.predict(X[features].fillna(0))
df['churn_segment'] = pd.cut(
    df['churn_probability'],
    bins=[0, 0.3, 0.7, 1.0],
    labels=['Dusuk Risk', 'Orta Risk', 'Yuksek Risk']
)

print("\n📊 Churn Segment Dağılımı:")
print(df['churn_segment'].value_counts())

conn2 = pyodbc.connect(
    'DRIVER={SQL Server};'
    'SERVER=DESKTOP-79S3HAN;'
    'DATABASE=Olist_DWH;'
    'Trusted_Connection=yes;'
)
cursor = conn2.cursor()

cursor.execute("""
IF OBJECT_ID('Churn_Predictions', 'U') IS NOT NULL
    DROP TABLE Churn_Predictions;

CREATE TABLE Churn_Predictions (
    customer_unique_id NVARCHAR(50),
    churn_probability  DECIMAL(5,4),
    churn_prediction   INT,
    churn_segment      NVARCHAR(20)
);
""")

for _, row in df.iterrows():
    cursor.execute(
        "INSERT INTO Churn_Predictions VALUES (?, ?, ?, ?)",
        row['customer_unique_id'],
        round(float(row['churn_probability']), 4),
        int(row['churn_prediction']),
        str(row['churn_segment'])
    )

conn2.commit()
conn2.close()

print(f"{len(df)} satır SSMS'e yazıldı!")
print("\nChurn modeli tamamlandı!")


