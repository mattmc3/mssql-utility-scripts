use master
go
if objectproperty(object_id('dbo.regex_is_match'), 'IsScalarFunction') is null begin
	exec('create function dbo.regex_is_match() returns int as begin return null end')
end
go
--------------------------------------------------------------------------------
-- Author: mattmc3
-- Description: regex_is_match takes any string and a regular expression pattern
--    and returns a boolean (bit) indicating whether the string matches the
--    pattern provided.
-- Usage:
--   select dbo.regex_is_match('foo', 'o+')    -- 1
--   select dbo.regex_is_match('foo', '[x-z]') -- 0
--------------------------------------------------------------------------------
alter function dbo.regex_is_match(@s varchar(8000), @pattern varchar(8000)) returns bit as
begin
	-- declare all variables
	declare
		@hr int       -- contains hresult returned by com
		,@obj_re int  -- VBScript.RegExp object
		,@result bit  -- return value

	-- short cut for nulls
	if @s is null or @pattern is null begin
		return 0
	end

	-- make regex obj
	exec @hr = sp_OACreate 'VBScript.RegExp', @obj_re out
	if (@hr <> 0) goto ErrorHandler

	-- set global property to true
	exec @hr = sp_OASetProperty @obj_re, 'Global', 1
	if (@hr <> 0) goto ErrorHandler

	-- set Pattern property to provided value
	exec @hr = sp_OASetProperty @obj_re, 'Pattern', @pattern
	if (@hr <> 0) goto ErrorHandler

	-- test for match
	exec @hr = sp_OAMethod @obj_re, 'Test', @result out, @s
	if (@hr <> 0) goto ErrorHandler

	-- destroy
	exec sp_OADestroy @obj_re
	return @result

ErrorHandler:
	exec sp_OADestroy @obj_re
	return null
end
go
