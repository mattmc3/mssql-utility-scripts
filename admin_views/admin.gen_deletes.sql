create or alter view admin.gen_deletes as
--------------------------------------------------------------------------------
-- Author: mattmc
-- Ver: v1.0.0
-- Description: Generate DELETE statements for tables
--------------------------------------------------------------------------------
select top 2147483647 *
from (
    -- delete statements
    select tab.db_name
         , tab.object_id
         , tab.table_type
         , tab.schema_name
         , tab.table_name
         , 1000000 * n.num as seq
         , case n.num
             when 1 then 'DELETE FROM ' + tab.quoted_name
             when 2 then space(6) + 'WHERE <Search Conditions,,>'
           end as sqltxt
      from admin.tables tab
     cross apply (
             select 1 as num union
             select 2
         ) n
     where tab.type_code in ('U')
) a
order by table_type, schema_name, table_name, seq
go
