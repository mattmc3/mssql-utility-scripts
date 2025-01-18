create or alter view admin.gen_drops as
--------------------------------------------------------------------------------
-- Author: mattmc
-- Ver: v1.0.0
-- Description: Generate object drops
--------------------------------------------------------------------------------
select a.*
from (
    select top 2147483647
        obj.db_name
        ,obj.object_id
        ,obj.object_type
        ,obj.schema_name
        ,obj.object_name
        ,1000000 as seq
        ,'DROP ' +
            case obj.type_code
               when 'U' then 'TABLE'
               when 'V' then 'VIEW'
               when 'P' then 'PROCEDURE'
               when 'FN' then 'FUNCTION'
               when 'IF' then 'FUNCTION'
               else '?'
            end + ' ' + obj.quoted_name as sqltxt
    from admin.objects obj
    where obj.type_code in ('U', 'V', 'P', 'FN', 'IF')
    and obj.is_builtin = 0
    order by object_type, schema_name, object_name, seq
) a
go
