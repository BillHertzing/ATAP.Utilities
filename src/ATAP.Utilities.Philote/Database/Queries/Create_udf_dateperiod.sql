USE [Coral8_ETL]
GO
/****** Object:  UserDefinedFunction [dbo].[udf_dateperiod]    Script Date: 09/18/2007 11:00:30 ******/
--================================================
-- Drop function if it exists
--================================================
IF OBJECT_ID (N'dbo.udf_dateperiod') IS NOT NULL
   DROP FUNCTION [dbo].[udf_dateperiod]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--================================================
--  Create Inline Table-valued Function template
--================================================
CREATE FUNCTION [dbo].[udf_dateperiod](
	@period_units char
	,@period_duration int
	,@dtstart datetime
	,@dtend datetime
	,@TZOffset int
)
RETURNS @tx TABLE
(
        earlierdts datetime
        ,laterdts datetime
)
AS
begin
   with rangeperiods (pnum) as (select 0 Union All select pnum + 1 from rangeperiods where pnum <
case when @period_units = 'm' then ((datediff(mi,convert(datetime,floor(convert(float,@dtstart))),convert(datetime,ceiling(convert(float, @dtend))))/@period_duration)-1)
	 when @period_units = 'h' then ((datediff(hh,convert(datetime,floor(convert(float,@dtstart))),convert(datetime,ceiling(convert(float, @dtend))))/@period_duration)-1)
	when @period_units = 's' then ((datediff(ss,@dtstart,@dtend)/@period_duration)-1) -- new
end
)

Insert into @tx SELECT
case when @period_units = 'm' then
		DATEADD(minute, (pnum*@period_duration)-(@TZOffset*60),convert(datetime,floor(convert(float, @dtstart))))
	when @period_units = 'h' then
		DATEADD(hour, (pnum*@period_duration)-(@TZOffset*1),convert(datetime,floor(convert(float, @dtstart))))
when @period_units = 's' then --new
DATEADD(second, (pnum*@period_duration)-(@TZOffset*3600),@dtstart) -- new

	end
	earlierDTS ,
		DATEADD(ms,-2,
		case when @period_units = 'm' then
			DATEADD(minute, ((pnum+1)*@period_duration)-(@TZOffset*60),convert(datetime,floor(convert(float, @dtstart))))
		when @period_units = 'h' then
			DATEADD(hour, ((pnum+1)*@period_duration)-(@TZOffset*1),convert(datetime,floor(convert(float, @dtstart))))
when @period_units = 's' then --new
DATEADD(second, ((pnum+1)*@period_duration)-(@TZOffset*3600),@dtstart) --new
		end
		)
	laterDTS
from (select pnum from rangeperiods) rp
option (maxrecursion 32767)
return
end
