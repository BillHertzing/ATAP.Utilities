#Requires -Module Pester

BeforeAll {
  $script:moduleRoot = (Join-Path $PSScriptRoot '..\..' | Resolve-Path).Path
  $script:manifestPath = Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell.psd1'
  $script:expectedCommands = @(
    'Collect-DatabasePackageEvidence'
    'Get-DatabasePackageBuildContext'
    'Initialize-ProGetSqlServiceLogin'
    'Invoke-BuildToolingSqlQuery'
    'New-DeveloperSqlServerInstances'
    'Parse-SQLFile'
    'Remove-DeveloperSqlServerInstances'
    'Remove-SprintDatabases'
    'Reset-SprintDatabases'
    'Resolve-BuildToolingDatabaseSqlConnection'
    'Resolve-DatabasePackageFeed'
    'Test-DatabasePackageCompatibility'
  )
  Remove-Module 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell' -Force -ErrorAction SilentlyContinue
  $script:module = Import-Module -Name $script:manifestPath -Force -PassThru -ErrorAction Stop
}

Describe 'DatabasePackaging child module contract' -Tag 'Unit', 'Contract' {
  It 'keeps SQL helper loading portable and resolves from an explicit repository root' {
    $helperPath = Join-Path $script:moduleRoot 'private\BuildToolingSql.Helpers.ps1'
    $helperText = Get-Content -LiteralPath $helperPath -Raw
    $helperText | Should -Not -Match 'C:\\Dropbox'
    $helperText | Should -Not -Match 'ATAP\.Utilities-wt-\d+'

    Remove-Item Function:\Resolve-DatabaseSqlConnection -ErrorAction SilentlyContinue
    Remove-Module ATAP.Utilities.DatabaseManagement.Powershell -Force -ErrorAction SilentlyContinue
    . $helperPath
    Import-BuildToolingDatabaseResolver -RepositoryRoot (Resolve-Path -LiteralPath (Join-Path $script:moduleRoot '..\..')).Path

    Get-Command -Name Resolve-DatabaseSqlConnection -CommandType Function -ErrorAction Stop |
      Should -Not -BeNullOrEmpty
  }

  It 'exports exactly the frozen legacy surface plus required child-only SQL helpers' {
    $actual = @($script:module.ExportedFunctions.Keys | Sort-Object)
    Compare-Object ($script:expectedCommands | Sort-Object) $actual | Should -BeNullOrEmpty
  }

  It 'declares the accepted immutable dependency floors' {
    $manifest = Import-PowerShellDataFile -LiteralPath $script:manifestPath
    $dependencies = @{}
    foreach ($requiredModule in $manifest.RequiredModules) {
      $dependencies[$requiredModule.ModuleName] = [string]$requiredModule.ModuleVersion
    }

    $dependencies['ATAP.Utilities.BuildTooling.Common.PowerShell'] | Should -BeExactly '0.1.7'
    $dependencies['ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'] | Should -BeExactly '0.1.1'
    $dependencies['ATAP.Utilities.BuildTooling.ProGet.PowerShell'] | Should -BeExactly '0.1.1'
    $dependencies['ATAP.Utilities.BuildTooling.Secrets.PowerShell'] | Should -BeExactly '0.1.0'
  }

  It 'parses SQL file headers without importing the compatibility parent' {
    $path = Join-Path $TestDrive 'V001__sample.sql'
    @"
-- Sample database migration

CREATE TABLE Example (Id int);
"@ | Set-Content -LiteralPath $path

    $result = Parse-SQLFile -FilePath $path -RelativePath 'Database/Flyway/V001__sample.sql'
    $result.Name | Should -BeExactly 'V001__sample'
    $result.Purpose | Should -BeExactly 'Sample database migration'
  }
}
