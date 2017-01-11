USE master
GO
IF OBJECT_ID('dbo.sp_xml_concat') IS NOT NULL AND OBJECTPROPERTY(OBJECT_ID('dbo.sp_xml_concat'), 'IsProcedure') = 1 BEGIN
    DROP PROCEDURE dbo.sp_xml_concat
END
GO
/***************************************************************************************************

Parameters:
    @hdl INT OUT,
    @table - The name of a table containing ONLY A SINGLE ROW of XML data.  If querying a table with
             multiple rows, then an aliased query in place of a table is an acceptable alternative.
             ie: @table = '(SELECT xml FROM #tbl WHERE id=1) a'
    @column - The name of the column in @table containing the XML

Notes:
Code taken from "The Guru's Guide to SQL Server(TM) Stored Procedures, XML, and HTML" by Ken
Henderson (Addison Wesley - ISBN:0-201-70046-8 - pg. 449)

The following description of what this procedure does was taken from pg 451:

    What this procedure does is dynamically generate the necessary DECLARE and SELECT statements to
    break up a large text column into nvarchar(4,000) pieces (e.g., DECLARE @c1 nvarchar(4000) SELECT
    @c1=...). As it does this, it also generates a concatenation expression that includes all of
    these variables (e.g., @c1+@c2+@c3,...).  Since the EXEC() function supports concatenation of
    strings up to 2GB in size, we pass this concatenation expression into it dynamically and allow
    EXEC() to perform the concatenation on-the-fly.  This basically reconstructs the document that we
    extracted from the table.  This concatenated string is then passed into sp_xml_preparedocument
    for processing.  The end result is a document handle that you can use with OPENXML().

In addition to that description, I'll add that this proc serves as a wrapper/replacement to
sp_xml_preparedocument.  So, when finished with the xml, a call to sp_xml_unpreparedocument should
still be made.  A sample call to this proc may look like the following:

EXEC sp_xml_concat @hdl OUT, '(SELECT doc FROM #tbl WHERE id=1) a', 'doc'

I have reworked this proc for clarity as well as to account (hackishly) for tick marks (') in the
XML, but the concept is basically the same.

***************************************************************************************************/
CREATE PROCEDURE dbo.sp_xml_concat
    @hdl INT OUT,
    @table SYSNAME,
    @column SYSNAME,
    @xml_header VARCHAR(1000) = ''
AS
    EXEC('
        SET TEXTSIZE 4000

        DECLARE
            @max INT,
            @cnt INT,
            @var VARCHAR(15),
            @declare VARCHAR(8000),
            @assign VARCHAR(8000),
            @concat VARCHAR(8000)

        SELECT @max = CEILING(DATALENGTH(' + @column + ')/3500.0) FROM ' + @table + '

        SELECT
            @declare = ''DECLARE @h VARCHAR(1000)'',
            @assign = '''',
            @concat = ''@h'',
            @cnt = 0

        WHILE(@cnt < @max) BEGIN
            SET @var = ''@x'' + CONVERT(VARCHAR, @cnt)
            SELECT
                @declare = @declare + '', '' + @var + '' NVARCHAR(4000)'',
                @assign = @assign + '', '' + @var + '' = REPLACE(SUBSTRING(' + @column + ', '' + CONVERT(VARCHAR, 1 + @cnt * 3500) + '', 3500), '''''''''''''''', '''''''''''''''''''''''')'',
                @concat = @concat + '' + '' + @var

                --@assign = @assign + '', '' + @var + '' = SUBSTRING(' + @column + ', '' + CONVERT(VARCHAR, 1 + @cnt * 3500) + '', 3500)'',
            SET @cnt = @cnt + 1
        END

        IF(@cnt > 0) BEGIN
            SET @assign = ''SELECT @h = ''''' + @xml_header + ''''''' + @assign + '' FROM ' + @table + '''
        END

        --PRINT @declare + CHAR(10) + CHAR(13) + @assign + CHAR(10) + CHAR(13) +
        --''PRINT
        --''''DECLARE @hdl_doc int
        --EXEC sp_xml_preparedocument @hdl_doc OUT, '''''''''''' + '' + @concat + '' + ''''''''''''
        --DECLARE hdlcursor CURSOR GLOBAL FOR SELECT @hdl_doc AS DocHandle''''''

        EXEC(@declare + '' '' + @assign + '' '' +
        ''EXEC(
        ''''DECLARE @hdl_doc int
        EXEC sp_xml_preparedocument @hdl_doc OUT, '''''''''''' + '' + @concat + '' + ''''''''''''
        DECLARE hdlcursor CURSOR GLOBAL FOR SELECT @hdl_doc AS DocHandle'''')''
        )
    ')

    OPEN hdlcursor
    FETCH hdlcursor INTO @hdl
    DEALLOCATE hdlcursor
GO
GRANT EXECUTE ON dbo.sp_xml_concat TO PUBLIC
GO
