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

-- update
select
	it.table_catalog
	,it.table_schema
	,it.table_name
	,0 as seq
	,'DELETE t' as ddl
from
	information_schema.tables it
where
	it.table_type = 'BASE TABLE'

-- from table
union all
select
	it.table_catalog
	,it.table_schema
	,it.table_name
	,100000000 as seq
	,'FROM ' + quotename(it.table_schema) + '.' + quotename(it.table_name) + ' t' as ddl
from
	information_schema.tables it
where
	it.table_type = 'BASE TABLE'

-- where
union all
select
	it.table_catalog
	,it.table_schema
	,it.table_name
	,300000000 as seq
	,'WHERE 1 = 0 -- CHANGE ME' as ddl
from
	information_schema.tables it
where
	it.table_type = 'BASE TABLE'

) a order by 1,2,3,4
go
