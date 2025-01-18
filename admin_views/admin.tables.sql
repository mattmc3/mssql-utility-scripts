create or alter view admin.tables as
--------------------------------------------------------------------------------
-- Author: mattmc
-- Ver: v1.0.0
-- Description: enhanced version of information_schema.tables
-- Notes: start with sp_helptext 'information_schema.tables'
--------------------------------------------------------------------------------
with rowcounts as (
    select ps.object_id
        ,sum(ps.row_count) as row_count
    from sys.dm_db_partition_stats ps
    where ps.index_id < 2
    group by ps.object_id
)
select sq.*, rc.row_count
from (
    select top 2147483647
        so.object_id as object_id
        ,db_name() as db_name
        ,ss.schema_id
        ,ss.name as schema_name
        ,so.name as table_name
        ,convert(nvarchar(1000), quotename(ss.name) + '.' + quotename(so.name)) as quoted_name
        ,so.[type] as type_code
        ,so.type_desc as table_type
        ,so.create_date
        ,so.modify_date
        ,isnull(filegroup_name(st.filestream_data_space_id), 'PRIMARY') as file_group
    from sys.objects so
    left join sys.tables st
        on so.object_id = st.object_id
    left join sys.schemas ss
        on ss.schema_id = so.schema_id
    where so.type in ('U', 'V')
    and ss.name not in ('sys')
    order by 6, 3, 4
) sq
left join rowcounts rc
    on sq.object_id = rc.object_id
go
