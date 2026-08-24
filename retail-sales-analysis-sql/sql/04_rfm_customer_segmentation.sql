USE RetailSalesDB
GO

/*
-- 1: RFM Calculation & Customer Segmentation
WITH CustomerMetrics AS (
    -- 1. حساب القيم الخام لكل عميل (Raw RFM Values)
    SELECT 
        CustomerID,
        DATEDIFF(DAY, MAX(TransactionDate), (
			SELECT MAX(TransactionDate) 
			FROM Unified_Retail_Sales)) AS Recency_Days,
        COUNT(DISTINCT TransactionID) AS Frequency_Orders,
        SUM(TotalSales) AS Monetary_Value
    FROM Unified_Retail_Sales
    GROUP BY CustomerID
),

RFM_Scores AS (
    -- 2. إعطاء درجات من 1 إلى 5 لكل بُعد باستخدام NTILE
    SELECT 
        CustomerID,
        Recency_Days,
        Frequency_Orders,
        Monetary_Value,
        -- الأحدث شراءً (Recency أقل) يأخذ الدرجة الأعلى 5
        NTILE(5) OVER (ORDER BY Recency_Days DESC) AS R_Score,
        -- الأكثر تكراراً للطلبات يأخذ الدرجة 5
        NTILE(5) OVER (ORDER BY Frequency_Orders ASC) AS F_Score,
        -- الأكثر إنفاقاً يأخذ الدرجة 5
        NTILE(5) OVER (ORDER BY Monetary_Value ASC) AS M_Score
    FROM CustomerMetrics
),
Segmented_Customers AS (
    -- 3. دمج الدرجات وتصنيف العملاء لشرائح استراتيجية
    SELECT 
        CustomerID,
        Recency_Days,
        Frequency_Orders,
        Monetary_Value,
        R_Score,
        F_Score,
        M_Score,
        CAST(R_Score AS VARCHAR(1)) + CAST(F_Score AS VARCHAR(1)) + CAST(M_Score AS VARCHAR(1)) AS RFM_Cell,
        ROUND((R_Score + F_Score + M_Score) / 3.0, 2) AS RFM_Composite_Score,
        CASE 
            -- Champions: اشتروا حديثاً، بيشتروا كتير، وبيصرفوا كتير
            WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions'
            
            -- Loyal Customers: بيشتروا بانتظام ومبالغ ممتازة
            WHEN R_Score >= 3 AND F_Score >= 3 AND M_Score >= 3 THEN 'Loyal Customers'
            
            -- Potential Loyalists: عملاء حديثين أو متوسطين مع فرصة للنمو
            WHEN R_Score >= 4 AND F_Score >= 2 THEN 'Potential Loyalists'
            
            -- New Customers: عمليات شراء حديثة جداً لكن عدد مرات قليل
            WHEN R_Score >= 4 AND F_Score = 1 THEN 'New Customers'
            
            -- Promising: عملاء جدد بمشتريات واعدة
            WHEN R_Score = 3 AND F_Score = 1 THEN 'Promising'
            
            -- Need Attention: معدلات شرائهم بدأت تقل ومحتاجين تنشيط
            WHEN R_Score = 3 AND F_Score >= 2 THEN 'Need Attention'
            
            -- About to Sleep: داخلين في مرحلة الخمول
            WHEN R_Score = 2 AND F_Score <= 2 THEN 'About to Sleep'
            
            -- At Risk: كانوا عملاء مميزين زمان لكن بقالهم فترة طويلة ما اشتروش
            WHEN R_Score <= 2 AND (F_Score >= 3 OR M_Score >= 3) THEN 'At Risk / Cannot Lose'
            
            -- Hibernating / Lost: من زمان جداً، وعدد طلبات قليل
            WHEN R_Score <= 2 AND F_Score <= 2 THEN 'Lost / Inactive'
            
            ELSE 'Others / General'
        END AS Customer_Segment
    FROM RFM_Scores
)
SELECT * 
FROM Segmented_Customers
ORDER BY Monetary_Value DESC;

-- 2: Segment Summary & Business Action Matrix

WITH CustomerMetrics AS (
    SELECT 
        CustomerID,
        DATEDIFF(DAY, MAX(TransactionDate), (
			SELECT MAX(TransactionDate) 
			FROM Unified_Retail_Sales)) AS Recency_Days,
        COUNT(DISTINCT TransactionID) AS Frequency_Orders,
        SUM(TotalSales) AS Monetary_Value
    FROM Unified_Retail_Sales
    GROUP BY CustomerID
),
RFM_Scores AS (
    SELECT 
        CustomerID,
        Recency_Days,
        Frequency_Orders,
        Monetary_Value,
        NTILE(5) OVER (ORDER BY Recency_Days DESC) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency_Orders ASC) AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary_Value ASC) AS M_Score
    FROM CustomerMetrics
),
Segmented_Customers AS (
    SELECT 
        CustomerID,
        Recency_Days,
        Frequency_Orders,
        Monetary_Value,
        R_Score,
        F_Score,
        M_Score,
        CAST(R_Score AS VARCHAR(1)) + CAST(F_Score AS VARCHAR(1)) + CAST(M_Score AS VARCHAR(1)) AS RFM_Cell,
        ROUND((R_Score + F_Score + M_Score) / 3.0, 2) AS RFM_Composite_Score,
        CASE 
            WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions'
            WHEN R_Score >= 3 AND F_Score >= 3 AND M_Score >= 3 THEN 'Loyal Customers'
            WHEN R_Score >= 4 AND F_Score >= 2 THEN 'Potential Loyalists'
            WHEN R_Score >= 4 AND F_Score = 1 THEN 'New Customers'
            WHEN R_Score = 3 AND F_Score = 1 THEN 'Promising'
            WHEN R_Score = 2 AND F_Score <= 2 THEN 'About to Sleep'
            WHEN R_Score <= 2 AND (F_Score >= 3 OR M_Score >= 3) THEN 'At Risk / Cannot Lose'
            WHEN R_Score <= 2 AND F_Score <= 2 THEN 'Lost / Inactive'
            
            ELSE 'Others / General'
        END AS Customer_Segment
    FROM RFM_Scores
)
SELECT 
    Customer_Segment,
    COUNT(CustomerID) AS Total_Customers,
    ROUND(COUNT(CustomerID) * 100.0 / (SELECT COUNT(DISTINCT CustomerID) FROM Unified_Retail_Sales), 2) AS Pct_Of_Customer_Base,
    SUM(Monetary_Value) AS Segment_Total_Revenue,
    ROUND(SUM(Monetary_Value) * 100.0 / (SELECT SUM(TotalSales) FROM Unified_Retail_Sales), 2) AS Pct_Of_Total_Revenue,
    ROUND(AVG(Recency_Days), 0) AS Avg_Recency_Days,
    ROUND(AVG(Frequency_Orders), 1) AS Avg_Orders_Per_Customer,
    ROUND(AVG(Monetary_Value), 2) AS Avg_Spend_Per_Customer
FROM Segmented_Customers
GROUP BY Customer_Segment
ORDER BY Segment_Total_Revenue DESC; 
 */

DROP TABLE IF EXISTS #Customer_RFM_Segments;

WITH CustomerMetrics AS (
    SELECT 
        CustomerID,
        DATEDIFF(DAY, MAX(TransactionDate), (SELECT MAX(TransactionDate) FROM Unified_Retail_Sales)) AS Recency_Days,
        COUNT(DISTINCT TransactionID) AS Frequency_Orders,
        SUM(TotalSales) AS Monetary_Value
    FROM Unified_Retail_Sales
    GROUP BY CustomerID
),
RFM_Scores AS (
    SELECT 
        CustomerID,
        Recency_Days,
        Frequency_Orders,
        Monetary_Value,
        NTILE(5) OVER (ORDER BY Recency_Days DESC) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency_Orders ASC) AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary_Value ASC) AS M_Score
    FROM CustomerMetrics
)
SELECT 
    CustomerID,
    Recency_Days,
    Frequency_Orders,
    Monetary_Value,
    R_Score,
    F_Score,
    M_Score,
    CAST(R_Score AS VARCHAR(1)) + CAST(F_Score AS VARCHAR(1)) + CAST(M_Score AS VARCHAR(1)) AS RFM_Cell,
    ROUND((R_Score + F_Score + M_Score) / 3.0, 2) AS RFM_Composite_Score,
    CASE 
        WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions'
        WHEN R_Score >= 3 AND F_Score >= 3 AND M_Score >= 3 THEN 'Loyal Customers'
        WHEN R_Score >= 4 AND F_Score >= 2 THEN 'Potential Loyalists'
        WHEN R_Score >= 4 AND F_Score = 1 THEN 'New Customers'
        WHEN R_Score = 3 AND F_Score = 1 THEN 'Promising'
        WHEN R_Score = 3 AND F_Score >= 2 THEN 'Need Attention'
        WHEN R_Score = 2 AND F_Score <= 2 THEN 'About to Sleep'
        WHEN R_Score <= 2 AND (F_Score >= 3 OR M_Score >= 3) THEN 'At Risk / Cannot Lose'
        WHEN R_Score <= 2 AND F_Score <= 2 THEN 'Lost / Inactive'
        ELSE 'Others / General'
    END AS Customer_Segment
INTO #Customer_RFM_Segments
FROM RFM_Scores;


-- 1 : RFM & Customer Segmentation (Individual Customer Details)
SELECT * 
FROM #Customer_RFM_Segments
ORDER BY Monetary_Value DESC;

-- 2 : RFM & Customer Segmentation (Executive Segment Summary)
SELECT 
    Customer_Segment,
    COUNT(CustomerID) AS Total_Customers,
    ROUND(COUNT(CustomerID) * 100.0 / (SELECT COUNT(*) FROM #Customer_RFM_Segments), 2) AS Pct_Of_Customer_Base,
    SUM(Monetary_Value) AS Segment_Total_Revenue,
    ROUND(SUM(Monetary_Value) * 100.0 / (SELECT SUM(Monetary_Value) FROM #Customer_RFM_Segments), 2) AS Pct_Of_Total_Revenue,
    ROUND(AVG(Recency_Days), 0) AS Avg_Recency_Days,
    ROUND(AVG(Frequency_Orders), 1) AS Avg_Orders_Per_Customer,
    ROUND(AVG(Monetary_Value), 2) AS Avg_Spend_Per_Customer
FROM #Customer_RFM_Segments
GROUP BY Customer_Segment
ORDER BY Segment_Total_Revenue DESC;