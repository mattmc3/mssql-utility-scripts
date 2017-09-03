-------------------------------------------------------------------------------
-- Description: Makes a basic SQL DELETE statment for tables and views in
--              the db
-------------------------------------------------------------------------------
create or alter view admin.gen_delete_sql as

select top 2147483647 * from (

-- use, go
select it.table_catalog
     , it.table_schema
     , it.table_name
     , it.table_type
     , 100000000 + n.num as seq
     , case n.num
         when 1 then 'USE ' + quotename(it.table_catalog)
         when 2 then 'GO'
         when 3 then ''
       end as ddl
  from meta.table_info it
 cross apply (select 1 as num union
              select 2 union
              select 3) n

-- delete from
union all
select it.table_catalog
     , it.table_schema
     , it.table_name
     , it.table_type
     , 200000000 as seq
     , 'DELETE FROM ' + quotename(it.table_schema) + '.' + quotename(it.table_name) as ddl
  from meta.table_info it

-- where
union all
select it.table_catalog
     , it.table_schema
     , it.table_name
     , it.table_type
     , 300000000 as seq
     , space(6) + 'WHERE <Search Conditions,,>' as ddl
  from meta.table_info it

-- end
union all
select it.table_catalog
     , it.table_schema
     , it.table_name
     , it.table_type
     , 999999000 + n.num as seq
     , case n.num
         when 1 then 'GO'
         when 2 then ''
       end as ddl
  from meta.table_info it
 cross apply (select 1 as num union
              select 2) n

) a order by 1, 2, 3, 5

go

-- select * from admin.gen_delete_sql
