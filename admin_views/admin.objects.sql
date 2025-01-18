create or alter view admin.objects as
--------------------------------------------------------------------------------
-- Author: mattmc
-- Ver: v1.0.0
-- Description: enhanced version of sysobjects
--------------------------------------------------------------------------------
select so.object_id
     , db_name() as db_name
     , so.schema_id
     , schema_name(so.schema_id) as schema_name
     , so.name as object_name
     , convert(nvarchar(1000), quotename(schema_name(so.schema_id)) + '.' + quotename(so.name)) as quoted_name
     , so.parent_object_id
     , so.[type] as type_code
     , so.type_desc as object_type
     , so.create_date
     , so.modify_date
     , so.is_ms_shipped
     , case
           when so.name in (
                'fn_diagramobjects'
                ,'sp_alterdiagram'
                ,'sp_creatediagram'
                ,'sp_dropdiagram'
                ,'sp_helpdiagramdefinition'
                ,'sp_helpdiagrams'
                ,'sp_renamediagram'
                ,'sp_upgraddiagrams'
                ,'sysdiagrams'
           ) then 1
        when so.is_ms_shipped = 1 then 1
        else 0
    end as is_builtin
from sys.objects so
go
