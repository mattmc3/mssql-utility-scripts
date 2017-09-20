use master
go
--------------------------------------------------------------------------------
-- Proc:        script_table
-- Author:      mattmc3
-- Version:     2017-09-16
-- Description: Generates SQL scripts for tables. Mimics SSMS "Script Table as"
--              behavior.
-- Params:      @database_name nvarchar(128): Name of the database
--              @script_type nvarchar(100): The type of script to generate:
--                  - SELECT
--                  - INSERT
--                  - UPDATE
--                  - DELETE
--                  - CREATE
--                  - ALTER
--                  - DROP
--                  - DROP AND CREATE
--------------------------------------------------------------------------------
create or alter proc script_table
    @database_name nvarchar(128)
    ,@script_type nvarchar(100)
    ,@table_schema nvarchar(128) = null
    ,@table_name nvarchar(128) = null
as
begin

set nocount on

--declare @database_name nvarchar(128) = 'master'
--      , @script_type nvarchar(100) = 'update'
declare @sql nvarchar(max)
set @database_name = replace(@database_name, ']', ']]')

if @table_name is not null begin
    select @table_schema = isnull(@table_schema, 'dbo')
end

-- get table information =======================================================
-- via sp_helptext 'information_schema.tables' in master
drop table if exists ##__script_table__table_info
set @sql = 'use ' + @database_name + '
select *
into ##__script_table__table_info
from (
    select top 2147483647
        o.object_id     as mssql_object_id
        ,db_name()      as table_catalog
        ,s.name         as table_schema
        ,o.name         as table_name
        ,quotename(s.name) + ''.'' + quotename(o.name) as quoted_name
        ,case o.type
            when ''U'' then ''BASE TABLE''
            when ''V'' then ''VIEW''
        end as table_type
        ,o.create_date as created_at
        ,o.modify_date as updated_at
        ,isnull(filegroup_name(t.filestream_data_space_id), ''PRIMARY'') as file_group
    from sys.objects o
    left join sys.tables t
        on o.object_id = t.object_id
    left join sys.schemas s
        on s.schema_id = o.schema_id
    where o.type in (''U'', ''V'')
    order by 5, 3, 4
) a
'
exec(@sql)
drop table if exists #table_info
select * into #table_info from ##__script_table__table_info
drop table if exists ##__script_table__table_info


-- get column information ======================================================
-- via sp_helptext 'information_schema.columns' in master
drop table if exists ##__script_table__column_info
set @sql = 'use ' + @database_name + '
select
    *
    ,''('' +
     case
        when t.data_type in (''binary'', ''char'', ''nchar'', ''nvarchar'', ''varbinary'', ''varchar'')
        then isnull(nullif(cast(t.character_maximum_length as varchar(10)), ''-1''), ''max'')
        when t.data_type in (''decimal'', ''numeric'')
        then cast(t.numeric_precision as varchar(10)) + '','' + cast(t.numeric_scale as varchar(10))
        when t.data_type in (''datetime2'', ''datetimeoffset'', ''time'')
        then cast(t.datetime_precision as varchar(10))
        else null
    end + '')'' as data_type_size
    ,case when t.is_identity = 1 or t.is_computed = 1 or t.data_type = ''timestamp'' then 0 else 1 end as is_modifiable
into ##__script_table__column_info
from (
    select top 2147483647
        o.object_id as mssql_object_id
        ,c.column_id as mssql_column_id
        ,db_name() as table_catalog
        ,schema_name(o.schema_id) as table_schema
        ,o.name as table_name
        ,quotename(schema_name(o.schema_id)) + ''.'' + quotename(o.name) as quoted_name
        ,case o.type
            when ''U'' then ''BASE TABLE''
            when ''V'' then ''VIEW''
        end as table_type
        ,c.name as column_name
        ,columnproperty(c.object_id, c.name, ''ordinal'') as ordinal_position
        ,convert(nvarchar(4000), object_definition(c.default_object_id)) as column_default
        ,c.is_nullable as is_nullable
        ,isnull(type_name(c.system_type_id), t.name) as data_type
        ,columnproperty(c.object_id, c.name, ''charmaxlen'') as character_maximum_length
        ,convert(tinyint,
            case
                -- int/decimal/numeric/real/float/money
                when c.system_type_id in (48, 52, 56, 59, 60, 62, 106, 108, 122, 127)
                then c.precision
            end) as numeric_precision
        ,convert(int,
            case
                -- datetime/smalldatetime
                when c.system_type_id in (40, 41, 42, 43, 58, 61) then null
                else odbcscale(c.system_type_id, c.scale)
            end) as numeric_scale
        ,convert(smallint,
            case
                -- datetime/smalldatetime
                when c.system_type_id in (40, 41, 42, 43, 58, 61)
                then odbcscale(c.system_type_id, c.scale)
            end) as datetime_precision

        ,c.is_computed as is_computed
        ,cc.definition as computed_column_definition
        ,c.is_identity as is_identity
    from sys.objects o
    join sys.columns c                on c.object_id = o.object_id
    left join sys.types t             on c.user_type_id = t.user_type_id
    left join sys.computed_columns cc on cc.object_id = o.object_id
                                     and cc.column_id = c.column_id
    where o.type in (''U'', ''V'')
    order by 6, 4, 5, 8
) t
'
exec(@sql)
drop table if exists #column_info
select * into #column_info from ##__script_table__column_info
drop table if exists ##__script_table__column_info


-- result ======================================================================
drop table if exists #result
create table #result (
    table_catalog nvarchar(128)
    ,table_schema nvarchar(128)
    ,table_name nvarchar(128)
    ,table_type nvarchar(128)
    ,seq int
    ,ddl nvarchar(max)
)


-- DROP ========================================================================
if @script_type = 'DROP' begin
    insert into #result
    select top 2147483647 *
    from (

    -- use, go
    select t.table_catalog
         , t.table_schema
         , t.table_name
         , t.table_type
         , 100000000 + n.num as seq
         , case n.num
             when 1 then 'USE ' + quotename(t.table_catalog)
             when 2 then 'GO'
             when 3 then ''
             when 4 then '/****** Object:  ' + case when t.table_type = 'VIEW' then 'View' else 'Table' end + ' ' + t.quoted_name + '    Script Date: ' + format(getdate(), 'M/d/yyyy h:mm:ss tt') + ' ******/'
             when 5 then 'DROP ' + case when t.table_type = 'VIEW' then 'VIEW' else 'TABLE' end + ' ' + t.quoted_name
             when 6 then 'GO'
             when 7 then ''
           end as ddl
      from #table_info t
     cross apply (select 1 as num union
                  select 2 union
                  select 3 union
                  select 4 union
                  select 5 union
                  select 6 union
                  select 7) n
    ) a
end
-- DELETE ======================================================================
else if @script_type = 'DELETE' begin
    insert into #result
    select top 2147483647 *
    from (

    -- use, go
    select t.table_catalog
         , t.table_schema
         , t.table_name
         , t.table_type
         , 100000000 + n.num as seq
         , case n.num
             when 1 then 'USE ' + quotename(t.table_catalog)
             when 2 then 'GO'
             when 3 then ''
           end as ddl
      from #table_info t
     cross apply (select 1 as num union
                  select 2 union
                  select 3) n

    -- delete from
    union all
    select t.table_catalog
         , t.table_schema
         , t.table_name
         , t.table_type
         , 200000000 as seq
         , 'DELETE FROM ' + t.quoted_name as ddl
      from #table_info t

    -- where
    union all
    select t.table_catalog
         , t.table_schema
         , t.table_name
         , t.table_type
         , 300000000 as seq
         , space(6) + 'WHERE <Search Conditions,,>' as ddl
      from #table_info t

    -- end
    union all
    select t.table_catalog
         , t.table_schema
         , t.table_name
         , t.table_type
         , 999999000 + n.num as seq
         , case n.num
             when 1 then 'GO'
             when 2 then ''
           end as ddl
      from #table_info t
     cross apply (select 1 as num union
                  select 2) n

    ) a

end
-- INSERT ======================================================================
else if @script_type = 'INSERT' begin
    insert into #result
    select top 2147483647 *
    from (

    -- use, go, insert
    select t.table_catalog
         , t.table_schema
         , t.table_name
         , t.table_type
         , 100000000 + n.num as seq
         , case n.num
           when 1 then 'USE ' + quotename(t.table_catalog)
           when 2 then 'GO'
           when 3 then ''
           when 4 then 'INSERT INTO ' + t.quoted_name
           end as ddl
      from #table_info t
     cross apply (select 1 as num union
                  select 2 union
                  select 3 union
                  select 4) n

    -- columns
    union
    select c.table_catalog
         , c.table_schema
         , c.table_name
         , c.table_type
         , 200000000 + c.ordinal_position as seq
         , space(11) +
           case when c.ordinal_rank = 1 then '(' else ',' end +
           quotename(c.column_name) +
           case when c.ordinal_rank_desc = 1 then ')' else '' end
           as ddl
       from (select *
                  , row_number() over (partition by x.mssql_object_id
                                           order by x.ordinal_position) as ordinal_rank
                  , row_number() over (partition by x.mssql_object_id
                                           order by x.ordinal_position desc) as ordinal_rank_desc
               from #column_info x
              where x.is_modifiable = 1) c

    -- values keyword
    union
    select t.table_catalog
         , t.table_schema
         , t.table_name
         , t.table_type
         , 300000000 as seq
         , space(5) + 'VALUES' ddl
      from #table_info t

    -- insert values
    union
    select c.table_catalog
         , c.table_schema
         , c.table_name
         , c.table_type
         , 400000000 + c.ordinal_position as seq
         , space(11) +
           case when c.ordinal_rank = 1 then '(<' else ',<' end +
           c.column_name + ', ' + c.data_type + isnull(c.data_type_size, '') + ',>' +
           case when c.ordinal_rank_desc = 1 then ')' else '' end
           as ddl
       from (select *
                  , row_number() over (partition by x.mssql_object_id
                                           order by x.ordinal_position) as ordinal_rank
                  , row_number() over (partition by x.mssql_object_id
                                           order by x.ordinal_position desc) as ordinal_rank_desc
               from #column_info x
              where x.is_modifiable = 1
        ) c

    -- close
    union
    select t.table_catalog
         , t.table_schema
         , t.table_name
         , t.table_type
         , 900000000 + n.num as seq
         , case n.num
           when 1 then 'GO'
           when 2 then ''
           end as ddl
      from #table_info t
     cross apply (select 1 as num union
                  select 2) n

    ) a

end
-- SELECT ======================================================================
else if @script_type = 'SELECT' begin
    insert into #result
    select top 2147483647 *
    from (

    -- use, go
    select t.table_catalog
         , t.table_schema
         , t.table_name
         , t.table_type
         , 100000000 + n.num as seq
         , case n.num
             when 1 then 'USE ' + quotename(t.table_catalog)
             when 2 then 'GO'
             when 3 then ''
           end as ddl
      from #table_info t
     cross apply (select 1 as num union
                  select 2 union
                  select 3) n

    -- select, columns
    union all
    select c.table_catalog
         , c.table_schema
         , c.table_name
         , c.table_type
         , 200000000 + c.ordinal_position as seq
         , case when c.ordinal_position = 1 then 'SELECT '
                else space(6) + ','
           end + quotename(c.column_name) as ddl
      from #column_info c

    -- from
    union all
    select t.table_catalog
         , t.table_schema
         , t.table_name
         , t.table_type
         , 300000000 as seq
         , 'FROM ' + t.quoted_name as ddl
      from #table_info t

    -- end
    union all
    select t.table_catalog
         , t.table_schema
         , t.table_name
         , t.table_type
         , 999999000 + n.num as seq
         , case n.num
             when 1 then 'GO'
             when 2 then ''
           end as ddl
      from #table_info t
     cross apply (select 1 as num union
                  select 2) n

    ) a

end
-- UPDATE ======================================================================
else if @script_type = 'UPDATE' begin
    insert into #result
    select top 2147483647 *
    from (

    -- use, go, insert
    select t.table_catalog
         , t.table_schema
         , t.table_name
         , t.table_type
         , 100000000 + n.num as seq
         , case n.num
           when 1 then 'USE ' + quotename(t.table_catalog)
           when 2 then 'GO'
           when 3 then ''
           when 4 then 'UPDATE ' + t.quoted_name
           end as ddl
      from #table_info t
     cross apply (select 1 as num union
                  select 2 union
                  select 3 union
                  select 4) n

    -- columns
    union
    select c.table_catalog
         , c.table_schema
         , c.table_name
         , c.table_type
         , 200000000 + c.ordinal_position as seq
         , space(3) +
           case when c.ordinal_rank = 1 then 'SET ' else space(3) + ',' end +
           quotename(c.column_name) + ' = ' +
           '<' + c.column_name + ', ' + c.data_type + isnull(c.data_type_size, '') + ',>'
           as ddl
       from (select *
                  , row_number() over (partition by x.mssql_object_id
                                           order by x.ordinal_position) as ordinal_rank
               from #column_info x
              where x.is_modifiable = 1) c

    -- where
    union
    select t.table_catalog
         , t.table_schema
         , t.table_name
         , t.table_type
         , 300000000 as seq
         , ' WHERE <Search Conditions,,>' as ddl
      from #table_info t

    -- close
    union
    select t.table_catalog
         , t.table_schema
         , t.table_name
         , t.table_type
         , 900000000 + n.num as seq
         , case n.num
           when 1 then 'GO'
           when 2 then ''
           end as ddl
      from #table_info t
     cross apply (select 1 as num union
                  select 2) n

    ) a
end
else begin
    declare @msg nvarchar(max)
    set @msg = 'Unsupported @script_type: ' + isnull(@script_type, '<NULL>')
    raiserror(@msg, 16, 10)
    return
end

-- Return the result data ======================================================
select *
from #result r
where (@table_name is null or r.table_name = @table_name)
and (@table_schema is null or r.table_schema = @table_schema)
order by 1, 2, 3, 4, 5

end
go

exec master.dbo.script_table 'outcomes_mart', 'SELECT'
exec master.dbo.script_table 'outcomes_mart', 'INSERT'
exec master.dbo.script_table 'outcomes_mart', 'UPDATE'
exec master.dbo.script_table 'outcomes_mart', 'DELETE'
exec master.dbo.script_table 'outcomes_mart', 'DROP'
