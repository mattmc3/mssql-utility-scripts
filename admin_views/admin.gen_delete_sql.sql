create or alter view admin.gen_delete_sql as
--------------------------------------------------------------------------------
-- Author: mattmc
-- Ver: v1.0.0
-- Description: Generate DELETE statements for tables.
--------------------------------------------------------------------------------
select top 2147483647 *
from (

-- delete from
select it.object_id
     , it.schema_name
     , it.table_name
     , it.table_type
     , 200000000 as seq
     , 'DELETE FROM ' + it.quoted_name as sqltxt
  from admin.table_info it
 where it.table_type = 'TABLE'

-- where
union all
select it.object_id
     , it.schema_name
     , it.table_name
     , it.table_type
     , 300000000 as seq
     , space(6) + 'WHERE <Search Conditions,,>' as sqltxt
  from admin.table_info it
 where it.table_type = 'TABLE'

-- end
union all
select it.object_id
     , it.schema_name
     , it.table_name
     , it.table_type
     , 999999000 + n.num as seq
     , case n.num
         when 1 then 'GO'
         when 2 then ''
       end as sqltxt
  from admin.table_info it
 cross apply (select 1 as num union
              select 2) n
 where it.table_type = 'TABLE'

) a order by 4, 2, 3, 5

go
