#Requires -Module Pester

BeforeAll {
  $script:repoRoot = (Resolve-Path (Join-Path (Split-Path -Parent $PSCommandPath) '..\..')).Path
  $script:rootXml = Join-Path $script:repoRoot 'FodyWeavers.xml'
  $script:sourcePaths = @(git -C $script:repoRoot ls-files --cached --others --exclude-standard |
      Where-Object {
        $_ -match '(^|/)FodyWeavers\.(xml|xsd)$' -and
        $_ -notmatch '(^|/)OpenHardwareMonitorLib(/|$)' -and
        (Test-Path -LiteralPath (Join-Path $script:repoRoot $_) -PathType Leaf)
      })
}

Describe 'Task 15.180.j canonical Fody configuration' -Tag 'RepoHealth', 'Fody' {
  It 'has exactly one non-OHM Fody configuration at repository root' {
    @($script:sourcePaths | Where-Object { $_ -match '\.xml$' }).Count | Should -Be 1
    @($script:sourcePaths | Where-Object { $_ -eq 'FodyWeavers.xml' }).Count | Should -Be 1
  }

  It 'has no non-OHM Fody XSD' {
    @($script:sourcePaths | Where-Object { $_ -match '\.xsd$' }).Count | Should -Be 0
  }

  It 'preserves the verified canonical payload' {
    Test-Path -LiteralPath $script:rootXml -PathType Leaf | Should -BeTrue
    (Get-FileHash -LiteralPath $script:rootXml -Algorithm SHA256).Hash |
      Should -BeExactly '8AEDAB44B3C5897ACD9D8B8F6210E007CF1B1F9BC0DD6ACA457F99BEED647267'
    { [xml] (Get-Content -LiteralPath $script:rootXml -Raw) } | Should -Not -Throw
  }

  It 'sets the canonical path before Fody targets and suppresses XSD generation' {
    [xml] $props = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Directory.Build.props') -Raw
    ([string] $props.Project.PropertyGroup.ProjectWeaverXml).Trim() | Should -BeExactly '$(MSBuildThisFileDirectory)FodyWeavers.xml'
    ([string] $props.Project.PropertyGroup.FodyGenerateXsd).Trim() | Should -BeExactly 'false'
  }

  It 'honors explicit DisableFody and excludes the deferred project' {
    $targetsText = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Directory.Build.targets') -Raw
    $targetsText | Should -Match "'\$\(DisableFody\)' != 'true'"
    $targetsText | Should -Match 'ATAPDeferredOpenHardwareMonitorLib'
  }
}
