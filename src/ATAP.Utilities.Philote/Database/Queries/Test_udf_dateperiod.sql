USE [Coral8_ETL]
GO

-- ===============================================
-- Test UDF that ....
-- Version vvv (date)
-- ===============================================

Declare 
	@startdate datetime	
	,@enddate datetime
	,@tzoffset int
	,@periodunits char(1)
	,@numunitsinperiod int

-- Use hours
set @periodunits = 's'
--  24 units (hour) in a period is a full day's count. 1 unit (hour) in a period provides hourly counts
set @numunitsinperiod = 1
--Set the start date to "yesterday, midnight
--set @startdate = Dateadd(d,-1,convert(datetime,floor(convert(float,GETDATE()))))
set @startdate = '2008-01-01 1:00:00'
-- The Enddate is always "yesterday, 3 milliseconds before midnight today..."
--set @enddate = Dateadd(ms,-3,convert(datetime,floor(convert(float,GETDATE()))))
set @enddate = '2008-01-01 22:00:00'
-- Calculate the @tzoffset using the SQL Server's computer's system time
set @tzoffset =  -5
SELECT *
FROM
DBO.udf_dateperiod (
	@periodunits
	,@numunitsinperiod
	,@startdate
	,@enddate
	,@tzoffset
)
ORDER BY EarlierDTS ASC

---- Calculate the @tzoffset using the SQL Server's computer's system time
--set @tzoffset =  DATEDIFF(hh,GETUTCDATE(),GETDATE())
--SELECT *
--FROM
--DBO.udf_dateperiod (
--	@periodunits
--	,@numunitsinperiod
--	,@startdate
--	,@enddate
--	,@tzoffset
--)
--ORDER BY EarlierDTS ASC
