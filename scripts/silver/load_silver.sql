/*
=================================================
Stored Procedure: Load Silver Layer(Bronze -> Silver)
=================================================
Script purpose :
	This Stored Procedure loads data into 'Silver' schema frm Bronze table
	It performs:
		- First truncates the bronze tables before loading
		-Uses the 'SELECT INSERT' command to load data from bronze table to silver tables.
Parameters:
	None.
	This stored procedure does not accept any parameters nor return value.
*/
USE [Datawarehouse]
GO
/****** Object:  StoredProcedure [silver].[load_silver]    Script Date: 22-07-2026 16:44:41 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   procedure [silver].[load_silver] as 
begin
	DECLARE @start_time DATETIME,@end_time DATETIME,@batch_start_time DATETIME,@batch_end_time DATETIME;
	begin try
		set @batch_start_time = getdate();
		PRINT '==================================';
		PRINT '   LOADING SILVER LAYER  ';
		PRINT '=================================';
		PRINT '--------------------------------'
		PRINT 'LOADING CRM TABLE';
		PRINT '--------------------------------'
		set @start_time = GETDATE();
		print('>>Truncating table silver.crm_cust_info')
		truncate table silver.crm_cust_info;
		print('>>Inserting data silver.crm_cust_info')
		insert into silver.crm_cust_info(
			cst_id,
			cst_key,
			cst_firstname,
			cst_lastname,
			cst_marital_status,
			cst_gndr,
			cst_create_date
		)
		select
		cst_id,
		cst_key,
		trim(cst_firstname) as cst_first_name,
		trim(cst_lastname) as cst_last_name,
		case 
			when upper(cst_marital_status) = 'M' then 'Married'
			when upper(cst_marital_status) = 'S' then 'Single'
			else 'n/a'
			end cst_marital_status,--Normalizing the column into readable form
		case 
			when upper(cst_gndr)='F' then 'Female'
			when upper(cst_gndr)='M' then 'Male'
			else 'n/a'
			end cst_gndr,--Nprmalizing the column into readable form
		cst_create_date
		from (
		select *,
		row_number() over(partition by cst_id order by cst_create_date desc) as flag_last
		from [bronze].[crm_cust_info]
		where cst_id is not null
		)t
		where flag_last=1 -- select the most recent record per customer
		SET @end_time = GETDATE();
		PRINT '>>Load Duration:'+cast(datediff(second,@start_time,@end_time) as nvarchar)+ 'seconds';


		set @start_time = GETDATE();
		print('>>Truncating table silver.crm_prd_info')
		truncate table silver.crm_prd_info;
		print('>>Inserting table silver.crm_prd_info')
		insert into silver.crm_prd_info(
			prd_id,
			cat_id,
			prd_key,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt,
			dwh_create_date
	
		)
		select
		prd_id,
		replace(substring(prd_key,1,5),'-','_') as cat_id,--extract category_id
		substring(prd_key,7,len(prd_key)) as prd_key,--extract prd_key
		prd_nm,
		isnull(prd_cost,0) as prd_cost,
		case upper(prd_line)
			when 'M' then 'Mountain'
			when 'R' then 'Road'
			when 'S' then 'Other Sales'
			when 'T' then 'Touring'
			else 'n/a'--Normalizing the abbreviation
			end prd_line,
		cast(prd_start_dt as date),
		cast(lead(prd_start_dt) over(partition by prd_key order by prd_start_dt)-1 as date)as prd_end_dt,--using lead to get date
		GETDATE() AS dwh_create_date--inserting creation_date
		from bronze.crm_prd_info
		SET @end_time = GETDATE();
		PRINT '>>Load Duration:'+cast(datediff(second,@start_time,@end_time) as nvarchar)+ 'seconds';


		set @start_time = GETDATE();
		print('>>Truncate table silver.crm_sales_details')
		truncate table silver.crm_sales_details;
		print('>>Inserting data into silver.crm_sales_details')
		insert into silver.crm_sales_details(
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_quantity,
			sls_price
		)
		select 
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		case when sls_order_dt=0 or len(sls_order_dt)!=8 then null
			 else cast(cast(sls_order_dt as varchar) as date)
			 end sls_order_dt,---format int into date
		case when sls_ship_dt=0 or len(sls_ship_dt)!=8 then null
			 else cast(cast(sls_ship_dt as varchar) as date)
			 end sls_ship_dt,
		case when sls_due_dt=0 or len(sls_due_dt)!=8 then null
			 else cast(cast(sls_due_dt as varchar) as date)
			 end sls_due_dt,
		case when sls_sales is null or sls_sales<=0 or sls_sales!=sls_quantity*abs(sls_price) then
			 sls_quantity*abs(sls_price)
			 else sls_sales
			 end as sls_sales,--recalculating sales 
		sls_quantity,
		case when sls_price is null or sls_price<=0 then 
			 sls_sales/nullif(sls_quantity,0)
			 else sls_price 
			 end sls_price--deriving accurate price
		from bronze.crm_sales_details
		SET @end_time = GETDATE();
		PRINT '>>Load Duration:'+cast(datediff(second,@start_time,@end_time) as nvarchar)+ 'seconds';


		PRINT '==============================';
		PRINT 'LOADING ERP TABLES';
		PRINT '=============================='
		SET @start_time = GETDATE();
		print('>>Truncating table silver.erp_cust_az12')
		truncate table silver.erp_cust_az12;
		print('>>Inserting data into silver.erp_cust_az12')
		insert into silver.erp_cust_az12(cid,bdate,gen)
		select 
		case when cid like 'NAS%' then SUBSTRING(cid,4,len(cid))
			else cid
		end cid,--Extracting the cid to join with silver.crm_cust_info
		case when bdate>getdate() then null
			else bdate
		end  as bdate,--Removing invalid dates
		case when upper(trim(gen)) in ('M','MALE') then 'Male'
			 when upper(trim(gen)) in ('F','FEMALE') then 'Female'
			 else 'n/a'--Normalizing the gen values
		end gen
		from bronze.erp_cust_az12
		SET @end_time = GETDATE()
		PRINT '>>Load Duration:'+cast(datediff(second,@start_time,@end_time) as nvarchar)+ 'seconds';


		SET @start_time = GETDATE()
		print('>>Truncating table silver.erp_loc_a101')
		truncate table silver.erp_loc_a101;
		print('>>Inserting data into silver.erp_loc_a101')
		insert into silver.erp_loc_a101(cid,country)
		select
		REPLACE(cid,'-','') as cid,
		case when trim(country) ='' or country is null then 'n/a'
			 when trim(country)='DE' then 'Germany'
			 when trim(country) in ('US','USA') then 'United States'
			 else trim(country)
		end country
		from bronze.erp_loc_a101
		SET @end_time = GETDATE()
		PRINT '>>Load Duration:'+cast(datediff(second,@start_time,@end_time) as nvarchar)+ 'seconds';


		SET @start_time = GETDATE()
		print('>>Truncating table silver.erp_px_cat_g1v2')
		truncate table silver.erp_px_cat_g1v2;
		print('>>Inserting data into silver.erp_px_cat_g1v2')
		insert into silver.erp_px_cat_g1v2(id,cat,subcat,maintenance)
		select 
		id,
		cat,
		subcat,
		maintenance
		from bronze.erp_px_cat_g1v2
		SET @end_time = GETDATE()
		PRINT '>>Load Duration:'+cast(datediff(second,@start_time,@end_time) as nvarchar)+ 'seconds';
		PRINT '------------------'
		SET @batch_end_time = getdate();
		PRINT '>> Total Load Duration:'+cast(datediff(second,@batch_start_time,@batch_end_time) as nvarchar)+ 'seconds';
	end try
	begin catch
	PRINT '==================================';
	PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER'
	PRINT 'Error Message'+ ERROR_MESSAGE();
	PRINT 'Error Message'+CAST(ERROR_NUMBER() AS NVARCHAR);
	PRINT 'Error Message'+CAST(ERROR_STATE() AS NVARCHAR);
	PRINT '==================================='
	end catch
end

EXEC SILVER.LOAD_SILVER