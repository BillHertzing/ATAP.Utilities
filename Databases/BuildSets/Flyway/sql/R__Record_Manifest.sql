/* Rebuilds and records package manifest. Flyway placeholders populate values. */

DECLARE @PackageName    nvarchar(128) = '${PackageName}';
DECLARE @PackageVersion nvarchar(64)  = '${PackageVersion}';
DECLARE @GitTag         nvarchar(128) = '${GitTag}';
DECLARE @GitCommit      nvarchar(40)  = '${GitCommit}';

/* ${ManifestValues} must expand to:
   (N'FileName1','V',N'<sha1>'),
   (N'FileName2','R',N'<sha2>')  (no trailing comma) */

DECLARE @Files dbo.SchemaManifestFileType;

INSERT @Files (FileName, FileType, Sha256Hex)
SELECT v.FileName, v.FileType, v.Sha256Hex
FROM (VALUES ${ManifestValues}) AS v(FileName, FileType, Sha256Hex);

EXEC dbo.RecordSchemaManifest
  @PackageName    = @PackageName,
  @PackageVersion = @PackageVersion,
  @GitTag         = @GitTag,
  @GitCommit      = @GitCommit,
  @Files          = @Files;
