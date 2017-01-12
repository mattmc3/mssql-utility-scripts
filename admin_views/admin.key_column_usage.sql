if objectproperty(object_id('admin.key_column_usage'), 'IsView') is null begin
    exec('create view admin.key_column_usage as select 1 as z')
end
go
-------------------------------------------------------------------------------
-- Author:      mattmc3
-- Description: An extended version of the information_schema view of the
--              same name.
-------------------------------------------------------------------------------
alter view admin.key_column_usage as

select
    db_name()                     as constraint_catalog
    ,schema_name(f.schema_id)     as constraint_schema
    ,f.name                       as constraint_name
    ,db_name()                    as table_catalog
    ,schema_name(p.schema_id)     as table_schema
    ,p.name                       as table_name
    ,col_name(k.parent_object_id,
              k.parent_column_id) as  column_name
    ,k.constraint_column_id       as  ordinal_position
    ,'FK'                         as  constraint_type
from sys.foreign_keys f
join sys.foreign_key_columns k on k.constraint_object_id = f.object_id
join sys.tables p              on p.object_id = f.parent_object_id

union all
select
    db_name()                 as constraint_catalog
    ,schema_name(k.schema_id) as constraint_schema
    ,k.name                   as constraint_name
    ,db_name()                as table_catalog
    ,schema_name(t.schema_id) as table_schema
    ,t.name                   as table_name
    ,col_name(c.object_id,
              c.column_id)    as column_name
    ,c.key_ordinal            as ordinal_position
    ,k.type                   as constraint_type
from sys.key_constraints k
join sys.index_columns c on c.object_id = k.parent_object_id
                        and c.index_id  = k.unique_index_id
join sys.tables t        on t.object_id = k.parent_object_id

go