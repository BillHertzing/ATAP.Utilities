# tests/Unit/ATAP.Utilities.RulesManagement.PowerShell.ExportConsistency.Tests.ps1
#
# Module export-consistency guard.
#
# This module's public/ folder contains eponymous public functions. The invariant
# we guard here is the one that matters for a published module: every name declared
# in FunctionsToExport must resolve to a real function, and the imported module must
# export each declared name (no phantom exports). This fails fast if a phantom
# export is reintroduced before the module reaches a ProGet feed.

#Requires -Module Pester

BeforeAll {
  $script:moduleRoot   = Join-Path $PSScriptRoot '..\..' | Resolve-Path
  $script:publicDir    = Join-Path $script:moduleRoot 'public' | Resolve-Path
  $script:manifestPath = Join-Path $script:moduleRoot 'ATAP.Utilities.RulesManagement.PowerShell.psd1' | Resolve-Path

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

Describe 'ATAP.Utilities.RulesManagement.PowerShell module export consistency' -Tag 'Unit' {

  Context 'Every declared export resolves to a defined public function' {
    It 'has no phantom export (declared name with no backing function)' {
      $phantom = $script:declared | Where-Object { $_ -notin $script:definedFunctions }
      $phantom | Should -BeNullOrEmpty -Because 'every FunctionsToExport name must be defined by a public/*.ps1 file'
    }
  }

  Context 'Every public function file has a matching declared export' {
    It 'exports every eponymous public function (basename == function name)' {
      # The published surface should expose each public/*.ps1 eponymous function.
      $eponymous = Get-ChildItem -Path $script:publicDir -Filter '*.ps1' -File |
        Where-Object { $_.Name -notmatch '\.Tests\.ps1$' } |
        ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) } |
        Where-Object { $_ -in $script:definedFunctions }
      $unexported = $eponymous | Where-Object { $_ -notin $script:declared }
      $unexported | Should -BeNullOrEmpty -Because 'each eponymous public function should be listed in FunctionsToExport'
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
      Remove-Module 'ATAP.Utilities.RulesManagement.PowerShell' -Force -ErrorAction SilentlyContinue
      Import-Module $script:manifestPath -Force -ErrorAction Stop -WarningAction SilentlyContinue
      $script:liveExports = (Get-Module 'ATAP.Utilities.RulesManagement.PowerShell').ExportedFunctions.Keys
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
