#Requires -Version 7.0

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $publicDir = Join-Path $moduleRoot 'public'

  . (Join-Path $publicDir 'Get-InstantiationSourceModuleInventory.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
}

Describe 'Get-InstantiationSourceModuleInventory' -Tag 'Unit' {
  BeforeEach {
    $script:repoRoot = Join-Path ([System.IO.Path]::GetTempPath()) "atap-source-ingestion-$([guid]::NewGuid().ToString('N'))"
    $script:srcRoot = Join-Path $script:repoRoot 'src'
    New-Item -ItemType Directory -Path $script:srcRoot -Force | Out-Null

    $securityRoot = Join-Path $script:srcRoot 'ATAP.Utilities.Security.Powershell'
    New-Item -ItemType Directory -Path (Join-Path $securityRoot 'public') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $securityRoot 'private') -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $securityRoot 'ATAP.Utilities.Security.Powershell.psd1') -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $securityRoot 'public\Get-SecuritySecret.ps1') -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $securityRoot 'private\Resolve-SecuritySecret.ps1') -Force | Out-Null

    $manifestOnlyRoot = Join-Path $script:srcRoot 'ATAP.Utilities.Hydrus.Powershell'
    New-Item -ItemType Directory -Path $manifestOnlyRoot -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $manifestOnlyRoot 'ATAP.Utilities.Hydrus.PowerShell.psd1') -Force | Out-Null

    $csharpRoot = Join-Path $script:srcRoot 'ATAP.Utilities.Secrets'
    New-Item -ItemType Directory -Path $csharpRoot -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $csharpRoot 'ATAP.Utilities.Secrets.csproj') -Force | Out-Null
  }

  AfterEach {
    Remove-Item -LiteralPath $script:repoRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'discovers PowerShell source modules and skips non-PowerShell source folders' {
    $result = @(Get-InstantiationSourceModuleInventory -RepositoryRoot $script:repoRoot)

    $result.ModuleName | Should -Contain 'ATAP.Utilities.Security.Powershell'
    $result.ModuleName | Should -Contain 'ATAP.Utilities.Hydrus.PowerShell'
    $result.ModuleName | Should -Not -Contain 'ATAP.Utilities.Secrets'
    $result.Count | Should -Be 2
  }

  It 'discovers C# project source modules when IncludeCSharp is set' {
    $result = @(Get-InstantiationSourceModuleInventory -RepositoryRoot $script:repoRoot -IncludeCSharp)
    $secretsModule = $result | Where-Object { $_.ModuleName -eq 'ATAP.Utilities.Secrets' }

    $secretsModule.ModuleKind | Should -Be 'CSharp'
    $secretsModule.SourceRootRelativePath | Should -Be 'src\ATAP.Utilities.Secrets'
    $secretsModule.IsPlanned | Should -BeFalse
  }

  It 'returns SourceModule rows shaped for the instantiation database model' {
    $result = @(Get-InstantiationSourceModuleInventory -RepositoryRoot $script:repoRoot)
    $securityModule = $result | Where-Object { $_.ModuleName -eq 'ATAP.Utilities.Security.Powershell' }

    $securityModule.EntityKind | Should -Be 'SourceModule'
    $securityModule.ModuleKind | Should -Be 'PowerShell'
    $securityModule.SourceRootRelativePath | Should -Be 'src\ATAP.Utilities.Security.Powershell'
    $securityModule.ManifestRelativePath | Should -Be 'src\ATAP.Utilities.Security.Powershell\ATAP.Utilities.Security.Powershell.psd1'
    $securityModule.PublicFunctionsRelativePath | Should -Be 'src\ATAP.Utilities.Security.Powershell\public'
    $securityModule.PrivateFunctionsRelativePath | Should -Be 'src\ATAP.Utilities.Security.Powershell\private'
    $securityModule.PublicFunctionCount | Should -Be 1
    $securityModule.PrivateFunctionCount | Should -Be 1
    $securityModule.IsPlanned | Should -BeFalse
    $securityModule.SourceModulePhiloteId | Should -BeOfType ([guid])
  }

  It 'adds planned PowerShell module rows when the module is not present on disk' {
    $result = @(Get-InstantiationSourceModuleInventory `
        -RepositoryRoot $script:repoRoot `
        -PlannedPowerShellModuleName 'ATAP.Utilities.Secrets.PowerShell')

    $plannedModule = $result | Where-Object { $_.ModuleName -eq 'ATAP.Utilities.Secrets.PowerShell' }

    $plannedModule.ModuleKind | Should -Be 'PlannedPowerShell'
    $plannedModule.SourceRootRelativePath | Should -Be 'src\ATAP.Utilities.Secrets.PowerShell'
    $plannedModule.IsPlanned | Should -BeTrue
    $plannedModule.ManifestationArtifacts[0].RenderPolicy | Should -Be 'Planned'
  }

  It 'uses stable SourceModule Philote identifiers for the same natural key' {
    $first = @(Get-InstantiationSourceModuleInventory -RepositoryRoot $script:repoRoot)
    $second = @(Get-InstantiationSourceModuleInventory -RepositoryRoot $script:repoRoot)

    $firstSecurityModule = $first | Where-Object { $_.ModuleName -eq 'ATAP.Utilities.Security.Powershell' }
    $secondSecurityModule = $second | Where-Object { $_.ModuleName -eq 'ATAP.Utilities.Security.Powershell' }

    $firstSecurityModule.SourceModulePhiloteId | Should -Be $secondSecurityModule.SourceModulePhiloteId
  }

  It 'throws when the source root does not exist' {
    { Get-InstantiationSourceModuleInventory -RepositoryRoot $script:repoRoot -SourceRootRelativePath 'missing-src' } |
      Should -Throw -ExpectedMessage '*Source root not found*'
  }
}
