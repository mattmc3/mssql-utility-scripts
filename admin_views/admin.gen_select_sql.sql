-------------------------------------------------------------------------------
-- Description: Makes a basic SQL SELECT statment for tables and views in
--              the db
-------------------------------------------------------------------------------
create or alter view admin.gen_select_sql as

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

-- select, columns
union all
select ic.table_catalog
     , ic.table_schema
     , ic.table_name
     , ic.table_type
     , 200000000 + ic.ordinal_position as seq
     , case when ic.ordinal_position = 1 then 'SELECT '
            else space(6) + ','
       end + quotename(ic.column_name) as ddl
  from meta.column_info ic

-- from
union all
select it.table_catalog
     , it.table_schema
     , it.table_name
     , it.table_type
     , 300000000 as seq
     , 'FROM ' + quotename(it.table_schema) + '.' + quotename(it.table_name) as ddl
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

-- select * from admin.gen_select_sql
