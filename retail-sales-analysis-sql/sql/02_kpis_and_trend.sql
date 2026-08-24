USE RetailSalesDB

-- 01 Calculate CORE KPIs
Select 
-- 1. إجمالي صافي الإيرادات
SUM (TotalSales) AS Total_Net_Revenue ,
-- 2. إجمالي الوحدات المباعة
SUM(Quantity) AS Total_Units_Sold,
-- 3. اجمالى عدد الطلبات / المعاملات
COUNT(Distinct TransactionID) AS Total_Orders,
-- 4. اجمالى عدد العملاء الفريدين
SUM(Distinct CustomerId) AS Total_Customers,
-- 5. إجمالي عدد المنتجات الفريدة
SUM(Distinct ProductID) AS Total_Products,
-- 6. متوسط قيمة الطلب (Average Order Value - AOV)
ROUND(SUM(TotalSales) * 1.0 / NULLIF(COUNT(DISTINCT TransactionID), 0), 2) AS Average_Order_Value,
-- 7. متوسط سعر الوحدة المباعة 
ROUND(AVG(UnitPrice), 2) AS Average_Unit_Price,
-- 8. متوسط عدد القطع في كل طلب (Average Basket Size)
ROUND(SUM(Quantity) * 1.0 / NULLIF(COUNT(DISTINCT TransactionID), 0), 2) AS Avg_Units_Per_Order,
-- 9. إجمالي مبالغ الخصومات الممنوحة
ROUND(Sum(Discount),2) AS Total_Discounts_Given,
-- 10. نسبة الخصم إلى إجمالي المبيعات
ROUND((Sum(Discount)/NULLIF(sum(TotalSales) + SUM(Discount) ,0) ) * 100.00,2 )AS Discount_Percentage_Rate

FROM Unified_Retail_Sales;


-- 02 MoM Sales & Order Growth
WITH MonthlyAggregates AS (
    -- المرحلة 1: تجميع أرقام كل شهر على حدة
    SELECT 
        DATEFROMPARTS(YEAR(TransactionDate), MONTH(TransactionDate), 1) AS SalesMonth,
        DATENAME(MONTH, TransactionDate) + ' ' + CAST(YEAR(TransactionDate) AS VARCHAR(4)) AS MonthYearLabel,
        SUM(TotalSales) AS Monthly_Revenue,
        COUNT(DISTINCT TransactionID) AS Monthly_Orders,
        COUNT(DISTINCT CustomerID) AS Active_Customers,
        SUM(Quantity) AS Units_Sold
    FROM Unified_Retail_Sales
    GROUP BY 
        DATEFROMPARTS(YEAR(TransactionDate), MONTH(TransactionDate), 1),
        DATENAME(MONTH, TransactionDate) + ' ' + CAST(YEAR(TransactionDate) AS VARCHAR(4)),
        YEAR(TransactionDate),
        MONTH(TransactionDate)
),
MoM_Calculations AS (
    -- المرحلة 2: جلب أرقام الشهر السابق للمقارنة
    SELECT 
        SalesMonth,
        MonthYearLabel,
        Monthly_Revenue,
        LAG(Monthly_Revenue) OVER (ORDER BY SalesMonth) AS Prev_Month_Revenue,
        Monthly_Orders,
        LAG(Monthly_Orders) OVER (ORDER BY SalesMonth) AS Prev_Month_Orders,
        Active_Customers,
        Units_Sold,
        ROUND(Monthly_Revenue * 1.0 / NULLIF(Monthly_Orders, 0), 2) AS Monthly_AOV
    FROM MonthlyAggregates
)
-- المرحلة 3: حساب نسب النمو المئوية والعرض النهائي
SELECT 
    SalesMonth,
    MonthYearLabel,
    Monthly_Revenue,
    Prev_Month_Revenue,
    ROUND(((Monthly_Revenue - Prev_Month_Revenue) / NULLIF(Prev_Month_Revenue, 0)) * 100.0, 2) AS MoM_Revenue_Growth_Percent,
    Monthly_Orders,
    Prev_Month_Orders,
    ROUND(((Monthly_Orders - Prev_Month_Orders) * 1.0 / NULLIF(Prev_Month_Orders, 0)) * 100.0, 2) AS MoM_Orders_Growth_Percent,
    Active_Customers,
    Units_Sold,
    Monthly_AOV
FROM MoM_Calculations
ORDER BY SalesMonth ASC;