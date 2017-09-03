--------------------------------------------------------------------------------
-- Author: mattmc3
-- Description: enhanced version of information_schema.tables
-- Notes: start with sp_helptext 'information_schema.key_column_usage' in the
--        master db and enhance from there.
--------------------------------------------------------------------------------
create or alter view [meta].[foreign_key_column_info] as

select *
from (
    select top 2147483647
        db_name()                  as constraint_catalog
        ,schema_name(f.schema_id)  as constraint_schema
        ,f.name                    as constraint_name
        ,db_name()                 as table_catalog
        ,schema_name(t.schema_id)  as table_schema
        ,t.name                    as table_name
        ,db_name()                 as ref_table_catalog
        ,schema_name(t2.schema_id) as ref_table_schema
        ,t2.name                   as ref_table_name
        ,col_name(k.parent_object_id, k.parent_column_id)         as column_name
        ,col_name(k.referenced_object_id, k.referenced_column_id) as ref_column_name
        ,k.constraint_column_id                                   as ordinal_position
        ,f.is_disabled
        ,f.is_not_trusted
        ,f.is_not_for_replication
        ,f.update_referential_action_desc as update_referential_action
        ,f.delete_referential_action_desc as delete_referential_action
        ,f.create_date
        ,f.modify_date
    from sys.foreign_keys f
    join sys.tables t              on t.object_id = f.parent_object_id
    join sys.tables t2             on t2.object_id = f.referenced_object_id
    join sys.foreign_key_columns k on k.constraint_object_id = f.object_id
    order by 1, 2, 4, 5, 6, 3
) a

go
