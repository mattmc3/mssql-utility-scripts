if objectproperty(object_id('admin.foreign_keys'), 'IsView') is null begin
    exec('create view admin.foreign_keys as select 1 as z')
end
go
-------------------------------------------------------------------------------
-- Author:      mattmc3
-- Description: An information_schema-style view of foreign keys.
-------------------------------------------------------------------------------
alter view admin.foreign_keys as

select db_name()                 as table_catalog
      ,schema_name(t.schema_id)  as table_schema
      ,t.name                    as table_name
      ,db_name()                 as ref_table_catalog
      ,schema_name(t2.schema_id) as ref_table_schema
      ,t2.name                   as ref_table_name
      ,db_name()                 as constraint_catalog
      ,schema_name(f.schema_id)  as constraint_schema
      ,f.name                    as constraint_name
from sys.foreign_keys f
join sys.tables t       on t.object_id = f.parent_object_id
join sys.tables t2      on t2.object_id = f.referenced_object_id

go
