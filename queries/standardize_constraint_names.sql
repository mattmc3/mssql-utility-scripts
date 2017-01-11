-- example of generating some sp_rename commands
select *
      ,case
          when a.constraint_type = 'PK'
          then 'exec sp_rename ''' + table_name + '.' + constraint_name + ''', ''pk_' + table_name + ''''
          
          when a.constraint_type = 'UQ'
          then 'exec sp_rename ''' + table_name + '.' + constraint_name + ''', ''un_' + table_name + ''''
          
          when a.constraint_type = 'C'
          then 'exec sp_rename ''' + constraint_name + ''', ''ck_' + table_name + ''''
          
          else null
      end as ddl
from admin.constraint_table_usage a
where a.constraint_type <> 'F'

-- foreign keys
select *
      ,'exec sp_rename ''' + constraint_name + ''', ''fk_' + table_name + '_to_' + a.ref_table_name + '''' as ddl
from admin.foreign_keys a
