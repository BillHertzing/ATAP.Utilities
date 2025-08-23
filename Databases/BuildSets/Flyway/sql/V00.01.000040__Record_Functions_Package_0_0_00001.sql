-- V00.01.000360__Record_Functions_Package_0_0_1.sql
DECLARE @PackageName nvarchar(128) = N'BuildSets.Functions';
DECLARE @Version     nvarchar(64)  = N'${functions_version}';   -- e.g. 0.0.00001
DECLARE @GitTag      nvarchar(128) = N'${git_tag}';
DECLARE @GitCommit   nvarchar(40)  = N'${git_commit}';

INSERT dbo.SchemaManifest (PackageName, PackageVersion, GitTag, GitCommit)
VALUES (@PackageName, @Version, @GitTag, @GitCommit);

DECLARE @ManifestId int = SCOPE_IDENTITY();

/* CI generates these INSERTs for each file with its SHA256 */
INSERT dbo.SchemaManifestFile(ManifestId, FileName, FileType, Sha256Hex) VALUES
(@ManifestId, N'R__Verification_BuildSets.sql', 'R', N'6a2fe...'),
(@ManifestId, N'R__Permissions.sql',                  'R', N'1bf0c...'),
(@ManifestId, N'V00.01.000100__Create_BuildSets_Core_Schema.sql','V',N'9e7db...');
