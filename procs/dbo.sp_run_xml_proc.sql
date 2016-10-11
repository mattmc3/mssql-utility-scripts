USE master
GO
IF OBJECT_ID('dbo.sp_run_xml_proc') IS NOT NULL AND OBJECTPROPERTY(OBJECT_ID('dbo.sp_run_xml_proc'), 'IsProcedure') = 1 BEGIN
	DROP PROCEDURE dbo.sp_run_xml_proc
END
GO
/***************************************************************************************************

Notes:
Code taken from "The Guru's Guide to SQL Server(TM) Stored Procedures, XML, and HTML" by Ken
Henderson (Addison Wesley - ISBN:0-201-70046-8 - pg. 453)

The following description of what this procedure does was taken from pg 452:

	You can use [this stored procedure] to call linked server stored procedures (it needs to reside
	on the linked server) that return XML documents, as well as local XML procedures with results
	that you'd like to store in a table or trap in a variable.  It does its magic by opening its own
	connection into the server (it assumes Windows authentication) and running your procedure.  Once
	your procedure completes, sp_run_xml_proc processes the XML stream it returns using SQL-DMO
	calls, then translates it into a traditional rowset and returns that rowset.  The result set can
	be inserted into a table or processed further just like any other result set.

This procedure has been modified from its original version to work with XML as a TEXT field rather
than as a VARCHAR(8000).

***************************************************************************************************/
CREATE PROCEDURE dbo.sp_run_xml_proc
	@procname SYSNAME -- Proc to run
AS
	DECLARE
		@dbname SYSNAME,
		@sqlobject INT,     -- SQL Server object
		@object INT,        -- Work variable for accessing COM objects
		@hr INT,            -- Contains HRESULT returned by COM
		@results INT,       -- QueryResults object
		@msgs VARCHAR(8000) -- Query messages

	IF(@procname = '/?') GOTO Help

	-- Create a SQLServer object
	EXEC @hr = sp_OACreate 'SQLDMO.SQLServer', @sqlobject OUT
	IF(@hr <> 0) GOTO ErrorHandler

	-- Set SQLServer object to use a trusted connection
	EXEC @hr = sp_OASetProperty @sqlobject, 'LoginSecure', 1
	IF(@hr <> 0) GOTO ErrorHandler

	-- Turn off ODBC prefixes on messages
	EXEC @hr = sp_OASetProperty @sqlobject, 'ODBCPrefix', 0
	IF(@hr <> 0) GOTO ErrorHandler

	-- Open a new connection (assumes a trusted connection)
	EXEC @hr = sp_OAMethod @sqlobject, 'Connect', NULL, @@SERVERNAME
	IF(@hr <> 0) GOTO ErrorHandler

	-- Get a pointer to the SQLServer object's Databases collection
	EXEC @hr = sp_OAGetProperty @sqlobject, 'Databases', @object OUT
	IF(@hr <> 0) GOTO ErrorHandler

	-- Get a pointer from the Databases collection for the current database
	SET @dbname = DB_NAME()
	EXEC @hr = sp_OAMethod @object, 'Item', @object OUT, @dbname
	IF(@hr <> 0) GOTO ErrorHandler

	-- Call the Database object's ExecuteWithResultsAndMessages2 method to run the proc
	EXEC @hr = sp_OAMethod @object, 'ExecuteWithResultsAndMessages2', @results OUT, @procname, @msgs OUT
	IF(@hr <> 0) GOTO ErrorHandler

	-- Display any messages returned by the proc
	PRINT @msgs

	DECLARE
		@rows int,
		@cols int,
		@x int,
		@y int,
		@col varchar(8000),
		@row varchar(8000)

	-- Call the QueryResult object's Rows method to get the number of rows in the result set
	EXEC @hr = sp_OAMethod @results, 'Rows', @rows OUT
	IF(@hr <> 0) GOTO ErrorHandler

	-- Call the QueryResult object's Columns method to get the number of columns in the result set
	EXEC @hr = sp_OAMethod @results, 'Columns', @cols OUT
	IF(@hr <> 0) GOTO ErrorHandler

	-------------------------------------------------------------------------------------------------
	-- SUBSTITUTION
	-- This is substituted code

	-- Create a temp table
	CREATE TABLE #tmpXml (
		XmlText TEXT
	)

	-- Insert an empty string to start our XML
	INSERT INTO #tmpXml VALUES ('')

	-- Get a pointer to the text field
	DECLARE @ptr BINARY(16)
	SELECT @ptr = TEXTPTR(XmlText) FROM #tmpXml

	-- Retrieve the result column-by-column using the GetColumnString method
	SET @y = 1
	WHILE(@y <= @rows) BEGIN
		SET @x = 1
		SET @row = ''
		WHILE(@x <= @cols) BEGIN
			EXEC @hr = sp_OAMethod @results, 'GetColumnString', @col OUT, @y, @x
			IF(@hr <> 0) GOTO ErrorHandler

			SET @row = @row + @col
			SET @x = @x + 1
		END

		-- Stuff the data into the temporary table
		UPDATETEXT #tmpXml.XmlText @ptr NULL 0 @row

		SET @y = @y + 1
	END

	-- Return the XML
	SELECT * FROM #tmpXml
	-------------------------------------------------------------------------------------------------

	-- Clean up and exit
	DROP TABLE #tmpXml

	EXEC sp_OADestroy @sqlobject
	RETURN 0

Help:
	PRINT 'You must specify a procedure name to run'
	RETURN -1

ErrorHandler:
	RAISERROR('ERROR: An error occurred within the sp_run_xml_proc procedure.', 16, 10)
GO
GRANT EXECUTE ON dbo.sp_run_xml_proc TO PUBLIC
GO
