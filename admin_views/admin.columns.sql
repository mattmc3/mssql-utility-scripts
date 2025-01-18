create or alter view admin.columns as
--------------------------------------------------------------------------------
-- Author: mattmc
-- Ver: v1.0.0
-- Description: enhanced version of information_schema.columns
-- Notes: start with sp_helptext 'information_schema.columns'
--------------------------------------------------------------------------------
select
    t.*
    ,t.data_type +
     case
        when t.data_type in ('binary', 'char', 'nchar', 'nvarchar', 'varbinary', 'varchar')
        then '(' + isnull(nullif(cast(t.character_maximum_length as varchar(10)), '-1'), 'max') + ')'
        when t.data_type in ('decimal', 'numeric')
        then '(' + cast(t.numeric_precision as varchar(10)) + ',' + cast(t.numeric_scale as varchar(10)) + ')'
        when t.data_type in ('datetime2', 'datetimeoffset', 'time')
        then '(' +cast(t.datetime_precision as varchar(10)) + ')'
        else ''
    end as data_type_sql
    ,case when t.is_identity = 1 or t.is_computed = 1 or t.data_type = 'timestamp' then 0 else 1 end as is_modifiable
from (
    select top 2147483647
        o.object_id as object_id
        ,db_name() as db_name
        ,o.schema_id
        ,schema_name(o.schema_id) as schema_name
        ,o.name as table_name
        ,o.[type] as type_code
        ,o.type_desc
        ,c.column_id as column_id
        ,c.name as column_name
        ,columnproperty(c.object_id, c.name, 'ordinal') as ordinal_position
        ,convert(nvarchar(4000), object_definition(c.default_object_id)) as column_default
        ,c.is_nullable as is_nullable
        ,isnull(type_name(c.system_type_id), t.name) as data_type
        ,columnproperty(c.object_id, c.name, 'charmaxlen') as character_maximum_length
        ,convert(tinyint,
            case
                -- tinyint/smallint/int/decimal/numeric/real/float/money/bigint/etc
                when c.system_type_id in (48, 52, 56, 59, 60, 62, 106, 108, 122, 127)
                then c.precision
            end) as numeric_precision
        ,convert(int,
            case
                -- date/time types
                when c.system_type_id in (40, 41, 42, 43, 58, 61) then null
                else odbcscale(c.system_type_id, c.scale)
            end) as numeric_scale
        ,convert(smallint,
            case
                -- date/time types
                when c.system_type_id in (40, 41, 42, 43, 58, 61)
                then odbcscale(c.system_type_id, c.scale)
            end) as datetime_precision

        ,convert(sysname,
            case
                -- char/varchar/text
                when c.system_type_id in (35, 167, 175)
                then collationproperty(c.collation_name, 'sqlcharsetname')
                -- nchar/nvarchar/ntext
                when c.system_type_id in ( 99, 231, 239 )
                then N'UNICODE'
            end) as character_set_name
        ,c.collation_name as collation_name
        ,c.is_computed as is_computed
        ,cc.definition as computed_column_definition
        ,c.is_identity as is_identity
        ,isnull(sep.value, '') as column_description
    from sys.objects o
    join sys.columns c
        on c.object_id = o.object_id
    left join sys.types t
        on c.user_type_id = t.user_type_id
    left join sys.computed_columns cc
        on cc.object_id = o.object_id
        and cc.column_id = c.column_id
    left join sys.extended_properties sep
        on o.object_id = sep.major_id
        and c.column_id = sep.minor_id
        and sep.name = 'MS_Description'
    where o.type in ('U', 'V')
    order by 6, 4, 5, 8
) t
go
