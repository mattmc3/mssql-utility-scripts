create or alter view [admin].[table_info] as
--------------------------------------------------------------------------------
-- Author: mattmc
-- Ver: v1.0.0
-- Description: enhanced version of information_schema.tables
-- Notes: start with sp_helptext 'information_schema.tables'
--------------------------------------------------------------------------------
with rowcounts as (
    select st.object_id
        ,sum(st.row_count) as row_count
    from sys.dm_db_partition_stats st
    where st.index_id < 2
    group by st.object_id
)
select a.*, b.row_count
from (
    select top 2147483647
        o.object_id as object_id
        ,db_name()  as db_name
        ,s.name     as schema_name
        ,o.name     as table_name
        ,quotename(s.name) + '.' + quotename(o.name) as quoted_name
        ,case o.type
            when 'U' then 'TABLE'
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
    and s.name not in ('sys')
    order by 6, 3, 4
) a
left join rowcounts b
    on a.object_id = b.object_id
go
