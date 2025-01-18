create or alter view admin.gen_updates as
--------------------------------------------------------------------------------
-- Author: mattmc
-- Ver: v1.0.0
-- Description: Generate UPDATE statements for tables
--------------------------------------------------------------------------------
select top 2147483647 *
from (
    -- table level
    select tab.db_name
         , tab.object_id
         , tab.schema_name
         , tab.table_name
         , tab.table_type
         , 1000000 * num.val as seq
         , case num.val
                when 1 then 'UPDATE ' + tab.quoted_name
                when 3 then ' WHERE <Search Conditions,,>'
           end as sqltxt
      from admin.tables tab
     cross apply (
             select 1 as val union
             select 3
         ) num
     where tab.type_code = 'U'

    -- columns
    union
    select col.db_name
         , col.object_id
         , col.schema_name
         , col.table_name
         , col.table_type
         , 2000000 + col.ordinal_position - 1 as seq
         , space(3) +
           case when col.ordinal_rank = 1 then 'SET ' else space(3) + ',' end +
           quotename(col.column_name) + ' = ' +
           '<' + col.column_name + ', ' + col.data_type_sql + ',>'
           as sqltxt
       from (select *
                  , row_number() over (partition by x.object_id
                                           order by x.ordinal_position) as ordinal_rank
               from admin.columns x
              where x.is_modifiable = 1) col
     where col.type_code = 'U'
) a
order by table_type, schema_name, table_name, seq
go
