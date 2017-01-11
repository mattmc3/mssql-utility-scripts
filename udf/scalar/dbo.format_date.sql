use master
go
if objectproperty(object_id('dbo.format_date'), 'IsScalarFunction') is null begin
    exec('create function dbo.format_date() returns int as begin return null end')
end
go
--------------------------------------------------------------------------------
-- Author: mattmc3
-- Description: dbo.format_date takes a date and a format string and returns
--              the date formatted to that spec. Format is the same as .NET
--              formatting rules.
-- Rules:       https://msdn.microsoft.com/en-us/library/8kb3ddd4(v=vs.110).aspx
--------------------------------------------------------------------------------
alter function dbo.format_date(@d datetime2, @format_string varchar(1000)) returns varchar(100) as
begin
    declare @i int
    declare @c char(1)
    declare @code varchar(10)
    declare @result varchar(2000)

    set @result = ''
    set @i = 1

    if @format_string is null or @d is null begin
        return null
    end

    while @i <= len(@format_string) begin
        set @c = substring(@format_string, @i, 1)
        -- escape with backslash
        if @c = char(92) begin
            set @result = @result + substring(@format_string, @i + 1, 1)
            set @i = @i + 1
        end
        else if @c collate Latin1_General_CS_AS in ('d', 'f', 'F', 'h', 'H', 'm', 'M', 's', 't', 'y') begin
            -- keep popping to see how long the code is
            set @code = @c
            while substring(@format_string, @i + 1, 1) collate Latin1_General_CS_AS = @c begin
                set @code = @code + @c
                set @i = @i + 1
            end

            select @result = @result
                + case
                    -- day
                    when @code = 'd'    then datename(day, @d)
                    when @code = 'dd'   then right('0' + datename(day, @d), 2)
                    when @code = 'ddd'  then left(datename(weekday, @d), 3)
                    when @code = 'dddd' then datename(weekday, @d)

                    -- parts of a second
                    when left(@code, 1) collate Latin1_General_CS_AS = 'f' then
                        left(right('00000000' + datename(nanosecond, @d), 9), len(@code))

                    -- parts of a second
                    when left(@code, 1) collate Latin1_General_CS_AS = 'F' then
                        case
                            when cast(left(right('-00000000' + datename(nanosecond, @d), 9), len(@code)) as int) = 0
                            then ''
                            else left(right('-00000000' + datename(nanosecond, @d), 9), len(@code))
                        end

                    -- 12 hour
                    when @code = 'h'  collate Latin1_General_CS_AS then
                        cast(case
                            when datepart(hour, @d) = 0 then 12
                            when datepart(hour, @d) > 12 then datepart(hour, @d) - 12
                            else datepart(hour, @d)
                        end as varchar(2))
                    when @code = 'hh' collate Latin1_General_CS_AS then
                        right('0' + cast(case
                            when datepart(hour, @d) = 0 then 12
                            when datepart(hour, @d) > 12 then datepart(hour, @d) - 12
                            else datepart(hour, @d)
                        end as varchar(2)), 2)

                    -- 24 hour
                    when @code = 'H'  collate Latin1_General_CS_AS then datename(hour, @d)
                    when @code = 'HH' collate Latin1_General_CS_AS then right('0' + datename(hour, @d), 2)

                    -- minute
                    when @code = 'm'  collate Latin1_General_CS_AS then datename(minute, @d)
                    when @code = 'mm' collate Latin1_General_CS_AS then right('0' + datename(minute, @d), 2)

                    -- month
                    when @code = 'M'    collate Latin1_General_CS_AS then cast(datepart(month, @d) as varchar(2))
                    when @code = 'MM'   collate Latin1_General_CS_AS then right('0' + cast(datepart(month, @d) as varchar(2)), 2)
                    when @code = 'MMM'  collate Latin1_General_CS_AS then left(datename(month, @d), 3)
                    when @code = 'MMMM' collate Latin1_General_CS_AS then datename(month, @d)

                    -- second
                    when @code = 's'  collate Latin1_General_CS_AS then datename(second, @d)
                    when @code = 'ss' collate Latin1_General_CS_AS then right('0' + datename(second, @d), 2)

                    -- AM/PM
                    when @code = 't'  collate Latin1_General_CS_AS then case when datepart(hour, @d) < 13 then 'A' else 'P' end
                    when @code = 'tt' collate Latin1_General_CS_AS then case when datepart(hour, @d) < 13 then 'AM' else 'PM' end

                    -- year
                    when @code = 'y'     collate Latin1_General_CS_AS then right(datename(year, @d), 2)
                    when @code = 'yy'    collate Latin1_General_CS_AS then right('0' + right(datename(year, @d), 2), 2)
                    when @code = 'yyy'   collate Latin1_General_CS_AS then case when datepart(year, @d) < 999 then right('00' + datename(year, @d), 3) else datename(year, @d) end
                    when @code = 'yyyy'  collate Latin1_General_CS_AS then case when datepart(year, @d) < 9999 then right('000' + datename(year, @d), 4) else datename(year, @d) end
                    when @code = 'yyyyy' collate Latin1_General_CS_AS then case when datepart(year, @d) < 99999 then right('0000' + datename(year, @d), 5) else datename(year, @d) end

                    else @code
                end
        end
        else begin
            set @result = @result + @c
        end
        set @i = @i + 1
    end

    return @result
end
go
grant execute on dbo.format_date to public
go
select
    unittest.assert_equals(dbo.format_date(a.input1, a.format_str), a.result) as msg
from (
    select cast('2006-01-02 15:04:05.123' as datetime) as input1, 'yyyy-MM-dd HH:mm:ss.fff' as format_str, '2006-01-02 15:04:05.123' as result
    union all select cast('10/9/2016' as datetime), null, null
    union all select cast('9/15/2016' as datetime), 'dddd, MMMM d, yyyy', 'Thursday, September 15, 2016'
    union all select cast('1/2/2003 13:14:15.099' as datetime2), 'MM-d-yy hh.mm.ss.ff tt', '01-2-03 01.14.15.09 PM'
    union all select cast('12/31/2016' as datetime), 'ddd MMM dd', 'Sat Dec 31'
    union all select cast('12/31/2016' as datetime), 'HH hh H h', '00 12 0 12'
    union all select cast('12/31/2016' as datetime), 'MM mm M m', '12 00 12 0'
) a
where unittest.assert_equals(dbo.format_date(a.input1, a.format_str), a.result) is not null
