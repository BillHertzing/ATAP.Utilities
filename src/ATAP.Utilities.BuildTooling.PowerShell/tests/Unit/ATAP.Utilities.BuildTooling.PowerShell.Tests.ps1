# tests/Unit/ATAP.Utilities.BuildTooling.PowerShell.Tests.ps1
#
# Module export-consistency guard (V4-B08).
#
# The build (module.build.ps1 -> BuildManifest task) computes FunctionsToExport
# from the *basenames* of public/*.ps1 files, NOT from the function names parsed
# out of those files. Therefore a public file whose top-level function name does
# not equal its basename produces a manifest entry that exports nothing — a
# "phantom export" that silently disappears from the published module.
#
# These tests fail fast if that drift is reintroduced, before a module ever
# reaches a ProGet feed.

#Requires -Module Pester

BeforeAll {
  $script:moduleRoot = Join-Path $PSScriptRoot '..\..' | Resolve-Path
  $script:publicDir = Join-Path $script:moduleRoot 'public' | Resolve-Path
  $script:manifestPath = Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.PowerShell.psd1' | Resolve-Path

  # Top-level function names declared in each public file, keyed by basename.
  $script:fileFunctionMap = Get-ChildItem -Path $script:publicDir -Filter '*.ps1' -File -Recurse |
    Where-Object { $_.Name -notmatch '\.Tests\.ps1$' } |
    ForEach-Object {
      $ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$null)
      $topLevel = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) |
        Select-Object -ExpandProperty Name
      [PSCustomObject]@{
        BaseName      = $_.BaseName
        TopLevelNames = @($topLevel)
      }
    }

  $script:basenames = $script:fileFunctionMap.BaseName | Sort-Object
  $script:declared = (Import-PowerShellDataFile $script:manifestPath).FunctionsToExport | Sort-Object
}

Describe 'BuildTooling.PowerShell module export consistency' {

  Context 'Every public file defines a top-level function matching its basename' {
    It 'has no file whose top-level function name differs from its basename' {
      $mismatched = $script:fileFunctionMap |
        Where-Object { $_.BaseName -notin $_.TopLevelNames } |
        ForEach-Object { "$($_.BaseName).ps1 -> defines [$($_.TopLevelNames -join ', ')]" }
      $mismatched | Should -BeNullOrEmpty -Because @'
Each public/*.ps1 file must define a top-level function whose name equals the
file basename; the build derives FunctionsToExport from basenames, so any drift
produces a phantom export.
'@
    }
  }

  Context 'Committed manifest FunctionsToExport matches the public file set' {
    It 'declares exactly one export per public file basename (no extras, no omissions)' {
      Compare-Object -ReferenceObject $script:basenames -DifferenceObject $script:declared |
        Should -BeNullOrEmpty
    }
  }

  Context 'Imported module exports every declared function with no phantoms' {
    BeforeAll {
      if (-not (Get-Module -Name 'ATAP.Utilities.BuildTooling.PowerShell')) {
        Import-Module $script:manifestPath -Force -ErrorAction Stop -WarningAction SilentlyContinue
      }
      $script:liveExports = (Get-Module 'ATAP.Utilities.BuildTooling.PowerShell').ExportedFunctions.Keys
    }

    It 'exports every name declared in FunctionsToExport' {
      $phantom = $script:declared | Where-Object { $_ -notin $script:liveExports }
      $phantom | Should -BeNullOrEmpty -Because 'declared exports must resolve to real functions'
    }

    It 'resolves the canonical Test-ProGetFeedSet (renamed from Validate-ProGetFeeds)' {
      Get-Command -Module 'ATAP.Utilities.BuildTooling.PowerShell' -Name 'Test-ProGetFeedSet' -ErrorAction SilentlyContinue |
        Should -Not -BeNullOrEmpty
    }
  }
}
