# tests/Unit/PSLSAType.Tests.ps1
#
# Regression guard for Task 12.18 (SC-0229): the PS_LSA C# type definition moved
# from public/Type-PSLSA.ps1 (top-level Add-Type in a function directory — broke
# manifest generation and violated the no-top-level-code module standard) to
# lib/PSLSA.types.ps1 (guarded Add-Type in the canonical type-definition location).
#
# Invariants guarded:
#   1. lib/PSLSA.types.ps1 exists and is idempotent (safe to dot-source repeatedly).
#   2. public/ contains no Type-PSLSA.ps1 and no file with top-level Add-Type.
#   3. Importing the module from source loads the PS_LSA type.

#Requires -Module Pester

BeforeAll {
  $script:moduleRoot   = Join-Path $PSScriptRoot '..\..' | Resolve-Path
  $script:publicDir    = Join-Path $script:moduleRoot 'public' | Resolve-Path
  $script:typesFile    = Join-Path $script:moduleRoot 'lib\PSLSA.types.ps1'
  $script:manifestPath = Join-Path $script:moduleRoot 'ATAP.Utilities.Powershell.psd1' | Resolve-Path
}

Describe 'PS_LSA type definition (lib/PSLSA.types.ps1)' {

  Context 'Canonical type-definition file placement' {
    It 'lib/PSLSA.types.ps1 exists' {
      Test-Path $script:typesFile | Should -BeTrue
    }

    It 'public/ no longer contains Type-PSLSA.ps1' {
      Test-Path (Join-Path $script:publicDir 'Type-PSLSA.ps1') | Should -BeFalse
    }

    It 'the types file defines no functions (types only)' {
      $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:typesFile, [ref]$null, [ref]$null)
      $funcs = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
      $funcs | Should -BeNullOrEmpty
    }

    It 'the Add-Type call is guarded by a type-existence check' {
      $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:typesFile, [ref]$null, [ref]$null)
      $addTypeCalls = $ast.FindAll({
          $args[0] -is [System.Management.Automation.Language.CommandAst] -and
          $args[0].GetCommandName() -eq 'Add-Type'
        }, $true)
      $addTypeCalls | Should -Not -BeNullOrEmpty
      foreach ($call in $addTypeCalls) {
        # every Add-Type must sit inside an if statement (the idempotency guard)
        $parent = $call.Parent
        $inIf = $false
        while ($null -ne $parent) {
          if ($parent -is [System.Management.Automation.Language.IfStatementAst]) { $inIf = $true; break }
          $parent = $parent.Parent
        }
        $inIf | Should -BeTrue -Because 'Add-Type must be wrapped in a type-existence guard for idempotent re-import'
      }
    }
  }

  Context 'Idempotent loading' {
    It 'dot-sourcing the types file twice in one session does not error' {
      { . $script:typesFile; . $script:typesFile } | Should -Not -Throw
    }

    It 'loads the PS_LSA.LsaWrapper and PS_LSA.Rights types' {
      . $script:typesFile
      ('PS_LSA.LsaWrapper' -as [type]) | Should -Not -BeNullOrEmpty
      ('PS_LSA.Rights' -as [type]) | Should -Not -BeNullOrEmpty
    }
  }

  Context 'Module import loads the type' {
    It 'importing the module from source dot-sources cleanly and resolves PS_LSA.LsaWrapper' {
      # NOTE: an installed/profile-loaded copy of this module may already have loaded
      # PS_LSA into the appdomain, so the type check alone cannot prove the source
      # module loads it. Guard the whole chain instead: the import itself must emit
      # no errors (the psm1 dot-sourcing loop Write-Errors on any file failure), the
      # module must actually export its functions, and the type must be resolvable.
      $importErrors = @()
      Remove-Module 'ATAP.Utilities.Powershell' -Force -ErrorAction SilentlyContinue
      Import-Module $script:manifestPath -Force -ErrorVariable +importErrors -ErrorAction Continue -WarningAction SilentlyContinue
      $importErrors | Should -BeNullOrEmpty -Because 'the psm1 file-enumeration and dot-sourcing loop must complete without errors'
      $sourceModule = Get-Module 'ATAP.Utilities.Powershell' |
        Where-Object { $_.Path -eq (Join-Path $script:moduleRoot 'ATAP.Utilities.Powershell.psm1') }
      $sourceModule | Should -Not -BeNullOrEmpty
      $sourceModule.ExportedFunctions.Count | Should -BeGreaterThan 0
      ('PS_LSA.LsaWrapper' -as [type]) | Should -Not -BeNullOrEmpty
    }
  }

  Context 'No top-level Add-Type remains in public/' {
    It 'no public *.ps1 file executes Add-Type at the top level' {
      $offenders = foreach ($ps1 in (Get-ChildItem -Path $script:publicDir -Filter '*.ps1' -File -Recurse |
            Where-Object { $_.Name -notmatch '\.Tests\.ps1$' })) {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($ps1.FullName, [ref]$null, [ref]$null)
        if ($ast.EndBlock) {
          foreach ($stmt in $ast.EndBlock.Statements) {
            if ($stmt -is [System.Management.Automation.Language.FunctionDefinitionAst]) { continue }
            $calls = $stmt.FindAll({
                $args[0] -is [System.Management.Automation.Language.CommandAst] -and
                $args[0].GetCommandName() -eq 'Add-Type'
              }, $true)
            if ($calls.Count -gt 0) { $ps1.Name }
          }
        }
      }
      $offenders | Should -BeNullOrEmpty -Because 'type definitions belong in lib/*.ps1 with a guard, never as top-level code in public/'
    }
  }
}
