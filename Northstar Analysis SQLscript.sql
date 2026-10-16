USE NorthStar_Distribution;
GO

-- DEMAND & INVENTORY
-- How has demand changed over time?
WITH monthly AS (
    SELECT YEAR(demand_date) AS year, MONTH(demand_date) AS month_number, DATENAME(MONTH, demand_date) AS month,
        SUM(units_sold) AS total_units, SUM(revenue) AS total_revenue
    FROM clean.fact_demand
    GROUP BY YEAR(demand_date), MONTH(demand_date), DATENAME(MONTH, demand_date))
SELECT year, month, month_number, total_units, total_revenue,
    CAST(100.0 * (total_units - LAG(total_units) OVER (ORDER BY year, month_number))
        / NULLIF(LAG(total_units) OVER (ORDER BY year, month_number), 0) AS DECIMAL(8,2)) AS mom_change_pct
FROM monthly
ORDER BY year, month_number;



-- Which products / locations drive the biggest changes? (2024 vs 2023, gains and drops)
SELECT TOP 15 s.category, d.sku, d.pack_type, d.us_region,
    SUM(CASE WHEN YEAR(d.demand_date) = 2023 THEN d.units_sold ELSE 0 END) AS units_2023,
    SUM(CASE WHEN YEAR(d.demand_date) = 2024 THEN d.units_sold ELSE 0 END) AS units_2024,
    (SUM(CASE WHEN YEAR(d.demand_date) = 2024 THEN d.units_sold ELSE 0 END) -
     SUM(CASE WHEN YEAR(d.demand_date) = 2023 THEN d.units_sold ELSE 0 END)) AS change_units
FROM clean.fact_demand d
INNER JOIN clean.dim_skus s ON s.sku = d.sku AND s.pack_type = d.pack_type
GROUP BY s.category, d.sku, d.pack_type, d.us_region
ORDER BY ABS(SUM(CASE WHEN YEAR(d.demand_date) = 2024 THEN d.units_sold ELSE 0 END) -
             SUM(CASE WHEN YEAR(d.demand_date) = 2023 THEN d.units_sold ELSE 0 END)) DESC;



-- Next quarter (Q1 2025) forecast by category and region, ranked by growth vs Q1 2024
-- Method: Q1 2024 units x (2024 / 2023 growth). Keeps seasonality, applies the recent trend.
WITH q AS (
    SELECT s.category, d.us_region,
        SUM(CASE WHEN d.demand_date >= '2024-01-01' AND d.demand_date < '2024-04-01' THEN d.units_sold ELSE 0 END) AS q1_2024,
        SUM(CASE WHEN d.demand_date >= '2024-10-01' THEN d.units_sold ELSE 0 END) AS q4_2024,
        SUM(CASE WHEN YEAR(d.demand_date) = 2023 THEN d.units_sold ELSE 0 END) AS y2023,
        SUM(CASE WHEN YEAR(d.demand_date) = 2024 THEN d.units_sold ELSE 0 END) AS y2024
    FROM clean.fact_demand d
    INNER JOIN clean.dim_skus s ON s.sku = d.sku AND s.pack_type = d.pack_type
    GROUP BY s.category, d.us_region),
f AS (
    SELECT category, us_region, q1_2024, q4_2024, q1_2024 * 1.0 * y2024 / NULLIF(y2023, 0) AS forecast_q1_2025
    FROM q)
SELECT category, us_region, q4_2024 AS last_quarter_units,
    CAST(forecast_q1_2025 AS DECIMAL(14,0)) AS forecast_next_quarter_units,
    CAST(100.0 * (forecast_q1_2025 - q4_2024) / NULLIF(q4_2024, 0) AS DECIMAL(8,2)) AS growth_vs_last_quarter_pct,
    CAST(100.0 * (forecast_q1_2025 - q1_2024) / NULLIF(q1_2024, 0) AS DECIMAL(8,2)) AS growth_vs_last_year_pct
FROM f
ORDER BY growth_vs_last_year_pct DESC;


--  Where is inventory out of line with demand? (stockout vs excess risk, latest week)
-- Excess = on-hand above reorder point + 4 weeks of average outflow. History = last 52 weeks.
WITH latest AS (SELECT MAX(week_date) AS d FROM clean.fact_inventory),
hist AS (
    SELECT dc_id, sku, pack_type, AVG(weekly_outflow_pallets * 1.0) AS avg_outflow, SUM(stockout_flag) AS stockout_weeks
    FROM clean.fact_inventory
    WHERE week_date > DATEADD(WEEK, -52, (SELECT d FROM latest))
    GROUP BY dc_id, sku, pack_type),
pos AS (
    SELECT c.dc_name, s.category, i.pallets_on_hand, i.reorder_point, h.stockout_weeks,
        CASE WHEN i.pallets_on_hand > i.reorder_point + 4 * h.avg_outflow
             THEN i.pallets_on_hand - (i.reorder_point + 4 * h.avg_outflow) ELSE 0 END AS excess_pallets
    FROM clean.fact_inventory i
    INNER JOIN latest l ON i.week_date = l.d
    INNER JOIN hist h ON h.dc_id = i.dc_id AND h.sku = i.sku AND h.pack_type = i.pack_type
    INNER JOIN clean.dim_dcs c ON c.dc_id = i.dc_id
    INNER JOIN clean.dim_skus s ON s.sku = i.sku AND s.pack_type = i.pack_type)
SELECT dc_name, category, COUNT(*) AS positions,
    SUM(CASE WHEN stockout_weeks > 0 OR pallets_on_hand < reorder_point THEN 1 ELSE 0 END) AS stockout_risk,
    SUM(CASE WHEN excess_pallets > 0 THEN 1 ELSE 0 END) AS excess,
    SUM(excess_pallets) AS excess_pallets
FROM pos
GROUP BY dc_name, category
ORDER BY excess_pallets DESC;


-- Working capital tied up in excess inventory, and cash that can be released safely
-- Cost per pallet = units_per_pallet x avg_price x 0.70 (avg_price is a selling price, 0.70 is an assumed cost ratio).
-- Safe release = excess on positions with no stockout in the last 52 weeks.
WITH latest AS (SELECT MAX(week_date) AS d FROM clean.fact_inventory),
hist AS (
    SELECT dc_id, sku, pack_type, AVG(weekly_outflow_pallets * 1.0) AS avg_outflow, SUM(stockout_flag) AS stockout_weeks
    FROM clean.fact_inventory
    WHERE week_date > DATEADD(WEEK, -52, (SELECT d FROM latest))
    GROUP BY dc_id, sku, pack_type),
pos AS (
    SELECT c.dc_name, i.pallets_on_hand, h.stockout_weeks,
        s.units_per_pallet * s.avg_price * 0.70 AS cost_per_pallet,
        CASE WHEN i.pallets_on_hand > i.reorder_point + 4 * h.avg_outflow
             THEN i.pallets_on_hand - (i.reorder_point + 4 * h.avg_outflow) ELSE 0 END AS excess_pallets
    FROM clean.fact_inventory i
    INNER JOIN latest l ON i.week_date = l.d
    INNER JOIN hist h ON h.dc_id = i.dc_id AND h.sku = i.sku AND h.pack_type = i.pack_type
    INNER JOIN clean.dim_dcs c ON c.dc_id = i.dc_id
    INNER JOIN clean.dim_skus s ON s.sku = i.sku AND s.pack_type = i.pack_type)
SELECT CASE WHEN GROUPING(dc_name) = 1 THEN 'TOTAL' ELSE dc_name END AS dc_name,
    CAST(SUM(pallets_on_hand * cost_per_pallet) AS DECIMAL(16,0)) AS inventory_value,
    CAST(SUM(excess_pallets * cost_per_pallet) AS DECIMAL(16,0)) AS excess_value,
    CAST(SUM(CASE WHEN stockout_weeks = 0 THEN excess_pallets * cost_per_pallet ELSE 0 END) AS DECIMAL(16,0)) AS safe_release_value
FROM pos
GROUP BY ROLLUP (dc_name)
ORDER BY GROUPING(dc_name), excess_value DESC;


-- TRANSPORTATION
-- Fuel and cost use placeholder assumptions: 45,000 lb payload, 6.5 mpg, 600 miles per load, $1.60 non-fuel cost per mile. The data has no origin terminal or mileage, so "routes" = destination region.

-- Where are we losing fuel and truck capacity?
WITH load_waste AS (
    SELECT l.dest_region, l.total_weight_lbs / 45000.0 AS util,
        CASE WHEN l.total_weight_lbs >= 45000 THEN 0 ELSE 1 - l.total_weight_lbs / 45000.0 END AS unused_share,
        f.price_per_gallon
    FROM clean.fact_loads l
    LEFT JOIN clean.fact_fuel f ON f.fuel_date = l.dispatch_date)
SELECT dest_region, COUNT(*) AS loads,
    CAST(AVG(util) AS DECIMAL(5,3)) AS avg_weight_util,
    SUM(CASE WHEN util < 0.60 THEN 1 ELSE 0 END) AS loads_under_60pct,
    CAST(SUM(unused_share * 600 / 6.5) AS DECIMAL(14,0)) AS unused_fuel_gallons,
    CAST(SUM(unused_share * 600 / 6.5 * price_per_gallon) AS DECIMAL(14,0)) AS fuel_cost_on_empty_space
FROM load_waste
GROUP BY dest_region
ORDER BY fuel_cost_on_empty_space DESC;


-- What is associated with late deliveries? (late = avg_delivery_days >= 4)
SELECT d.us_region, d.channel, s.category,
    COUNT(*) AS rows_count,
    CAST(100.0 * AVG(CASE WHEN d.avg_delivery_days >= 4 THEN 1.0 ELSE 0 END) AS DECIMAL(5,2)) AS late_pct,
    CAST(AVG(d.avg_delivery_days) AS DECIMAL(4,2)) AS avg_delivery_days
FROM clean.fact_demand d
INNER JOIN clean.dim_skus s ON s.sku = d.sku AND s.pack_type = d.pack_type
GROUP BY d.us_region, d.channel, s.category
ORDER BY late_pct DESC;


-- Which routes / activities offer the biggest efficiency opportunity? (region x category)
SELECT ll.dest_region, ll.category, COUNT(DISTINCT ll.load_id) AS loads,
    CAST(SUM(CASE WHEN l.total_weight_lbs < 45000
        THEN (1 - l.total_weight_lbs / 45000.0) * 600 / 6.5 * f.price_per_gallon * ll.weight_lbs / l.total_weight_lbs
        ELSE 0 END) AS DECIMAL(14,0)) AS wasted_fuel_cost
FROM clean.fact_load_lines ll
INNER JOIN clean.fact_loads l ON l.load_id = ll.load_id
LEFT JOIN clean.fact_fuel f ON f.fuel_date = l.dispatch_date
GROUP BY ll.dest_region, ll.category
ORDER BY wasted_fuel_cost DESC;


-- Which destination regions have the lowest truck utilization?
SELECT
    dest_region,
    COUNT(*) AS loads,
    CAST(AVG(total_weight_lbs / 45000.0) * 100 AS DECIMAL(5,1)) AS avg_utilization_pct
FROM clean.fact_loads
GROUP BY dest_region
ORDER BY avg_utilization_pct;


-- Which destination regions have the most loads under 60% utilization?
SELECT
    dest_region,
    COUNT(*) AS loads_under_60pct
FROM clean.fact_loads
WHERE total_weight_lbs / 45000.0 < 0.60
GROUP BY dest_region
ORDER BY loads_under_60pct DESC;

-- DERIVED METRICS (KPIs)

-- Inventory KPIs
-- Inventory days = on-hand / weekly outflow x 7; Turnover = annualised outflow value / inventory value.
WITH latest AS (SELECT MAX(week_date) AS d FROM clean.fact_inventory),
hist AS (
    SELECT dc_id, sku, pack_type, AVG(weekly_outflow_pallets * 1.0) AS avg_outflow, SUM(stockout_flag) AS stockout_weeks
    FROM clean.fact_inventory
    WHERE week_date > DATEADD(WEEK, -52, (SELECT d FROM latest))
    GROUP BY dc_id, sku, pack_type),
pos AS (
    SELECT i.pallets_on_hand, h.avg_outflow, h.stockout_weeks, s.units_per_pallet * s.avg_price * 0.70 AS cost_per_pallet,
        CASE WHEN i.pallets_on_hand > i.reorder_point + 4 * h.avg_outflow
             THEN i.pallets_on_hand - (i.reorder_point + 4 * h.avg_outflow) ELSE 0 END AS excess_pallets
    FROM clean.fact_inventory i
    INNER JOIN latest l ON i.week_date = l.d
    INNER JOIN hist h ON h.dc_id = i.dc_id AND h.sku = i.sku AND h.pack_type = i.pack_type
    INNER JOIN clean.dim_skus s ON s.sku = i.sku AND s.pack_type = i.pack_type)
SELECT CAST(SUM(pallets_on_hand * cost_per_pallet) AS DECIMAL(16,0)) AS total_inventory_value,
    CAST(SUM(excess_pallets * cost_per_pallet) AS DECIMAL(16,0)) AS excess_inventory_value,
    CAST(100.0 * SUM(excess_pallets * cost_per_pallet) / SUM(pallets_on_hand * cost_per_pallet) AS DECIMAL(5,1)) AS excess_pct_of_inventory,
    CAST(SUM(CASE WHEN stockout_weeks = 0 THEN excess_pallets * cost_per_pallet ELSE 0 END) AS DECIMAL(16,0)) AS potential_cash_freed,
    CAST(SUM(pallets_on_hand) * 7.0 / NULLIF(SUM(avg_outflow), 0) AS DECIMAL(6,1)) AS inventory_days,
    CAST(SUM(avg_outflow * 52 * cost_per_pallet) / NULLIF(SUM(pallets_on_hand * cost_per_pallet), 0) AS DECIMAL(6,2)) AS inventory_turnover
FROM pos;



-- Stockout rate = share of DC x SKU weeks with a stockout (by year, with overall total)
SELECT CASE WHEN GROUPING(YEAR(week_date)) = 1 THEN 'ALL' ELSE CAST(YEAR(week_date) AS VARCHAR(4)) END AS year,
    COUNT(*) AS dc_sku_weeks, SUM(stockout_flag) AS stockout_weeks,
    CAST(100.0 * SUM(stockout_flag) / COUNT(*) AS DECIMAL(5,2)) AS stockout_rate_pct
FROM clean.fact_inventory
GROUP BY ROLLUP (YEAR(week_date));

SELECT
    YEAR(week_date) AS year,
    COUNT(*) AS total_records,
    SUM(stockout_flag) AS stockout_records,
    CAST(100.0 * SUM(stockout_flag) / COUNT(*) AS DECIMAL(5,2)) AS stockout_rate_pct
FROM clean.fact_inventory
GROUP BY YEAR(week_date)
ORDER BY year;

SELECT
    COUNT(*) AS total_records,
    SUM(stockout_flag) AS stockout_records,
    CAST(100.0 * SUM(stockout_flag) / COUNT(*) AS DECIMAL(5,2)) AS stockout_rate_pct
FROM clean.fact_inventory;

-- Forecasted demand (Q1 2025) and expected growth vs Q1 2024, same method as D2
WITH q AS (
    SELECT s.category, d.us_region,
        SUM(CASE WHEN d.demand_date >= '2024-01-01' AND d.demand_date < '2024-04-01' THEN d.units_sold ELSE 0 END) AS q1_2024,
        SUM(CASE WHEN YEAR(d.demand_date) = 2023 THEN d.units_sold ELSE 0 END) AS y2023,
        SUM(CASE WHEN YEAR(d.demand_date) = 2024 THEN d.units_sold ELSE 0 END) AS y2024
    FROM clean.fact_demand d
    INNER JOIN clean.dim_skus s ON s.sku = d.sku AND s.pack_type = d.pack_type
    GROUP BY s.category, d.us_region)
SELECT SUM(q1_2024) AS q1_2024_units,
    CAST(SUM(q1_2024 * 1.0 * y2024 / NULLIF(y2023, 0)) AS DECIMAL(14,0)) AS forecast_q1_2025_units,
    CAST(100.0 * (SUM(q1_2024 * 1.0 * y2024 / NULLIF(y2023, 0)) - SUM(q1_2024)) / NULLIF(SUM(q1_2024), 0) AS DECIMAL(6,2)) AS expected_growth_pct
FROM q;


-- Truck KPIs by year: utilization, unused capacity, fuel purchased (measured) and fuel on empty space (modelled)
WITH l AS (
    SELECT
        YEAR(l.dispatch_date) AS year,
        COUNT(*) AS loads,
        SUM(l.total_weight_lbs) AS lbs,
        SUM(CASE WHEN l.total_weight_lbs >= 45000 THEN 0
            ELSE 45000 - l.total_weight_lbs END) AS unused_lbs,
        SUM(CASE WHEN l.total_weight_lbs >= 45000 THEN 0
            ELSE 1 - l.total_weight_lbs / 45000.0 END * 600 / 6.5)
            AS gallons_on_empty_space
    FROM clean.fact_loads l
    GROUP BY YEAR(l.dispatch_date)
),
f AS (
    SELECT
        YEAR(fuel_date) AS year,
        SUM(gallons_purchased) AS gallons_purchased
    FROM clean.fact_fuel
    GROUP BY YEAR(fuel_date)
)
SELECT
    l.year,
    l.loads,
    CAST(l.lbs / (45000.0 * l.loads) AS DECIMAL(5,4))
        AS truck_utilization_pct,
    CAST(l.unused_lbs / (45000.0 * l.loads) AS DECIMAL(5,4))
        AS unused_capacity_pct,
    CAST(f.gallons_purchased AS DECIMAL(14,0))
        AS fuel_gallons_purchased,
    CAST(l.gallons_on_empty_space AS DECIMAL(14,0))
        AS modelled_gallons_on_empty_space
FROM l
LEFT JOIN f ON f.year = l.year
ORDER BY l.year;


-- Delivery KPIs by year and region: average delivery time, delivered within 3 days %, delayed (4+ days) %
SELECT YEAR(demand_date) AS year, us_region, COUNT(*) AS rows_count,
    CAST(AVG(avg_delivery_days) AS DECIMAL(4,2)) AS avg_delivery_days,
    CAST(AVG(CASE WHEN avg_delivery_days < 4 THEN 1.0 ELSE 0 END) AS DECIMAL(5,2)) AS delivered_within_3_days_pct,
    CAST(AVG(CASE WHEN avg_delivery_days >= 4 THEN 1.0 ELSE 0 END) AS DECIMAL(5,2)) AS delayed_pct
FROM clean.fact_demand
GROUP BY YEAR(demand_date), us_region
ORDER BY year, us_region;

SELECT
    YEAR(demand_date) AS year,
    us_region,
    COUNT(*) AS rows_count,
    CAST(AVG(avg_delivery_days) AS DECIMAL(4,2)) AS avg_delivery_days,
    CAST(AVG(CASE WHEN avg_delivery_days < 4 THEN 1.0 ELSE 0 END) AS DECIMAL(5,4))
        AS delivered_within_3_days_pct,
    CAST(AVG(CASE WHEN avg_delivery_days >= 4 THEN 1.0 ELSE 0 END) AS DECIMAL(5,4))
        AS delayed_pct
FROM clean.fact_demand
GROUP BY YEAR(demand_date), us_region
ORDER BY year, us_region;

-- Inbound lead time by DC (replaces wait/detention time, which the data does not record)
SELECT c.dc_name, c.us_region, COUNT(*) AS orders,
    CAST(AVG(r.lead_time_days * 1.0) AS DECIMAL(5,2)) AS avg_inbound_lead_days,
    MAX(r.lead_time_days) AS max_lead_days
FROM clean.fact_replenishment r
INNER JOIN clean.dim_dcs c ON c.dc_id = r.dc_id
GROUP BY c.dc_name, c.us_region
ORDER BY avg_inbound_lead_days DESC;


-- Monthly trend for the Executive Overview: demand, revenue, loads, truck utilization
WITH d AS (
    SELECT month_start, SUM(units_sold) AS units, SUM(revenue) AS revenue
    FROM clean.fact_demand GROUP BY month_start),
l AS (
    SELECT DATEFROMPARTS(YEAR(dispatch_date), MONTH(dispatch_date), 1) AS month_start, COUNT(*) AS loads,
        CAST(100.0 * SUM(total_weight_lbs) / (45000.0 * COUNT(*)) AS DECIMAL(5,1)) AS truck_utilization_pct
    FROM clean.fact_loads GROUP BY DATEFROMPARTS(YEAR(dispatch_date), MONTH(dispatch_date), 1))
SELECT d.month_start, d.units, d.revenue, l.loads, l.truck_utilization_pct
FROM d LEFT JOIN l ON l.month_start = d.month_start
ORDER BY d.month_start;


-- Estimated fuel savings by year. Assumes 50% of modelled fuel cost can be saved.
SELECT YEAR(l.dispatch_date) AS year,
    CAST(SUM(CASE WHEN l.total_weight_lbs < 45000
        THEN (1 - l.total_weight_lbs / 45000.0) * 600 / 6.5 * f.price_per_gallon * 0.50
        ELSE 0 END) AS DECIMAL(14,2)) AS estimated_fuel_savings
FROM clean.fact_loads l
LEFT JOIN clean.fact_fuel f ON f.fuel_date = l.dispatch_date
GROUP BY YEAR(l.dispatch_date)
ORDER BY year;


-- Estimated Total Savings 
WITH x AS (
    SELECT YEAR(dispatch_date) AS year, dispatch_date, dest_region, COUNT(*) AS loads, SUM(total_weight_lbs) AS total_weight
    FROM clean.fact_loads GROUP BY YEAR(dispatch_date), dispatch_date, dest_region),
y AS (
    SELECT year, dest_region, loads,
        CASE WHEN CEILING(total_weight / (45000.0 * 0.85)) < loads
             THEN loads - CEILING(total_weight / (45000.0 * 0.85)) ELSE 0 END AS loads_avoided
    FROM x)
SELECT year, dest_region, SUM(loads) AS loads, SUM(loads_avoided) AS loads_avoided,
    CAST(SUM(loads_avoided) * (600 / 6.5 * (SELECT AVG(price_per_gallon) FROM clean.fact_fuel) + 600 * 1.60) AS DECIMAL(14,0)) AS est_total_savings
FROM y
GROUP BY year, dest_region
ORDER BY year, est_total_savings DESC;


-- Revenue by Year, Region and Category
SELECT YEAR(d.demand_date) AS year, s.category, d.us_region, SUM(d.revenue) AS revenue
FROM clean.fact_demand d INNER JOIN clean.dim_skus s ON s.sku = d.sku AND s.pack_type = d.pack_type
GROUP BY YEAR(d.demand_date), s.category, d.us_region ORDER BY year, revenue DESC;


SELECT
    load_id,
    dispatch_date,
    dest_region,
    total_weight_lbs,
    CAST(
        total_weight_lbs * 100.0 / 45000
        AS DECIMAL(5,2)
    ) AS truck_utilization_pct
FROM clean.fact_loads
WHERE total_weight_lbs IS NOT NULL
ORDER BY truck_utilization_pct;


-- Summary Statistics
SELECT
    COUNT(*) AS Total_Loads,
    CAST(AVG(total_weight_lbs * 100.0 / 45000) AS DECIMAL(6,2)) AS [Average Truck Utilisation (%)],
    CAST(MIN(total_weight_lbs * 100.0 / 45000) AS DECIMAL(6,2)) AS [Minimum Truck Utilisation (%)],
    CAST(MAX(total_weight_lbs * 100.0 / 45000) AS DECIMAL(6,2)) AS [Maximum Truck Utilisation (%)],
    SUM(CASE WHEN total_weight_lbs < 27000 THEN 1 ELSE 0 END) AS [Loads Below 60% Capacity],
    CAST(100.0 * SUM(CASE WHEN total_weight_lbs < 27000 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS DECIMAL(6,2)) AS [Loads Below 60% Capacity (%)]
FROM clean.fact_loads
WHERE total_weight_lbs IS NOT NULL;