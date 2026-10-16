# NorthStar Distribution: Data Cleaning and Preparation

This guide explains how to reproduce the data-cleaning process for the NorthStar Distribution supply-chain project using SQL Server and SQL Server Management Studio (SSMS). It follows the accompanying SQL script in execution order.

The goal is to turn the original CSV data into typed, validated tables in a separate `clean` schema for demand, inventory, replenishment, and transportation analysis.

## Contents

1. [Requirements and files](#1-requirements-and-files)
2. [Create the database](#2-create-the-database)
3. [Import the raw CSV files](#3-import-the-raw-csv-files)
4. [Run the script in stages](#4-run-the-script-in-stages)
   - [Stage A: Inspect the raw tables](#stage-a-inspect-the-raw-tables)
   - [Stage B: Check row counts](#stage-b-check-row-counts)
   - [Stage C: Check relationships](#stage-c-check-relationships-between-tables)
   - [Stage D: Check duplicate keys](#stage-d-check-duplicate-keys)
   - [Stage E: Check invalid values and business rules](#stage-e-check-invalid-values-and-business-rules)
   - [Stage F: Inspect category values and whitespace](#stage-f-inspect-category-values-and-whitespace)
   - [Stage G: Build the clean tables](#stage-g-build-the-clean-tables)
   - [Stage H: Verify the clean tables](#stage-h-verify-the-clean-tables)
5. [Expected outputs](#5-expected-outputs)
6. [Cleaning decisions and limitations](#6-cleaning-decisions-and-limitations)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Requirements and files

You will need:

- SQL Server 2017 or later.
- SQL Server Management Studio (SSMS).
- The nine original NorthStar CSV files.
- The SQL cleaning script in this repository.

The script expects the following raw tables in the `dbo` schema. Import each CSV using the matching table name, without `.csv`.

| Raw table / CSV name | Expected rows | What it contains |
|---|---:|---|
| `fact_sku_demand_daily` | 190,757 | Daily demand and sales |
| `fact_dc_inventory_weekly` | 41,580 | Weekly distribution-centre inventory |
| `fact_replenishment_orders` | 25,729 | Supplier replenishment orders |
| `fact_sku_to_load_link` | 88,158 | SKU-level lines assigned to truck loads |
| `fact_fuel_macro_daily` | 1,098 | Daily fuel data |
| `dim_skus` | 90 | Product/SKU details |
| `dim_dcs` | 50 | Distribution-centre details |
| `dim_retailers` | 100 | Retailer details |
| `dim_manufacturers` | 14 | Manufacturer details |

Keep an unchanged copy of the source CSV files. The script reads the raw tables and creates new tables in `clean`; it does not update the raw tables.


---

## 2. Create the database

1. Open SSMS and connect to your SQL Server instance.
2. Click **New Query**.
3. Run:

   ```sql
   CREATE DATABASE NorthStar_Distribution;
   GO
   ```

4. In Object Explorer, refresh **Databases** and confirm that `NorthStar_Distribution` appears.

If the database already exists, do not create it again; select it and continue.


---

## 3. Import the raw CSV files

Repeat these steps for all nine CSV files:

1. In Object Explorer, right-click `NorthStar_Distribution`.
2. Select **Tasks → Import Flat File**.
3. Browse to the CSV file and select it.
4. Confirm the preview shows the expected columns and records.
5. Set the destination table name to the file name without `.csv` (for example, `fact_sku_demand_daily`).
6. Complete the import wizard.
7. Repeat for the remaining files.

Import the tables into the `dbo` schema. The SQL script starts with `USE NorthStar_Distribution;` and refers to these exact table names.

**Important:** The import wizard may detect some numbers and dates as text. That is why the cleaning script explicitly converts data types later.


---

## 4. Run the script in stages

Open the SQL cleaning script in SSMS. Confirm the database statement at the top is:

```sql
USE NorthStar_Distribution;
GO
```

Run the script in the order below. You can select and execute one section at a time with **Execute** (or press **F5**). Reviewing each result set makes it easier to spot problems before moving on.

### Stage A: Inspect the raw tables

The script begins by selecting the contents of each raw table. This is an initial inspection to confirm the tables can be queried and the columns look as expected.

**What to check:** The query runs without an "invalid object name" error and the result sets contain the expected columns.


### Stage B: Check row counts

The first validation query counts records in all nine raw tables.

**Why this matters:** These counts establish a baseline. After cleaning, you can compare the output against the original row counts and identify unexpected loss of records.

**Expected raw row counts:** Use the table in Section 1 as the reference.


If a count differs, check that you imported the correct file, did not import a file twice, and used the expected table name.

### Stage C: Check relationships between tables

The script uses `LEFT JOIN` checks to look for records in fact tables whose IDs do not exist in their corresponding dimension tables. These are called orphan records.

It checks:

- Demand records against retailers.
- Demand records against SKUs, using both `sku` and `pack_type`.
- Inventory records against distribution centres.
- Replenishment orders against manufacturers.

**Why this matters:** An unmatched ID can cause records to disappear from analysis when tables are joined.

**Expected result:** Each orphan count is `0`.

**Screenshot to add:** The orphan-check queries and their result counts.

If a count is above zero, identify the unmatched IDs and investigate them before deciding whether to correct, map, or quarantine the affected records. Do not delete them without documenting the reason.

### Stage D: Check duplicate keys

The script groups each table by its expected business key and counts groups that appear more than once. For example, demand is checked by date, SKU, pack type, and retailer; inventory is checked by date, DC, SKU, and pack type.

**Why this matters:** Duplicate records can inflate totals and distort trends.

**Expected result:** All duplicate-check counts are `0`.

A `load_id` or `trip_id` can legitimately appear on multiple rows in `fact_sku_to_load_link`, because one truck load can contain several SKU lines. Those repeated IDs are not automatically duplicates; the script checks the combination of `load_id`, `sku`, and `pack_type`.

### Stage E: Check invalid values and business rules

The script checks for values that conflict with expected business rules, including:

- Negative sales, delivered quantities, stock, or revenue.
- Replenishment arrival dates earlier than order dates.
- Revenue that differs from `units_sold × avg_price` by more than $0.05.
- Negative inventory quantities.
- Orders with non-positive pallet quantities or lead times.
- Lead times that do not match the difference between order and arrival dates.
- Load lines with non-positive pallets, units, or weight.
- Non-positive fuel values.
- SKU records with non-positive price, units per pallet, or weight per pallet.
- Distribution centres with non-positive storage capacity or dock-door counts.

**Key finding:** The negative-demand check returns **3** rows. The other listed invalid-value checks are expected to return `0`.

The three negative-demand rows are not silently deleted. In Stage G, the script copies them into `clean.demand_rejects` and excludes them from `clean.fact_demand`, so the issue remains auditable.


### Stage F: Inspect category values and whitespace

The script lists distinct values and their frequencies for selected categorical columns, such as region, channel, pack type, product category, brand, and account status. This lets you spot inconsistent labels (for example, different spellings of the same category).

It then checks selected text columns for leading or trailing spaces using `DATALENGTH(column)` compared with `DATALENGTH(TRIM(column))`.

**Why this matters:** Inconsistent labels can split one business category into multiple groups, while hidden spaces can interfere with grouping or matching.

**Expected result:** The reported whitespace counts are `0`, and the distinct values should be consistent with the categories used in the source data.

**Important distinction:** This part of the script checks category values and whitespace; it does not automatically rewrite category labels or apply `TRIM()` to the source tables. If the checks reveal a problem, document the issue and amend the cleaning transformation deliberately before proceeding.


### Stage G: Build the clean tables

The script creates a `clean` schema if it does not already exist, then drops and rebuilds the output tables. This makes the transformation repeatable: rerunning the script recreates the clean outputs from the raw tables.

The main transformations are:

| Output table | What the script does |
|---|---|
| `clean.dim_skus` | Converts numeric and refrigeration fields to suitable types and adds `sku_key` by combining SKU and pack type. |
| `clean.dim_dcs` | Renames `facility_id` to `dc_id` and `facility_name` to `dc_name`; converts flag and capacity fields. |
| `clean.dim_retailers` | Converts store count and annual revenue potential to numeric types. |
| `clean.dim_manufacturers` | Renames `categories` to `category`. |
| `clean.demand_rejects` | Preserves the three demand rows containing negative values for review. |
| `clean.fact_demand` | Converts date, quantity, price, revenue, promotion, and delivery fields to appropriate types; creates `month_start`; excludes the three negative-demand rows. |
| `clean.fact_inventory` | Converts the weekly date and inventory fields; adds stockout, zero-stock, below-reorder flags, and `days_of_cover`. |
| `clean.fact_replenishment` | Converts order and arrival dates and the pallet/lead-time fields. |
| `clean.fact_load_lines` | Converts dispatch dates and load-line quantity/weight fields. Each row still represents a SKU on a load. |
| `clean.fact_loads` | Groups load lines by `load_id` to create one row per load, with total pallets, total weight, SKU-line count, and a legacy pallet-based fill ratio. |
| `clean.fact_fuel` | Converts fuel dates, prices, volumes, transaction counts, and rolling/YoY fields. |

The script uses `TRY_CAST` for many conversions. Unlike `CAST`, `TRY_CAST` returns `NULL` when a value cannot be converted instead of immediately stopping the query. The post-clean checks help reveal unexpected `NULL` values.

It also creates derived fields:

- `month_start`: first day of the demand month, useful for monthly reporting.
- `sku_key`: a combined SKU and pack-type key.
- `stockout_flag`, `zero_stock_flag`, and `below_reorder_flag`: inventory status indicators.
- `days_of_cover`: estimated days of inventory based on on-hand pallets and weekly outflow. It remains `NULL` when weekly outflow is zero because the calculation would otherwise divide by zero.
- `clean.fact_loads` summary fields: aggregated measures at load level.


### Stage H: Verify the clean tables

At the end, the script lists tables in the `clean` schema and runs post-clean checks.

Confirm that the `clean` schema contains these 11 tables:

- `clean.dim_skus`
- `clean.dim_dcs`
- `clean.dim_retailers`
- `clean.dim_manufacturers`
- `clean.demand_rejects`
- `clean.fact_demand`
- `clean.fact_inventory`
- `clean.fact_replenishment`
- `clean.fact_load_lines`
- `clean.fact_loads`
- `clean.fact_fuel`

Confirm demand row accounting:

- Raw demand: 190,757
- Clean demand: 190,754
- Rejected demand: 3
- Reconciliation: 190,754 + 3 = 190,757

Review the post-clean null checks. A `NULL` may indicate a failed type conversion or missing required value; investigate it rather than assuming the data is ready.

Confirm the replenishment lead-time mismatch count is `0`.

Review the load sanity check. It reports the number of loads and how many have more than 26 pallets. Loads over 26 pallets are flagged for review; the check does not automatically remove or correct them.


---

## 5. Expected outputs

The script should create 11 tables in the `clean` schema. The main row-count expectations are:

| Output | Expected rows | Explanation |
|---|---:|---|
| `clean.dim_skus` | 90 | Product dimension |
| `clean.dim_dcs` | 50 | Distribution-centre dimension |
| `clean.dim_retailers` | 100 | Retailer dimension |
| `clean.dim_manufacturers` | 14 | Manufacturer dimension |
| `clean.fact_demand` | 190,754 | Three negative-demand rows excluded |
| `clean.demand_rejects` | 3 | Quarantined demand records |
| `clean.fact_inventory` | 41,580 | Weekly inventory |
| `clean.fact_replenishment` | 25,729 | Replenishment orders |
| `clean.fact_load_lines` | 88,158 | SKU-level load lines |
| `clean.fact_loads` | 41,959 | One row per load |
| `clean.fact_fuel` | 1,098 | Daily fuel data |

Use the actual query results as the final evidence. If your counts differ, do not assume the run succeeded just because SQL Server reports that the commands completed.

---

## 6. Cleaning decisions and limitations

- **Raw data is preserved:** transformations create tables in `clean`; the raw `dbo` tables are not updated.
- **Negative demand is quarantined:** three records are kept in `clean.demand_rejects` and excluded from the analysis-ready demand table.
- **No automatic category edits:** the script inspects category consistency and whitespace but does not normalize values unless the transformation is explicitly changed.
- **Load lines versus loads:** `clean.fact_load_lines` contains multiple SKU rows per load. Use `clean.fact_loads` for analyses that require one row per truck load.
- **Pallet fill ratio assumption:** `truck_fill_ratio` uses an assumed capacity of 26 pallets for a standard 53-foot trailer. Treat it as a model assumption, not a measured truck-capacity value. The project's transportation analysis uses weight-based utilisation instead.
- **Inventory coverage:** the source inventory snapshots cover six distribution centres even though `dim_dcs` lists 50 centres.
- **Zero weekly outflow:** `days_of_cover` is `NULL` when weekly outflow is zero because the ratio cannot be calculated.
- **Fuel YoY field:** the source may have no year-over-year comparison for its earliest dates.

---

## 7. Troubleshooting

| Problem | What to check |
|---|---|
| Invalid object name | Confirm that all nine raw tables were imported into `NorthStar_Distribution` under `dbo` with the exact names listed in Section 1. |
| Script runs against the wrong database | Check that `USE NorthStar_Distribution;` is at the top and that the database exists. |
| A raw row count differs | Recheck the source file and import destination; make sure the CSV was not imported twice or truncated. |
| A post-clean `NULL` count is above zero | Check the source values and data types for failed `TRY_CAST` conversions or missing required values. |
| The script fails on a missing column | Confirm that the imported table uses the expected column names; avoid renaming source columns unless you also update the script. |
| A clean table is missing | Review the **Messages** pane for the first error and rerun after correcting it. The script executes in order, so an earlier error may prevent later outputs from being created. |

---


