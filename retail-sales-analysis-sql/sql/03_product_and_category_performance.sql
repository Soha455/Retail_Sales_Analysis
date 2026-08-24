-- 03_product_and_category_performance

USE RetailSalesDB;
GO
 ------ 1. Top 10 Best-Selling Products by Revenue
	SELECT TOP 10
		ProductID,
		SUM(TotalSales) AS Total_Revenue,
		SUM(Quantity) AS Total_Units_Sold,
		COUNT(DISTINCT TransactionID) AS Order_Count,
		ROUND(AVG(UnitPrice), 2) AS Avg_Selling_Price,
		ROUND(SUM(TotalSales) * 100.0 / (SELECT SUM(TotalSales) FROM Unified_Retail_Sales), 2) AS Pct_Of_Total_Revenue
	FROM Unified_Retail_Sales
	GROUP BY ProductID
	ORDER BY Total_Revenue DESC;

------ 2. Bottom 10 Performing Products (Slow-Moving / Low Revenue)
	SELECT TOP 10
		ProductID,
		SUM(TotalSales) AS Total_Revenue,
		SUM(Quantity) AS Total_Units_Sold,
		COUNT(DISTINCT TransactionID) AS Order_Count,
		ROUND(AVG(UnitPrice), 2) AS Avg_Selling_Price
	FROM Unified_Retail_Sales
	GROUP BY ProductID
	ORDER BY Total_Revenue ASC;

------3. Pareto Analysis (80/20 Rule) - Cumulative Revenue Contribution

	WITH ProductSalesSummary AS (
		SELECT 
			ProductID,
			SUM(TotalSales) AS Product_Revenue,
			SUM(Quantity) AS Units_Sold
		FROM Unified_Retail_Sales
		GROUP BY ProductID
	),
	CumulativeRanked AS (
		SELECT 
			ProductID,
			Product_Revenue,
			Units_Sold,
			-- حساب المجموع التراكمي للإيرادات
			SUM(Product_Revenue) OVER (ORDER BY Product_Revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Running_Total_Revenue,
			SUM(Product_Revenue) OVER () AS Overall_Total_Revenue
		FROM ProductSalesSummary
	)
	SELECT 
		ProductID,
		Product_Revenue,
		Units_Sold,
		Running_Total_Revenue,
		-- النسبة المئوية التراكمية
		ROUND((Running_Total_Revenue / NULLIF(Overall_Total_Revenue, 0)) * 100.0, 2) AS Cumulative_Revenue_Pct,
		CASE 
			WHEN (Running_Total_Revenue / NULLIF(Overall_Total_Revenue, 0)) <= 0.80 THEN 'Top 80% Contributor (Core)'
			ELSE 'Long Tail (Remaining 20%)'
		END AS Pareto_Segment
	FROM CumulativeRanked
	ORDER BY Product_Revenue DESC;


-----4.Discount Impact & Sensitivity Analysis per Product
Select 
	ProductID,
	COUNT(DISTINCT TransactionID) AS Total_Orders,
	SUM(Quantity) AS Units_Sold,
	SUM(TotalSales) AS Total_Net_Revenue,
	SUM(Discount) AS Total_Discounts_Given,
	-- متوسط نسبة الخصم على المنتج
	ROUND(AVG(Discount / NULLIF((UnitPrice * Quantity), 0)) * 100.0, 2) AS Avg_Discount_Rate_Pct,
    -- متوسط الإيراد لكل طلب
    ROUND(SUM(TotalSales) * 1.0 / NULLIF(COUNT(DISTINCT TransactionID), 0), 2) AS Revenue_Per_Order
FROM Unified_Retail_Sales
GROUP BY ProductID
Having Count(DISTINCT TransactionID) >=5    -- to avoid rarely selling products 
ORDER BY Total_Net_Revenue;