# Pester 5+ unit tests for Resolve-PSModuleMetadata (T-10).
#
# NOTE: The NTFS-junction reachability case described in the T-10 spec is
# covered manually (it requires elevated rights and a real junction) and is
# therefore intentionally NOT asserted here. These tests cover:
#   - Module at depth 2 below 'src/' (happy path)
#   - Module at depth 4 below 'src/' (deep nesting)
#   - Module folder with zero matching .psd1 (throws)
#   - Module folder with two matching .psd1 (throws)

BeforeAll {
  $functionName = 'Resolve-PSModuleMetadata'
  if (-not (Get-Command -Name $functionName -CommandType Function -ErrorAction SilentlyContinue)) {
    $functionPath = Join-Path $PSScriptRoot -ChildPath "../../public/$functionName.ps1"
    if (Test-Path $functionPath) {
      . $functionPath
    } else {
      throw "Function file not found: $functionPath"
    }
  }
}

Describe 'Resolve-PSModuleMetadata' {

  BeforeAll {
    $script:createdRoots = New-Object System.Collections.Generic.List[string]

    function New-TempGitRepo {
      [CmdletBinding()]
      param()
      $repo = Join-Path ([System.IO.Path]::GetTempPath()) ('RPMM_' + [guid]::NewGuid().ToString('N'))
      New-Item -ItemType Directory -Path $repo -Force | Out-Null
      Push-Location $repo
      try {
        & git init --quiet 2>&1 | Out-Null
        & git config user.email 'test@example.com' 2>&1 | Out-Null
        & git config user.name 'test' 2>&1 | Out-Null
      } finally {
        Pop-Location
      }
      $script:createdRoots.Add($repo)
      return $repo
    }

    function New-ModuleFolder {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)] [string]$RepoRoot,
        [Parameter(Mandatory)] [string]$RelativePath,
        [Parameter(Mandatory)] [string]$ModuleName,
        [int]$ManifestCount = 1,
        [string[]]$ExtraManifestNames = @()
      )
      $moduleRoot = Join-Path $RepoRoot (Join-Path $RelativePath $ModuleName)
      New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null

      if ($ManifestCount -ge 1) {
        $psd1 = Join-Path $moduleRoot "$ModuleName.psd1"
        Set-Content -LiteralPath $psd1 -Value "@{ ModuleVersion = '0.0.1' }" -Encoding utf8
      }
      foreach ($extra in $ExtraManifestNames) {
        $extraPath = Join-Path $moduleRoot "$extra.psd1"
        Set-Content -LiteralPath $extraPath -Value "@{ ModuleVersion = '0.0.1' }" -Encoding utf8
      }
      return $moduleRoot
    }
  }

  AfterAll {
    foreach ($root in $script:createdRoots) {
      if (Test-Path $root) {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }

  It 'Function exists' {
    Get-Command -Name 'Resolve-PSModuleMetadata' | Should -Not -BeNullOrEmpty
  }

  Context 'Happy path — module at depth 2 below src/' {
    It 'returns a PSCustomObject with all five fields correctly populated' {
      $repo = New-TempGitRepo
      $moduleName = 'My.Module.ShallowCase'
      $moduleRoot = New-ModuleFolder -RepoRoot $repo -RelativePath 'src' -ModuleName $moduleName

      $result = Resolve-PSModuleMetadata -StartPath $moduleRoot

      $result | Should -Not -BeNullOrEmpty
      $result.ModuleName | Should -Be $moduleName
      $expectedModuleRoot = ($moduleRoot -replace '\\', '/').TrimEnd('/')
      $result.ModuleRoot | Should -Be $expectedModuleRoot
      $expectedRepoRoot = ($repo -replace '\\', '/').TrimEnd('/')
      # Use -Match because on Windows temp paths may have differing case for drive letter
      $result.RepoRoot.ToLower() | Should -Be $expectedRepoRoot.ToLower()
      $result.ManifestPath | Should -Match ([regex]::Escape("$moduleName.psd1") + '$')
      $result.ManifestPath | Should -Not -Match '\\'
      $result.OutputRoot | Should -Be "$($result.RepoRoot)/_generated/psmodules/$moduleName/"
    }
  }

  Context 'Deep nesting — module at depth 4 below src/' {
    It 'still locates the manifest and repo root' {
      $repo = New-TempGitRepo
      $moduleName = 'My.Module.DeepCase'
      $moduleRoot = New-ModuleFolder -RepoRoot $repo -RelativePath 'src/level1/level2/level3' -ModuleName $moduleName

      $result = Resolve-PSModuleMetadata -StartPath $moduleRoot

      $result.ModuleName | Should -Be $moduleName
      $result.ManifestPath | Should -Match ([regex]::Escape("$moduleName.psd1") + '$')
      $result.OutputRoot | Should -Be "$($result.RepoRoot)/_generated/psmodules/$moduleName/"
      $result.ModuleRoot | Should -Match 'level1/level2/level3'
    }
  }

  Context 'Error — no .psd1 file present' {
    It 'throws a clear error' {
      $repo = New-TempGitRepo
      $moduleName = 'My.Module.NoManifest'
      $moduleRoot = New-ModuleFolder -RepoRoot $repo -RelativePath 'src' -ModuleName $moduleName -ManifestCount 0

      { Resolve-PSModuleMetadata -StartPath $moduleRoot } | Should -Throw -ErrorId '*'
      { Resolve-PSModuleMetadata -StartPath $moduleRoot } | Should -Throw "*No '*.psd1' manifest*"
    }
  }

  Context 'Error — two matching .psd1 files present' {
    It 'throws a clear error' {
      $repo = New-TempGitRepo
      $moduleName = 'My.Module.Dup'
      # Build a folder with one matching manifest, then add a second one that
      # also matches the folder BaseName by renaming the module folder path
      # trickery — simplest way is to drop a second file named identically but
      # at a different casing. Windows is case-insensitive, so instead we
      # simulate "multiple matching" by creating TWO folders sharing the same
      # BaseName via a nested duplicate. But Get-ChildItem -File non-recursive
      # won't see nested. So we rig the test using a folder whose name matches
      # TWO files: one exact and one created by copying after-the-fact.
      $moduleRoot = Join-Path $repo (Join-Path 'src' $moduleName)
      New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null
      $first = Join-Path $moduleRoot "$moduleName.psd1"
      Set-Content -LiteralPath $first -Value "@{ ModuleVersion = '0.0.1' }" -Encoding utf8

      # Force a second matching file by temporarily using Mock on Get-ChildItem
      # within this scope — because the filesystem cannot actually host two
      # files with the same name in the same directory.
      Mock -CommandName Get-ChildItem -MockWith {
        @(
          [PSCustomObject]@{ BaseName = 'My.Module.Dup'; FullName = (Join-Path $moduleRoot 'My.Module.Dup.psd1') }
          [PSCustomObject]@{ BaseName = 'My.Module.Dup'; FullName = (Join-Path $moduleRoot 'My.Module.Dup.Copy.psd1') }
        )
      } -ParameterFilter { $Filter -eq '*.psd1' }

      { Resolve-PSModuleMetadata -StartPath $moduleRoot } | Should -Throw "*Multiple '*.psd1' manifests*"
    }
  }
}
