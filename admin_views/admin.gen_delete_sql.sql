create or alter view admin.gen_delete_sql as
--------------------------------------------------------------------------------
-- Author: mattmc
-- Ver: v1.0.0
-- Description: Generate DELETE statements for tables.
--------------------------------------------------------------------------------
select top 2147483647 *
from (
    -- delete statements
    select it.object_id
         , it.schema_name
         , it.table_name
         , it.table_type
         , 100000000 * n.num as seq
         , case n.num
             when 1 then 'DELETE FROM ' + it.quoted_name
             when 2 then space(6) + 'WHERE <Search Conditions,,>'
             when 3 then 'GO'
             when 4 then ''
           end as sqltxt
      from admin.table_info it
     cross apply (
             select 1 as num union
             select 2 union
             select 3 union
             select 4
         ) n
     where it.table_type = 'TABLE'
) a order by 4, 2, 3, 5

go
