use master
go
--------------------------------------------------------------------------------
-- Proc:        script_definition
-- Author:      mattmc3
-- Version:     2017-09-16
-- Description: Generates SQL scripts for objects with SQL definitions.
--              Specifically views, sprocs, and user defined funcs.
--              Mimics SSMS scripting behavior.
-- Params:      @database_name nvarchar(128): Name of the database
--              @script_type nvarchar(100): The type of script to generate:
--                  - CREATE
--                  - ALTER
--                  - DROP
--                  - DROP AND CREATE
--------------------------------------------------------------------------------
--create or alter proc script_definition
--    @database_name nvarchar(128)
--    ,@script_type nvarchar(100)
--    ,@object_schema nvarchar(128) = null
--    ,@object_name nvarchar(128) = null
--as
--begin

set nocount on

-- Temporarily uncomment for inline testing
declare @database_name nvarchar(128) = 'outcomes_mart'
      , @script_type nvarchar(100) = 'drop and create'
      , @object_schema nvarchar(128) = null
      , @object_name nvarchar(128) = null

declare @sql nvarchar(max)
      , @has_drop bit = 0
      , @has_definition bit = 1

if @object_name is not null begin
    set @object_schema = isnull(@object_schema, 'dbo')
end

if @script_type in ('drop', 'drop and create') begin
    set @has_drop = 1
end

if @script_type in ('drop') begin
    set @has_definition = 0  -- false
end


-- get view information ========================================================
-- via sp_helptext 'information_schema.views' in master
drop table if exists ##__script_definition__view_info
select *
into ##__script_definition__view_info
from (
    select top 2147483647
           db_name() as table_catalog
         , schema_name(schema_id) as table_schema
         , name as table_name
         , convert(varchar(7), case with_check_option when 1 then 'CASCADE' else 'NONE' end) as check_option
      from sys.views
      order by 1, 2, 3
) a where 1 = 0
set @sql = 'use ' + quotename(@database_name) + '
insert into ##__script_definition__view_info
select *
from (
    select top 2147483647
           db_name() as table_catalog
         , schema_name(schema_id) as table_schema
         , name as table_name
         , convert(varchar(7), case with_check_option when 1 then ''CASCADE'' else ''NONE'' end) as check_option
      from sys.views
      order by 1, 2, 3
) a
'
exec(@sql)
drop table if exists #view_info
select *, quotename(table_schema) + '.' + quotename(table_name) as quoted_name
into #view_info
from ##__script_definition__view_info
drop table if exists ##__script_definition__view_info


-- get routine information =====================================================
-- via sp_helptext 'information_schema.routines' in master
drop table if exists ##__script_definition__routine_info
select *
into ##__script_definition__routine_info
from (
    select top 2147483647
           db_name() as routine_catalog
         , schema_name(o.schema_id) as routine_schema
         , o.name as routine_name
         , convert(nvarchar(20), case when o.type in ('P','PC') then 'PROCEDURE' else 'FUNCTION' end) as routine_type
         , convert(nvarchar(30), case when o.type in ('P ', 'FN', 'TF', 'IF') then 'SQL' else 'EXTERNAL' end) as routine_body
         , o.create_date as created
         , o.modify_date as last_altered
    from sys.objects o
    left join sys.parameters c
        on c.object_id = o.object_id and c.parameter_id = 0
    where o.type in ('P', 'FN', 'TF', 'IF', 'AF', 'FT', 'IS', 'PC', 'FS')
    order by 1, 2, 3
) a
where 1 = 0
set @sql = 'use ' + quotename(@database_name) + '
insert into ##__script_definition__routine_info
select *
from (
    select top 2147483647
           db_name() as routine_cataloga
         , schema_name(o.schema_id) as routine_schema
         , o.name as routine_name
         , convert(nvarchar(20), case when o.type in (''P'',''PC'') then ''PROCEDURE'' else ''FUNCTION'' end) as routine_type
         , convert(nvarchar(30), case when o.type in (''P '', ''FN'', ''TF'', ''IF'') then ''SQL'' else ''EXTERNAL'' end) as routine_body
         , o.create_date as created
         , o.modify_date as last_altered
    from sys.objects o
    left join sys.parameters c
        on c.object_id = o.object_id and c.parameter_id = 0
    where o.type in (''P'', ''FN'', ''TF'', ''IF'', ''AF'', ''FT'', ''IS'', ''PC'', ''FS'')
    order by 1, 2, 3
) a
'
exec(@sql)
drop table if exists #routine_info
select *, quotename(routine_schema) + '.' + quotename(routine_name) as quoted_name
into #routine_info
from ##__script_definition__routine_info
drop table if exists ##__script_definition__routine_info


-- result ======================================================================
drop table if exists #result
create table #result (
    object_catalog nvarchar(128)
    ,object_schema nvarchar(128)
    ,object_name nvarchar(128)
    ,object_type nvarchar(128)
    ,seq int
    ,ddl nvarchar(max)
)

drop table if exists #objects
select *
into #objects
from (
    select table_catalog as obj_catalog
         , table_schema as obj_schema
         , table_name as obj_name
         , 'VIEW' as obj_type
         , quoted_name
    from #view_info
    union all
    select routine_catalog as obj_catalog
         , routine_schema as obj_schema
         , routine_name as obj_name
         , routine_type as obj_type
         , quoted_name
    from #routine_info r
    where r.routine_body = 'SQL'
) a
where (@object_schema is null or obj_schema = @object_schema)
and (@object_name is null or obj_name = @object_name)


-- header ======================================================================
insert into #result (
    object_catalog
    ,object_schema
    ,object_name
    ,object_type
    ,seq
    ,ddl
)
select
    a.obj_catalog
    ,a.obj_schema
    ,a.obj_name
    ,a.obj_type
    ,100000000 + b.seq
    ,case b.seq
        when 1 then 'USE ' + quotename(a.obj_catalog)
        when 2 then 'GO'
        when 3 then ''
    end as ddl
from #objects a
cross apply (select 1 as seq union
             select 2 union
             select 3) b


-- drops =======================================================================
if @has_drop = 1 begin
    insert into #result (
        object_catalog
        ,object_schema
        ,object_name
        ,object_type
        ,seq
        ,ddl
    )
    select
        a.obj_catalog
        ,a.obj_schema
        ,a.obj_name
        ,a.obj_type
        ,200000000 + b.seq
        ,case b.seq
            when 1 then '/****** Object:  ' +
                case a.obj_type
                    when 'VIEW' then 'View'
                    when 'PROCEDURE' then 'StoredProcedure'
                    when 'FUNCTION' then 'UserDefinedFunction'
                    else ''
                end + ' ' + a.quoted_name + '    Script Date: ' + format(getdate(), 'M/d/yyyy h:mm:ss tt') + ' ******/'
            when 2 then 'DROP ' + a.obj_type + ' ' + a.quoted_name
            when 3 then 'GO'
            when 4 then ''
        end as ddl
    from #objects a
    cross apply (select 1 as seq union
                 select 2 union
                 select 3 union
                 select 4) b
end


-- definition ==================================================================
if @has_definition = 1 begin
    drop table if exists ##__script_definition__def
    create table ##__script_definition__def (
        seq int identity(1,1)
        ,ddl nvarchar(max)
    )

    declare @obj_catalog nvarchar(128)
          , @obj_schema nvarchar(128)
          , @obj_name nvarchar(128)
          , @obj_type nvarchar(128)
          , @quoted_name nvarchar(500)
          , @ddl nvarchar(max)

    declare @ddl_combined table (
        ddl nvarchar(max)
    )

    drop table if exists #ddl_lines
    create table #ddl_lines (
        seq int identity(1,1)
        ,ddl nvarchar(max)
    )

    declare @cur cursor
    set @cur = cursor local fast_forward for
        select obj_catalog, obj_schema, obj_name, obj_type, quoted_name
        from #objects
        order by 1, 2
    open @cur

    fetch next from @cur into @obj_catalog, @obj_schema, @obj_name, @obj_type, @quoted_name
    while @@fetch_status = 0 begin
        truncate table ##__script_definition__def
        set @sql = 'use ' + quotename(@database_name) + '
    insert into ##__script_definition__def (ddl)
    exec sp_helptext ''' + @quoted_name + ''''
        exec(@sql)

        -- sp_help text makes each line 256 characters long, and splits on crlf (\r\n),
        -- but if your definition uses just newlines (\n), then it mashes everything
        -- together. This part normalizes to \n, combines the script into a variable,
        -- puts that variable in a table so that we can cross apply with a string_split
        -- on the newline, and leverages an identity to preserve the order.
        update ##__script_definition__def
        set ddl = replace(ddl, char(13) + char(10), char(10))

        -- combine into variable
        set @ddl = ''
        select @ddl = @ddl + ddl
        from ##__script_definition__def
        order by seq

        -- put variable into table
        delete from @ddl_combined
        insert into @ddl_combined (ddl)
        select @ddl

        -- split script back out into proper lines
        truncate table #ddl_lines
        insert into #ddl_lines (ddl)
        select ca.value
        from @ddl_combined
        cross apply string_split(ddl, char(10)) ca

        insert into #result (
            object_catalog
            ,object_schema
            ,object_name
            ,object_type
            ,seq
            ,ddl
        )
        select
            @obj_catalog
            ,@obj_schema
            ,@obj_name
            ,@obj_type
            ,seq + 500000000  -- start with a high sequence so that we can add sql
            ,ddl
        from #ddl_lines
        order by seq

        fetch next from @cur into @obj_catalog, @obj_schema, @obj_name, @obj_type, @quoted_name
    end
    drop table if exists ##__script_definition__def


    -- Wrap the SQL statements with boiler plate ===============================
    insert into #result (
        object_catalog
        ,object_schema
        ,object_name
        ,object_type
        ,seq
        ,ddl
    )
    select
        a.obj_catalog
        ,a.obj_schema
        ,a.obj_name
        ,a.obj_type
        ,300000000 + b.seq
        ,case b.seq
            when 1 then '/****** Object:  ' +
                case a.obj_type
                    when 'VIEW' then 'View'
                    when 'PROCEDURE' then 'StoredProcedure'
                    when 'FUNCTION' then 'UserDefinedFunction'
                    else ''
                end + ' ' + a.quoted_name + '    Script Date: ' + format(getdate(), 'M/d/yyyy h:mm:ss tt') + ' ******/'
            when 2 then 'SET ANSI_NULLS ON'
            when 3 then 'GO'
            when 4 then ''
            when 5 then 'SET QUOTED_IDENTIFIER ON'
            when 6 then 'GO'
            when 7 then ''
        end as ddl
        from #objects a
        cross apply (select 1 as seq union
                     select 2 union
                     select 3 union
                     select 4 union
                     select 5 union
                     select 6 union
                     select 7) b

        insert into #result (
            object_catalog
            ,object_schema
            ,object_name
            ,object_type
            ,seq
            ,ddl
        )
        select
            a.obj_catalog
            ,a.obj_schema
            ,a.obj_name
            ,a.obj_type
            ,800000000 + b.seq
            ,case b.seq
                when 1 then 'GO'
                when 2 then ''
            end as ddl
        from #objects a
        cross apply (select 1 as seq union
                     select 2) b
end

-- Return the result data ======================================================
select *
from #result r
order by 1, 2, 3, 4, 5

--end
--go

--exec master.dbo.script_definition 'outcomes_mart', 'drop'
--exec master.dbo.script_definition 'outcomes_mart', 'create', @object_name = 'regex_matches'
--exec master.dbo.script_definition 'outcomes_mart', 'drop and create'

