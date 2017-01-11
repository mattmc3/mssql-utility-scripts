use master
go
if objectproperty(object_id('dbo.to_title_case'), 'IsScalarFunction') is null begin
    exec('create function dbo.to_title_case() returns int as begin return null end')
end
go
--------------------------------------------------------------------------------
-- Author: mattmc3
-- Description: Convert a string to Title Case
-- Usage: select dbo.to_title_case('THE quick bRoWn Fox') -- 'The Quick Brown Fox'
--------------------------------------------------------------------------------
alter function dbo.to_title_case(@s varchar(4000)) returns varchar(4000) as
begin
    declare @i int
    declare @c char(1)
    declare @result varchar(255)

    set @result = lower(@s)
    set @i = 2
    set @result = stuff(@result, 1, 1, upper(substring(@s, 1, 1)))

    while @i <= len(@s) begin
        set @c = substring(@s, @i, 1)
        if @c in (' ', ';', ':', '!', '?', ',', '.', '_', '-', '/', '&', '''', '(', '{', '[') begin
            if @i + 1 <= len(@s) begin
                -- handle "apostrophe ess"
                if @c != '''' or substring(@s, @i + 1, 1) <> 's'
                set @result = stuff(@result, @i + 1, 1, upper(substring(@s, @i + 1, 1)))
            end
        end
        set @i = @i + 1
    end
    return isnull(@result, '')
end
go
-- tests!
select
    isnull(unittest.assert_equals(dbo.to_title_case(a.s), a.expected), 'error') as msg
from (
    select cast('asdf' as sql_variant) as s, 'Asdf' as expected
    union all select 'ASDF', 'Asdf'
    union all select null, null
    union all select 10, convert(decimal(10, 2), 10), 1
    union all select convert(float, 10.0), convert(decimal(10, 2), 10), 0
    union all select 10, '10', 0
    union all select convert(nvarchar(50), 'abc'), convert(varchar(50), 'ABC'), 1
) a
where case when unittest.assert_equals(a.input1, a.input2) is null then 1 else 0 end <> a.same
