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
--                  - CREATE OR ALTER
--------------------------------------------------------------------------------
create or alter proc [dbo].[script_definition]
    @database_name nvarchar(128)
    ,@script_type nvarchar(100)
    ,@object_schema nvarchar(128) = null
    ,@object_name nvarchar(128) = null
    ,@tab_replacement varchar(10) = null
as
begin

set nocount on

-- Temporarily uncomment for inline testing
--declare @database_name nvarchar(128) = 'master'
--      , @script_type nvarchar(100) = 'drop and create'
--      , @object_schema nvarchar(128) = null
--      , @object_name nvarchar(128) = null

if @script_type not in ('CREATE', 'DROP', 'DROP AND CREATE', 'CREATE OR ALTER') begin
    raiserror('The @script_type values supported are ''CREATE'', ''DROP'', ''DROP AND CREATE'', and ''CREATE OR ALTER''', 16, 10)
    return
end

set @tab_replacement = isnull(@tab_replacement, char(9))

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


-- get definitions ============================================================
declare @defs table (
    object_id int not null
    ,object_catalog nvarchar(128) not null
    ,object_schema nvarchar(128) not null
    ,object_name nvarchar(128) not null
    ,quoted_name nvarchar(500) not null
    ,object_definition nvarchar(max) null
    ,uses_ansi_nulls bit null
    ,uses_quoted_identifier bit null
    ,is_schema_bound bit null
    ,object_type_code char(2) null
    ,object_type varchar(10) not null
    ,object_language varchar(10) not null
)

set @sql = 'use ' + quotename(@database_name) + '
select so.object_id as object_id
     , db_name() as object_catalog
     , schema_name(so.schema_id) as object_schema
     , so.name as object_name
     , quotename(schema_name(so.schema_id)) + ''.'' + quotename(so.name) as quoted_name
     , sm.definition as object_definition
     , sm.uses_ansi_nulls
     , sm.uses_quoted_identifier
     , sm.is_schema_bound
     , so.type as object_type_code
     , case when so.type in (''V'') then ''VIEW''
            when so.type in (''P'', ''PC'') then ''PROCEDURE''
            else ''FUNCTION''
       end as object_type
     , case when so.type in (''V'', ''P'', ''FN'', ''TF'', ''IF'') then ''SQL''
            else ''EXTERNAL''
       end as object_language
from sys.objects so
left join sys.sql_modules sm
  on sm.object_id = so.object_id
where so.type in (''V'', ''P'', ''FN'', ''TF'', ''IF'', ''AF'', ''FT'', ''IS'', ''PC'', ''FS'')
order by 1, 2, 3
'

insert into @defs
exec sp_executesql @sql

-- whittle down
delete from @defs
where (@object_schema is not null and object_schema <> @object_schema)
or (@object_name is not null and object_name <> @object_name)

-- standardize on newlines for split
update @defs
set object_definition = replace(object_definition, char(13) + char(10), char(10))

-- standardize tabs
if @tab_replacement <> char(9) begin
    update @defs
    set object_definition = replace(object_definition, char(9), @tab_replacement)
end

-- result ======================================================================
declare @result table (
    object_catalog nvarchar(128)
    ,object_schema nvarchar(128)
    ,object_name nvarchar(128)
    ,object_type nvarchar(128)
    ,seq int
    ,ddl nvarchar(max)
)


-- header ======================================================================
insert into @result (
    object_catalog
    ,object_schema
    ,object_name
    ,object_type
    ,seq
    ,ddl
)
select
    a.object_catalog
    ,a.object_schema
    ,a.object_name
    ,a.object_type
    ,100000000 + b.seq
    ,case b.seq
        when 1 then 'USE ' + quotename(a.object_catalog)
        when 2 then 'GO'
        when 3 then ''
    end as ddl
from @defs a
cross apply (select 1 as seq union
             select 2 union
             select 3) b


-- drops =======================================================================
if @has_drop = 1 begin
    insert into @result (
        object_catalog
        ,object_schema
        ,object_name
        ,object_type
        ,seq
        ,ddl
    )
    select
        a.object_catalog
        ,a.object_schema
        ,a.object_name
        ,a.object_type
        ,200000000 + b.seq
        ,case b.seq
            when 1 then '/****** Object:  ' +
                case a.object_type
                    when 'VIEW' then 'View'
                    when 'PROCEDURE' then 'StoredProcedure'
                    when 'FUNCTION' then 'UserDefinedFunction'
                    else ''
                end + ' ' + a.quoted_name + '    Script Date: ' + format(getdate(), 'M/d/yyyy h:mm:ss tt') + ' ******/'
            when 2 then 'DROP ' + a.object_type + ' ' + a.quoted_name
            when 3 then 'GO'
            when 4 then ''
        end as ddl
    from @defs a
    cross apply (select 1 as seq union
                 select 2 union
                 select 3 union
                 select 4) b
end

-- Parse DDL into one record per line ==========================================
-- I could use string_split but the documentation does not specify that order is
-- preserved, and that is crucial to this parse. Also, string_split is 2016+.
if @has_definition = 1 begin
    declare @ddl_parse table (
        object_id int
        ,seq int
        ,start_idx int
        ,end_idx int
    )

    declare @rc int = -1
    declare @seq int = 1
    while @rc <> 0 begin
        insert into @ddl_parse (
            object_id
            ,seq
            ,start_idx
            ,end_idx
        )
        select 
            d.object_id
            ,@seq as seq
            ,isnull(p.end_idx, 0) + 1 as start_idx
            ,isnull(nullif(charindex(char(10), d.object_definition, isnull(p.end_idx, 0) + 1), 0), len(d.object_definition) + 1) as end_idx
        from @defs d
        left join @ddl_parse p
            on d.object_id = p.object_id
            and p.seq = @seq - 1
        where @seq = 1
           or p.end_idx <= len(d.object_definition)

        set @rc = @@rowcount
        set @seq = @seq + 1
    end

    -- Add DDL lines to result =================================================
    insert into @result (
        object_catalog
        ,object_schema
        ,object_name
        ,object_type
        ,seq
        ,ddl
    )
    select d.object_catalog
         , d.object_schema
         , d.object_name
         , d.object_type
         , p.seq + 500000000  -- start with a high sequence so that we can add header/footer sql
         , substring(d.object_definition, p.start_idx, p.end_idx - p.start_idx) as ddl
    from @defs d
    join @ddl_parse p
            on d.object_id = p.object_id
    order by d.object_id, p.seq

    -- Wrap the SQL statements with boiler plate ===============================
    insert into @result (
        object_catalog
        ,object_schema
        ,object_name
        ,object_type
        ,seq
        ,ddl
    )
    select
        a.object_catalog
        ,a.object_schema
        ,a.object_name
        ,a.object_type
        ,300000000 + b.seq
        ,case b.seq
            when 1 then '/****** Object:  ' +
                case a.object_type
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
        from @defs a
        cross apply (select 1 as seq union
                     select 2 union
                     select 3 union
                     select 4 union
                     select 5 union
                     select 6 union
                     select 7) b

        insert into @result (
            object_catalog
            ,object_schema
            ,object_name
            ,object_type
            ,seq
            ,ddl
        )
        select
            a.object_catalog
            ,a.object_schema
            ,a.object_name
            ,a.object_type
            ,800000000 + b.seq
            ,case b.seq
                when 1 then 'GO'
                when 2 then ''
            end as ddl
        from @defs a
        cross apply (select 1 as seq union
                     select 2) b
end

-- Fix the create statement ====================================================
if @script_type in ('alter', 'create or alter') begin
    ;with cte as (
        select *
             , row_number() over (partition by object_schema, object_name
                                  order by seq) as rn
        from (
            select *
                 , patindex('%create%' + case when object_type = 'PROCEDURE' then 'PROC' else object_type end + '%' + object_schema + '%.%' + object_name + '%', ddl) as create_idx
            from @result
        ) a
        where create_idx > 0
    )
    update cte
    set ddl = stuff(ddl, create_idx, 6, @script_type)
    where rn = 1
end

-- Return the result data ======================================================
select *
from @result r
order by 1, 2, 3, 4, 5

end
go
