use master
go
if objectproperty(object_id('admin.v_gen_select_sql'), 'IsView') is null begin
	exec('create view admin.v_gen_select_sql as select 1 as z')
end
go
-------------------------------------------------------------------------------
-- Author: mattmc3
-- Description: Makes a basic SQL SELECT statment for tables and views in
--   the db
-------------------------------------------------------------------------------
alter view admin.v_gen_select_sql as

select top 9999999 * from (

-- select
select
	it.table_catalog
	,it.table_schema
	,it.table_name
	,0 as seq
	,'SELECT' as ddl
from
	information_schema.tables it

-- columns
union all
select
	ic.table_catalog
	,ic.table_schema
	,ic.table_name
	,100000000 + ic.ordinal_position as seq
	,char(9) + case when ic.ordinal_position = 1 then '' else ',' end + quotename(ic.column_name) as ddl
from
	information_schema.columns ic

-- from
union all
select
	it.table_catalog
	,it.table_schema
	,it.table_name
	,200000000 as seq
	,'FROM' ddl
from
	information_schema.tables it

-- table
union all
select
	it.table_catalog
	,it.table_schema
	,it.table_name
	,200000001 as seq
	,char(9) + quotename(it.table_schema) + '.' + quotename(it.table_name) + ' t' ddl
from
	information_schema.tables it

-- where
union all
select
	it.table_catalog
	,it.table_schema
	,it.table_name
	,300000000 as seq
	,'WHERE' as ddl
from
	information_schema.tables it

-- default where
union all
select
	it.table_catalog
	,it.table_schema
	,it.table_name
	,300000001 as seq
	,char(9) + '1 = 1' as ddl
from
	information_schema.tables it

) a order by 1,2,3,4

go
