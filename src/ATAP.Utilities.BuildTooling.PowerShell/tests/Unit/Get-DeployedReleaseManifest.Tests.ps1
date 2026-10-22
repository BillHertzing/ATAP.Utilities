#Requires -Version 7.0
BeforeAll {
  $moduleRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot);$publicDir=Join-Path $moduleRoot 'public';$fixtureDir=Join-Path $moduleRoot 'tests\fixtures\release-manifests'
  . (Join-Path $publicDir 'Get-DeployedReleaseManifest.ps1')
  if(-not(Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)){function global:Write-PSFMessage{param([Parameter(ValueFromRemainingArguments=$true)]$rest)}}
  $script:valid=Join-Path $fixtureDir 'acecommander-1.4.0-manifest.json';$script:malformed=Join-Path $fixtureDir 'malformed-manifest.json';$script:v1=Join-Path $fixtureDir 'invalid-schema-manifest.json';$script:oldProgramData=$env:ProgramData
  $script:fixtureRoot=Join-Path ([IO.Path]::GetTempPath()) ('DM-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($script:fixtureRoot)
}
AfterAll {$env:ProgramData=$script:oldProgramData}
Describe 'Get-DeployedReleaseManifest canonical v2' -Tag Unit {
  It 'returns a schema-v2 application-only manifest' {
    $m=Get-DeployedReleaseManifest -Path $script:valid;$m.schemaVersion|Should -Be 2;$m.releaseVersion|Should -BeExactly '1.4.0';$m.applicationProvenance.root.id|Should -BeExactly 'AceCommander.Server';$m.databasePackageReference.id|Should -BeExactly 'AceCommander.Database';$m.PSObject.Properties.Name|Should -Not -Contain 'migrationFiles'
  }
  It 'defaults to ProgramData AceCommander manifest.json' {
    $root=Join-Path $script:fixtureRoot 'ProgramData';$dir=Join-Path $root 'AceCommander';[IO.Directory]::CreateDirectory($dir)|Out-Null;Copy-Item $script:valid (Join-Path $dir 'manifest.json')
    try{$env:ProgramData=$root;(Get-DeployedReleaseManifest).schemaVersion|Should -Be 2}finally{$env:ProgramData=$script:oldProgramData}
  }
  It 'throws for missing files' {{$missing=Join-Path $script:fixtureRoot 'missing.json';Get-DeployedReleaseManifest -Path $missing}|Should -Throw -ExpectedMessage '*not found*'}
  It 'throws for malformed JSON' {{Get-DeployedReleaseManifest -Path $script:malformed}|Should -Throw -ExpectedMessage '*malformed JSON*'}
  It 'rejects ordinary v1 before legacy data can be consumed' {{Get-DeployedReleaseManifest -Path $script:v1}|Should -Throw -ExpectedMessage 'ATAPBUILD014:*v1*'}
  It 'rejects string schemaVersion even when its value is 2' {
    $m=Get-Content $script:valid -Raw|ConvertFrom-Json;$m.schemaVersion='2';$path=Join-Path $script:fixtureRoot 'string-schema.json';$m|ConvertTo-Json -Depth 20|Set-Content $path
    {Get-DeployedReleaseManifest -Path $path}|Should -Throw -ExpectedMessage 'ATAPBUILD014:*numeric*'
  }
}
