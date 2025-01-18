create or alter view admin.gen_inserts as
--------------------------------------------------------------------------------
-- Author: mattmc
-- Ver: v1.0.0
-- Description: Generate INSERT statements for tables
--------------------------------------------------------------------------------
select top 2147483647 *
from (
    -- table level
    select tab.db_name
         , tab.object_id
         , tab.table_type
         , tab.schema_name
         , tab.table_name
         , 1000000 * num.val as seq
         , case num.val
                when 1 then 'INSERT INTO ' + tab.quoted_name
                when 3 then space(5) + 'VALUES'
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
         , col.table_type
         , col.schema_name
         , col.table_name
         , (1000000 * num.val) + col.ordinal_position - 1 as seq
         , case num.val
                when 2 then
                    space(11) +
                    case when col.ordinal_rank = 1 then '(' else ',' end +
                    quotename(col.column_name) +
                    case when col.ordinal_rank_desc = 1 then ')' else '' end
                when 4 then
                   space(11) +
                   case when col.ordinal_rank = 1 then '(<' else ',<' end +
                   col.column_name + ', ' + isnull(col.data_type_sql, '') + ',>' +
                   case when col.ordinal_rank_desc = 1 then ')' else '' end
           end as sqltxt
      from (select *
                  , row_number() over (partition by x.object_id
                                           order by x.ordinal_position) as ordinal_rank
                  , row_number() over (partition by x.object_id
                                           order by x.ordinal_position desc) as ordinal_rank_desc
               from admin.columns x
              where x.is_modifiable = 1) col
     cross apply (
             select 2 as val union
             select 4
         ) num
     where col.type_code = 'U'
) a
order by table_type, schema_name, table_name, seq
go
