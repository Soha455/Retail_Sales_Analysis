📊 End-to-End Retail Sales Analytics & Customer Segmentation
An end-to-end business intelligence and data engineering project analyzing retail transaction data. This project encompasses automated data staging, cleaning, unified schema design, advanced analytical querying (MoM growth, Pareto 80/20 distribution, and RFM customer segmentation) in Microsoft SQL Server (T-SQL), followed by data modeling and interactive dashboard development in Power BI.

📌 Project Architecture & Workflow:
Raw Transaction Data (CSV Sources)
               │
               ▼
   [ Microsoft SQL Server ]
   ├── Stage & Clean: Type casting, anomaly removal, unified table creation
   ├── Analytical Queries: MoM Growth, Pareto Analysis, RFM Customer Scoring
   └── SQL Views: Optimized Star Schema serving layer
               │
               ▼
      [ Power BI Desktop ]
   ├── Direct Import & Star Schema Modeling
   ├── DAX Measures Layer
   └── Interactive 3-Page Executive Dashboard
🚀 Key Business Questions Answered
Executive Revenue Trends: What is our net revenue trajectory, and how do Month-over-Month (MoM) revenue and order volumes fluctuate?

Catalog Concentration (Pareto Principle): Which top 20% of products generate 80% of total revenue, and which items are low-velocity/long-tail?

Pricing & Discount Sensitivity: How do discount rates impact product demand and overall profitability?

Customer Lifetime Behavior (RFM): Who are our Champions, who is At Risk of churn, and what revenue is tied to each customer cohort?


🛠️ Data Engineering & SQL Implementation
1. Data Cleaning & Transformation (01_data_cleaning_and_merge.sql)
Explicit casting using TRY_CAST / CAST to handle corrupted formats.

Derived metrics calculation: TotalSales = (Quantity * UnitPrice) - Discount.

Data hygiene rules: Removal of negative quantities, zero-price anomalies, and non-numeric artifacts.

Performance indexing on TransactionDate, CustomerID, and ProductID.

2. Window Functions & MoM Growth (02_kpis_and_trends.sql)
Used LAG() over partitioned dates to calculate Month-over-Month growth rates while safeguarding against zero-division using NULLIF:

MoM Growth %= 
Previous Month Revenue
Current Month Revenue−Previous Month Revenue
​
 ×100
3. Pareto 80/20 Analysis (03_product_and_category_performance.sql)
Calculated running totals with window frames (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) to segment catalog items into Top 80% Core Contributors vs. Long Tail.

4. RFM Customer Segmentation (04_rfm_customer_segmentation.sql)
Scored customers on 1–5 scales using NTILE(5):

Recency (R): Days since the customer's last purchase relative to dataset max date.

Frequency (F): Total unique orders per customer.

Monetary (M): Total net revenue contributed.

Mapped scores into business segments: Champions, Loyal Customers, Potential Loyalists, New Customers, Need Attention, At Risk / Cannot Lose, and Lost / Inactive.

📊 Power BI Dashboard Highlights
🖥️ Page 1: Executive Sales Overview
Summary view tracking total revenue, order count, average order value (AOV), and customer base with MoM movement markers, peak weekday distribution, and top product drivers.

📦 Page 2: Product & Pricing Intelligence
Pareto analysis visualization showing revenue distribution across SKUs, price-volume scatter distribution, and top-discounted product matrices.

👥 Page 3: Customer RFM Segmentation
Treemap breakdown of customer cohorts, revenue share per tier, spend vs. recency behavior, and an actionable tabular target list for retention campaigns.

📐 Data Model (Star Schema)
Fact Table: vw_Sales_Fact (Transaction records with full date granularity)

Dimension Tables:

vw_Product_Performance linked via ProductID (1 : *)

vw_Customer_RFM_Segments linked via CustomerID (1 : *)

Aggregate Reporting Table: vw_Monthly_Sales_Trends

💡 Strategic Business Recommendations
VIP Retention (Champions & Loyal): Automate loyalty tier perks and exclusive early access to prevent churn among top spenders.

Win-Back Strategy (At Risk Segment): Trigger targeted promotional campaigns offering limited-time discounts for customers with high historical monetary value who have not purchased in >90 days.

Inventory & Catalog Optimization: Prioritize stock availability and supply chain velocity for the Top 80% Core SKUs identified in the Pareto analysis while optimizing clearance of low-margin long-tail items.

Discount Rationalization: Restrict heavy discount margins (>15%) on price-inelastic products that maintain steady sales volume regardless of promotions.
