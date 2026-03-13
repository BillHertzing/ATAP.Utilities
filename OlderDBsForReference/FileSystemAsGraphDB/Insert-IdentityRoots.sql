USE FileSystemAsGraphDB
GO
DECLARE @mylastident AS int
Insert INTO DirectoryInfo(DirectoryName) select 'root'
Insert INTO DirectoryInfo(DirectoryName) select 'Windows'
Insert INTO DirectoryInfo(DirectoryName) select 'Temp'
Insert INTO BelongsTo Values ((SELECT $node_id From DirectoryInfo WHERE DirectoryName = 'root'),(SELECT $node_id From DirectoryInfo WHERE DirectoryName = 'Windows'))
Insert INTO DirectoryInfo(DirectoryName) select 'Temp'
PRINT '@@Identy = ' + @@IDENTITY
SET @mylastident = @@IDENTITY
PRINT  '@mylastident = ' + @mylastident
DECLARE @xmltmp xml = (SELECT * FROM DirectoryInfo FOR XML AUTO   )
PRINT CONVERT(NVARCHAR(MAX), @xmltmp)
/*
Insert INTO BelongsTo Values ((SELECT $node_id From DirectoryInfo WHERE DirectoryName = 'root'),(SELECT $node_id From DirectoryInfo WHERE DirectoryName = 'Temp' ))
*/
GO

/*
Select N.DirectoryName as 'Parent', N2.DirectoryName as 'Child' from DirectoryInfo N,  DirectoryInfo N2, BelongsTo S WHERE Match(N-(S)->N2)
*/
