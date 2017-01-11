use master
go
if objectproperty(object_id('dbo.calc_age'), 'IsScalarFunction') is null begin
    exec('create function dbo.calc_age() returns int as begin return null end')
end
go
--------------------------------------------------------------------------------
-- Author: mattmc3
-- Description: Calculates an age based on start and end dates
--------------------------------------------------------------------------------
alter function dbo.calc_age(@start_date datetime, @end_date datetime) returns int as
begin
    declare @result int
    select
        @result =
            case
                when @start_date > @end_date then 0
                else
                    datediff(year, @start_date, @end_date) -
                    case
                        when dateadd(year, datediff(year, @start_date, @end_date), @start_date) > @end_date then 1
                        else 0
                    end
            end
    return @result
end
go
