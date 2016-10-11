use master
go
if objectproperty(object_id('unittest.assert_equals'), 'IsScalarFunction') is null begin
	exec('create function unittest.assert_equals() returns int as begin return null end')
end
go
--------------------------------------------------------------------------------
-- Author: mattmc3
-- Description: unittest.assert_equals tests whether two values are equal and
--  returns null if they are, and an error message if they aren't.
--------------------------------------------------------------------------------
alter function unittest.assert_equals(@thing1 sql_variant, @thing2 sql_variant) returns varchar(2000) as
begin
	declare @result varchar(2000)
	select
		@result =
			case
				when @thing1 is null or @thing2 is null then
					case when coalesce(@thing1, @thing2) is null then null
					else 'unittest.assert_equals fail: ' + isnull(convert(varchar(8000), @thing1), '<NULL>') + ' != ' + isnull(convert(varchar(8000), @thing2), '<NULL>')
					end
				when @thing1 <> @thing2 then
					'unittest.assert_equals fail: '
					+ convert(varchar(8000), @thing1)
					+ '::' + convert(varchar(250), sql_variant_property(@thing1, 'BaseType'))
					+ ' != '
					+ convert(varchar(8000), @thing2)
					+ '::' + convert(varchar(250), sql_variant_property(@thing2, 'BaseType'))
				else null
			end
	return @result
end
go
grant execute on unittest.assert_equals to public
go
-- tests!
select
	isnull(unittest.assert_equals(a.input1, a.input2), 'error') as msg
from (
	select cast('asdf' as sql_variant) as input1, cast('asdf' as sql_variant) as input2, cast(1 as bit) as same
	union all select 'asdf', null, 0
	union all select null, 'asdf', 0
	union all select null, null, 1
	union all select 10, convert(decimal(10, 2), 10), 1
	union all select convert(float, 10.0), convert(decimal(10, 2), 10), 0
	union all select 10, '10', 0
	union all select convert(nvarchar(50), 'abc'), convert(varchar(50), 'ABC'), 1
) a
where case when unittest.assert_equals(a.input1, a.input2) is null then 1 else 0 end <> a.same
