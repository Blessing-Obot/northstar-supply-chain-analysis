# NORTHSTAR DISTRIBUTION: DEMAND, INVENTORY AND TRANSPORTATION ANALYSIS

## Executive Summary
This project analyzed NorthStar Distribution Co.’s supply chain performance from 2022 to 2024, examining demand trends, inventory management, and transportation efficiency across 100 retailers in three US regions. The objective was to identify operational inefficiencies, understand their impact on business performance, and recommend practical improvements.
The analysis revealed three major challenges. First, sales declined by 0.9% in 2024 compared with 2023, with monthly sales remaining below the previous year’s levels from May onward. Second, approximately $1.01 million in inventory, representing around 20% of its value, was identified as excess stock, particularly in Yogurt and SnackBar, while Milk and Ready Meal experienced stockouts. Third, trucks operated at 61% of their weight capacity, indicating significant unused space, while around 40% of deliveries took four or more days across regions, sales channels, and product categories.
Based on these findings, the project recommended combining partially loaded shipments to improve truck utilization, reviewing excess inventory and reallocating stock toward products experiencing shortages, and adopting cautious demand planning in response to slowing sales. Improved transportation efficiency could yield estimated annual savings of $4.5 million, while reviewing excess inventory could identify up to $0.99 million for potential cash release. These estimates have limitations: transportation costs were calculated using stated assumptions because distance travelled and fuel consumption per load were unavailable, and further investigation is needed to determine the causes of delivery delays.

## Project Overview
NorthStar Distribution operates in the FMCG distribution industry, supplying everyday products to retailers across three US regions. To run efficiently, the company needs to meet customer demand without tying up too much money in stock or spending unnecessarily on transportation.
This project examines how the company manages these operations and where changes could help reduce costs, improve stock availability, and make better use of its resources.

## Data Source
The project used the NorthStar Distribution FMCG Supply Chain dataset from Kaggle, covering January 2022 to December 2024. The structured, transactional data includes approximately 190,000 daily sales records, 41,580 weekly inventory records, 25,729 supplier orders, and 88,158 truck-load lines representing 41,959 loads, alongside product, retailer, supplier, distribution centre, and fuel price details.

## Problem Statement
Stakeholders at NorthStar Distribution, including supply chain managers, inventory planners, and transportation managers want to know:
1.	How has demand changed over time?
2.	Which products / locations drive the biggest changes? (2024 vs 2023, gains and drops)
3.	What is the forecast for next quarter (Q1 2025) by category and region, ranked by growth vs Q1 2024?
4.	Where is inventory out of line with demand? (stockout vs excess risk, latest week)
5.	How much working capital is tied up in excess inventory, and what cash can be released safely?
6.	Where are we losing fuel and truck capacity?
7.	What is associated with late deliveries? (late = average delivery days ≥ 4)
8.	Which routes / activities offer the biggest efficiency opportunity? (region × category)
9.	Which destination regions have the lowest truck utilization?
10.	Which destination regions have the most loads under 60% utilization?

## Tools & Methodology
### Tools used: 
-	SQL Server 
-	Power BI.

### Methodology
- Data validation and cleaning: The nine source tables were checked for row counts, duplicate records, missing relationships, invalid values, date inconsistencies, and formatting issues. Categorical fields were reviewed for inconsistent values and unnecessary whitespace, while data types were standardized using SQL conversions. Three sales records containing negative values were separated from the cleaned dataset for review.
- Data transformation: Cleaned tables were created under a dedicated SQL schema. The transformations included standardizing date fields, creating monthly reporting dates, adding inventory indicators for stockouts and low stock, calculating inventory days of cover, and consolidating product-level shipment records into one record per load for transportation analysis.
- Post-cleaning validation: The cleaned tables were checked for missing values and data consistency. The checks also confirmed that replenishment lead times matched the order and arrival dates, and assessed whether shipment loads exceeded the assumed 26-pallet trailer capacity.
- Data modeling: The cleaned tables were connected in Power BI to bring demand, inventory, replenishment, product, distribution centre, retailer, and transportation data together for analysis.
- Data analysis and visualization: SQL queries were used to investigate demand trends, inventory imbalances, working capital, truck utilization, delivery performance, and potential cost savings. The findings were presented in a three-page Power BI dashboard covering business performance, demand and inventory, and transportation efficiency.


### 1. BUSINESS PERFORMANCE OVERVIEW
<img width="1543" height="859" alt="Business Performance Overview" src="https://github.com/user-attachments/assets/2bcb3d83-305d-4289-abe6-83eb963f092c" />

#### Key Findings

- Revenue is $19.95M from 3.8M units over 2022-2024, and growth has levelled off. Revenue was about $3.2M in 2022, then roughly $8.4M in both 2023 and 2024. 2022 was a start-up year (quarterly revenue rose from $0.1M to $1.2M), so it isn’t used as a benchmark.
- Since 2023, quarterly revenue has moved sideways. It ranges from $1.7M to $2.4M with no sustained upward trend, and Q4 2024 ($1.8M) is below Q4 2023 ($1.9M).
- Truck utilisation has barely moved. It stayed at about 61% throughout (roughly 60.5% to 61.5%, apart from a higher start in early 2022), even though revenue grew and then plateaued. This points to how loads are planned, not a temporary issue.
- Yogurt is the largest category, at $8.2M (about 41% of revenue). Milk ($4.1M), ReadyMeal ($3.6M), SnackBar ($3.4M) and Juice ($0.7M) follow, so Yogurt’s stock and transport issues carry the biggest financial impact.
- The Midwest carries most of the fuel waste. It accounts for $3.8M of the $5.88M fuel cost on empty space (about 65%), against $1.4M in the South and $0.7M in the Northeast, which makes it the priority region.
- Forecast and savings. Q1 2025 demand is forecast at 389,810 units, and improving truck utilisation could save an estimated $13.55M over three years (about $4.5M a year). With revenue flat and utilisation stuck at 61%, operational efficiency is the main route to better performance.

### 2. DEMAND & INVENTORY PERFORMANCE
<img width="1542" height="857" alt="Demand & Inventory Performance" src="https://github.com/user-attachments/assets/07e4d768-8c63-4c59-8ef0-81d4c507c30e" />

#### Key Findings

- Sales volume fell by 0.9% in 2024, with monthly sales below 2023 levels from May to October and roughly level by year end. Q1 2025 demand is forecast at 389,810 units, 0.9% below Q1 2024, so purchasing at previous levels risks adding excess stock.
- NorthStar holds $1.01M of excess stock (about 20% of the $5.15M inventory value), while products were out of stock in 23.8% of product-and-warehouse weeks. Yogurt and SnackBar account for much of the excess, while Milk and ReadyMeal face more frequent shortages. Philadelphia Hub has the highest excess and stockout risk.
- Among the top movers, Yogurt SKUs YO-018 (+13.7K units) and YO-024 (+4.0K) and SnackBar SKU SN-030 (+9.0K) grew strongly, while SN-013 fell by 4.5K. Category-level trends alone may not be detailed enough for purchasing decisions.
- About $994K of the excess is potentially releasable, based on products with no stockouts in the previous 52 weeks. Reducing this surplus while prioritising products with recurring shortages could free cash and improve availability, subject to validating demand, lead times and service requirements.


### 3. TRANSPORTATION OPERATIONS ANALYSIS
<img width="1545" height="863" alt="Transportation Operations Analysis" src="https://github.com/user-attachments/assets/7d054830-a14c-459e-8052-f37b9187710c" />

#### Key Findings

- On average they run at 61.0% of their assumed weight capacity, leaving 39.0% unused, and about 48% of loads (roughly 20,300) leave less than 60% full. The pattern is steady across all three years, which points to how loads are planned and not to a temporary dip in demand.
- The empty space costs an estimated $5.88M in fuel over the three years, modelled from stated assumptions because actual distance and fuel per load were not available. The Midwest drives most of it: $3.8M (about 65%), against $1.4M in the South and $0.7M in the Northeast. It also has the most under-filled loads, about 13,000 versus 4,800 in the South and 2,500 in the Northeast. These are counts and not rates, so part of the lead reflects the Midwest shipping the most loads. By category, Yogurt wastes the most fuel ($1.81M), followed by SnackBar ($1.47M), ReadyMeal ($1.21M), Milk ($1.15M) and Juice ($0.24M), partly because Yogurt is also the largest category by revenue.
- The biggest opportunity is combining part-loaded trucks. Combining compatible loads going to the same region on the same day, to about 85% full, is estimated to save $13.55M over three years, about $4.5M a year (Midwest $9.3M, South $3.0M, Northeast $1.2M). The figure exceeds the $5.88M fuel waste because it also includes other running costs. It ignores product compatibility and truck starting locations, so a pilot is needed before treating it as a target.
- Deliveries take 3.0 days on average, but 40.2% are delayed (an average of four days or more). The rate is almost identical across regions (40.19% to 40.61%), channels (40.12% to 40.63%) and categories (39.93% to 40.90%), so no single factor explains it and the cause is likely system-wide. No promised delivery dates were available, so the four-day cut-off is a proxy for lateness.
- The priority is to start consolidation in the Midwest, where waste and savings are largest, and to investigate where delays arise before taking targeted action. Track delivery times during any pilot so that cutting cost does not make delays worse.

## Exploratory Data Analysis (EDA)

EDA was conducted on the cleaned dataset to examine data distributions, identify unusual records, understand performance trends, and explore relationships between demand, inventory, and transportation metrics. The findings helped guide the subsequent analysis and highlighted limitations that needed to be considered when interpreting results.

### Key Patterns
Yogurt contributed $8.2 million (41%) of total revenue, making it NorthStar's largest product category. Inventory analysis revealed that excess stock and stockouts occurred simultaneously, suggesting that inventory was not consistently aligned with demand. Truck utilisation averaged 61%, indicating considerable unused capacity.

### Distributions
Summary statistics were used to examine sales volumes, revenue, delivery times, inventory levels, and truck utilisation. Of the 41,959 loads analysed, 48.34% operated below 60% of assumed weight capacity, while average truck utilisation was 60.98%. Delivery times also showed a widespread pattern, with 40.2% of demand records averaging four days or more.
<img width="1170" height="265" alt="Summary Statistics" src="https://github.com/user-attachments/assets/1933d767-af4b-4a7a-bdfa-891471c43cce" />


### Trends
Monthly and quarterly comparisons showed that revenue grew from approximately $3.2 million in 2022 to $8.4 million in 2023, before remaining broadly flat in 2024. Unit sales declined by 0.9% in 2024, with monthly sales below the corresponding 2023 levels from May onward. Truck utilisation remained close to 61% throughout the period.
<img width="1067" height="365" alt="Trends" src="https://github.com/user-attachments/assets/b3b9c571-7d7d-45d8-b7e1-cfce3ba22a7b" />


### Outliers
Rule-based checks identified three demand records containing negative values. These were excluded from the cleaned dataset and retained separately for review. The interquartile range (IQR) method was used to flag unusually high or low sales values, while capacity checks identified loads exceeding the assumed limits of 45,000 lb or 26 pallets. Plausible high sales and long supplier lead times were retained to avoid removing genuine business activity.

### Correlations and Relationships
Relationships between selling price, promotional activity, sales volume, delivery time, inventory levels, stockouts, and load characteristics were examined using Pearson correlation and comparative analysis. These tests were intended to identify associations, such as whether higher stock levels corresponded with greater outflows or whether loads with more product lines were fuller. Correlation results were interpreted cautiously because associations do not establish causation.

### Impact on the Analysis
The EDA informed key analytical decisions: 2022 was excluded as a performance benchmark because it was a start-up year; invalid sales records were separated rather than corrected; inventory cover was calculated using aggregate stock and outflow; and delivery times of four days or more were treated as a proxy for delays because promised delivery dates were unavailable.
The EDA highlighted stagnant sales, uneven inventory allocation, underutilised truck capacity, and widespread delivery delays. These findings informed the subsequent analysis and recommendations for demand planning, inventory optimisation, and transportation efficiency.


## Recommendations
- Review excess stock and recurring stockouts by product and distribution centre. Prioritise Yogurt and SnackBar for excess-stock review, and Milk and ReadyMeal for stockout investigation. Validate the estimated $994,000 in potentially releasable cash before reducing orders or transferring stock.
- Start with underfilled loads in the Midwest, where the opportunity appears largest. Identify compatible shipments travelling to the same area and test whether combining them reduces trips and costs without delaying deliveries. Validate the projected savings against actual route, fuel, and operating-cost data before scaling up.
- Track order processing, warehouse waiting, dispatch, and transit times to identify where delays occur. Introduce promised delivery dates and monitor on-time delivery rates so managers can address the actual causes rather than relying on delivery duration alone.
- Use recent sales trends and product-level forecasts to guide purchasing and replenishment. Review declining demand for Juice and ReadyMeal alongside expected Yogurt growth, and compare forecasts with actual sales monthly to adjust orders as conditions change.
- Create a monthly review of inventory, truck utilisation, delivery performance, and demand forecasts. Assign each issue to a responsible team, agree on corrective actions, and track results against validated baseline measures. Expand data coverage where possible to improve decision-making.


## Limitations
- Inventory records cover only six of the 50 facilities referenced in the dataset description. Excess-stock and potential cash-release estimates may not represent the full network. Validate findings against additional facility records before making company-wide decisions.
- Promised delivery dates are unavailable. The 40.2% of records with average delivery times of four days or more is a proxy, not a verified late-delivery rate. Actual promised and delivery timestamps are needed to measure on-time performance.
- The $5.88 million in empty-capacity fuel costs and $13.55 million in potential consolidation savings are model-based estimates using assumed capacity, mileage, fuel efficiency, and costs. They are not confirmed expenditure or realised savings and require validation using actual trip-level data.
- The Q1 2025 forecast is based on historical sales and may not account for promotions, pricing changes, supply disruptions, or shifts in customer behaviour. Compare forecasts with actual results and update the model as new data becomes available.
- Three negative sales records were excluded and retained separately for review. Some unusual values may still require operational validation, and distribution centres sharing the name “Philadelphia Hub” are combined in name-based charts. Consistent facility identifiers and improved source-data checks would strengthen future analysis.


## Conclusion
NorthStar Distribution experienced declining sales in 2024 while excess inventory and underutilised trucks highlighted opportunities to improve supply chain efficiency. Excess stock in Yogurt and SnackBar, stockouts in Milk and ReadyMeal, and low truck utilisation suggest that inventory and transportation resources could be better aligned with demand. Improving stock allocation and consolidating compatible shipments could free up working capital and reduce transport costs, with potential annual savings estimated at $4.5 million. The business should pilot these improvements, monitor delivery performance, and collect more detailed transport data to validate the estimates and measure actual results.


