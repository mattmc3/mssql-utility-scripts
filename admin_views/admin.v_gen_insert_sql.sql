use master
go
if objectproperty(object_id('admin.v_gen_insert_sql'), 'IsView') is null begin
	exec('create view admin.v_gen_insert_sql as select 1 as z')
end
go
-------------------------------------------------------------------------------
-- Author: mattmc3
-- Description: Makes a basic INSERT statment for the tables in the db
-------------------------------------------------------------------------------
alter view admin.v_gen_insert_sql as

select top 9999999 * from (

-- insert into
select
	it.table_catalog
	,it.table_schema
	,it.table_name
	,0 as seq
	,'INSERT INTO ' + quotename(it.table_schema) + '.' + quotename(it.table_name) + ' (' as ddl
from
	information_schema.tables it
where
	it.table_type = 'BASE TABLE'

-- columns
union all
select
	ic.table_catalog
	,ic.table_schema
	,ic.table_name
	,100000000 + ic.ordinal_position as seq
	,char(9) + case when ic.ordinal_position = 1 then '' else ',' end + quotename(ic.column_name) as ddl
from
	information_schema.columns ic join
	information_schema.tables it on
		it.table_catalog = ic.table_catalog and
		it.table_schema = ic.table_schema and
		it.table_name = ic.table_name
where
	it.table_type = 'BASE TABLE'

-- values keyword
union all
select
	it.table_catalog
	,it.table_schema
	,it.table_name
	,200000000 as seq
	,') VALUES (' ddl
from
	information_schema.tables it
where
	it.table_type = 'BASE TABLE'

-- insert values
union all
select
	ic.table_catalog
	,ic.table_schema
	,ic.table_name
	,300000000 + ic.ordinal_position as seq
	,char(9) + case when ic.ordinal_position = 1 then '' else ',' end + '? -- ' + quotename(ic.column_name)
	+ ' ' + quotename(ic.data_type)
	+ case when ic.character_maximum_length is not null then '(' + cast(ic.character_maximum_length as varchar(5)) + ')'
	when lower(ic.data_type) in ('numeric', 'decimal') then '(' + cast(ic.numeric_precision as varchar(5)) + ', ' + cast(ic.numeric_scale as varchar(5)) + ')'
	else '' end as ddl
from
	information_schema.columns ic join
	information_schema.tables it on
		it.table_catalog = ic.table_catalog and
		it.table_schema = ic.table_schema and
		it.table_name = ic.table_name
where
	it.table_type = 'BASE TABLE'

-- close
union all
select
	it.table_catalog
	,it.table_schema
	,it.table_name
	,999999999 as seq
	,')' as ddl
from
	information_schema.tables it
where
	it.table_type = 'BASE TABLE'

) a order by 1,2,3,4
go
