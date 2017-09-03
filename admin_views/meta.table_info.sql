--------------------------------------------------------------------------------
-- Author: mattmc3
-- Description: enhanced version of information_schema.tables
-- Notes: start with sp_helptext 'information_schema.tables' in the master
--        db and enhance from there.
--------------------------------------------------------------------------------
create or alter view [meta].[table_info] as

select *
from (
    select top 2147483647
        o.object_id as mssql_object_id
        ,db_name()  as table_catalog
        ,s.name     as table_schema
        ,o.name     as table_name
        ,case o.type
            when 'U' then 'BASE TABLE'
            when 'V' then 'VIEW'
        end as table_type
        ,o.create_date as created_at
        ,o.modify_date as updated_at
        ,isnull(filegroup_name(t.filestream_data_space_id), 'PRIMARY') as file_group
    from sys.objects o
    left join sys.tables t
        on o.object_id = t.object_id
    left join sys.schemas s
        on s.schema_id = o.schema_id
    where o.type in ('U', 'V')
    order by 5, 3, 4
) a

go
