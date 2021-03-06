--------------------------------------------------------------------------------
-- Description: enhanced version of information_schema.tables
-- Notes: start with sp_helptext 'information_schema.columns' in the master
--        db and enhance from there.
--------------------------------------------------------------------------------
create or alter view [meta].[column_info] as

select
    *
    ,'(' +
     case
        when t.data_type in ('binary', 'char', 'nchar', 'nvarchar', 'varbinary', 'varchar')
        then isnull(nullif(cast(t.character_maximum_length as varchar(10)), '-1'), 'max')
        when t.data_type in ('decimal', 'numeric')
        then cast(t.numeric_precision as varchar(10)) + ',' + cast(t.numeric_scale as varchar(10))
        when t.data_type in ('datetime2', 'datetimeoffset', 'time')
        then cast(t.datetime_precision as varchar(10))
        else null
    end + ')' as data_type_size
    ,case when t.is_identity = 1 or t.is_computed = 1 or t.data_type = 'timestamp' then 0 else 1 end as is_modifiable
from (
    select top 2147483647
        o.object_id as mssql_object_id
        ,c.column_id as mssql_column_id
        ,db_name() as table_catalog
        ,schema_name(o.schema_id) as table_schema
        ,o.name as table_name
        ,case o.type
            when 'U' then 'BASE TABLE'
            when 'V' then 'VIEW'
        end as table_type
        ,c.name as column_name
        ,columnproperty(c.object_id, c.name, 'ordinal') as ordinal_position
        ,convert(nvarchar(4000), object_definition(c.default_object_id)) as column_default
        ,c.is_nullable as is_nullable
        ,isnull(type_name(c.system_type_id), t.name) as data_type
        ,columnproperty(c.object_id, c.name, 'charmaxlen') as character_maximum_length
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
    join sys.columns c                    on c.object_id = o.object_id
    left join sys.types t                 on c.user_type_id = t.user_type_id
    left join sys.computed_columns cc     on cc.object_id = o.object_id
                                         and cc.column_id = c.column_id
    left join sys.extended_properties sep on o.object_id = sep.major_id
                                         and c.column_id = sep.minor_id
                                         and sep.name = 'MS_Description'
    where o.type in ('U', 'V')
    order by 6, 4, 5, 8
) t

go
