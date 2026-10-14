#Requires -Version 7.0
BeforeAll {
  $moduleRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot);$publicDir=Join-Path $moduleRoot 'public';$fixtureDir=Join-Path $moduleRoot 'tests\fixtures\release-manifests'
  . (Join-Path $publicDir 'Get-DeployedReleaseManifest.ps1');. (Join-Path $publicDir 'Compare-ReleaseManifest.ps1')
  if(-not(Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)){function global:Write-PSFMessage{param([Parameter(ValueFromRemainingArguments=$true)]$rest)}}
  $script:old=Join-Path $fixtureDir 'acecommander-1.4.0-manifest.json';$script:new=Join-Path $fixtureDir 'acecommander-1.4.1-manifest.json'
}
Describe 'Compare-ReleaseManifest canonical v2' -Tag Unit {
  It 'reports library payload component and database reference changes' {
    $r=Compare-ReleaseManifest -Old $script:old -New $script:new
    $r.OperationName|Should -BeExactly 'Compare-ReleaseManifest';$r.OldReleaseVersion|Should -BeExactly '1.4.0';$r.NewReleaseVersion|Should -BeExactly '1.4.1';$r.HasDifferences|Should -BeTrue
    $r.AddedLibraryPackages[0].id|Should -BeExactly 'ATAP.Utilities.NewLibrary';$r.RemovedLibraryPackages[0].id|Should -BeExactly 'ATAP.Utilities.Legacy';$r.ChangedLibraryPackages[0].Id|Should -BeExactly 'ATAP.Utilities.Philote'
    $r.AddedPayloadFiles[0].path|Should -BeExactly 'app/new.txt';$r.RemovedPayloadFiles[0].path|Should -BeExactly 'docs/RELEASE_NOTES.md';$r.ChangedPayloadFiles[0].Path|Should -BeExactly 'app/config/appsettings.template.json'
    $r.ChangedApplicationComponents.Count|Should -Be 2;$r.DatabasePackageReferenceChanged|Should -BeTrue;$r.NewDatabasePackageReference.lifecycleCeiling|Should -BeExactly 'database-stable'
    $r.ResponseSummary|Should -Match 'payload \+1 -1 ~1';$r.PSObject.Properties.Name|Should -Not -Contain 'AddedMigrationFiles'
  }
  It 'accepts parsed v2 objects and is stable for identical input' {
    $m=Get-DeployedReleaseManifest -Path $script:old;$r=Compare-ReleaseManifest -Old $m -New $m
    $r.HasDifferences|Should -BeFalse;$r.AddedPayloadFiles.Count|Should -Be 0;$r.ChangedApplicationComponents.Count|Should -Be 0;$r.DatabasePackageReferenceChanged|Should -BeFalse
  }
  It 'rejects ordinary v1 objects' {
    $v1=[pscustomobject]@{schemaVersion=1;releaseVersion='1.0.0';migrationFiles=@('db/flyway/V1.sql')}
    {Compare-ReleaseManifest -Old $v1 -New (Get-DeployedReleaseManifest -Path $script:new)}|Should -Throw -ExpectedMessage 'ATAPBUILD014:*v1*'
  }
  It 'rejects embedded database fields even on an object labeled v2' {
    $m=Get-DeployedReleaseManifest -Path $script:old;$m|Add-Member migrationFiles @('db/flyway/V1.sql')
    {Compare-ReleaseManifest -Old $m -New $m}|Should -Throw -ExpectedMessage 'ATAPBUILD015:*migrationFiles*'
  }
  It 'rejects unsupported input types' {{Compare-ReleaseManifest -Old 42 -New $script:new}|Should -Throw -ExpectedMessage '*expects a manifest object or a path*'}
}
Describe 'Compare-ReleaseManifest v2 adversarial identity and payload safety' {
  It 'rejects case-colliding component project paths' {
    $m=Get-DeployedReleaseManifest -Path $script:old
    $m.applicationProvenance.components=@($m.applicationProvenance.components)+@([pscustomobject]@{id='AceCommander.Client.Collision';version='1.4.0';qualityTier='Production';projectPath='SRC/ACECOMMANDER.CLIENT/ACECOMMANDER.CLIENT.CSPROJ'})
    {Compare-ReleaseManifest -Old $m -New $m}|Should -Throw -ExpectedMessage 'ATAPBUILD014:*duplicate ordinal key*'
  }
  It 'rejects an embedded database payload path' {
    $m=Get-DeployedReleaseManifest -Path $script:old
    $m.payloadFiles=@($m.payloadFiles)+@([pscustomobject]@{path='db/flyway/V1.sql';checksumSha256=('d'*64);sizeBytes=1})
    {Compare-ReleaseManifest -Old $m -New $m}|Should -Throw -ExpectedMessage 'ATAPBUILD014:*schema validation*'
  }
}