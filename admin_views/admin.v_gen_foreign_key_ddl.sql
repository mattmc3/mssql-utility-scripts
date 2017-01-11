if objectproperty(object_id('admin.v_gen_foreign_key_ddl'), 'IsView') is null begin
    exec('create view admin.v_gen_foreign_key_ddl as select 1 as z')
end
go
-------------------------------------------------------------------------------
-- Author: mattmc3
-- Description:
-------------------------------------------------------------------------------
alter view admin.v_gen_foreign_key_ddl as

select top 9999999 * from (

select db_name() as constraint_catalog
    ,schema_name(f.schema_id) as constraint_schema
    ,f.name as constraint_name
    ,db_name() as table_catalog
    ,schema_name(t.schema_id) as table_schema
    ,t.name as table_name
    ,db_name() as ref_table_catalog
    ,schema_name(t2.schema_id) as ref_table_schema
    ,t2.name as ref_table_name
    ,1000000 as seq
    ,'ALTER TABLE '
    + quotename(schema_name(t.schema_id)) + '.' + quotename(t.name) + '  WITH '
    + case when f.is_disabled = 1 then 'NO' else '' end + 'CHECK'
    + ' ADD  CONSTRAINT ' + quotename(f.name) + ' FOREIGN KEY('
    + substring((
        select ', ' + quotename(col_name(k.parent_object_id, k.parent_column_id)) as [text()]
        from sys.foreign_key_columns k
        where k.constraint_object_id = f.object_id
        for xml path ('')
    ), 3, 8000)
    + ')' COLLATE DATABASE_DEFAULT as ddl
from sys.foreign_keys f
join sys.tables t       on t.object_id = f.parent_object_id
join sys.tables t2      on t2.object_id = f.referenced_object_id

union all
select
    db_name() as constraint_catalog
    ,schema_name(f.schema_id) as constraint_schema
    ,f.name as constraint_name
    ,db_name() as table_catalog
    ,schema_name(t.schema_id) as table_schema
    ,t.name as table_name
    ,db_name() as ref_table_catalog
    ,schema_name(t2.schema_id) as ref_table_schema
    ,t2.name as ref_table_name
    ,2000000 as seq
    ,'REFERENCES '
    + quotename(schema_name(t2.schema_id)) + '.' + quotename(t2.name) + ' ('
    + substring((
        select ', ' + quotename(col_name(k.referenced_object_id, k.referenced_column_id)) as [text()]
        from sys.foreign_key_columns k
        where k.constraint_object_id = f.object_id
        for xml path ('')
    ), 3, 8000)
    + ')' COLLATE DATABASE_DEFAULT as ddl
from sys.foreign_keys f
join sys.tables t
  on t.object_id = f.parent_object_id
join sys.tables t2
  on t2.object_id = f.referenced_object_id

union all
select
    db_name() as constraint_catalog
    ,schema_name(f.schema_id) as constraint_schema
    ,f.name as constraint_name
    ,db_name() as table_catalog
    ,schema_name(t.schema_id) as table_schema
    ,t.name as table_name
    ,db_name() as ref_table_catalog
    ,schema_name(t2.schema_id) as ref_table_schema
    ,t2.name as ref_table_name
    ,4000000 as seq
    ,'ON UPDATE ' + f.update_referential_action_desc as ddl
from sys.foreign_keys f
join sys.tables t
  on t.object_id = f.parent_object_id
join sys.tables t2
  on t2.object_id = f.referenced_object_id
where f.update_referential_action_desc <> 'NO_ACTION'

union all
select
    db_name() as constraint_catalog
    ,schema_name(f.schema_id) as constraint_schema
    ,f.name as constraint_name
    ,db_name() as table_catalog
    ,schema_name(t.schema_id) as table_schema
    ,t.name as table_name
    ,db_name() as ref_table_catalog
    ,schema_name(t2.schema_id) as ref_table_schema
    ,t2.name as ref_table_name
    ,4000001 as seq
    ,'ON DELETE ' + f.delete_referential_action_desc as ddl
from sys.foreign_keys f
join sys.tables t
  on t.object_id = f.parent_object_id
join sys.tables t2
  on t2.object_id = f.referenced_object_id
where f.delete_referential_action_desc <> 'NO_ACTION'

union all
select
    db_name() as constraint_catalog
    ,schema_name(f.schema_id) as constraint_schema
    ,f.name as constraint_name
    ,db_name() as table_catalog
    ,schema_name(t.schema_id) as table_schema
    ,t.name as table_name
    ,db_name() as ref_table_catalog
    ,schema_name(t2.schema_id) as ref_table_schema
    ,t2.name as ref_table_name
    ,4000002 as seq
    ,'NOT FOR REPLICATION ' as ddl
from sys.foreign_keys f
join sys.tables t
  on t.object_id = f.parent_object_id
join sys.tables t2
  on t2.object_id = f.referenced_object_id
where f.is_not_for_replication = 1

) a order by 1,2,3,4,5,6,7,8,9,10,11

go
