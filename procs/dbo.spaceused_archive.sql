create table spaceused_archive (
    id int identity(1,1) not null
    ,created_on datetime
    ,object_id int
    ,table_catalog varchar(128)
    ,table_schema varchar(128)
    ,table_name varchar(128)
    ,row_count bigint
    ,reserved_size_kb bigint
    ,data_size_kb bigint
    ,index_size_kb bigint
    ,unused_size_kb bigint
)

create index ix_created_on on spaceused_archive (created_on)
create index ix_table_id on spaceused_archive (object_id, table_catalog)
create index ix_table_name on spaceused_archive (table_name, table_schema, table_catalog)
go
--------------------------------------------------------------------------------
-- Author: mattmc
-- Created: 2017-09-19
-- Description: Takes snapshots of sp_spaceused
--------------------------------------------------------------------------------
create or alter proc dbo.p_persist_sp_spaceused as

set nocount on

declare @dbname varchar(200)
      , @sql varchar(max)
      , @now datetime = getdate()

declare @spaceused table (
    name varchar(500)
    ,rows int
    ,reserved varchar(50)
    ,data varchar(50)
    ,index_size varchar(50)
    ,unused varchar(50)
)

declare @tables table (
    object_id int
    ,table_catalog nvarchar(128)
    ,table_schema nvarchar(128)
    ,table_name nvarchar(128)
    ,quotedname nvarchar(500)
)

-- keep everything for 30 days, but clean up prior months keeping only the
-- most recent readout from that month
;with d as (
    select *
    from (
        select x.id
             , row_number() over (partition by year(created_on), month(created_on)
                                  order by created_on desc) as row_num
        from dbo.spaceused_archive x
        where x.created_on < dateadd(day, -30, @now)
    ) y
    where y.row_num <> 1
)
delete from d

-- loop through all the databases and tables calling sp_spaceused
declare @c cursor
set @c = cursor local fast_forward for
    select name as dbname
    from sys.databases
    where name <> 'tempdb'
    and state = 0
open @c

fetch next from @c into @dbname
while @@fetch_status = 0 begin
    delete from @spaceused
    set @sql = @dbname + '..sp_msforeachtable ''exec sp_spaceused [?]'''
    insert into @spaceused
    exec(@sql)

    set @sql = '
select o.object_id
     , ''' + @dbname + ''' as table_catalog
     , s.name as table_schema
     , o.name as table_name
     , quotename(s.name) + ''.'' + quotename(o.name) as quotedname
  from ' + quotename(@dbname) + '.sys.objects o
  join ' + quotename(@dbname) + '.sys.schemas s
    on o.schema_id = s.schema_id
 where o.type IN (''U'')
 order by 2, 3, 4'

    insert into @tables
    exec(@sql)

    insert into dbo.spaceused_archive (
        object_id
        ,created_on
        ,table_catalog
        ,table_schema
        ,table_name
        ,row_count
        ,reserved_size_kb
        ,data_size_kb
        ,index_size_kb
        ,unused_size_kb
    )
    select t.object_id
         , @now
         , t.table_catalog
         , t.table_schema
         , isnull(t.table_name, s.name)
         , replace(s.rows, ' KB', '')
         , replace(s.reserved, ' KB', '')
         , replace(s.data, ' KB', '')
         , replace(s.index_size, ' KB', '')
         , replace(s.unused, ' KB', '')
    from @spaceused s
    left join @tables t
        on s.name = t.quotedname

    fetch next from @c into @dbname
end
close @c
deallocate @c
go
