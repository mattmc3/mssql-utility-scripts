use master
go
if objectproperty(object_id('admin.v_gen_update_sql'), 'IsView') is null begin
    exec('create view admin.v_gen_update_sql as select 1 as z')
end
go
-------------------------------------------------------------------------------
-- Author: mattmc3
-- Description: Makes a basic UPDATE statment for the tables in the db
-------------------------------------------------------------------------------
alter view admin.v_gen_update_sql as

select top 9999999 * from (

-- update
select
    it.table_catalog
    ,it.table_schema
    ,it.table_name
    ,0 as seq
    ,'UPDATE' as ddl
from
    information_schema.tables it
where
    it.table_type = 'BASE TABLE'
-- table
union all
select
    it.table_catalog
    ,it.table_schema
    ,it.table_name
    ,100000000 as seq
    ,char(9) + quotename(it.table_schema) + '.' + quotename(it.table_name) as ddl
from
    information_schema.tables it
where
    it.table_type = 'BASE TABLE'
-- set
union all
select
    it.table_catalog
    ,it.table_schema
    ,it.table_name
    ,100000001 as seq
    ,'SET' as ddl
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
    ,200000000 + ic.ordinal_position as seq
    ,char(9) + case when ic.ordinal_position = 1 then ' ' else ',' end
    + quotename(ic.column_name)
    + replicate(' ', (
        select max(len(quotename(x.column_name)))
        from information_schema.columns x
        where x.table_name = ic.table_name
        and x.table_schema = ic.table_schema) - len(quotename(ic.column_name))
    )
    + ' = ? -- ' + quotename(ic.column_name)
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

) a order by 1,2,3,4
go
