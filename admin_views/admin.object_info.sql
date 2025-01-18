create or alter view admin.object_info as
--------------------------------------------------------------------------------
-- Author: mattmc
-- Ver: v1.0.0
-- Description: enhanced version of sysobjects
--------------------------------------------------------------------------------
select so.object_id
     , so.name as object_name
     , so.schema_id
     , schema_name(so.schema_id) as schema_name
     , so.parent_object_id
     , so.[type] as type_code
     , so.type_desc
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
