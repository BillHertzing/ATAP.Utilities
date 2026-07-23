# tests/Unit/ATAP.Utilities.BuildTooling.PowerShell.Tests.ps1
#
# Module export-consistency guard (V4-B08).
#
# The build (module.build.ps1 -> BuildManifest task) computes physical exports
# from the *basenames* of public/*.ps1 files and retains explicit source-manifest
# exports for compatibility proxies created at runtime. Therefore a public file
# whose top-level function name does not equal its basename still produces a
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
  $script:manifest = Import-PowerShellDataFile $script:manifestPath
  $script:declared = $script:manifest.FunctionsToExport | Sort-Object
  $script:childDeclared = @(
    foreach ($requiredModule in @($script:manifest.RequiredModules)) {
      $requiredName = [string] $requiredModule.ModuleName
      if ($requiredName -notlike 'ATAP.Utilities.BuildTooling.*.PowerShell') {
        continue
      }
      $childManifestPath = Join-Path (
        Split-Path -Parent $script:moduleRoot
      ) "$requiredName\$requiredName.psd1"
      if (Test-Path -LiteralPath $childManifestPath -PathType Leaf) {
        (Import-PowerShellDataFile $childManifestPath).FunctionsToExport
      }
    }
  ) | Sort-Object -Unique
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

  Context 'Committed manifest FunctionsToExport covers parent and compatibility children' {
    It 'declares every remaining parent public file basename' {
      @($script:basenames | Where-Object { $_ -notin $script:declared }) |
        Should -BeNullOrEmpty
    }

    It 'sources every compatibility-only export from a required child manifest' {
      $compatibilityExports = @($script:declared | Where-Object { $_ -notin $script:basenames })

      @($compatibilityExports | Where-Object { $_ -notin $script:childDeclared }) |
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
