# tests/Unit/ATAP.Utilities.DatabaseManagement.Powershell.ExportConsistency.Tests.ps1
#
# Module export-consistency guard (V4-B08).
#
# This module's public/ folder contains eponymous public functions plus a number
# of co-located internal helpers (e.g. Sec-*, build*Section, Invoke-SqlFile,
# Resolve-ServerInstance) that are intentionally NOT exported. The invariant we
# guard here is the one that matters for a published module: every name declared
# in FunctionsToExport must resolve to a real function, and the imported module
# must export each declared name (no phantom exports). This fails fast if a
# phantom export is reintroduced before the module reaches a ProGet feed.

#Requires -Module Pester

BeforeAll {
  $script:moduleRoot   = Join-Path $PSScriptRoot '..\..' | Resolve-Path
  $script:publicDir    = Join-Path $script:moduleRoot 'public' | Resolve-Path
  $script:manifestPath = Join-Path $script:moduleRoot 'ATAP.Utilities.DatabaseManagement.Powershell.psd1' | Resolve-Path

  # Every function name defined anywhere in the public files (eponymous + helpers).
  $script:definedFunctions = Get-ChildItem -Path $script:publicDir -Filter '*.ps1' -File -Recurse |
    Where-Object { $_.Name -notmatch '\.Tests\.ps1$' } |
    ForEach-Object {
      $ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$null)
      $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
        Select-Object -ExpandProperty Name
    } | Sort-Object -Unique

  $script:declared = @((Import-PowerShellDataFile $script:manifestPath).FunctionsToExport) | Sort-Object
}

Describe 'ATAP.Utilities.DatabaseManagement.Powershell module export consistency' {

  Context 'Every declared export resolves to a defined public function' {
    It 'has no phantom export (declared name with no backing function)' {
      $phantom = $script:declared | Where-Object { $_ -notin $script:definedFunctions }
      $phantom | Should -BeNullOrEmpty -Because 'every FunctionsToExport name must be defined by a public/*.ps1 file'
    }
  }

  Context 'FunctionsToExport has no duplicate entries' {
    It 'declares each export name at most once' {
      $dupes = $script:declared | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name
      $dupes | Should -BeNullOrEmpty
    }
  }

  Context 'Manifest and import' {
    BeforeAll {
      $script:tmm = Test-ModuleManifest -Path $script:manifestPath -ErrorAction Stop
      Remove-Module 'ATAP.Utilities.DatabaseManagement.Powershell' -Force -ErrorAction SilentlyContinue
      Import-Module $script:manifestPath -Force -ErrorAction Stop -WarningAction SilentlyContinue
      $script:liveExports = (Get-Module 'ATAP.Utilities.DatabaseManagement.Powershell').ExportedFunctions.Keys
    }

    It 'Test-ModuleManifest succeeds' {
      $script:tmm | Should -Not -BeNullOrEmpty
    }

    It 'exports every name declared in FunctionsToExport' {
      $missing = $script:declared | Where-Object { $_ -notin $script:liveExports }
      $missing | Should -BeNullOrEmpty -Because 'declared exports must resolve to real, exported functions'
    }
  }
}
