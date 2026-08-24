-- Creating Views For BI 
-- 1.Fact Table View: Cleaned Transaction Level with Date Dimensions
CREATE OR ALTER View vw_Sales_Fact AS 
	SELECT 
		TransactionID,
		TransactionDate,
		YEAR(TransactionDate) AS SalesYear,
		MONTH(TransactionDate) AS SalesMonth,
		DATENAME(MONTH , TransactionDate) AS MonthName,
		DATEPART(QUARTER , TransactionDate) AS SalesQuarter,
		DATENAME(WEEKDAY , TransactionDate) AS DayOfWeekName,
		ProductID,
		CustomerID,
		Quantity,
		UnitPrice,
		Discount,
		TotalSales,
		DataSource
	FROM Unified_Retail_Sales
	GO


----------------------------------------------------------------------
-- 2. Monthly Trends View: Pre-aggregated MoM Growth for Executive Dashboards
CREATE OR ALTER VIEW vw_Monthly_Sales_Trend AS

WITH MonthlyAggregates AS (
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
GO

-- 3. Product Performance View: Aggregates, Pricing, and Pareto Classification
Create Or Alter View vw_Product_Performance AS
WITH ProductSalesSummary AS (
		SELECT 
			ProductID,
			SUM(TotalSales) AS Product_Revenue,
			SUM(Quantity) AS Units_Sold,
			ROUND(AVG(UnitPrice), 2) AS Avg_Selling_Price,
			ROUND(AVG(Discount / NULLIF((UnitPrice * Quantity), 0)) * 100.0, 2) AS Avg_Discount_Pct
		FROM Unified_Retail_Sales
		GROUP BY ProductID
	),
	CumulativeRanked AS (
		SELECT 
			ProductID,
			Product_Revenue,
			Units_Sold,
			Avg_Selling_Price ,
			Avg_Discount_Pct ,
			SUM(Product_Revenue) OVER (ORDER BY Product_Revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Running_Total_Revenue,
			SUM(Product_Revenue) OVER () AS Overall_Total_Revenue
		FROM ProductSalesSummary
	)
	SELECT 
		ProductID,
		Product_Revenue,
		Units_Sold,
		Running_Total_Revenue,
		Avg_Selling_Price ,
		Avg_Discount_Pct ,
		ROUND((Running_Total_Revenue / NULLIF(Overall_Total_Revenue, 0)) * 100.0, 2) AS Cumulative_Revenue_Pct,
		CASE 
			WHEN (Running_Total_Revenue / NULLIF(Overall_Total_Revenue, 0)) <= 0.80 THEN 'Top 80% Contributor (Core)'
			ELSE 'Long Tail (Remaining 20%)'
		END AS Pareto_Segment
	FROM CumulativeRanked
GO



---------------------------------------------------------------

-- 4. Customer RFM Segmentation View: Granular Customer Scores and Segments
CREATE OR ALTER VIEW vw_Customer_RFM_Segments AS
WITH CustomerMetrics AS (
    SELECT 
        CustomerID,
        DATEDIFF(DAY, MAX(TransactionDate), (SELECT MAX(TransactionDate) FROM Unified_Retail_Sales)) AS Recency_Days,
        COUNT(DISTINCT TransactionID) AS Frequency_Orders,
        SUM(TotalSales) AS Monetary_Spend,
        MIN(TransactionDate) AS First_Purchase_Date,
        MAX(TransactionDate) AS Last_Purchase_Date
    FROM Unified_Retail_Sales
    GROUP BY CustomerID
),
RFM_Scoring AS (
    SELECT 
        CustomerID,
        Recency_Days,
        Frequency_Orders,
        Monetary_Spend,
        First_Purchase_Date,
        Last_Purchase_Date,
        NTILE(5) OVER (ORDER BY Recency_Days DESC) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency_Orders ASC) AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary_Spend ASC) AS M_Score
    FROM CustomerMetrics
)
SELECT 
    CustomerID,
    Recency_Days,
    Frequency_Orders,
    Monetary_Spend,
    First_Purchase_Date,
    Last_Purchase_Date,
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
FROM RFM_Scoring;
GO