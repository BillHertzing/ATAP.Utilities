# tests/Unit/ATAP.Utilities.Powershell.ExportConsistency.Tests.ps1
#
# Module export-consistency guard (V4-B08).
#
# Unlike ATAP.Utilities.BuildTooling.PowerShell (whose manifest is auto-generated
# from public/*.ps1 basenames and therefore requires every public file to be
# eponymous), this module's manifest is hand-maintained and the public/ folder
# legitimately contains a few NON-function files:
#
#   - Type-PSLSA.ps1            defines the PS_LSA C# type via Add-Type (no function)
#   - testIcomparer.ps1         demonstrates a PowerShell class (no function)
#   - Test-Copilot.ps1          empty placeholder (no function)
#   - SomethingDebugUtilities.ps1  internal Write-* debug helpers (no eponymous function)
#
# Those files must therefore NOT appear in FunctionsToExport. The invariant we
# guard here is the one that actually matters for a published module: every name
# declared in FunctionsToExport must resolve to a real function, and the imported
# module must export each declared name (no phantom exports). This fails fast if a
# phantom export (e.g. a tool re-adding a basename that defines no function) is
# reintroduced before the module reaches a ProGet feed.

#Requires -Module Pester

BeforeAll {
  $script:moduleRoot   = Join-Path $PSScriptRoot '..\..' | Resolve-Path
  $script:publicDir    = Join-Path $script:moduleRoot 'public' | Resolve-Path
  $script:manifestPath = Join-Path $script:moduleRoot 'ATAP.Utilities.Powershell.psd1' | Resolve-Path

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

Describe 'ATAP.Utilities.Powershell module export consistency' {

  Context 'Every declared export resolves to a defined public function' {
    It 'has no phantom export (declared name with no backing function)' {
      $phantom = $script:declared | Where-Object { $_ -notin $script:definedFunctions }
      $phantom | Should -BeNullOrEmpty -Because @'
Every name in FunctionsToExport must be defined by a public/*.ps1 file. A
declared name with no backing function exports nothing and silently disappears
from the published module (e.g. Type-PSLSA / testIcomparer / Test-Copilot /
SomethingDebugUtilities, which define a type, a class, nothing, and internal
helpers respectively, and must not be declared as exports).
'@
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
      Remove-Module 'ATAP.Utilities.Powershell' -Force -ErrorAction SilentlyContinue
      Import-Module $script:manifestPath -Force -ErrorAction Stop -WarningAction SilentlyContinue
      $script:liveExports = (Get-Module 'ATAP.Utilities.Powershell').ExportedFunctions.Keys
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
