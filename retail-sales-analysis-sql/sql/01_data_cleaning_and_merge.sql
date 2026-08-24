--01 Exploration for data records
-- 1. فحص أول 10 صفوف من الجدول الأول
SELECT TOP 10 * FROM sales_transactions_a;

-- 2. فحص أول 10 صفوف من الجدول الثاني
SELECT TOP 10 * FROM sales_transactions_b;

-- 3. معرفة عدد الصفوف في كل جدول
SELECT COUNT(*) AS Table1_Rows 
FROM sales_transactions_a;

SELECT COUNT(*) AS Table2_Rows 
FROM sales_transactions_b;


------------------------------------------------------------

-- 02 Unified_Retail_Sales
-- حذف الجدول إذا كان موجوداً مسبقاً لإعادة إنشائه بنظافة
DROP TABLE IF EXISTS Unified_Retail_Sales;

WITH Raw_Union AS (
    SELECT 
        CAST(DocumentID AS INT) AS TransactionID,
        CAST(Date AS DATE) AS TransactionDate,
        CAST(SKU AS INT) AS ProductID,
        CAST(Customer AS INT) AS CustomerID,
        CAST(Quantity AS INT) AS Quantity,
        -- UnitPrice = Price الأصلي مقسوماً على الكمية (إذا كان Price هو Gross Amount)
        CAST(CAST(Price AS DECIMAL(12, 2)) / NULLIF(CAST(Quantity AS INT), 0) AS DECIMAL(12, 2)) AS UnitPrice,
        CAST(ISNULL(Discount, 0) AS DECIMAL(12, 2)) AS Discount,
        -- TotalSales = Price (Gross) - Discount
        CAST(CAST(Price AS DECIMAL(12, 2)) - CAST(ISNULL(Discount, 0) AS DECIMAL(12, 2)) AS DECIMAL(12, 2)) AS TotalSales,
        'Source_1' AS DataSource
    FROM sales_transactions_a

    UNION ALL
	SELECT 
        CAST(InvoiceID AS INT) AS TransactionID,
        CAST(Date AS DATE) AS TransactionDate,
        CAST(ProductID AS INT) AS ProductID,
        CAST(CustomerID AS INT) AS CustomerID,
        CAST(Quantity AS INT) AS Quantity,
        -- UnitPrice = TotalSales / Quantity
        CAST(CAST(TotalSales AS DECIMAL(12, 2)) / NULLIF(CAST(Quantity AS INT), 0) AS DECIMAL(12, 2)) AS UnitPrice,
        CAST(ISNULL(Discount, 0) AS DECIMAL(12, 2)) AS Discount,
        CAST(TotalSales AS DECIMAL(12, 2)) AS TotalSales,
        'Source_2' AS DataSource
    FROM sales_transactions_b
)
SELECT 
    TransactionID,
    TransactionDate,
    ProductID,
    CustomerID,
    Quantity,
    UnitPrice,
    Discount,
    TotalSales,
    DataSource
INTO Unified_Retail_Sales
FROM Raw_Union
WHERE 
    CustomerID IS NOT NULL 
    AND Quantity > 0
    AND TotalSales > 0;






-- create Indexes
-- إنشاء Index على التاريخ لسرعة الفلترة وتحليلات الوقت
CREATE NONCLUSTERED INDEX IX_UnifiedSales_Date 
ON Unified_Retail_Sales(TransactionDate);

-- إنشاء Index على معرّف العميل لتسريع تحليلات الـ RFM
CREATE NONCLUSTERED INDEX IX_UnifiedSales_Customer 
ON Unified_Retail_Sales(CustomerID);

-- إنشاء Index على معرّف المنتج لتسريع تحليلات المنتجات
CREATE NONCLUSTERED INDEX IX_UnifiedSales_Product 
ON Unified_Retail_Sales(ProductID);







-- 03 Checking_Leading_Zeros
-- فحص إذا كان هناك أي قيم غير رقمية في الأعمدة
SELECT 
    COUNT(CASE WHEN ISNUMERIC(DocumentID) = 0 THEN 1 END) AS NonNumeric_Docs,
    COUNT(CASE WHEN ISNUMERIC(SKU) = 0 THEN 1 END) AS NonNumeric_SKUs,
    COUNT(CASE WHEN ISNUMERIC(Customer) = 0 THEN 1 END) AS NonNumeric_Customers
FROM sales_transactions_a;

SELECT 
    COUNT(CASE WHEN ISNUMERIC(InvoiceID) = 0 THEN 1 END) AS NonNumeric_Docs,
    COUNT(CASE WHEN ISNUMERIC(ProductID) = 0 THEN 1 END) AS NonNumeric_SKUs,
    COUNT(CASE WHEN ISNUMERIC(CustomerID) = 0 THEN 1 END) AS NonNumeric_Customers
FROM sales_transactions_b;

-- فحص إذا كانت الاعمدة تبدأ باصفار 
SELECT 
    COUNT(CASE WHEN DocumentID LIKE '0%' AND DocumentID <> '0' THEN 1 END) AS LeadingZeros_DocID,
    COUNT(CASE WHEN SKU LIKE '0%' AND SKU <> '0' THEN 1 END) AS LeadingZeros_SKU,
    COUNT(CASE WHEN Customer LIKE '0%' AND Customer <> '0' THEN 1 END) AS LeadingZeros_Customer
FROM sales_transactions_a;

    -- الجدول الثاني
SELECT 
    COUNT(CASE WHEN InvoiceID LIKE '0%' AND InvoiceID <> '0' THEN 1 END) AS LeadingZeros_InvoiceID,
    COUNT(CASE WHEN ProductID LIKE '0%' AND ProductID <> '0' THEN 1 END) AS LeadingZeros_ProductID,
    COUNT(CASE WHEN CustomerID LIKE '0%' AND CustomerID <> '0' THEN 1 END) AS LeadingZeros_CustomerID
FROM sales_transactions_b;


-- فحص إذا كان التحويل يغير القيمة الأصلية
-- هاتلي الصفوف اللي القيمة الأصلية مختلفة عن القيمة بعد التحويل
SELECT COUNT(*) AS Changed_DocumentID
FROM sales_transactions_a
WHERE DocumentID <> CAST(CAST(DocumentID AS INT) AS VARCHAR(50));


-- 04 Data Quality Check-Excluded Sales Transactions
-- Data Quality Check: Excluded Sales Transactions

-- فحص السجلات المستبعدة من الجدول الأول
SELECT 
    'sales_transactions_a' AS SourceTable,
    COUNT(*) AS Excluded_Rows,
    COUNT(CASE WHEN Customer IS NULL THEN 1 END) AS Null_Customer_Count,
    COUNT(CASE WHEN Quantity <= 0 THEN 1 END) AS Invalid_Quantity_Count,
    COUNT(CASE WHEN ((Price * Quantity) - ISNULL(Discount, 0)) <= 0 THEN 1 END) AS Zero_Or_Negative_Sales_Count
FROM sales_transactions_a
WHERE Customer IS NULL 
	  OR Quantity <= 0 
	  OR ((Price * Quantity) - ISNULL(Discount, 0)) <= 0

UNION ALL

-- فحص السجلات المستبعدة من الجدول الثاني
SELECT 
    'sales_transactions_b' AS SourceTable,
    COUNT(*) AS Excluded_Rows,
    COUNT(CASE WHEN CustomerID IS NULL THEN 1 END) AS Null_Customer_Count,
    COUNT(CASE WHEN Quantity <= 0 THEN 1 END) AS Invalid_Quantity_Count,
    COUNT(CASE WHEN TotalSales <= 0 THEN 1 END) AS Zero_Or_Negative_Sales_Count
FROM sales_transactions_b
WHERE CustomerID IS NULL 
	OR TRY_CAST(Quantity AS INT) <= 0 
    OR TRY_CAST(TotalSales AS DECIMAL(12, 2)) <= 0;

-- to show why there are total sales <=0 althougth the quantity and dis count is positive 
	SELECT TOP 10 
    DocumentID,
    Price,
    Quantity,
    Discount,
    (TRY_CAST(Price AS DECIMAL(12, 2)) * TRY_CAST(Quantity AS INT)) AS Gross_Amount,
    (TRY_CAST(Price AS DECIMAL(12, 2)) * TRY_CAST(Quantity AS INT)) - ISNULL(TRY_CAST(Discount AS DECIMAL(12, 2)), 0) AS Net_Sales
FROM sales_transactions_a
WHERE 
    TRY_CAST(Quantity AS INT) > 0 
    AND (TRY_CAST(Price AS DECIMAL(12, 2)) * TRY_CAST(Quantity AS INT)) - ISNULL(TRY_CAST(Discount AS DECIMAL(12, 2)), 0) <= 0;

