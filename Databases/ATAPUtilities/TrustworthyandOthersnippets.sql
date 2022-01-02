-- list of what references what
SELECT OBJECT_NAME(referencing_id) AS referencing_entity_name,
    o.type_desc AS referencing_desciption,
    COALESCE(COL_NAME(referencing_id, referencing_minor_id), '(n/a)') AS referencing_minor_id,
    referencing_class_desc,
    referenced_server_name, referenced_database_name, referenced_schema_name,
    referenced_entity_name,
    COALESCE(COL_NAME(referenced_id, referenced_minor_id), '(n/a)') AS referenced_column_name,
    is_caller_dependent, is_ambiguous
FROM sys.sql_expression_dependencies AS sed
INNER JOIN sys.objects AS o ON sed.referencing_id = o.object_id
WHERE referencing_id = OBJECT_ID(N'Map_GComment_GStatement');
GO

SELECT OBJECT_ID(N'Map_GComment_GStatement');

select * from sys.sql_expression_dependencies

-- who are the saysadmins of databases that are marked trustworthy
ALTER DATABASE ATAPUtilities SET TRUSTWORTHY OFF;
  SELECT SUSER_SNAME(owner_sid) AS DBOWNER, d.name AS DATABASENAME
FROM sys.server_principals r
INNER JOIN sys.server_role_members m ON r.principal_id = m.role_principal_id
INNER JOIN sys.server_principals p ON
p.principal_id = m.member_principal_id
inner join sys.databases d on suser_sname(d.owner_sid) = p.name
WHERE is_trustworthy_on = 1 AND d.name NOT IN ('MSDB') and r.type = 'R' and r.name = N'sysadmin'

-- Get all schemas and objects
	 SET NOCOUNT ON;
DECLARE @json NVARCHAR(MAX);
SELECT @json =
  (SELECT Object_Schema_Name (object_id) AS [Schema], name
     FROM sys.tables
     WHERE
     is_ms_shipped = 0 AND name NOT LIKE 'Flyway%'
  FOR JSON AUTO);
SELECT @json;

-- Get JSON list of all objects in the DATABASE that did not come shipped from Microsoft or Flyway
use[ATAPUtilities]

SET NOCOUNT ON

DECLARE @JSONDatabaseModel NVARCHAR(MAX)
SELECT @JSONDatabaseModel=
(SELECT The_Schemas.TheSchema AS "Schema", types.TheType AS "type",
       names.Name, attributes.TheType, attr.name
  FROM
    --start by finding all schemas being occupied by User objects
    (SELECT DISTINCT Object_Schema_Name (object_id) AS "TheSchema"
       FROM sys.objects
       WHERE
       is_ms_shipped = 0 AND parent_object_id = 0) The_Schemas
    -- outer join with all base objects by schema
    LEFT OUTER JOIN
	-- first we add in all the categories of objects for each schema
	--ensuring there are no empty categories
      (SELECT DISTINCT Object_Schema_Name (object_id) AS "TheSchema",
                       Replace ( --create something more readable
                         Replace (--delete unnecessary prefixes
                           Replace (Lower (type_desc), 'User_', ''),
                           'SQL_',
                           ''),
                         '_',
                         ' ') AS TheType, type
         FROM sys.objects
         WHERE is_ms_shipped = 0 AND parent_object_id = 0
		 UNION ALL --all the schemas with defined user types in them
		 SELECT DISTINCT schemas.Name,'User Type','UT'
			FROM sys.types
			INNER JOIN sys.schemas
			  ON schemas.schema_id = types.schema_id
			  WHERE  types.is_user_defined<>0
		 ) [types]
      ON The_Schemas.TheSchema = types.TheSchema
    LEFT OUTER JOIN
    --now add in all the  base  user objects (Views, tables, functions procs.
    --in each schema, -- in each type
		(SELECT -- Object_Schema_Name (object_id) + '.' +
			  name AS "Name", type,
              object_id, Object_Schema_Name (object_id) AS The_schema
         FROM sys.objects
         WHERE
         is_ms_shipped = 0 AND parent_object_id = 0
		 UNION ALL
	--and add in all the user types
		SELECT types.name,
			'UT',types.user_type_id,schemas.Name
		FROM sys.types
		INNER JOIN sys.schemas
		  ON schemas.schema_id = types.schema_id
		  WHERE types.is_user_defined=1
		 ) names
      ON names.type = types.type AND The_Schemas.TheSchema = names.The_schema
     LEFT OUTER JOIN
    --now add in all the types/categories  of attributes/child objects (defaults, keys and
	--constraints, parameters, indexes and columns) of every
    --base object in each schema, and the columns, indexes, parameters and
	--return. Make sure the category exists only if there is something to
	-- put in it
	(SELECT DISTINCT Replace (Lower (type_desc), '_', ' ') AS TheType,
                       type, parent_object_id
         FROM sys.objects
         WHERE
         is_ms_shipped = 0 AND parent_object_id <> 0
	   UNION ALL --and the columns
      SELECT DISTINCT 'Columns', 'CL', objects.object_id
         FROM
         sys.columns
           INNER JOIN sys.objects
             ON COLUMNS.object_id = objects.object_id
         WHERE is_ms_shipped = 0
       UNION ALL --and the indexes
 		SELECT 'System Type', 'ST',types.user_type_id
		FROM sys.types
		WHERE  types.is_user_defined<>0
		UNION all
	   SELECT DISTINCT 'Indexes', 'IX', objects.object_id
         FROM
         sys.indexes
           INNER JOIN sys.objects
             ON indexes.object_id = objects.object_id
         WHERE  is_primary_key=0 AND is_unique_constraint=0 AND is_ms_shipped = 0
       UNION ALL --and the parameters
       SELECT DISTINCT CASE WHEN parameter_id = 0 THEN 'Return' ELSE
                                                                'parameters' END,
                       'CL', objects.object_id
		 FROM
           sys.parameters
           INNER JOIN sys.objects
             ON PARAMETERS.object_id = objects.object_id
         WHERE
         is_ms_shipped = 0) attributes --the attributes Columns and parameters
      ON names.object_id = attributes.parent_object_id
    LEFT OUTER JOIN
	/* now we have to get the names of all these objects, and where necessary the
	datatypes (columns and parameters) or columns (indexes (primary keys etc.  */
      (SELECT Replace (Lower (type_desc), '_', ' ') AS TheType, objects.name,
              parent_object_id AS "object_id", 1 AS TheOrder
         FROM sys.objects
         WHERE
         is_ms_shipped = 0 AND parent_object_id <> 0
		 AND type NOT IN ('PK','UQ')-- do the primary key and unique constraint separately
	   UNION ALL
       SELECT 'System Type', Coalesce(usertypes.name,'')
			+CASE WHEN types.precision>0 AND types.scale>0
			   THEN '('+Convert(VARCHAR(10),types.precision)+','
					+Convert(VARCHAR(10),types.precision)+ ')'
			   WHEN types.max_length=types.precision THEN ''
			   WHEN types.max_length<>-1
			   THEN '('+Convert(VARCHAR(10),types.Max_length)+')' ELSE '' END
			 + CASE WHEN types.is_table_type<>0 THEN 'Table type'
					WHEN types.is_assembly_type<>0 THEN 'Assembly type'
					ELSE '' END,types.user_type_id,1
		FROM sys.types
		LEFT OUTER JOIN sys.types usertypes
		ON usertypes.user_type_id = types.system_type_id
		WHERE types.is_user_defined=1
       UNION ALL --and the columns
       SELECT Type,
            colsandparams.name + ' ' +
-- SQL Prompt formatting off
			t.[name]+ CASE --do the basic datatype
			WHEN t.[name] IN ('char', 'varchar', 'nchar', 'nvarchar')
			THEN '(' + -- we have to put in the length
				CASE WHEN ValueTypemaxlength = -1 THEN 'MAX'
				ELSE CONVERT(VARCHAR(4),
					CASE WHEN t.[name] IN ('nchar', 'nvarchar')
					THEN ValueTypemaxlength / 2 ELSE ValueTypemaxlength
					END)
				END + ')' --having to put in the length
			WHEN t.[name] IN ('decimal', 'numeric')
			--Ah. We need to put in the precision
			THEN '(' + CONVERT(VARCHAR(4), ValueTypePrecision)
					+ ',' + CONVERT(VARCHAR(4), ValueTypeScale) + ')'
			ELSE ''-- no more to do
			END+ --we've now done the datatype
			CASE WHEN XMLcollectionID <> 0 --when an XML document
			THEN --deal with object schema names
				'(' +
				CASE WHEN isXMLDocument = 1 THEN 'DOCUMENT ' ELSE 'CONTENT ' END
				+ COALESCE(
				QUOTENAME(Schemae.name) + '.' + QUOTENAME(SchemaCollection.name)
				,'NULL') + ')'
				ELSE ''
			END+Coalesce(' -- '+Description,'')	AS Name,
			object_id,  TheOrder
-- SQL Prompt formatting on
         FROM--columns, parameters, return values ColsAndParams.
		 --first get all the parameters
           (SELECT cols.object_id, cols.name, 'Columns' AS "Type",
                   Convert (NVARCHAR(2000), value) AS "Description",
                   column_id AS TheOrder, cols.xml_collection_id,
                   cols.max_length AS ValueTypemaxlength,
                   cols.precision AS ValueTypePrecision,
                   cols.scale AS ValueTypeScale,
                   cols.xml_collection_id AS XMLcollectionID,
                   cols.is_xml_document AS isXMLDocument, cols.user_type_id
              FROM
              sys.objects AS object
                INNER JOIN sys.columns AS cols
                  ON cols.object_id = object.object_id
                LEFT OUTER JOIN sys.extended_properties AS EP
                  ON cols.object_id = EP.major_id
                 AND class = 1
                 AND minor_id = cols.column_id
                 AND EP.name = 'MS_Description'
              WHERE is_ms_shipped = 0
            UNION ALL
            --get in all the parameters
            SELECT params.object_id, params.name AS "Name",
                   CASE WHEN parameter_id = 0 THEN 'Return' ELSE 'Parameters' END AS "Type",
                   --'Parameters' AS "Type",
                   Convert (NVARCHAR(2000), value) AS "Description",
                   parameter_id AS TheOrder, params.xml_collection_id,
                   params.max_length AS ValueTypemaxlength,
                   params.precision AS ValueTypePrecision,
                   params.scale AS ValueTypeScale,
                   params.xml_collection_id AS XMLcollectionID,
                   params.is_xml_document AS isXMLDocument,
                   params.user_type_id
              FROM
              sys.objects AS object
                INNER JOIN sys.parameters AS params
                  ON params.object_id = object.object_id
                LEFT OUTER JOIN sys.extended_properties AS EP
                  ON params.object_id = EP.major_id
                 AND class = 2
                 AND minor_id = params.parameter_id
                 AND EP.name = 'MS_Description'
              WHERE is_ms_shipped = 0) AS colsandparams
           INNER JOIN sys.types AS t
             ON colsandparams.user_type_id = t.user_type_id
           LEFT OUTER JOIN sys.xml_schema_collections AS SchemaCollection
             ON SchemaCollection.xml_collection_id = colsandparams.xml_collection_id
           LEFT OUTER JOIN sys.schemas AS Schemae
             ON SchemaCollection.schema_id = Schemae.schema_id
       UNION ALL --and the indexes
       SELECT Max(CASE WHEN ind.is_unique_constraint=1 THEN 'unique constraint'
					WHEN ind.is_primary_key =1
					THEN  'primary key constraint' ELSE 'Indexes' END),
			 ind.name+ ' ('+
       String_Agg (col.name, ', ') WITHIN GROUP(ORDER BY ic.key_ordinal)+')',
	   t.object_id, 1
  FROM
  sys.indexes ind
    INNER JOIN sys.index_columns ic
      ON ind.object_id = ic.object_id AND ind.index_id = ic.index_id
    INNER JOIN sys.columns col
      ON ic.object_id = col.object_id AND ic.column_id = col.column_id
    INNER JOIN sys.tables t
      ON ind.object_id = t.object_id
  WHERE t.is_ms_shipped = 0
  GROUP BY ind.name,t.object_id
		) attr
      ON attr.object_id = attributes.parent_object_id
     AND attr.TheType = attributes.TheType
  ORDER BY
  The_Schemas.TheSchema, types.TheType, names.Name, attributes.TheType,attr.TheOrder
FOR JSON AUTO);
SELECT @JSONDatabaseModel; --needed to work with SQLCMD


--- SQL Server Foreign Key Hierarchy Order and Dependency List Script
--- https://www.mssqltips.com/sqlservertip/6179/sql-server-foreign-key-hierarchy-order-and-dependency-list-script/
WITH dependencies -- Get object with FK dependencies
AS (
    SELECT FK.TABLE_NAME AS Obj
        , PK.TABLE_NAME AS Depends
    FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS C
    INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS FK
        ON C.CONSTRAINT_NAME = FK.CONSTRAINT_NAME
    INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS PK
        ON C.UNIQUE_CONSTRAINT_NAME = PK.CONSTRAINT_NAME
    ),
no_dependencies -- The first level are objects with no dependencies
AS (
    SELECT
        name AS Obj
    FROM sys.objects
    WHERE name NOT IN (SELECT obj FROM dependencies) --we remove objects with dependencies from first CTE
    AND type = 'U' -- Just tables
    ),
recursiv -- recursive CTE to get dependencies
AS (
    SELECT Obj AS [Table]
        , CAST('' AS VARCHAR(max)) AS DependsON
        , 0 AS LVL -- Level 0 indicate tables with no dependencies
    FROM no_dependencies

    UNION ALL

    SELECT d.Obj AS [Table]
        , CAST(IIF(LVL > 0, r.DependsON + ' > ', '') + d.Depends AS VARCHAR(max)) -- visually reflects hierarchy
        , R.lvl + 1 AS LVL
    FROM dependencies d
    INNER JOIN recursiv r
        ON d.Depends = r.[Table]
    )
-- The final result, with some extra fields for more information
SELECT DISTINCT SCHEMA_NAME(O.schema_id) AS [TableSchema]
    , R.[Table]
    , R.DependsON
    , R.LVL
FROM recursiv R
INNER JOIN sys.objects O
    ON R.[Table] = O.name
ORDER BY R.LVL
    , R.[Table]


--- SQL Script to create Sub directories if they do not exist
-- https://stackoverflow.com/questions/55146586/sql-script-to-create-sub-directories-if-they-do-not-exist
declare
     @dirPath varchar(1024)
    ,@msg varchar(1024)
    ,@bkUp varchar(1024)
    ,@fileDate VARCHAR(20) = CONVERT(VARCHAR(20),GETDATE(),112)
    ,@name VARCHAR(128) -- database name  128 is max for sql objects

DECLARE db_cursor CURSOR FOR
SELECT name
FROM master.dbo.sysdatabases
WHERE name NOT IN ('master',
                    'model',
                    'msdb',
                    'tempdb',
                    'PracticaSd-Dallasmetro')  -- exclude these databases

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @name

WHILE @@FETCH_STATUS = 0
BEGIN
        set @dirPath = '\\nas01\Admin\bbelden\test\' + @name
        --set @dirPath = 'D:\SQL Server\MSSQL\Backup\' + @name --my home path
        begin try
            exec xp_create_subdir @dirPath;
            set @msg = 'Created directory: ' + @dirPath
            raiserror(@msg,0,0);
            set @bkUp = 'backup database ' + quotename(@name) + ' to disk = ''' + @dirPath + '\' + @name + '_' + @fileDate + '.bak'' with compression';
            exec(@bkUp);
            set @bkUp = 'RESTORE VERIFYONLY FROM DISK = ''' + @dirPath + '\' + @name + '_' + @fileDate + '.bak''';
            exec(@bkUp);
        end try
        begin catch
            set @msg = 'something went wrong!!! with: ' + @name + '    ' + error_message()
            raiserror(@msg,0,0);
        end catch
       FETCH NEXT FROM db_cursor INTO @name
END

CLOSE db_cursor
DEALLOCATE db_cursor


