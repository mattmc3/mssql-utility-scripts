-------------------------------------------------------------------------------
-- Description: Makes an INSERT statment populated from a SELECT for all the
--              tables in the db.
-------------------------------------------------------------------------------
create or alter view [admin].[gen_insert_sql_from_select] as

select top 2147483647 * from (

-- use, go, insert
select it.table_catalog
     , it.table_schema
     , it.table_name
     , it.table_type
     , 100000000 + n.num as seq
     , case
          when n.num = 1 then 'use ' + quotename(it.table_catalog)
          when n.num = 2 then 'go'
          when n.num = 3 then ''
       end as ddl
  from meta.table_info it
 cross apply (select 1 as num union
              select 2 union
              select 3
) n

-- identity_insert
 union
select ic.table_catalog
     , ic.table_schema
     , ic.table_name
     , ic.table_type
     , 200000000 as seq
     , 'set identity_insert ' + quotename(ic.table_schema) + '.' + quotename(ic.table_name) + ' on' as ddl
  from meta.column_info ic
 where ic.is_identity = 1

-- insert into
 union
select it.table_catalog
     , it.table_schema
     , it.table_name
     , it.table_type
     , 210000000 as seq
     , 'insert into ' + quotename(it.table_schema) + '.' + quotename(it.table_name) + ' (' as ddl
  from meta.table_info it

-- columns
 union
select ic.table_catalog
     , ic.table_schema
     , ic.table_name
     , ic.table_type
     , 300000000 + ic.ordinal_position as seq
     , space(4) + case when ic.ordinal_rank = 1 then '' else ',' end + quotename(ic.column_name) as ddl
  from (select *
             , row_number() over (partition by x.mssql_object_id
                                  order by x.ordinal_position) as ordinal_rank
          from meta.column_info x
         where x.is_modifiable = 1
     ) ic
 where ic.is_modifiable = 1

-- end paren, select
 union
select it.table_catalog
     , it.table_schema
     , it.table_name
     , it.table_type
     , 400000000 + n.num as seq
     , case when n.num = 1 then ')'
            when n.num = 2 then 'select'
       end as ddl
from meta.table_info it
cross apply (select 1 as num union
             select 2) n

-- select values
 union
select ic.table_catalog
     , ic.table_schema
     , ic.table_name
     , ic.table_type
     , 500000000 + ic.ordinal_position as seq
     , space(4) + case when ic.ordinal_rank = 1 then '' else ',' end + 's.' + quotename(ic.column_name) as ddl
  from (
      select *
           , row_number() over (partition by x.mssql_object_id
                                order by x.ordinal_position) as ordinal_rank
        from meta.column_info x
       where x.is_modifiable = 1
     ) ic
 where ic.is_modifiable = 1

-- from
 union
select it.table_catalog
     , it.table_schema
     , it.table_name
     , it.table_type
     , 600000000 as seq
     , 'from #' + it.table_name + ' s  -- CHANGE ME!' as ddl
from meta.table_info it

-- identity_insert off
union all
select ic.table_catalog
     , ic.table_schema
     , ic.table_name
     , ic.table_type
     , 700000000 as seq
     , 'set identity_insert ' + quotename(ic.table_schema) + '.' + quotename(ic.table_name) + ' off' as ddl
from meta.column_info ic
where ic.is_identity = 1

-- end
 union
select it.table_catalog
     , it.table_schema
     , it.table_name
     , it.table_type
     , 999999000 + n.num as seq
     , case when n.num = 1 then 'go'
            when n.num = 2 then ''
       end as ddl
from meta.table_info it
cross apply (
          select 1 as num
    union select 2
) n

) a order by 1, 2, 3, 5

go

-- select * from [admin].[gen_insert_sql_from_select]
