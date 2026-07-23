#Requires -Version 7.0

Describe 'PlanningSession child scaffold contract' -Tag 'Unit' {
  BeforeAll {
    $script:ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:ManifestPath = Join-Path $script:ModuleRoot 'ATAP.Utilities.BuildTooling.PlanningSession.PowerShell.psd1'
    $script:Manifest = Import-PowerShellDataFile -LiteralPath $script:ManifestPath
    $script:Family = Import-PowerShellDataFile -LiteralPath (Join-Path (Split-Path -Parent (Split-Path -Parent $script:ModuleRoot)) 'ModuleFamily.psd1')
  }

  It 'uses the approved identity and PowerShell policy' {
    $script:Manifest.GUID.ToString() | Should -Be '80eb57ae-f4e4-4473-8b87-fcd3a51a5629'
    $script:Manifest.PowerShellVersion.ToString() | Should -Be '7.0'
    @($script:Manifest.CompatiblePSEditions) | Should -Be @('Core')
  }

  It 'starts with explicit empty exports' {
    @($script:Manifest.FunctionsToExport).Count | Should -Be 0
    @($script:Manifest.CmdletsToExport).Count | Should -Be 0
    @($script:Manifest.AliasesToExport).Count | Should -Be 0
  }

  It 'pins GitWorktree 0.1.3 consistently in manifest and family metadata' {
    $requirement = @($script:Manifest.RequiredModules | Where-Object ModuleName -eq 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell')
    $requirement.Count | Should -Be 1
    $requirement[0].ModuleVersion.ToString() | Should -Be '0.1.3'

    $member = @($script:Family.Members | Where-Object Name -eq 'ATAP.Utilities.BuildTooling.PlanningSession.PowerShell')
    $member.Count | Should -Be 1
    @($member[0].Dependencies) | Should -Be @('ATAP.Utilities.BuildTooling.GitWorktree.PowerShell')
    $member[0].MinimumVersions['ATAP.Utilities.BuildTooling.GitWorktree.PowerShell'] | Should -Be '0.1.3'
  }

  It 'has stable-release NBGV metadata' {
    $metadata = Get-Content -LiteralPath (Join-Path $script:ModuleRoot 'version.json') -Raw | ConvertFrom-Json
    $metadata.version | Should -Be '0.1.0'
    @($metadata.publicReleaseRefSpec) | Should -Contain '.*'
  }
}
