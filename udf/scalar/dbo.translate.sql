use master
go
if objectproperty(object_id('dbo.translate'), 'IsScalarFunction') is null begin
    exec('create function dbo.translate() returns int as begin return null end')
end
go
--------------------------------------------------------------------------------
-- Author: mattmc3
-- Description: Takes a string and substitutes characters in the specified
--              from --> to mapping. Similar to the XSLT translate() method.
--------------------------------------------------------------------------------
alter function dbo.translate(@s varchar(4000), @from varchar(4000), @to varchar(4000)) returns varchar(4000) as
begin

if @s is null goto EndFunc

declare
    @result varchar(4000)
    ,@i int
    ,@cur_char char(1)
    ,@char_idx int
    ,@slen int
    ,@to_len int

select
    @result = '',
    @i = 1,
    @slen = len(@s),
    @to_len = len(@to)

while @i <= @slen begin
    set @cur_char = substring(@s, @i, 1)
    set @char_idx = charindex(@cur_char, @from collate SQL_Latin1_General_CP1_CS_AS)

    if @char_idx <= 0 begin
        set @result = @result + @cur_char
    end
    else if @char_idx <= @to_len begin
        set @result = @result + substring(@to, @char_idx, 1)
    end

    set @i = @i + 1
end

EndFunc:
return @result 

end
go
