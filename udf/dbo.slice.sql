use master
go
if objectproperty(object_id('dbo.slice'), 'IsScalarFunction') is null begin
	exec('create function dbo.slice() returns int as begin return null end')
end
go
---------------------------------------------------------------------------------------------------
-- Author: mattmc3
-- Description: Slice behaves like JavaScript Slice(), allowing negative indexing
---------------------------------------------------------------------------------------------------
alter function dbo.slice(@s nvarchar(4000), @startIndex int, @endIndex int) returns nvarchar(4000) as
begin
	declare @result nvarchar(4000) = null
	if @s is not null begin
		declare @slen int = len(@s)
		declare @startPosition int = isnull(@startIndex, 0)
		declare @endPosition int = isnull(@endIndex, @slen)

		-- Handle negative indexes
		if @startPosition < 0 set @startPosition = @slen + @startIndex
		if @endPosition < 0 set @endPosition = @slen + @endPosition

		-- Smooth the positions
		if @startPosition < 0     set @startPosition = 0
		if @startPosition > @slen set @startPosition = @slen
		if @endPosition < 0       set @endPosition = 0
		if @endPosition > @slen   set @endPosition = @slen

		-- Do the slice
		declare @length int = @endPosition - @startPosition
		if @length < 0 set @length = 0
		if @startPosition + @length > @slen begin
			set @length = @slen - @startPosition
		end

		set @result = substring(@s, @startPosition + 1, @length)
	end

	return @result
end
go
