-- =========================================
-- Create Graph Node Template
-- =========================================
USE FileSystemAsGraphDB
GO

DROP TABLE IF EXISTS FileNames
GO

CREATE TABLE FileNames
(
	FileName varchar(255)
    -- Unique index on $node_id is required.
    -- If no user-defined index is specified, a default index is created.
    INDEX ix_graphid UNIQUE ($node_id)
)
AS NODE
GO

DROP TABLE IF EXISTS DirectoryNames
GO

CREATE TABLE DirectoryNames
(
	DirectoryName varchar(255)
    -- Unique index on $node_id is required.
    -- If no user-defined index is specified, a default index is created.
    INDEX ix_graphid UNIQUE ($node_id)
)
AS NODE
GO

DROP TABLE IF EXISTS SubDirectoryOf
GO

CREATE TABLE SubDirectoryOf
(
    -- If no user-defined index is specified, a default index is created.
    --
    INDEX ix_graphid UNIQUE ($edge_id),

    -- indexes on $from_id and $to_id are optional, but support faster lookups.
    --
    INDEX ix_fromid ($from_id, $to_id),
    INDEX ix_toid ($to_id, $from_id)

)
AS Edge
GO

DECLARE @mylastident AS int
Insert INTO DirectoryNames(DirectoryName) select 'root'
Insert INTO DirectoryNames(DirectoryName) select 'Windows'
Insert INTO DirectoryNames(DirectoryName) select 'Temp'
Insert INTO SubDirectoryOf Values ((SELECT $node_id From DirectoryNames WHERE DirectoryName = 'root'),(SELECT $node_id From DirectoryNames WHERE DirectoryName = 'Windows'))
Insert INTO DirectoryNames(DirectoryName) select 'Temp'
PRINT '@@Identy = ' + @@IDENTITY
SET @mylastident = @@IDENTITY
PRINT  '@mylastident = ' + @mylastident
DECLARE @xmltmp xml = (SELECT * FROM DirectoryNames FOR XML AUTO   )
PRINT CONVERT(NVARCHAR(MAX), @xmltmp)
/*
Insert INTO SubDirectoryOf Values ((SELECT $node_id From DirectoryNames WHERE DirectoryName = 'root'),(SELECT $node_id From DirectoryNames WHERE DirectoryName = 'Temp' ))
*/
GO

/*
Select N.DirectoryName as 'Parent', N2.DirectoryName as 'Child' from DirectoryNames N,  DirectoryNames N2, SubDirectoryOf S WHERE Match(N-(S)->N2)
*/


