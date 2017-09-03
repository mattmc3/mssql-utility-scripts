-------------------------------------------------------------------------------
-- Description: Makes a basic INSERT statment for the tables in the db matching
--              the SSMS script INSERT format.
-------------------------------------------------------------------------------
create or alter view [admin].[gen_insert_sql] as

select top 2147483647 * from (

-- use, go, insert
select it.table_catalog
     , it.table_schema
     , it.table_name
     , it.table_type
     , 100000000 + n.num as seq
     , case n.num
       when 1 then 'USE ' + quotename(it.table_catalog)
       when 2 then 'GO'
       when 3 then ''
       when 4 then 'INSERT INTO ' + quotename(it.table_schema) + '.' + quotename(it.table_name)
       end as ddl
  from meta.table_info it
 cross apply (select 1 as num union
              select 2 union
              select 3 union
              select 4) n

-- columns
 union
select ic.table_catalog
     , ic.table_schema
     , ic.table_name
     , ic.table_type
     , 200000000 + ic.ordinal_position as seq
     , space(11) +
       case when ic.ordinal_rank = 1 then '(' else ',' end +
       quotename(ic.column_name) +
       case when ic.ordinal_rank_desc = 1 then ')' else '' end
       as ddl
   from (select *
              , row_number() over (partition by x.mssql_object_id
                                       order by x.ordinal_position) as ordinal_rank
              , row_number() over (partition by x.mssql_object_id
                                       order by x.ordinal_position desc) as ordinal_rank_desc
           from meta.column_info x
          where x.is_modifiable = 1) ic

-- values keyword
 union
select it.table_catalog
     , it.table_schema
     , it.table_name
     , it.table_type
     , 300000000 as seq
     , space(5) + 'VALUES' ddl
  from meta.table_info it

-- insert values
 union
select ic.table_catalog
     , ic.table_schema
     , ic.table_name
     , ic.table_type
     , 400000000 + ic.ordinal_position as seq
     , space(11) +
       case when ic.ordinal_rank = 1 then '(<' else ',<' end +
       ic.column_name + ', ' + ic.data_type + isnull(ic.data_type_size, '') + ',>' +
       case when ic.ordinal_rank_desc = 1 then ')' else '' end
       as ddl
   from (select *
              , row_number() over (partition by x.mssql_object_id
                                       order by x.ordinal_position) as ordinal_rank
              , row_number() over (partition by x.mssql_object_id
                                       order by x.ordinal_position desc) as ordinal_rank_desc
           from meta.column_info x
          where x.is_modifiable = 1
    ) ic

-- close
 union
select it.table_catalog
     , it.table_schema
     , it.table_name
     , it.table_type
     , 900000000 + n.num as seq
     , case n.num
       when 1 then 'GO'
       when 2 then ''
       end as ddl
  from meta.table_info it
 cross apply (select 1 as num union
              select 2) n

) a order by 1, 2, 3, 5

go

-- select * from [admin].[gen_insert_sql]
