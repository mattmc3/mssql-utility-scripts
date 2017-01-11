use master
go
if objectproperty(object_id('dbo.split'), 'IsTableFunction') is null begin
    exec('create function dbo.split() returns @t table(x int) as begin return end')
end
go
---------------------------------------------------------------------------------------------------
-- Author: mattmc3
-- Description: Takes a delimited string and splits it on the specified delimiter
---------------------------------------------------------------------------------------------------
alter function dbo.split(@str varchar(8000), @split_marker varchar(8000))
returns
    @values table (
        idx int
        ,value varchar(8000)
    )
as
begin
    declare
        @idx int
        ,@len_split_marker int
        ,@pos int

    select
        @len_split_marker = datalength(@split_marker)
        ,@pos = charindex(@split_marker, @str)
        ,@idx = 1

    -- loop through the string and split out all the values
    while (@pos <> 0) begin
        insert into @values (idx, value) values (@idx, substring(@str, 0, @pos))
        set @str = right(@str, datalength(@str) - (@pos + @len_split_marker - 1))
        select
            @pos = charindex(@split_marker, @str),
            @idx = @idx + 1
    end
    insert into @values (idx, value) values (@idx, @str)

    return
end
go
