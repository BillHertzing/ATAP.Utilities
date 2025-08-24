DECLARE @PackageName    nvarchar(128) = N'$(PackageName)';
DECLARE @PackageVersion nvarchar(64)  = N'$(PackageVersion)';
DECLARE @GitTag         nvarchar(128) = N'$(GitTag)';
DECLARE @GitCommit      nvarchar(40)  = N'$(GitCommit)';

INSERT dbo.SchemaManifest (PackageName, PackageVersion, GitTag, GitCommit)
VALUES (@PackageName, @PackageVersion, @GitTag, @GitCommit);

DECLARE @ManifestId int = SCOPE_IDENTITY();

/* -- $(ValuesList) must expand to: (N'<FileName>', '<Type>', N'<Sha>'),(N'...', 'R', N'...') */
INSERT dbo.SchemaManifestFile(ManifestId, FileName, FileType, Sha256Hex)
SELECT @ManifestId, v.FileName, v.FileType, v.Sha256Hex
FROM (VALUES $(ValuesList)) AS v(FileName, FileType, Sha256Hex);


