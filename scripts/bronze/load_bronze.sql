/*
=================================================
Stored Procedure: Load Bronze Layer(source -> Bronze)
=================================================
Script purpose :
	This Stored Procedure loads data into 'bronze' schema frm external .csv file
	It performs:
		- First truncates the bronze tables before loading
		-Uses the 'BULK INSERT' command to load data from csv files to bronze tables.
Parameters:
	None.
	This stored procedure does not accept any parameters nor return value.
*/
create or alter procedure bronze.load_bronze as 
begin
	DECLARE @start_time DATETIME,@end_time DATETIME,@batch_start_time DATETIME,@batch_end_time DATETIME;
	begin try
		set @batch_start_time = getdate();
		PRINT '==================================';
		PRINT '   LOADING BRONZE LAYER  ';
		PRINT '=================================';
		PRINT '--------------------------------'
		PRINT 'LOADING CRM TABLE';
		PRINT '--------------------------------'
		set @start_time = GETDATE();
		PRINT '>>truncating table bronze.crm_cust_info';
		truncate table bronze.crm_cust_info;
		print '>> inserting data into bronze.crm_cust_info';
		bulk insert bronze.crm_cust_info
		from 'C:\Temp\cust_info.csv'
		with (
			firstrow = 2,
			fieldterminator =',',
			tablock
		);
		SET @end_time = GETDATE();
		PRINT '>>Load Duration:'+cast(datediff(second,@start_time,@end_time) as nvarchar)+ 'seconds';

		set @start_time = GETDATE();
		PRINT '>>truncating table bronze.crm_prd_info';
		truncate table bronze.crm_prd_info; 
		PRINT '>>inserting data into bronze.crm_prd_info';
		bulk insert bronze.crm_prd_info
		from 'C:\Temp\prd_info.csv'
		with(
			firstrow = 2,
			fieldterminator = ',',
			tablock
		);
		Set @end_time = GETDATE();
		PRINT '>>Load Duration:'+cast(datediff(second,@start_time,@end_time) as nvarchar)+ 'seconds';

		set @start_time = GETDATE();
		PRINT '>>truncating table bronze.crm_sales_details';
		truncate table bronze.crm_sales_details;
		PRINT '>>inserting data into bronze.crm_sales_details'
		bulk insert bronze.crm_sales_details
		from 'C:\Temp\sales_details.csv'
		with (
			firstrow = 2,
			fieldterminator =',',
			tablock
		);
		Set @end_time = GETDATE();
		PRINT '>>Load Duration:'+cast(datediff(second,@start_time,@end_time) as nvarchar)+ 'seconds';

		PRINT '==============================';
		PRINT 'LOADING ERP TABLES';
		PRINT '=============================='
		set @start_time = GETDATE();
		PRINT '>>truncating table bronze.erp_cust_az12';
		truncate table bronze.erp_cust_az12; 
		PRINT '>>inserting data into bronze.erp_cust_az12'
		bulk insert bronze.erp_cust_az12
		from 'C:\Temp\CUST_AZ12.csv'
		with(
			firstrow =2,
			fieldterminator = ',',
			tablock
		);
		set @end_time = GETDATE();
		PRINT '>>Load Duration:'+cast(datediff(second,@start_time,@end_time) as nvarchar)+ 'seconds';

		set @start_time = getdate();
		PRINT '>>truncating table bronze.erp_loc_a101';
		truncate table bronze.erp_loc_a101;
		PRINT '>>inserting data into bronze.erp_loc_a101';
		bulk insert bronze.erp_loc_a101
		from 'C:\Temp\LOC_A101.csv'
		with (
			firstrow =2,
			fieldterminator = ',',
			tablock
		);
		set @end_time = getdate();
		PRINT '>>Load Duration:'+cast(datediff(second,@start_time,@end_time) as nvarchar)+ 'seconds';

		set @start_time = getdate();
		PRINT '>>truncating table bronze.erp_px_cat_g1v2';
		truncate table bronze.erp_px_cat_g1v2; 
		PRINT '>>inserting data into bronze.erp_px_cat_g1v2';
		bulk insert bronze.erp_px_cat_g1v2
		from 'C:\Temp\PX_CAT_G1V2.csv'
		with(
			firstrow = 2,
			fieldterminator = ',',
			tablock
		);
		set @end_time = getdate();
		PRINT '>>Load Duration:'+cast(datediff(second,@start_time,@end_time) as nvarchar)+ 'seconds';
		PRINT '------------------'
		SET @batch_end_time = getdate();
		PRINT '>> Total Load Duration:'+cast(datediff(second,@batch_start_time,@batch_end_time) as nvarchar)+ 'seconds';
	end try
	begin catch
	PRINT '==================================';
	PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER'
	PRINT 'Error Message'+ ERROR_MESSAGE();
	PRINT 'Error Message'+CAST(ERROR_NUMBER() AS NVARCHAR);
	PRINT 'Error Message'+CAST(ERROR_STATE() AS NVARCHAR);
	PRINT '==================================='
	end catch
end
exec bronze.load_bronze