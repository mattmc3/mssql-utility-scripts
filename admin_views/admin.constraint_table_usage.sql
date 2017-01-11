if objectproperty(object_id('admin.constraint_table_usage'), 'IsView') is null begin
    exec('create view admin.constraint_table_usage as select 1 as z')
end
go
-------------------------------------------------------------------------------
-- Author:      mattmc3
-- Description: An extended version of the information_schema view of the
--              same name.
-------------------------------------------------------------------------------
alter view admin.constraint_table_usage as

select db_name()                as table_catalog
      ,schema_name(t.schema_id) as table_schema
      ,t.name                   as table_name
      ,db_name()                as constraint_catalog
      ,schema_name(c.schema_id) as constraint_schema
      ,c.name                   as constraint_name
      ,c.type                   as constraint_type
from sys.objects c
join sys.tables t  on t.object_id = c.parent_object_id  
where c.type in ('C' ,'UQ' ,'PK' ,'F')

go
