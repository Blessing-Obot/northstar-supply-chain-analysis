### Data Dictionary (Raw Source Files)

The dataset has 12 files: 4 dimension files that describe things (products, centres, customers), and 8 files that record events (sales, stock, orders, loads, fuel). Names below are the original column names.

| File                        | What it holds                                               | Rows    |
| --------------------------- | ----------------------------------------------------------- | ------- |
| `fact_sku_demand_daily`     | Daily sales of each product to each retailer                | 190,757 |
| `fact_dc_inventory_weekly`  | Weekly stock levels at each distribution centre             | 41,580  |
| `fact_replenishment_orders` | Orders placed with manufacturers to restock centres         | 25,729  |
| `fact_sku_to_load_link`     | Which products were on which truck load                     | 88,158  |
| `fact_fuel_macro_daily`     | Daily fuel prices and fuel purchases                        | 1,098   |
| `fact_customer_experience`  | Customer orders with payment, satisfaction and support data | 500     |
| `dim_skus`                  | List of products                                            | 90      |
| `dim_dcs`                   | List of distribution centres and facilities                 | 50      |
| `dim_retailers`             | List of retailers                                           | 100     |
| `dim_manufacturers`         | List of manufacturers                                       | 14      |
| `dim_customer_roles`        | List of all customers and the role each plays               | 200     |
| `dim_region_mapping`        | How company regions map to US regions                       | 3       |


#### `fact_sku_demand_daily`: daily sales

| Column             | Definition                                                                                               |
| ------------------ | -------------------------------------------------------------------------------------------------------- |
| date               | The day of the sale                                                                                      |
| sku                | Product code                                                                                             |
| pack_type          | How the product is packed (Carton, Multipack, Single). A SKU and pack type together identify one product |
| retailer_id        | The retailer that bought the product                                                                     |
| us_region           | The US region the retailer is in                                                                         |
| channel            | How the retailer sells: Retail, Discount or E-commerce                                                   |
| units_sold         | Number of units sold                                                                                     |
| delivered_qty      | Number of units delivered                                                                                |
| pallets_shipped    | Number of pallets shipped                                                                                |
| weight_lbs_shipped | Weight shipped, in pounds                                                                                |
| stock_available    | Units in stock when the order was filled                                                                 |
| avg_price          | Selling price per unit                                                                                   |
| revenue            | Money earned from the sale (units sold × price)                                                          |
| promotion_flag     | 1 if the product was on promotion, 0 if not                                                              |
| avg_delivery_days  | Average number of days the delivery took                                                                 |

#### `fact_dc_inventory_weekly`: weekly stock

| Column                 | Definition                                                                                   |
| ---------------------- | -------------------------------------------------------------------------------------------- |
| date                   | The week of the stock count                                                                  |
| dc_id                  | The distribution centre holding the stock                                                    |
| sku                    | Product code                                                                                 |
| pack_type              | Pack format of the product                                                                   |
| pallets_on_hand        | Pallets currently in stock                                                                   |
| reorder_point_s        | Stock level that triggers a new order. When stock falls below this, the product is reordered |
| order_up_to_S          | Stock level to restock up to when an order is placed                                         |
| in_transit_pallets     | Pallets ordered but not yet arrived                                                          |
| weekly_outflow_pallets | Pallets that left the centre that week                                                       |
| stockout_pallets       | Pallets of demand that could not be met because stock ran out                                |

#### `fact_replenishment_orders`: orders to manufacturers

| Column          | Definition                                      |
| --------------- | ----------------------------------------------- |
| order_date      | Day the order was placed                        |
| arrival_date    | Day the order arrived                           |
| dc_id           | The distribution centre that received the order |
| sku             | Product code                                    |
| pack_type       | Pack format of the product                      |
| manufacturer_id | The manufacturer that supplied the order        |
| pallets_ordered | Size of the order, in pallets                   |
| lead_time_days  | Days between placing the order and receiving it |

#### `fact_sku_to_load_link`: products on truck loads

| Column        | Definition                                                       |
| ------------- | ---------------------------------------------------------------- |
| trip_id       | Code for the truck trip                                          |
| load_id       | Code for the truck load. One load can have several product lines |
| dispatch_date | Day the load left                                                |
| sku           | Product code                                                     |
| pack_type     | Pack format of the product                                       |
| category      | Product category (Yogurt, Milk, ReadyMeal, SnackBar, Juice)      |
| brand         | Brand of the product                                             |
| pallets       | Pallets of this product on the load                              |
| units         | Units of this product on the load                                |
| weight_lbs    | Weight of this product on the load, in pounds                    |
| dest_region   | The region the load was delivered to                             |

#### `fact_fuel_macro_daily`: daily fuel data

| Column                        | Definition                                                                                    |
| ----------------------------- | --------------------------------------------------------------------------------------------- |
| date                          | The day                                                                                       |
| national_avg_price_per_gallon | Average US fuel price per gallon that day                                                     |
| total_gallons_purchased       | Gallons of fuel bought that day                                                               |
| n_transactions                | Number of fuel purchases that day                                                             |
| fuel_price_usd_per_barrel     | Crude oil price per barrel, in US dollars                                                     |
| fuel_price_rolling_7d         | Fuel price averaged over the last 7 days, which smooths out daily ups and downs               |
| fuel_price_dod_pct_change     | Percentage change in fuel price from the day before                                           |
| fuel_price_yoy_pct_change     | Percentage change in fuel price from the same day last year. Empty for the first year of data |
| day_of_week                   | Name of the weekday                                                                           |
| week_of_year                  | Week number in the year                                                                       |
| month                         | Month number                                                                                  |
| is_month_end                  | 1 if the day is the last day of the month                                                     |
| is_quarter_end                | 1 if the day is the last day of a quarter                                                     |
| is_us_holiday                 | 1 if the day is a US public holiday                                                           |

#### `fact_customer_experience`: customer orders and feedback

| Column                 | Definition                                                                                        |
| ---------------------- | ------------------------------------------------------------------------------------------------- |
| order_id               | Code for the order                                                                                |
| retailer_id            | The retailer that placed the order                                                                |
| order_date             | Day the order was placed                                                                          |
| order_value_usd        | Value of the order, in US dollars                                                                 |
| payment_date           | Day the retailer paid                                                                             |
| satisfaction_score_1_5 | How satisfied the customer was, from 1 (lowest) to 5 (highest)                                    |
| support_tickets        | Number of support requests raised for the order                                                   |
| lead_time_days_actual  | Days the order actually took to fulfil                                                            |
| market_segment         | Part of the world the order belongs to (North America, Europe, Asia-Pacific, Middle East, Africa) |

#### `dim_skus`: products

| Column                 | Definition                                                  |
| ---------------------- | ----------------------------------------------------------- |
| sku                    | Product code                                                |
| brand                  | Brand name                                                  |
| segment                | Group within a category the product belongs to              |
| category               | Product category (Yogurt, Milk, ReadyMeal, SnackBar, Juice) |
| pack_type              | How the product is packed (Carton, Multipack, Single)       |
| avg_price              | Typical selling price per unit                              |
| avg_delivery_days      | Typical delivery time for the product, in days              |
| units_per_pack         | Units in one pack                                           |
| packs_per_pallet       | Packs that fit on one pallet                                |
| units_per_pallet       | Units that fit on one pallet                                |
| weight_lbs_per_pallet  | Weight of one full pallet, in pounds                        |
| requires_refrigeration | 1 if the product must be kept cold, 0 if not                |
| shelf_life_days        | Days the product stays fresh                                |

#### `dim_dcs`: distribution centres and facilities

| Column                   | Definition                                                               |
| ------------------------ | ------------------------------------------------------------------------ |
| facility_id              | Code for the facility                                                    |
| facility_name            | Name of the facility                                                     |
| facility_type            | Kind of facility: Distribution Center, Warehouse, Cross-Dock or Terminal |
| city                     | City where it is located                                                 |
| state                    | State where it is located                                                |
| us_region                | US region it belongs to                                                  |
| dc_role                  | Whether it is a Primary DC or a Secondary DC                             |
| has_refrigeration        | 1 if it has cold storage, 0 if not                                       |
| dock_doors               | Number of doors where trucks load and unload                             |
| storage_capacity_pallets | How many pallets it can hold                                             |
| latitude                 | North-south map position                                                 |
| longitude                | East-west map position                                                   |
| operating_hours          | Hours it is open (for example 24/7 or 7AM-7PM)                           |

#### `dim_retailers`: retailers

| Column                   | Definition                                                |
| ------------------------ | --------------------------------------------------------- |
| retailer_id              | Code for the retailer                                     |
| customer_id              | Matching code in the customer list (`dim_customer_roles`) |
| customer_name            | Name of the retailer                                      |
| us_region                | US region the retailer is in                                                                         |
| channel                  | How the retailer sells: Retail, Discount or E-commerce    |
| n_stores                 | Number of stores the retailer has                         |
| contract_start_date      | Day the retailer became a customer                        |
| annual_revenue_potential | Estimated yearly sales value of the retailer              |
| account_status           | Active or Inactive                                        |

#### `dim_manufacturers`: manufacturers

| Column            | Definition                                      |
| --------------- | ----------------------------------------------- |
| manufacturer_id   | Code for the manufacturer                       |
| manufacturer_name | Name of the manufacturer                       |
| brand             | Brand the manufacturer makes                    |
| categories        | Product category the manufacturer supplies      |
| country           | Country where the manufacturer is based         |
| hq_city           | City of the manufacturer's head office          |
| hq_state          | State of the manufacturer's head office         |
| contract_type     | Kind of supply agreement: Contract or Dedicated |

#### `dim_customer_roles`: all customers and their roles

| Column                   | Definition                                                                             |
| ------------------------ | -------------------------------------------------------------------------------------- |
| customer_id              | Code for the customer                                                                  |
| customer_name            | Name of the customer                                                                   |
| customer_type            | How they buy: Contract (agreed terms), Dedicated (reserved capacity) or Spot (one-off) |
| credit_terms_days        | Days the customer has to pay after an order                                            |
| primary_freight_type     | Main kind of goods they ship (for example Retail or Food/Beverage)                     |
| account_status           | Active or Inactive                                                                     |
| contract_start_date      | Day the contract began                                                                 |
| annual_revenue_potential | Estimated yearly sales value of the customer                                           |
| role                     | What the customer is in this dataset: Retailer, Manufacturer or Other                  |
| linked_manufacturer_id   | The manufacturer code, filled in only when the role is Manufacturer                    |
| us_region                | US region, filled in only for retailers                                                |
| channel                  | Sales channel, filled in only for retailers                                            |

#### `dim_region_mapping`: region lookup

| Column       | Definition                                             |
| ------------ | ------------------------------------------------------ |
| fmcg_region  | The company's own region code (for example PL-Central) |
| us_region    | The matching US region (Midwest, Northeast or South)   |
| us_states    | The states that make up the region                     |
| anchor_city  | The main city used to represent the region             |
| anchor_state | The state of that main city                            |











