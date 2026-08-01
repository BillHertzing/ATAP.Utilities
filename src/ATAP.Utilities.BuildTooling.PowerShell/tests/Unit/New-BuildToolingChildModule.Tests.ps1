#Requires -Module Pester

Describe 'New-BuildToolingChildModule' {
  BeforeAll {
    $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
    . (Join-Path $script:RepositoryRoot 'src\ATAP.Utilities.BuildTooling.PowerShell\public\New-BuildToolingChildModule.ps1')
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) { function Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$args) } }
  }

  It 'renders one empty importable approved child without editing other repositories' {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
    try {
      New-Item -ItemType Directory -Path $root -Force | Out-Null
      $result = New-BuildToolingChildModule -ModuleName 'ATAP.Utilities.BuildTooling.PesterScaffolding.PowerShell' -SourceRoot $root -ModuleFamilyPath (Join-Path $script:RepositoryRoot 'ModuleFamily.psd1') -Confirm:$false
      Test-Path -LiteralPath $result.ManifestPath | Should -BeTrue
      (Test-ModuleManifest -Path $result.ManifestPath).Name | Should -Be $result.ModuleName
      $result.BuildMasterMapEntry | Should -Match 'ATAP.Utilities-PowerShell'
      $result.SolutionDocumentationIndexPointer | Should -Match $result.ModuleName
    } finally {
      Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}
