USE [master]
GO
CREATE DATABASE [iDBA] ON  PRIMARY
  (
  NAME = N'iDBA',
  FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL.1\MSSQL\DATA\iDBA.mdf' ,
  SIZE = 10MB ,
  FILEGROWTH = 5MB
  )
  LOG ON
  (
  NAME = N'iDBA_log',
  FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL.1\MSSQL\DATA\iDBA_log.ldf' ,
  SIZE = 5120KB ,
  FILEGROWTH = 5120KB
  )
GO

USE [iDBA]
GO
CREATE SCHEMA [MetaBot] AUTHORIZATION [dbo]
GO



CREATE TABLE [MetaBOT].[dm_db_index_usage_stats](
  [database_id] [smallint] NOT NULL,
  [object_id] [int] NOT NULL,
  [index_id] [int] NOT NULL,
  [user_seeks] [bigint] NOT NULL,
  [user_scans] [bigint] NOT NULL,
  [user_lookups] [bigint] NOT NULL,
  [user_updates] [bigint] NOT NULL,
  [last_user_seek] [datetime] NULL,
  [last_user_scan] [datetime] NULL,
  [last_user_lookup] [datetime] NULL,
  [last_user_update] [datetime] NULL,
  [system_seeks] [bigint] NOT NULL,
  [system_scans] [bigint] NOT NULL,
  [system_lookups] [bigint] NOT NULL,
  [system_updates] [bigint] NOT NULL,
  [last_system_seek] [datetime] NULL,
  [last_system_scan] [datetime] NULL,
  [last_system_lookup] [datetime] NULL,
  [last_system_update] [datetime] NULL,
  [last_poll_user_seeks] [bigint] NOT NULL,
  [last_poll_user_scans] [bigint] NOT NULL,
  [last_poll_user_lookups] [bigint] NOT NULL,
  [last_poll_user_updates] [bigint] NOT NULL,
  [last_poll_system_seeks] [bigint] NOT NULL,
  [last_poll_system_scans] [bigint] NOT NULL,
  [last_poll_system_lookups] [bigint] NOT NULL,
  [last_poll_system_updates] [bigint] NOT NULL,
  [date_stamp] [datetime] NOT NULL,
 CONSTRAINT [PK_dm_db_index_usage_stats] PRIMARY KEY CLUSTERED
( [database_id] ASC,
  [object_id] ASC,
  [index_id] ASC
)WITH (FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

CREATE NONCLUSTERED INDEX [IX_user_reads] ON [MetaBOT].[dm_db_index_usage_stats]
  ([user_scans], [user_seeks], [user_lookups])
  WITH (FILLFACTOR = 80) ON [PRIMARY]

CREATE NONCLUSTERED INDEX [IX_user_writes] ON [MetaBOT].[dm_db_index_usage_stats]
  ([user_updates])
  WITH (FILLFACTOR = 80) ON [PRIMARY]



  USE iDBA
  GO

  CREATE PROCEDURE MetaBot.usp_persist_dm_db_index_usage_stats AS
  DECLARE @last_service_start_date datetime
  DECLARE @last_data_persist_date datetime

  --Determine last service restart date based upon tempdb creation date
  SELECT @last_service_start_date =
    SD.[create_date]
    FROM sys.databases SD
    WHERE SD.[name] = 'tempdb'

  --Return the value for the last refresh date of the persisting table
  SELECT @last_data_persist_date =
    MAX(MDDIUS.[date_stamp])
    FROM [iDBA].[MetaBOT].[dm_db_index_usage_stats] MDDIUS

  --Take care of updated records first
  IF @last_service_start_date < @last_data_persist_date
    BEGIN
       --Service restart date > last poll date
       PRINT 'The latest persist date was ' +
          CAST(@last_data_persist_date AS VARCHAR(50)) +
          '; no restarts occurred since ' +
          CAST(@last_service_start_date AS VARCHAR(50)) +
          '  (' + CAST(DATEDIFF(d, @last_service_start_date, @last_data_persist_date) AS VARCHAR(10)) +
          ' days ago.)'

       UPDATE MDDIUS
       SET
          MDDIUS.[user_seeks] = MDDIUS.[user_seeks]+(SDDIUS.[user_seeks] - MDDIUS.[last_poll_user_seeks]),
          MDDIUS.[user_scans] = MDDIUS.[user_scans]+(SDDIUS.[user_scans] - MDDIUS.[last_poll_user_scans]),
          MDDIUS.[user_lookups] = MDDIUS.[user_lookups]+(SDDIUS.[user_lookups] - MDDIUS.[last_poll_user_lookups]),
          MDDIUS.[user_updates] = MDDIUS.[user_updates]+(SDDIUS.[user_updates] - MDDIUS.[last_poll_user_updates]),
          MDDIUS.[last_user_seek] = SDDIUS.[last_user_seek],
          MDDIUS.[last_user_scan] = SDDIUS.[last_user_scan],
          MDDIUS.[last_user_lookup] = SDDIUS.[last_user_lookup],
          MDDIUS.[last_user_update] = SDDIUS.[last_user_update],
          MDDIUS.[system_seeks] = MDDIUS.[system_seeks]+(SDDIUS.[system_seeks] - MDDIUS.[last_poll_system_seeks]),
          MDDIUS.[system_scans] = MDDIUS.[system_scans]+(SDDIUS.[system_scans] - MDDIUS.[last_poll_system_scans]),
          MDDIUS.[system_lookups] = MDDIUS.[system_lookups]+(SDDIUS.[system_lookups] - MDDIUS.[last_poll_system_lookups]),
          MDDIUS.[system_updates] = MDDIUS.[system_updates]+(SDDIUS.[system_updates] - MDDIUS.[last_poll_system_updates]),
          MDDIUS.[last_system_seek] = SDDIUS.[last_system_seek],
          MDDIUS.[last_system_scan] = SDDIUS.[last_system_scan],
          MDDIUS.[last_system_lookup] = SDDIUS.[last_system_lookup],
          MDDIUS.[last_system_update] = SDDIUS.[last_system_update],
          MDDIUS.[last_poll_user_seeks] = SDDIUS.[user_seeks],
          MDDIUS.[last_poll_user_scans] = SDDIUS.[user_scans],
          MDDIUS.[last_poll_user_lookups] = SDDIUS.[user_lookups],
          MDDIUS.[last_poll_user_updates] = SDDIUS.[user_updates],
          MDDIUS.[last_poll_system_seeks] = SDDIUS.[system_seeks],
          MDDIUS.[last_poll_system_scans] = SDDIUS.[system_scans],
          MDDIUS.[last_poll_system_lookups] = SDDIUS.[system_lookups],
          MDDIUS.[last_poll_system_updates] = SDDIUS.[system_updates],
          MDDIUS.date_stamp = GETDATE()
       FROM [sys].[dm_db_index_usage_stats] SDDIUS INNER JOIN
          [iDBA].[MetaBot].[dm_db_index_usage_stats] MDDIUS
             ON SDDIUS.[database_id] = MDDIUS.[database_id]
                AND SDDIUS.[object_id] = MDDIUS.[object_id]
                AND SDDIUS.[index_id] = MDDIUS.[index_id]
    END
  ELSE
    BEGIN
       --Service restart date < last poll date
       PRINT 'Lastest service restart occurred on ' +
          CAST(@last_service_start_date AS VARCHAR(50)) +
          ' which is after the latest persist date of ' +
          CAST(@last_data_persist_date AS VARCHAR(50))

       UPDATE MDDIUS
       SET
          MDDIUS.[user_seeks] = MDDIUS.[user_seeks]+ SDDIUS.[user_seeks],
          MDDIUS.[user_scans] = MDDIUS.[user_scans]+ SDDIUS.[user_scans],
          MDDIUS.[user_lookups] = MDDIUS.[user_lookups]+ SDDIUS.[user_lookups],
          MDDIUS.[user_updates] = MDDIUS.[user_updates]+ SDDIUS.[user_updates],
          MDDIUS.[last_user_seek] = SDDIUS.[last_user_seek],
          MDDIUS.[last_user_scan] = SDDIUS.[last_user_scan],
          MDDIUS.[last_user_lookup] = SDDIUS.[last_user_lookup],
          MDDIUS.[last_user_update] = SDDIUS.[last_user_update],
          MDDIUS.[system_seeks] = MDDIUS.[system_seeks]+ SDDIUS.[system_seeks],
          MDDIUS.[system_scans] = MDDIUS.[system_scans]+ SDDIUS.[system_scans],
          MDDIUS.[system_lookups] = MDDIUS.[system_lookups]+ SDDIUS.[system_lookups],
          MDDIUS.[system_updates] = MDDIUS.[system_updates]+ SDDIUS.[system_updates],
          MDDIUS.[last_system_seek] = SDDIUS.[last_system_seek],
          MDDIUS.[last_system_scan] = SDDIUS.[last_system_scan],
          MDDIUS.[last_system_lookup] = SDDIUS.[last_system_lookup],
          MDDIUS.[last_system_update] = SDDIUS.[last_system_update],
          MDDIUS.[last_poll_user_seeks] = SDDIUS.[user_seeks],
          MDDIUS.[last_poll_user_scans] = SDDIUS.[user_scans],
          MDDIUS.[last_poll_user_lookups] = SDDIUS.[user_lookups],
          MDDIUS.[last_poll_user_updates] = SDDIUS.[user_updates],
          MDDIUS.[last_poll_system_seeks] = SDDIUS.[system_seeks],
          MDDIUS.[last_poll_system_scans] = SDDIUS.[system_scans],
          MDDIUS.[last_poll_system_lookups] = SDDIUS.[system_lookups],
          MDDIUS.[last_poll_system_updates] = SDDIUS.[system_updates],
          MDDIUS.date_stamp = GETDATE()
       FROM [sys].[dm_db_index_usage_stats] SDDIUS INNER JOIN
          [iDBA].[MetaBot].[dm_db_index_usage_stats] MDDIUS
             ON SDDIUS.[database_id] = MDDIUS.[database_id]
                AND SDDIUS.[object_id] = MDDIUS.[object_id]
                AND SDDIUS.[index_id] = MDDIUS.[index_id]
    END

  --Take care of new records next
       INSERT INTO [iDBA].[MetaBot].[dm_db_index_usage_stats]
          (
          [database_id], [object_id], [index_id],
          [user_seeks], [user_scans], [user_lookups],
          [user_updates], [last_user_seek], [last_user_scan],
          [last_user_lookup], [last_user_update], [system_seeks],
          [system_scans], [system_lookups], [system_updates],
          [last_system_seek], [last_system_scan],
          [last_system_lookup], [last_system_update],
          [last_poll_user_seeks],    [last_poll_user_scans],
          [last_poll_user_lookups], [last_poll_user_updates],
          [last_poll_system_seeks], [last_poll_system_scans],
          [last_poll_system_lookups], [last_poll_system_updates],
          [date_stamp]
          )
       SELECT SDDIUS.[database_id], SDDIUS.[object_id], SDDIUS.[index_id],
          SDDIUS.[user_seeks], SDDIUS.[user_scans], SDDIUS.[user_lookups],
          SDDIUS.[user_updates], SDDIUS.[last_user_seek], SDDIUS.[last_user_scan],
          SDDIUS.[last_user_lookup], SDDIUS.[last_user_update], SDDIUS.[system_seeks],
          SDDIUS.[system_scans], SDDIUS.[system_lookups], SDDIUS.[system_updates],
          SDDIUS.[last_system_seek], SDDIUS.[last_system_scan],
          SDDIUS.[last_system_lookup], SDDIUS.[last_system_update],
          SDDIUS.[user_seeks], SDDIUS.[user_scans], SDDIUS.[user_lookups],
          SDDIUS.[user_updates],SDDIUS.[system_seeks],
          SDDIUS.[system_scans], SDDIUS.[system_lookups],
          SDDIUS.[system_updates], GETDATE()
       FROM [sys].[dm_db_index_usage_stats] SDDIUS LEFT JOIN
          [iDBA].[MetaBot].[dm_db_index_usage_stats] MDDIUS
             ON SDDIUS.[database_id] = MDDIUS.[database_id]
             AND SDDIUS.[object_id] = MDDIUS.[object_id]
             AND SDDIUS.[index_id] = MDDIUS.[index_id]
       WHERE MDDIUS.[database_id] IS NULL
          AND MDDIUS.[object_id] IS NULL
        AND MDDIUS.[index_id] IS NULL
