/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/
-------------------------------------
--       DIMENSION_CUSTOMERS   --
if object_id('gold.dim_customers','v') is not null
	drop view gold.dim_customers;
go

create view gold.dim_customers as
select 
row_number() over(order by ci.cst_id) as customer_key,
ci.cst_id as customer_id,
ci.cst_key as customer_number,
ci.cst_firstname as firstname,
ci.cst_lastname as lastname,
lo.country as country,
ci.cst_marital_status as marital_status,
case when cst_gndr !='n/a' then cst_gndr
else coalesce(cp.gen,'n/a')
end gender,
cp.bdate birth_date,
ci.cst_create_date
from silver.crm_cust_info ci
left join silver.erp_cust_az12 cp
on ci.cst_key = cp.cid
left join silver.erp_loc_a101 lo
on ci.cst_key = lo.cid;
go
-------------------------------------
--       DIMENSION_PRODUCTS   --
if object_id('gold.dim_products','v') is not null
	drop view gold.dim_products
go

create view gold.dim_products as
select 
row_number() over(order by p.prd_start_dt,prd_key) as product_key,
p.prd_id as product_id,
p.prd_key as product_number,
p.prd_nm as product_name,
p.cat_id as category_id,
e.cat as category,
e.subcat as subcategory,
e.maintenance as maintenance,
p.prd_cost as cost,
p.prd_line as product_line,
p.prd_start_dt as start_date
from silver.crm_prd_info p
left join silver.erp_px_cat_g1v2 e
on p.cat_id= e.id
where p.prd_end_dt is  null ;--Filtering out the historical data
go
-------------------------------------
--       FACT_SALES_DETAILS   --
if object_id('gold.fact_sales','v') is not null
	drop view gold.fact_sales
go

create view gold.fact_sales as
select 
sd.sls_ord_num as order_number,
pr.product_key,
c.customer_key,
sd.sls_order_dt as order_date,
sd.sls_ship_dt as ship_date,
sd.sls_due_dt as due_date,
sd.sls_sales as sales_amount,
sd.sls_quantity as quantity,
sd.sls_price as price
from silver.crm_sales_details sd
left join gold.dim_products pr
on sd.sls_prd_key = pr.product_number
left join gold.dim_customers c 
on sd.sls_cust_id = c.customer_id
go