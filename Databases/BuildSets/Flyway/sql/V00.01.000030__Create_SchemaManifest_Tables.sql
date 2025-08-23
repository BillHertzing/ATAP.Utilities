
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
