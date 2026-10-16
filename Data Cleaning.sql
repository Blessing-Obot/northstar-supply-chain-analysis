USE NorthStar_Distribution;
GO

SELECT * FROM fact_sku_demand_daily;
SELECT * FROM fact_dc_inventory_weekly;
SELECT * FROM fact_replenishment_orders;
SELECT * FROM fact_sku_to_load_link;
SELECT * FROM fact_fuel_macro_daily;
SELECT * FROM dim_skus;
SELECT * FROM dim_dcs;
SELECT * FROM dim_retailers;
SELECT * FROM dim_manufacturers;


-- DATA VALIDATION + CLEANING
-- RAW VALIDATION 

-- 1. Find the number of rows per table
SELECT 'fact_sku_demand_daily' AS table_name, COUNT(*) AS no_of_rows FROM fact_sku_demand_daily UNION ALL
SELECT 'fact_dc_inventory_weekly', COUNT(*) FROM fact_dc_inventory_weekly UNION ALL
SELECT 'fact_replenishment_orders', COUNT(*) FROM fact_replenishment_orders UNION ALL
SELECT 'fact_sku_to_load_link', COUNT(*) FROM fact_sku_to_load_link UNION ALL
SELECT 'fact_fuel_macro_daily', COUNT(*) FROM dbo.fact_fuel_macro_daily UNION ALL
SELECT 'dim_skus', COUNT(*) FROM dim_skus UNION ALL
SELECT 'dim_dcs', COUNT(*) FROM dim_dcs UNION ALL
SELECT 'dim_retailers', COUNT(*) FROM dim_retailers UNION ALL
SELECT 'dim_manufacturers', COUNT(*) FROM dim_manufacturers;


-- 2. Check for orphan tables (tables that disappear when you join tables)
SELECT COUNT(*) AS orphan_retailers FROM fact_sku_demand_daily d
LEFT JOIN dim_retailers r ON d.retailer_id = r.retailer_id 
WHERE r.retailer_id IS NULL;

SELECT COUNT(*) AS orphan_skus FROM fact_sku_demand_daily d
LEFT JOIN dim_skus s ON d.sku = s.sku 
    AND d.pack_type = s.pack_type 
WHERE s.sku IS NULL;

SELECT COUNT(*) AS orphan_dcs FROM fact_dc_inventory_weekly i
LEFT JOIN dim_dcs c ON i.dc_id = c.facility_id 
WHERE c.facility_id IS NULL;

SELECT COUNT(*) AS orphan_mfg FROM fact_replenishment_orders o
LEFT JOIN dim_manufacturers m ON o.manufacturer_id = m.manufacturer_id 
WHERE m.manufacturer_id IS NULL;


-- 3. Check for duplicates in each table (all should return 0)
SELECT COUNT(*) AS demand_dupes 
FROM (
       SELECT [date], sku, pack_type, retailer_id 
       FROM fact_sku_demand_daily
       GROUP BY [date], sku, pack_type, retailer_id 
       HAVING COUNT(*) > 1) x;

SELECT COUNT(*) AS inventory_dupes 
FROM (
    SELECT [date], dc_id, sku, pack_type 
    FROM fact_dc_inventory_weekly
    GROUP BY [date], dc_id, sku, pack_type 
    HAVING COUNT(*) > 1) x;

SELECT COUNT(*) AS replenishment_dupes 
FROM (
    SELECT order_date, dc_id, sku, pack_type 
    FROM fact_replenishment_orders
    GROUP BY order_date, dc_id, sku, pack_type 
    HAVING COUNT(*) > 1) x;

SELECT COUNT(*) AS load_line_dupes 
FROM (
    SELECT load_id, sku, pack_type 
    FROM fact_sku_to_load_link
    GROUP BY load_id, sku, pack_type 
    HAVING COUNT(*) > 1) x;

SELECT COUNT(*) AS fuel_dupes 
FROM (
    SELECT [date] 
    FROM fact_fuel_macro_daily
    GROUP BY [date] 
    HAVING COUNT(*) > 1) x;

SELECT COUNT(*) AS sku_dupes 
FROM (
    SELECT sku, pack_type 
    FROM dim_skus 
    GROUP BY sku, pack_type 
    HAVING COUNT(*) > 1) x;

SELECT COUNT(*) AS dc_dupes 
FROM (
    SELECT facility_id 
    FROM dim_dcs 
    GROUP BY facility_id 
    HAVING COUNT(*) > 1) x;

SELECT COUNT(*) AS retailer_dupes 
FROM (
    SELECT retailer_id 
    FROM dim_retailers 
    GROUP BY retailer_id 
    HAVING COUNT(*) > 1) x;

SELECT COUNT(*) AS mfg_dupes 
FROM (
    SELECT manufacturer_id 
    FROM dim_manufacturers 
    GROUP BY manufacturer_id 
    HAVING COUNT(*) > 1) x;


-- 4. Value Checks (check for negative values in each table
SELECT COUNT(*) AS negative_demand_rows FROM fact_sku_demand_daily
WHERE units_sold < 0 OR delivered_qty < 0 OR stock_available < 0 OR revenue < 0;

SELECT COUNT(*) AS arrival_before_order FROM fact_replenishment_orders
WHERE arrival_date < order_date;

SELECT COUNT(*) AS revenue_mismatch FROM fact_sku_demand_daily
WHERE ABS(units_sold * avg_price - revenue) > 0.05;

SELECT COUNT(*) AS negative_inventory_rows FROM fact_dc_inventory_weekly
WHERE pallets_on_hand < 0 OR in_transit_pallets < 0
   OR weekly_outflow_pallets < 0 OR stockout_pallets < 0;

SELECT COUNT(*) AS invalid_orders FROM fact_replenishment_orders
WHERE pallets_ordered <= 0 OR lead_time_days <= 0;

SELECT COUNT(*) AS lead_time_mismatch FROM fact_replenishment_orders
WHERE DATEDIFF(DAY, order_date, arrival_date) <> lead_time_days;

SELECT COUNT(*) AS invalid_load_rows FROM fact_sku_to_load_link
WHERE pallets <= 0 OR units <= 0 OR weight_lbs <= 0;

SELECT COUNT(*) AS invalid_fuel_rows FROM fact_fuel_macro_daily
WHERE national_avg_price_per_gallon <= 0 OR total_gallons_purchased <= 0;

SELECT COUNT(*) AS invalid_sku_rows FROM dim_skus
WHERE avg_price <= 0 OR units_per_pallet <= 0 OR weight_lbs_per_pallet <= 0;

SELECT COUNT(*) AS invalid_dc_rows FROM dim_dcs
WHERE storage_capacity_pallets <= 0 OR dock_doors <= 0;




-- STANDARDIZING THE DATA (for every categorical data in each table)
SELECT 'fact_sku_demand_daily' AS table_name, 'pack_type' AS column_name, pack_type AS value, COUNT(*) AS frequency FROM fact_sku_demand_daily GROUP BY pack_type UNION ALL
SELECT 'fact_sku_demand_daily' AS table_name, 'us_region' AS column_name, us_region AS value, COUNT(*) AS frequency FROM fact_sku_demand_daily GROUP BY us_region UNION ALL
SELECT 'fact_sku_demand_daily' AS table_name, 'channel' AS column_name, channel AS value, COUNT(*) AS frequency FROM fact_sku_demand_daily GROUP BY channel UNION ALL
SELECT 'fact_dc_inventory_weekly' AS table_name, 'pack_type' AS column_name, pack_type AS value, COUNT(*) AS frequency FROM fact_dc_inventory_weekly GROUP BY pack_type UNION ALL
SELECT 'fact_replenishment_orders' AS table_name, 'pack_type' AS column_name, pack_type AS value, COUNT(*) AS frequency FROM fact_replenishment_orders GROUP BY pack_type UNION ALL
SELECT 'fact_sku_to_load_link' AS table_name, 'pack_type' AS column_name, pack_type AS value, COUNT(*) AS frequency FROM fact_sku_to_load_link GROUP BY pack_type UNION ALL
SELECT 'fact_sku_to_load_link' AS table_name, 'category' AS column_name, category AS value, COUNT(*) AS frequency FROM fact_sku_to_load_link GROUP BY category UNION ALL
SELECT 'fact_sku_to_load_link' AS table_name, 'brand' AS column_name, brand AS value, COUNT(*) AS frequency FROM fact_sku_to_load_link GROUP BY brand UNION ALL
SELECT 'fact_sku_to_load_link' AS table_name, 'dest_region' AS column_name, dest_region AS value, COUNT(*) AS frequency FROM fact_sku_to_load_link GROUP BY dest_region UNION ALL
SELECT 'fact_fuel_macro_daily' AS table_name, 'day_of_week' AS column_name, day_of_week AS value, COUNT(*) AS frequency FROM fact_fuel_macro_daily GROUP BY day_of_week UNION ALL
SELECT 'dim_skus' AS table_name, 'pack_type' AS column_name, pack_type AS value, COUNT(*) AS frequency FROM dim_skus GROUP BY pack_type UNION ALL
SELECT 'dim_skus' AS table_name, 'category' AS column_name, category AS value, COUNT(*) AS frequency FROM dim_skus GROUP BY category UNION ALL
SELECT 'dim_skus' AS table_name, 'brand' AS column_name, brand AS value, COUNT(*) AS frequency FROM dim_skus GROUP BY brand UNION ALL
SELECT 'dim_skus' AS table_name, 'segment' AS column_name, segment AS value, COUNT(*) AS frequency FROM dim_skus GROUP BY segment UNION ALL
SELECT 'dim_dcs' AS table_name, 'facility_type' AS column_name, facility_type AS value, COUNT(*) AS frequency FROM dim_dcs GROUP BY facility_type UNION ALL
SELECT 'dim_dcs' AS table_name, 'state' AS column_name, state AS value, COUNT(*) AS frequency FROM dim_dcs GROUP BY state UNION ALL
SELECT 'dim_dcs' AS table_name, 'us_region' AS column_name, us_region AS value, COUNT(*) AS frequency FROM dim_dcs GROUP BY us_region UNION ALL
SELECT 'dim_dcs' AS table_name, 'dc_role' AS column_name, dc_role AS value, COUNT(*) AS frequency FROM dim_dcs GROUP BY dc_role UNION ALL
SELECT 'dim_dcs' AS table_name, 'operating_hours' AS column_name, operating_hours AS value, COUNT(*) AS frequency FROM dim_dcs GROUP BY operating_hours UNION ALL
SELECT 'dim_retailers' AS table_name, 'us_region' AS column_name, us_region AS value, COUNT(*) AS frequency FROM dim_retailers GROUP BY us_region UNION ALL
SELECT 'dim_retailers' AS table_name, 'channel' AS column_name, channel AS value, COUNT(*) AS frequency FROM dim_retailers GROUP BY channel UNION ALL
SELECT 'dim_retailers' AS table_name, 'account_status' AS column_name, account_status AS value, COUNT(*) AS frequency FROM dim_retailers GROUP BY account_status UNION ALL
SELECT 'dim_manufacturers' AS table_name, 'categories' AS column_name, categories AS value, COUNT(*) AS frequency FROM dim_manufacturers GROUP BY categories UNION ALL
SELECT 'dim_manufacturers' AS table_name, 'contract_type' AS column_name, contract_type AS value, COUNT(*) AS frequency FROM dim_manufacturers GROUP BY contract_type UNION ALL
SELECT 'dim_manufacturers' AS table_name, 'country' AS column_name, country AS value, COUNT(*) AS frequency FROM dim_manufacturers GROUP BY country
ORDER BY table_name, column_name, value;



-- Check for Whitespaces
SELECT 'fact_sku_demand_daily' AS table_name, COUNT(*) AS whitespace_count FROM fact_sku_demand_daily 
WHERE DATALENGTH(pack_type) <> DATALENGTH(TRIM(pack_type)) OR DATALENGTH(us_region) <> DATALENGTH(TRIM(us_region)) OR DATALENGTH(channel) <> DATALENGTH(TRIM(channel)) UNION ALL
SELECT 'fact_dc_inventory_weekly' AS table_name, COUNT(*) AS whitespace_count FROM fact_dc_inventory_weekly 
WHERE DATALENGTH(pack_type) <> DATALENGTH(TRIM(pack_type)) UNION ALL
SELECT 'fact_replenishment_orders' AS table_name, COUNT(*) AS whitespace_count FROM fact_replenishment_orders WHERE DATALENGTH(pack_type) <> DATALENGTH(TRIM(pack_type)) UNION ALL
SELECT 'fact_sku_to_load_link' AS table_name, COUNT(*) AS whitespace_count FROM fact_sku_to_load_link 
WHERE DATALENGTH(pack_type) <> DATALENGTH(TRIM(pack_type)) OR DATALENGTH(category) <> DATALENGTH(TRIM(category)) OR DATALENGTH(brand) <> DATALENGTH(TRIM(brand)) OR DATALENGTH(dest_region) <> DATALENGTH(TRIM(dest_region)) UNION ALL
SELECT 'fact_fuel_macro_daily' AS table_name, COUNT(*) AS whitespace_count FROM fact_fuel_macro_daily 
WHERE DATALENGTH(day_of_week) <> DATALENGTH(TRIM(day_of_week)) UNION ALL
SELECT 'dim_skus' AS table_name, COUNT(*) AS whitespace_count FROM dim_skus 
WHERE DATALENGTH(pack_type) <> DATALENGTH(TRIM(pack_type)) OR DATALENGTH(category) <> DATALENGTH(TRIM(category)) OR DATALENGTH(brand) <> DATALENGTH(TRIM(brand)) OR DATALENGTH(segment) <> DATALENGTH(TRIM(segment)) UNION ALL
SELECT 'dim_dcs' AS table_name, COUNT(*) AS whitespace_count FROM dim_dcs 
WHERE DATALENGTH(facility_type) <> DATALENGTH(TRIM(facility_type)) OR DATALENGTH(state) <> DATALENGTH(TRIM(state)) OR DATALENGTH(us_region) <> DATALENGTH(TRIM(us_region)) OR DATALENGTH(dc_role) <> DATALENGTH(TRIM(dc_role)) OR DATALENGTH(operating_hours) <> DATALENGTH(TRIM(operating_hours)) UNION ALL
SELECT 'dim_retailers' AS table_name, COUNT(*) AS whitespace_count FROM dim_retailers 
WHERE DATALENGTH(us_region) <> DATALENGTH(TRIM(us_region)) OR DATALENGTH(channel) <> DATALENGTH(TRIM(channel)) OR DATALENGTH(account_status) <> DATALENGTH(TRIM(account_status)) UNION ALL
SELECT 'dim_manufacturers' AS table_name, COUNT(*) AS whitespace_count FROM dim_manufacturers 
WHERE DATALENGTH(categories) <> DATALENGTH(TRIM(categories)) OR DATALENGTH(contract_type) <> DATALENGTH(TRIM(contract_type)) OR DATALENGTH(country) <> DATALENGTH(TRIM(country));





-- 2. CLEAN SCHEMA
IF SCHEMA_ID('clean') IS NULL EXEC('CREATE SCHEMA clean');
GO

DROP TABLE IF EXISTS clean.dim_skus;
SELECT sku, pack_type,
       sku + '|' + pack_type AS sku_key,
       brand, segment, category,
       TRY_CAST(avg_price AS DECIMAL(10,2)) AS avg_price,
       TRY_CAST(units_per_pack AS INT) AS units_per_pack,
       TRY_CAST(packs_per_pallet AS INT) AS packs_per_pallet,
       TRY_CAST(units_per_pallet AS INT) AS units_per_pallet,
       TRY_CAST(weight_lbs_per_pallet AS INT) AS weight_lbs_per_pallet,
       TRY_CAST(requires_refrigeration AS BIT) AS requires_refrigeration,
       TRY_CAST(shelf_life_days AS INT) AS shelf_life_days
INTO clean.dim_skus FROM dim_skus;

DROP TABLE IF EXISTS clean.dim_dcs;
SELECT facility_id AS dc_id, facility_name AS dc_name, facility_type,
       city, state, us_region, dc_role,
       TRY_CAST(has_refrigeration AS BIT) AS has_refrigeration,
       TRY_CAST(dock_doors AS INT) AS dock_doors,
       TRY_CAST(storage_capacity_pallets AS INT) AS storage_capacity_pallets
INTO clean.dim_dcs FROM dim_dcs;

DROP TABLE IF EXISTS clean.dim_retailers;
SELECT retailer_id, customer_name,
       us_region, channel,
       TRY_CAST(n_stores AS INT) AS n_stores,
       TRY_CAST(annual_revenue_potential AS BIGINT) AS annual_revenue_potential,
       account_status
INTO clean.dim_retailers FROM dim_retailers;

DROP TABLE IF EXISTS clean.dim_manufacturers;
SELECT manufacturer_id, manufacturer_name,
       brand, categories AS category, contract_type
INTO clean.dim_manufacturers FROM dim_manufacturers;

-- Separate the 3 negative rows in demand table
DROP TABLE IF EXISTS clean.demand_rejects;
SELECT * INTO clean.demand_rejects FROM fact_sku_demand_daily
WHERE units_sold < 0 OR delivered_qty < 0 OR stock_available < 0 OR revenue < 0;

DROP TABLE IF EXISTS clean.fact_demand;
SELECT TRY_CAST([date] AS DATE) AS demand_date,
       DATEFROMPARTS(YEAR(TRY_CAST([date] AS DATE)), MONTH(TRY_CAST([date] AS DATE)), 1) AS month_start,
       sku, pack_type, retailer_id,
       us_region, channel,
       TRY_CAST(units_sold AS INT) AS units_sold,
       TRY_CAST(delivered_qty AS INT) AS delivered_qty,
       TRY_CAST(pallets_shipped AS INT) AS pallets_shipped,
       TRY_CAST(weight_lbs_shipped AS INT) AS weight_lbs_shipped,
       TRY_CAST(stock_available AS INT) AS stock_available,
       TRY_CAST(avg_price AS DECIMAL(10,2)) AS avg_price,
       TRY_CAST(revenue AS DECIMAL(12,2)) AS revenue,
       TRY_CAST(promotion_flag AS BIT) AS promotion_flag,
       TRY_CAST(avg_delivery_days AS DECIMAL(6,2)) AS avg_delivery_days
INTO clean.fact_demand
FROM fact_sku_demand_daily
WHERE units_sold >= 0 AND delivered_qty >= 0 AND stock_available >= 0 AND revenue >= 0;

DROP TABLE IF EXISTS clean.fact_inventory;
SELECT week_date, dc_id, sku, pack_type,
       pallets_on_hand, reorder_point, order_up_to,
       in_transit_pallets, weekly_outflow_pallets, stockout_pallets,
       CASE WHEN stockout_pallets > 0 THEN 1 ELSE 0 END AS stockout_flag,
       CASE WHEN pallets_on_hand = 0 THEN 1 ELSE 0 END AS zero_stock_flag,
       CASE WHEN pallets_on_hand < reorder_point THEN 1 ELSE 0 END AS below_reorder_flag,
       CASE WHEN weekly_outflow_pallets > 0
            THEN CAST(pallets_on_hand * 7.0 / weekly_outflow_pallets AS DECIMAL(10,1)) END AS days_of_cover
INTO clean.fact_inventory
FROM (
    SELECT TRY_CAST([date] AS DATE) AS week_date,
           dc_id, sku, pack_type,
           TRY_CAST(pallets_on_hand AS INT) AS pallets_on_hand,
           TRY_CAST(reorder_point_s AS INT) AS reorder_point,
           TRY_CAST(order_up_to_S AS INT) AS order_up_to,
           TRY_CAST(in_transit_pallets AS INT) AS in_transit_pallets,
           TRY_CAST(weekly_outflow_pallets AS INT) AS weekly_outflow_pallets,
           TRY_CAST(stockout_pallets AS INT) AS stockout_pallets
    FROM fact_dc_inventory_weekly
) c;

DROP TABLE IF EXISTS clean.fact_replenishment;
SELECT TRY_CAST(order_date AS DATE) AS order_date, TRY_CAST(arrival_date AS DATE) AS arrival_date,
       dc_id, sku, pack_type,
       manufacturer_id,
       TRY_CAST(pallets_ordered AS INT) AS pallets_ordered,
       TRY_CAST(lead_time_days AS INT) AS lead_time_days
INTO clean.fact_replenishment FROM fact_replenishment_orders;

DROP TABLE IF EXISTS clean.fact_load_lines;
SELECT trip_id, load_id,
       TRY_CAST(dispatch_date AS DATE) AS dispatch_date,
       sku, pack_type, category,
       TRY_CAST(pallets AS INT) AS pallets, TRY_CAST(units AS INT) AS units,
       TRY_CAST(weight_lbs AS INT) AS weight_lbs, dest_region
INTO clean.fact_load_lines FROM fact_sku_to_load_link;

-- One row per load, used for transportation analysis
DROP TABLE IF EXISTS clean.fact_loads;
SELECT load_id, MIN(trip_id) AS trip_id, MIN(dispatch_date) AS dispatch_date,
       MIN(dest_region) AS dest_region, COUNT(*) AS sku_lines,
       SUM(pallets) AS total_pallets, SUM(weight_lbs) AS total_weight_lbs,
       CAST(SUM(pallets) / 26.0 AS DECIMAL(6,2)) AS truck_fill_ratio   -- 26 = assumed standard 53ft trailer
INTO clean.fact_loads FROM clean.fact_load_lines GROUP BY load_id;

DROP TABLE IF EXISTS clean.fact_fuel;
SELECT TRY_CAST([date] AS DATE) AS fuel_date,
       TRY_CAST(national_avg_price_per_gallon AS DECIMAL(10,4)) AS price_per_gallon,
       TRY_CAST(total_gallons_purchased AS DECIMAL(12,1)) AS gallons_purchased,
       TRY_CAST(n_transactions AS INT) AS n_transactions,
       TRY_CAST(fuel_price_rolling_7d AS DECIMAL(10,4)) AS price_rolling_7d,
       TRY_CAST(fuel_price_yoy_pct_change AS DECIMAL(10,4)) AS price_yoy_pct   -- NULL for first 365 days (kept)
INTO clean.fact_fuel FROM fact_fuel_macro_daily;
GO

SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'clean';



-- 3. POST-CLEAN CHECKS
-- Demand: 190757 raw = 190754 clean + 3 rejected
SELECT 
    (SELECT COUNT(*) FROM clean.fact_demand) AS clean_rows,
    (SELECT COUNT(*) FROM clean.demand_rejects) AS rejected_rows;

-- Confirm no null values (should be zero)
SELECT 'clean.dim_skus' AS table_name, COUNT(*) AS null_rows FROM clean.dim_skus 
WHERE sku IS NULL OR pack_type IS NULL OR sku_key IS NULL OR brand IS NULL OR segment IS NULL OR category IS NULL OR avg_price IS NULL OR units_per_pack IS NULL OR packs_per_pallet IS NULL OR units_per_pallet IS NULL OR weight_lbs_per_pallet IS NULL OR requires_refrigeration IS NULL OR shelf_life_days IS NULL UNION ALL
SELECT 'clean.dim_dcs' AS table_name, COUNT(*) AS null_rows FROM clean.dim_dcs 
WHERE dc_id IS NULL OR dc_name IS NULL OR facility_type IS NULL OR city IS NULL OR state IS NULL OR us_region IS NULL OR dc_role IS NULL OR has_refrigeration IS NULL OR dock_doors IS NULL OR storage_capacity_pallets IS NULL UNION ALL
SELECT 'clean.dim_retailers' AS table_name, COUNT(*) AS null_rows FROM clean.dim_retailers 
WHERE retailer_id IS NULL OR customer_name IS NULL OR us_region IS NULL OR channel IS NULL OR n_stores IS NULL OR annual_revenue_potential IS NULL OR account_status IS NULL UNION ALL
SELECT 'clean.dim_manufacturers' AS table_name, COUNT(*) AS null_rows FROM clean.dim_manufacturers
WHERE manufacturer_id IS NULL OR manufacturer_name IS NULL OR brand IS NULL OR category IS NULL OR contract_type IS NULL UNION ALL
SELECT 'clean.fact_demand' AS table_name, COUNT(*) AS null_rows FROM clean.fact_demand 
WHERE demand_date IS NULL OR month_start IS NULL OR sku IS NULL OR pack_type IS NULL OR retailer_id IS NULL OR us_region IS NULL OR channel IS NULL OR units_sold IS NULL OR delivered_qty IS NULL OR pallets_shipped IS NULL OR weight_lbs_shipped IS NULL OR stock_available IS NULL OR avg_price IS NULL OR revenue IS NULL OR promotion_flag IS NULL OR avg_delivery_days IS NULL UNION ALL
SELECT 'clean.fact_inventory' AS table_name, COUNT(*) AS null_rows FROM clean.fact_inventory 
WHERE week_date IS NULL OR dc_id IS NULL OR sku IS NULL OR pack_type IS NULL OR pallets_on_hand IS NULL OR reorder_point IS NULL OR order_up_to IS NULL OR in_transit_pallets IS NULL OR weekly_outflow_pallets IS NULL OR stockout_pallets IS NULL UNION ALL
SELECT 'clean.fact_replenishment' AS table_name, COUNT(*) AS null_rows FROM clean.fact_replenishment
WHERE order_date IS NULL OR arrival_date IS NULL OR dc_id IS NULL OR sku IS NULL OR pack_type IS NULL OR manufacturer_id IS NULL OR pallets_ordered IS NULL OR lead_time_days IS NULL UNION ALL
SELECT 'clean.fact_load_lines' AS table_name, COUNT(*) AS null_rows FROM clean.fact_load_lines
WHERE trip_id IS NULL OR load_id IS NULL OR dispatch_date IS NULL OR sku IS NULL OR pack_type IS NULL OR category IS NULL OR pallets IS NULL OR units IS NULL OR weight_lbs IS NULL OR dest_region IS NULL UNION ALL
SELECT 'clean.fact_fuel' AS table_name, COUNT(*) AS null_rows FROM clean.fact_fuel 
WHERE fuel_date IS NULL OR price_per_gallon IS NULL OR gallons_purchased IS NULL OR n_transactions IS NULL OR price_rolling_7d IS NULL;

-- Lead time check (should be 0)
SELECT COUNT(*) AS lead_time_mismatch FROM clean.fact_replenishment
WHERE DATEDIFF(DAY, order_date, arrival_date) <> lead_time_days;

-- Loads sanity: how many exceed one truck (26 pallets)?
SELECT COUNT(*) AS loads, SUM(CASE WHEN total_pallets > 26 THEN 1 ELSE 0 END) AS loads_over_26_pallets
FROM clean.fact_loads;