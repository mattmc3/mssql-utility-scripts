use master
go
if objectproperty(object_id('admin.v_gen_delete_sql'), 'IsView') is null begin
    exec('create view admin.v_gen_delete_sql as select 1 as z')
end
go
-------------------------------------------------------------------------------
-- Author: mattmc3
-- Description: Makes a basic DELETE statment for the tables in the db
-------------------------------------------------------------------------------
alter view admin.v_gen_delete_sql as

select top 9999999 * from (

-- USE [database_name]
select t.table_catalog
      ,t.table_schema
      ,t.table_name
      ,100000000 as seq
      ,'USE ' + quotename(t.table_catalog) as ddl
from information_schema.tables t
where t.table_type = 'BASE TABLE'

-- GO
union all
select t.table_catalog
      ,t.table_schema
      ,t.table_name
      ,100000001 as seq
      ,'GO' as ddl
from information_schema.tables t
where t.table_type = 'BASE TABLE'

-- blank line
union all
select t.table_catalog
      ,t.table_schema
      ,t.table_name
      ,100000002 as seq
      ,'' as ddl
from information_schema.tables t
where t.table_type = 'BASE TABLE'

-- DELETE FROM [schema].[table_name]
union all
select t.table_catalog
      ,t.table_schema
      ,t.table_name
      ,200000000 as seq
      ,'DELETE FROM ' + quotename(t.table_schema) + '.' + quotename(t.table_name) as ddl
from information_schema.tables t
where t.table_type = 'BASE TABLE'

-- WHERE <Search Conditions,,>
union all
select t.table_catalog
      ,t.table_schema
      ,t.table_name
      ,300000000 as seq
      ,'      WHERE <Search Conditions,,>' as ddl
from information_schema.tables t
where t.table_type = 'BASE TABLE'

-- GO
union all
select t.table_catalog
      ,t.table_schema
      ,t.table_name
      ,800000000 as seq
      ,'GO' as ddl
from information_schema.tables t
where t.table_type = 'BASE TABLE'

-- blank line
union all
select t.table_catalog
      ,t.table_schema
      ,t.table_name
      ,900000000 as seq
      ,'' as ddl
from information_schema.tables t
where t.table_type = 'BASE TABLE'

-- blank line 2
union all
select t.table_catalog
      ,t.table_schema
      ,t.table_name
      ,900000001 as seq
      ,'' as ddl
from information_schema.tables t
where t.table_type = 'BASE TABLE'

) a order by 1,2,3,4
go
