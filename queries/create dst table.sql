-- make a table (#dst) of years 1970-2101. Note that DST could change in the future and
-- everything was all custom and jacked before 1970 in the US.
declare @first_year varchar(4) = '1970'
declare @last_year varchar(4) = '2101'

-- make a table of all the years desired
if object_id('tempdb..#years') is not null drop table #years
;with cte as (
    select cast(@first_year as int) as int_year
            ,@first_year as str_year
            ,cast(@first_year + '-01-01' as datetime) as start_of_year
    union all
    select int_year + 1
            ,cast(int_year + 1 as varchar(4))
            ,dateadd(year, 1, start_of_year)
    from cte
    where int_year + 1 <= @last_year
)
select *
into #years
from cte
option (maxrecursion 500);

-- make a staging table of all the important DST dates each year
if object_id('tempdb..#dst_stage') is not null drop table #dst_stage
select dst_date
        ,time_period
        ,int_year
        ,row_number() over (order by dst_date) as ordinal
into #dst_stage
from (
    -- start of year
    select y.start_of_year as dst_date
            ,'start of year' as time_period
            ,int_year
    from #years y
    
    union all
    select dateadd(year, 1, y.start_of_year)
            ,'start of year' as time_period
            ,int_year
    from #years y
    where y.str_year = @last_year

    -- start of dst
    union all
    select
        case
            when y.int_year >= 2007 then
                -- second sunday in march
                dateadd(day, ((7 - datepart(weekday, y.str_year + '-03-08')) + 1) % 7, y.str_year + '-03-08')
            when y.int_year between 1987 and 2006 then
                -- first sunday in april
                dateadd(day, ((7 - datepart(weekday, y.str_year + '-04-01')) + 1) % 7, y.str_year + '-04-01')
            when y.int_year = 1974 then
                -- special case
                cast('1974-01-06' as datetime)
            when y.int_year = 1975 then
                -- special case
                cast('1975-02-23' as datetime)
            else
                -- last sunday in april
                dateadd(day, ((7 - datepart(weekday, y.str_year + '-04-24')) + 1) % 7, y.str_year + '-04-24')
        end
        ,'start of dst' as time_period
        ,int_year
    from #years y

    -- end of dst
    union all
    select
        case
            when y.int_year >= 2007 then
                -- first sunday in november
                dateadd(day, ((7 - datepart(weekday, y.str_year + '-11-01')) + 1) % 7, y.str_year + '-11-01')
            else
                -- last sunday in october
                dateadd(day, ((7 - datepart(weekday, y.str_year + '-10-25')) + 1) % 7, y.str_year + '-10-25')
        end
        ,'end of dst' as time_period
        ,int_year
    from #years y
) y
order by 1

-- assemble a final table
if object_id('tempdb..#dst') is not null drop table #dst
select a.dst_date +
            case
                when a.time_period = 'start of dst' then ' 03:00'
                when a.time_period = 'end of dst' then ' 02:00'
                else ' 00:00'
            end as start_date
        ,b.dst_date +
            case
                when b.time_period = 'start of dst' then ' 02:00'
                when b.time_period = 'end of dst' then ' 01:00'
                else ' 00:00'
            end as end_date
        ,cast(case when a.time_period = 'start of dst' then 1 else 0 end as bit) as is_dst
        ,cast(0 as bit) as is_ambiguous
        ,cast(0 as bit) as is_invalid
into #dst
from #dst_stage a
join #dst_stage b on a.ordinal + 1 = b.ordinal
union all
select a.dst_date + ' 02:00' as start_date
        ,a.dst_date + ' 03:00' as end_date
        ,cast(1 as bit) as is_dst
        ,cast(0 as bit) as is_ambiguous
        ,cast(1 as bit) as is_invalid
from #dst_stage a
where a.time_period = 'start of dst'
union all
select a.dst_date + ' 01:00' as start_date
        ,a.dst_date + ' 02:00' as end_date
        ,cast(0 as bit) as is_dst
        ,cast(1 as bit) as is_ambiguous
        ,cast(0 as bit) as is_invalid
from #dst_stage a
where a.time_period = 'end of dst'
order by 1

-------------------------------------------------------------------------------

-- Test Eastern
select
    the_date as eastern_local
    ,todatetimeoffset(the_date, case when b.is_dst = 1 then '-04:00' else '-05:00' end) as eastern_local_tz
    ,switchoffset(todatetimeoffset(the_date, case when b.is_dst = 1 then '-04:00' else '-05:00' end), '+00:00') as utc_tz
    --,b.*
from (
    select cast('2015-03-08' as datetime) as the_date
    union all select cast('2015-03-08 02:30' as datetime) as the_date
    union all select cast('2015-03-08 13:00' as datetime) as the_date
    union all select cast('2015-11-01 01:30' as datetime) as the_date
    union all select cast('2015-11-01 03:00' as datetime) as the_date
) a left join
#dst b on b.start_date <= a.the_date and a.the_date < b.end_date
