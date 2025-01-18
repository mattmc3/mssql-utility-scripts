create or alter view admin.v_generate_drops as
--------------------------------------------------------------------------------
-- Author: mattmc
-- Ver: v1.0.0
-- Description: Generate object drops
--------------------------------------------------------------------------------
select *
from (
    select top 2147483647
        ti.object_id
        ,ti.type_desc
        ,ti.schema_name
        ,ti.object_name
        ,n.num * 100000 as seq
        ,case n.num
            when 1 then 'DROP ' +
               case ti.type_code
                   when 'U' then 'TABLE'
                   when 'V' then 'VIEW'
                   when 'P' then 'PROCEDURE'
                   when 'FN' then 'FUNCTION'
                   when 'IF' then 'FUNCTION'
                   else '?'
                end + ' ' + ti.quoted_name
            when 2 then 'GO'
            when 3 then ''
        end as sqltxt
    from admin.object_info ti
    cross apply (
        select 1 as num union
        select 2 union
        select 3
    ) n
    where ti.type_code in ('U', 'V', 'P', 'FN', 'IF')
    and ti.is_builtin = 0
    order by 2, 3, 4, 5
) a
go
