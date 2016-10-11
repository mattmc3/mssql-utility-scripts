use master
go
if objectproperty(object_id('dbo.last_char_index'), 'IsScalarFunction') is null begin
	exec('create function dbo.last_char_index() returns int as begin return null end')
end
go
--------------------------------------------------------------------------------
-- Author: mattmc3
--------------------------------------------------------------------------------
alter function dbo.last_char_index(
	@find varchar(8000)
	,@str varchar(8000)
)
returns int
as
begin
	declare @index int

	select
		@index =
			case
				when charindex(@find, @str) < 1 then 0
				else datalength(@str) - charindex(@find, reverse(@str)) + 1
			end

	return @index
end
