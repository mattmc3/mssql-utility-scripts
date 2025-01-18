create or alter view admin.gen_selects as
--------------------------------------------------------------------------------
-- Author: mattmc
-- Ver: v1.0.0
-- Description: Generate SELECT statements for tables
--------------------------------------------------------------------------------
select top 2147483647 *
from (
    -- select, columns
    select col.db_name
         , col.object_id
         , col.table_type
         , col.schema_name
         , col.table_name
         , 1000000 + col.ordinal_position - 1 as seq
         , case when col.ordinal_position = 1 then 'SELECT TOP (1000) '
                else space(6) + ','
           end + quotename(col.column_name) as sqltxt
      from admin.columns col

    -- from
    union all
    select tab.db_name
         , tab.object_id
         , tab.table_type
         , tab.schema_name
         , tab.table_name
         , 2000000 as seq
         , 'FROM ' + tab.quoted_name as sqltxt
      from admin.tables tab
) a
order by table_type, schema_name, table_name, seq
go
