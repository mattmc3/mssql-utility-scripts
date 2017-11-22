use master
go
create or alter proc dbo.standardize_index_names
    @dbname sysname
    ,@dry_run bit = 0
as

set nocount on

-- POPULATE #idx FROM sys.indexes IN THE SPECIFIED DATABASE
declare @sql nvarchar(max)
      , @NL nvarchar(max) = nchar(13) + nchar(10)

set @sql = '
use ' + @dbname + '
insert into ##__D63E49D_sys_indexes (
    object_id
    ,index_id
    ,schema_id
    ,table_schema
    ,table_name
    ,index_name
    ,type
    ,type_desc
    ,is_primary_key
    ,is_unique
    ,is_unique_constraint
    ,is_padded
    ,allow_row_locks
    ,allow_page_locks
    ,is_ms_shipped
)
select si.object_id
     , si.index_id
     , ss.schema_id
     , ss.name as table_schema
     , st.name as table_name
     , si.name as index_name
     , si.type
     , si.type_desc
     , si.is_primary_key
     , si.is_unique
     , si.is_unique_constraint
     , si.is_padded
     , si.allow_row_locks
     , si.allow_page_locks
     , st.is_ms_shipped
  from sys.indexes si
  join sys.tables st  on si.object_id = st.object_id
  join sys.schemas ss on ss.schema_id = st.schema_id
 where si.type <> 0
'

drop table if exists ##__D63E49D_sys_indexes
create table ##__D63E49D_sys_indexes (
    object_id int
    ,index_id int
    ,schema_id int
    ,table_schema sysname
    ,table_name sysname
    ,index_name sysname
    ,type tinyint
    ,type_desc nvarchar(60)
    ,is_primary_key bit
    ,is_unique bit
    ,is_unique_constraint bit
    ,is_padded bit
    ,allow_row_locks bit
    ,allow_page_locks bit
    ,is_ms_shipped bit
)
exec sp_executesql @sql
drop table if exists #idx
select *
into #idx
from ##__D63E49D_sys_indexes a
where a.is_ms_shipped = 0
  and a.table_name not in ('sysdiagrams')
  and a.table_schema not in ('sys')
drop table if exists ##__D63E49D_sys_indexes

-- POPULATE #idx_cols FROM sys.indexes_columns IN THE SPECIFIED DATABASE
set @sql = '
use ' + @dbname + '
insert into ##__D35DFFE9__index_columns (
     object_id
    ,index_id
    ,column_id
    ,column_name
    ,index_column_id
    ,is_descending_key
    ,is_included_column
    ,key_ordinal
    ,partition_ordinal
)
select si.object_id
     , si.index_id
     , sic.column_id
     , sc.name as column_name
     , sic.index_column_id
     , sic.is_descending_key
     , sic.is_included_column
     , sic.key_ordinal
     , sic.partition_ordinal
  from sys.indexes si
  join sys.index_columns sic on si.object_id = sic.object_id
                            and si.index_id = sic.index_id
  join sys.columns sc        on sc.object_id = sic.object_id
                            and sc.column_id = sic.column_id
'

create table ##__D35DFFE9__index_columns (
     object_id int
    ,index_id int
    ,column_id int
    ,column_name sysname
    ,index_column_id int
    ,is_descending_key bit
    ,is_included_column bit
    ,key_ordinal tinyint
    ,partition_ordinal tinyint
)

exec sp_executesql @sql
drop table if exists #idx_cols
select *
into #idx_cols
from ##__D35DFFE9__index_columns a
drop table if exists ##__D35DFFE9__index_columns

-- pivot to get the columns used in the index. MSSQL has a hard limit of 16 cols
drop table if exists #pvt_cols
select pic.object_id
     , pic.index_id
     , max([1]) as index_column01
     , max([2]) as index_column02
     , max([3]) as index_column03
     , max([4]) as index_column04
     , max([5]) as index_column05
     , max([6]) as index_column06
     , max([7]) as index_column07
     , max([8]) as index_column08
     , max([9]) as index_column09
     , max([10]) as index_column10
     , max([11]) as index_column11
     , max([12]) as index_column12
     , max([13]) as index_column13
     , max([14]) as index_column14
     , max([15]) as index_column15
     , max([16]) as index_column16
into #pvt_cols
from (
    select x.object_id
         , x.index_id
         , row_number() over (partition by x.object_id, x.index_id
                              order by x.index_column_id) as ord
         , x.column_name
    from #idx_cols as x
    where x.is_included_column = 0
) ic
pivot (max(ic.column_name) for ic.ord in (
     [1],  [2],  [3],  [4],
     [5],  [6],  [7],  [8],
     [9], [10], [11], [12],
    [13], [14], [15], [16])) as pic
group by
      pic.object_id
    , pic.index_id

-- get the included column count
drop table if exists #idx_incl
select a.object_id
     , a.index_id
     , count(*) as included_cols_count
into #idx_incl
from #idx_cols a
where a.is_included_column = 1
group by a.object_id, a.index_id

drop table if exists #new
select i.*
     , cast(
       case when i.is_primary_key = 1 then 'pk_'
            when i.is_unique_constraint = 1 then 'un_'
            when i.is_unique = 1 then 'ux_'
            when i.type = 1 then 'cx_'
            else 'ix_'
       end as nvarchar(50)) as prefix
     , case when i.is_primary_key = 1 then i.table_name + '__'
            when i.is_unique_constraint = 1 then i.table_name + '__'
            else ''
        end +
        isnull(pc.index_column01, '') +
        isnull('__' + pc.index_column02, '') +
        isnull('__' + pc.index_column03, '') +
        isnull('__' + pc.index_column04, '') +
        isnull('__' + pc.index_column05, '') +
        isnull('__' + pc.index_column06, '') +
        isnull('__' + pc.index_column07, '') +
        isnull('__' + pc.index_column08, '') +
        isnull('__' + pc.index_column09, '') +
        isnull('__' + pc.index_column10, '') +
        isnull('__' + pc.index_column11, '') +
        isnull('__' + pc.index_column12, '') +
        isnull('__' + pc.index_column13, '') +
        isnull('__' + pc.index_column14, '') +
        isnull('__' + pc.index_column15, '') +
        isnull('__' + pc.index_column16, '') as new_index_name
     , cast(
       case when inc.included_cols_count is null then ''
            else '__inc' + cast(inc.included_cols_count as varchar(5))
       end as nvarchar(50)) as suffix
     ,cast(null as sysname) as new_index_fullname
into #new
from #idx i
join #pvt_cols pc on i.object_id = pc.object_id
                 and i.index_id = pc.index_id
left join #idx_incl as inc on i.object_id = inc.object_id
                          and i.index_id = inc.index_id

update #new
set suffix = '__etc' + suffix
where len(prefix) + len(new_index_name) + len(suffix) > 128

-- fix length to fit 128 chars
update #new
set new_index_name = left(new_index_name, 128 - len(prefix) - len(suffix))

-- Handle dupes
;with cte as (
    select *
         , row_number() over (partition by table_schema, table_name, prefix, new_index_name, suffix
                              order by index_id) as rn
    from #new
)
update cte
set prefix = stuff(prefix, 3, 0, cast(rn as varchar(10)))
where rn > 1

-- fix length to fit 128 chars again
update #new
set new_index_name = left(new_index_name, 128 - len(prefix) - len(suffix))

update #new
set new_index_fullname = prefix + new_index_name + suffix

-- make table of rename instructions
drop table if exists #instructions
select
    'exec sp_rename N''' + quotename(n.table_schema) + '.' + quotename(n.table_name) + '.' + quotename(n.index_name) + ''', N''' + new_index_fullname + ''', N''INDEX'';' as rename_sql
    ,case when n.index_name <> n.new_index_fullname COLLATE Latin1_General_CS_AS then 1
          else 0
     end as needs_renamed
    ,*
into #instructions
from #new n

if @dry_run = 1 begin
    select @dbname, *
    from #instructions
    order by table_schema, table_name, new_index_fullname

    return
end

-- loop through and execute the renames
declare @c cursor
      , @msg nvarchar(4000)

set @c = cursor local fast_forward for
    select i.rename_sql
    from #instructions i
    where i.needs_renamed = 1
    order by i.table_schema, i.table_name, i.new_index_fullname

open @c
fetch next from @c into @sql
while @@fetch_status = 0 begin
    set @msg = '{{timestamp}}: running sql - {{sql}}'
    set @msg = replace(replace(@msg,
                   '{{timestamp}}', sysdatetimeoffset())
                   ,'{{sql}}', @sql)
    print @msg

    set @sql = 'use ' + @dbname + @NL + @sql
    exec sp_executesql @sql

    fetch next from @c into @sql
end

-- Clean up cursor
close @c
deallocate @c

go
