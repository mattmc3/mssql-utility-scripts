use master
go
if objectproperty(object_id('dbo.regex_matches'), 'IsTableFunction') is null begin
	exec('create function dbo.regex_matches() returns @t table(x int) as begin return end')
end
go
--------------------------------------------------------------------------------
-- Author: mattmc3
-- Description: regex_matches takes any string and a regular expression pattern
--    and returns a table of the matches and submatches (groups)
-- Usage:
--   select * from dbo.regex_matches('foo', '[aeiou]')
--------------------------------------------------------------------------------
alter function dbo.regex_matches(@s varchar(8000), @pattern varchar(8000))
	returns @result table (
		-- Columns returned by the function
		id int identity(1,1) primary key not null
		,match_highlight varchar(8000) not null
		,match_num int not null
		,match varchar(8000) not null
		,match_first_index int not null
		,submatch_num int null
		,submatch varchar(8000) null
	)
as
begin
	-- declare all variables
	declare
		@hr int                 -- contains hresult returned by com
		,@matches_count int     -- total number of matches
		,@submatches_count int  -- total number of submatches
		,@obj_re int            -- VBScript.RegExp object
		,@obj_matches int       -- VBScript.RegExp.Matches object
		,@obj_match int         -- VBScript.RegExp.Match object
		,@obj_submatches int    -- VBScript.RegExp.SubMatches object
		,@match_highlight varchar(8000)
		,@match_num int
		,@match varchar(8000)
		,@match_first_index int
		,@submatch_num int
		,@submatch varchar(8000)

	-- short cut for nulls
	if @s is null or @pattern is null begin
		return
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

	-- get matches
	exec @hr = sp_OAMethod @obj_re, 'Execute', @obj_matches out, @s
	if (@hr <> 0) goto ErrorHandler

	exec @hr = sp_OAGetProperty @obj_matches, 'Count', @matches_count out
	if (@hr <> 0) goto ErrorHandler

	-- loop through matches
	set @match_num = 0
	while @match_num < @matches_count begin
		exec @hr = sp_OAGetProperty @obj_matches, 'Item', @obj_match out, @match_num
		if (@hr <> 0) goto ErrorHandler

		exec @hr = sp_OAGetProperty @obj_match, 'FirstIndex', @match_first_index out
		if (@hr <> 0) goto ErrorHandler

		exec @hr = sp_OAGetProperty @obj_match, 'Value', @match out
		if (@hr <> 0) goto ErrorHandler

		-- add chevrons to highlight the match
		set @match_highlight =
			case
				when @match_first_index + len(@match) + 1 > len(@s) then
					stuff(@s + '<<<', @match_first_index + 1, 0, '>>>')
				else
					stuff(stuff(@s, @match_first_index + len(@match) + 1, 0, '<<<'), @match_first_index + 1, 0, '>>>')
			end

		-- put the record in the result set
		-- Note: SQL indexing is one-based, not zero-based
		insert into @result (match_highlight, match_num, match, match_first_index, submatch_num, submatch)
		values (@match_highlight, @match_num + 1, @match, @match_first_index + 1, 0, null)

		-- submatches
		exec @hr = sp_OAGetProperty @obj_match, 'SubMatches', @obj_submatches out
		if (@hr <> 0) goto ErrorHandler

		exec @hr = sp_OAGetProperty @obj_submatches, 'Count', @submatches_count out
		if (@hr <> 0) goto ErrorHandler

		set @submatch_num = 0
		while @submatch_num < @submatches_count begin
			exec @hr = sp_OAGetProperty @obj_submatches, 'Item', @submatch out, @submatch_num
			if (@hr <> 0) goto ErrorHandler

			-- put the record in the result set
			insert into @result (match_highlight, match_num, match, match_first_index, submatch_num, submatch)
			values (@match_highlight, @match_num + 1, @match, @match_first_index + 1, @submatch_num + 1, @submatch)

			set @submatch_num = @submatch_num + 1
		end

		exec sp_OADestroy @obj_submatches
		exec sp_OADestroy @obj_match

		set @match_num = @match_num + 1
	end

-- Ugly SQL error handling with spaghetti GOTOs
goto Done

ErrorHandler:
	-- on error, don't return a half result
	delete @result
Done:
	-- clean up
	exec sp_OADestroy @obj_submatches
	exec sp_OADestroy @obj_match
	exec sp_OADestroy @obj_matches
	exec sp_OADestroy @obj_re
	return
end
go
