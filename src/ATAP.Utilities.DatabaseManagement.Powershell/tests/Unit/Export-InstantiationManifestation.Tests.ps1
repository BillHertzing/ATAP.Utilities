#Requires -Version 7.0

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $publicDir = Join-Path $moduleRoot 'public'

  . (Join-Path $publicDir 'Get-InstantiationSourceModuleInventory.ps1')
  . (Join-Path $publicDir 'Export-InstantiationManifestation.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
}

Describe 'Export-InstantiationManifestation' -Tag 'Unit' {
  BeforeEach {
    $script:repoRoot = Join-Path ([System.IO.Path]::GetTempPath()) "atap-manifestation-render-$([guid]::NewGuid().ToString('N'))"
    $script:srcRoot = Join-Path $script:repoRoot 'src'
    $script:outputRoot = Join-Path $script:repoRoot '_generated\Instantiation'
    New-Item -ItemType Directory -Path $script:srcRoot -Force | Out-Null

    $securityRoot = Join-Path $script:srcRoot 'ATAP.Utilities.Security.Powershell'
    New-Item -ItemType Directory -Path (Join-Path $securityRoot 'public') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $securityRoot 'private') -Force | Out-Null
    Set-Content -Path (Join-Path $securityRoot 'ATAP.Utilities.Security.Powershell.psd1') -Value '@{}' -Encoding utf8
    Set-Content -Path (Join-Path $securityRoot 'ATAP.Utilities.Security.Powershell.psm1') -Value 'function Invoke-Security {}' -Encoding utf8
    Set-Content -Path (Join-Path $securityRoot 'public\Get-SecuritySecret.ps1') -Value 'function Get-SecuritySecret {}' -Encoding utf8
    Set-Content -Path (Join-Path $securityRoot 'private\Resolve-SecuritySecret.ps1') -Value 'function Resolve-SecuritySecret {}' -Encoding utf8

    $secretsRoot = Join-Path $script:srcRoot 'ATAP.Utilities.Secrets'
    New-Item -ItemType Directory -Path $secretsRoot -Force | Out-Null
    Set-Content -Path (Join-Path $secretsRoot 'ATAP.Utilities.Secrets.csproj') -Value '<Project />' -Encoding utf8
    Set-Content -Path (Join-Path $secretsRoot 'Secret.cs') -Value 'namespace ATAP.Utilities.Secrets { public sealed class Secret {} }' -Encoding utf8
  }

  AfterEach {
    Remove-Item -LiteralPath $script:repoRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'renders source modules, source files, folder tree, report, and summary files' {
    $rows = @(Get-InstantiationSourceModuleInventory `
        -RepositoryRoot $script:repoRoot `
        -IncludeCSharp `
        -PlannedPowerShellModuleName 'ATAP.Utilities.Secrets.PowerShell')

    $summary = Export-InstantiationManifestation `
      -RepositoryRoot $script:repoRoot `
      -OutputDirectory $script:outputRoot `
      -VersionLabel 'v2-secrets-powershell-and-security-rearrange' `
      -SourceModule $rows

    Test-Path -LiteralPath $summary.SourceModulesPath | Should -BeTrue
    Test-Path -LiteralPath $summary.SourceFilesPath | Should -BeTrue
    Test-Path -LiteralPath $summary.FolderTreePath | Should -BeTrue
    Test-Path -LiteralPath $summary.ReportPath | Should -BeTrue
    Test-Path -LiteralPath $summary.SummaryPath | Should -BeTrue
    $summary.SourceModuleCount | Should -Be 3
    $summary.SourceFileCount | Should -BeGreaterThan 0
    $summary.MissingExpectedCount | Should -Be 0

    $folderTree = Get-Content -LiteralPath $summary.FolderTreePath
    $folderTree | Should -Contain 'src\ATAP.Utilities.Security.Powershell'
    $folderTree | Should -Contain 'src\ATAP.Utilities.Secrets.PowerShell'

    $report = Get-Content -LiteralPath $summary.ReportPath -Raw
    $report | Should -Match 'ATAP.Utilities.Secrets.PowerShell'
    $report | Should -Match 'planned'
  }
}
