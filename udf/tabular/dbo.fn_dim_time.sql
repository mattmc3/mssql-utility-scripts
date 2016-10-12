use master
go
if objectproperty(object_id('dbo.fn_dim_date'), 'IsTableFunction') is null begin
	exec('create function dbo.fn_dim_date() returns table as return ( select 1 a )')
end
go
--------------------------------------------------------------------------------
-- Author: mattmc3
-- Description: Generates data for a time dimension.
--------------------------------------------------------------------------------
alter function dbo.fn_dim_date(@start_date date, @end_date date) returns table as
return (
	with cte as (
		select 0 as seq1
		union all
		select seq1 + 1
		from cte
		where seq1 + 1 < 100
	),
	cte2 as (
		select 0 as seq2
		union all
		select seq2 + 1
		from cte2
		where seq2 + 1 < 100
	),
	cte3 as (
		select 0 as seq3
		union all
		select seq3 + 1
		from cte3
		where seq3 + 1 <= 4
	)
	select
		cast(convert(varchar(8), a.dt, 112) as int) as dim_date_id
		,cast(a.dt as date)      as date_val
		,cast(a.dt as datetime)  as datetime_val
		,cast(a.dt as datetime2) as datetime2_val
		,year(a.dt)              as calendar_year
		,month(a.dt)             as calendar_month
		,day(a.dt)               as calendar_day
		,datename(day, a.dt)
		+ case
			when datepart(day, a.dt) in (1, 21, 31) then 'st'
			when datepart(day, a.dt) in (2, 22)     then 'nd'
			when datepart(day, a.dt) in (3, 23)     then 'rd'
			else 'th'
		end as calendar_day_with_suffix
		,datepart(quarter, a.dt) as calendar_quarter
		,'Q' + datename(quarter, a.dt)    as calendar_quarter_name
		,datename(month, a.dt)            as month_name
		,left(datename(month, a.dt), 3)   as month_name_short
		,datename(weekday, a.dt)          as weekday_name
		,left(datename(weekday, a.dt), 3) as weekday_name_short
		,case
			when datepart(weekday, a.dt) = 5 then 'R'
			when datepart(weekday, a.dt) = 1 then 'U'
			else left(datename(weekday, a.dt), 1)
		end as weekday_name_1char
		,datepart(weekday, a.dt)   as day_of_week
		,datepart(dayofyear, a.dt) as day_of_year
		,datepart(week, a.dt) + 1 - datepart(week, cast(datepart(month,a.dt) as varchar(2)) + '/1/' + datename(year, a.dt)) as week_of_month
		,datepart(week, a.dt) as week_of_year
		,cast(convert(varchar(8), dateadd(month, datediff(month, 0, a.dt), 0), 112) as int) as start_of_month_id
		,cast(convert(varchar(8), dateadd(month, 1 + datediff(month, 0, a.dt), -1), 112) as int) as end_of_month_id
		,isdate('2/29/' + cast(year(a.dt) as varchar(5))) as is_leap_year
		,case when datepart(weekday, a.dt) in (1, 7) then 1 else 0 end as is_weekend
		,case when datepart(weekday, a.dt) not in (1, 7) then 1 else 0 end as is_weekday
		,case
			when month(a.dt) = 1 and day(a.dt) = 1 then 1 -- New Year's Day, Jan 1
			when month(a.dt) = 5 and datepart(weekday, a.dt) = 2 and month(dateadd(day, 7, a.dt)) <> 5 then 1 -- Memorial Day, last Monday in May
			when month(a.dt) = 7 and day(a.dt) = 4 then 1 -- Independance Day, July 4
			when month(a.dt) = 9 and datepart(weekday, a.dt) = 2 and month(dateadd(day, -7, a.dt)) <> 9 then 1 -- Labor Day, 1st Monday in Sept
			when month(a.dt) = 11 and datepart(weekday, a.dt) = 5 and month(dateadd(day, 7, a.dt)) <> 11 then 1 -- Thanksgiving Day, 4th Thursday in Nov
			when month(a.dt) = 12 and day(a.dt) = 25 then 1 -- Christmas Day, Dec 25
			else 0
		end as is_us_holiday
		,datename(weekday, a.dt) + ', ' + datename(month, a.dt) + ' ' + datename(day, a.dt)
		+ case
			when datepart(day, a.dt) in (1, 21, 31) then 'st'
			when datepart(day, a.dt) in (2, 22)     then 'nd'
			when datepart(day, a.dt) in (3, 23)     then 'rd'
			else 'th'
		end
		+ ', ' + datename(year, a.dt) as calendar_date_name_long
	from (
		select top 100000
			seq1 + (100 * seq2) + (10000 * seq3) as master_seq,
			dateadd(day, seq1 + (100 * seq2) + (10000 * seq3), @start_date) as dt
		from cte, cte2, cte3
		where (seq1 + (100 * seq2) + (10000 * seq3)) <= datediff(day, @start_date, @end_date)
		order by 1
	) a
)
go
