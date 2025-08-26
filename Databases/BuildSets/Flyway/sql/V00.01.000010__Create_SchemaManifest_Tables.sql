
CREATE TABLE dbo.SchemaManifest (
  ManifestId     int IDENTITY(1,1) PRIMARY KEY,
  PackageName    nvarchar(128) NOT NULL,     -- e.g. 'BuildSets.Functions'
  PackageVersion nvarchar(64)  NOT NULL,     -- e.g. '1.3.0'
  GitTag         nvarchar(128) NOT NULL,     -- e.g. 'buildsets-funcs-1.3.0'
  GitCommit      nvarchar(40)  NOT NULL,     -- short or full SHA
  CreatedAt      datetime2(3)  NOT NULL CONSTRAINT DF_SchemaManifest_CreatedAt DEFAULT sysutcdatetime()
);

CREATE TABLE dbo.SchemaManifestFile (
  ManifestId   int           NOT NULL
    CONSTRAINT FK_ManifestFile_Manifest REFERENCES dbo.SchemaManifest(ManifestId),
  FileName     nvarchar(260) NOT NULL,      -- 'R__Functions_BuildSets_and_Tree.sql'
  FileType     char(1)       NOT NULL,      -- 'R' or 'V'
  Sha256Hex    varchar(64)   NOT NULL
);


  CREATE TYPE dbo.SchemaManifestFileType AS TABLE
  (
    FileName   nvarchar(260) NOT NULL,
    FileType   char(1)       NOT NULL, -- 'V' or 'R'
    Sha256Hex  char(64)      NOT NULL
  );

GO

CREATE PROCEDURE dbo.RecordSchemaManifest
  @PackageName    nvarchar(128),
  @PackageVersion nvarchar(64),
  @GitTag         nvarchar(128),
  @GitCommit      nvarchar(40),
  @Files          dbo.SchemaManifestFileType READONLY
AS
BEGIN
  SET NOCOUNT ON;

  INSERT dbo.SchemaManifest (PackageName, PackageVersion, GitTag, GitCommit)
  VALUES (@PackageName, @PackageVersion, @GitTag, @GitCommit);

  DECLARE @ManifestId int = SCOPE_IDENTITY();

  INSERT dbo.SchemaManifestFile (ManifestId, FileName, FileType, Sha256Hex)
  SELECT @ManifestId, f.FileName, f.FileType, f.Sha256Hex
  FROM @Files f;
END;
GO
GO
