use master
go
if objectproperty(object_id('dbo.regex_replace'), 'IsScalarFunction') is null begin
	exec('create function dbo.regex_replace() returns int as begin return null end')
end
go
--------------------------------------------------------------------------------
-- Author: mattmc3
-- Description: regex_replace takes any string, a regular expression pattern,
--    and a replacement value and replaces all occurences of the pattern in
--    the input value with the replacement value.
-- Usage: select dbo.regex_replace('foo', '[a-k]', 'm') -- 'moo'
--------------------------------------------------------------------------------
alter function dbo.regex_replace(@s varchar(8000), @pattern varchar(8000), @obj_replacement varchar(8000)) returns varchar(8000) as
begin
	-- declare all variables
	declare
		@hr int                 -- contains hresult returned by com
		,@obj_re int            -- VBScript.RegExp object
		,@result varchar(8000)  -- return value

	-- short cut for nulls
	if @s is null or @pattern is null begin
		return @s
	end

	-- make regex obj
	exec @hr = sp_OACreate 'VBScript.RegExp', @obj_re out
	if (@hr <> 0) goto ErrorHandler

	-- set Global property to true
	exec @hr = sp_OASetProperty @obj_re, 'Global', 1
	if (@hr <> 0) goto ErrorHandler

	-- set Pattern property to provided value
	exec @hr = sp_OASetProperty @obj_re, 'Pattern', @pattern
	if (@hr <> 0) goto ErrorHandler

	-- do replace
	exec @hr = sp_OAMethod @obj_re, 'Replace', @result out, @s, @obj_replacement
	if (@hr <> 0) goto ErrorHandler

	-- clean up
	exec sp_OADestroy @obj_re
	return @result

ErrorHandler:
	exec sp_OADestroy @obj_re
	return null
end
go
