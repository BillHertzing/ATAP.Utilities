BeforeAll {
  $script:testRoot = $PSScriptRoot
}

Describe 'Sprint-boundary test isolation contract' -Tag 'Unit' {
  It 'gives every system-temporary-directory fixture a recursive cleanup hook' {
    $violations = [System.Collections.Generic.List[string]]::new()
    $testFiles = Get-ChildItem -LiteralPath $script:testRoot -File -Filter '*.Tests.ps1'

    foreach ($testFile in $testFiles) {
      if ($testFile.Name -eq 'SprintBoundaryTestIsolation.Contract.Tests.ps1') {
        continue
      }

      $source = Get-Content -LiteralPath $testFile.FullName -Raw
      if ($source -notmatch 'GetTempPath') {
        continue
      }

      $hasCleanupHook = $source -match '(?m)^\s*After(?:Each|All)\s*\{'
      $hasRecursiveCleanup = $source -match 'Remove-Item[^\r\n]*-Recurse'
      if (-not ($hasCleanupHook -and $hasRecursiveCleanup)) {
        $violations.Add($testFile.Name)
      }
    }

    $violations | Should -BeNullOrEmpty
  }

  It 'does not contain a literal path to a real Sprint 0013 worktree in a mutating command' {
    $violations = [System.Collections.Generic.List[string]]::new()
    $testFiles = Get-ChildItem -LiteralPath $script:testRoot -File -Filter '*.Tests.ps1'

    foreach ($testFile in $testFiles) {
      $lineNumber = 0
      foreach ($line in Get-Content -LiteralPath $testFile.FullName) {
        $lineNumber++
        if ($line -match '(New-Item|Set-Content|Remove-Item|Copy-Item|Move-Item).*(ATAP\.Utilities|_Planning|SharedVSCode)-wt-\d+-Sprint-0013-work-items') {
          $violations.Add("$($testFile.Name):$lineNumber")
        }
      }
    }

    $violations | Should -BeNullOrEmpty
  }

  It 'stubs the machine-wide profile worker for every mutating New-SprintStage2 test' {
    $violations = [System.Collections.Generic.List[string]]::new()
    $testFiles = Get-ChildItem -LiteralPath $script:testRoot -File -Filter '*.Tests.ps1'

    foreach ($testFile in $testFiles) {
      if ($testFile.Name -eq 'SprintBoundaryTestIsolation.Contract.Tests.ps1') {
        continue
      }

      $tokens = $null
      $parseErrors = $null
      $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $testFile.FullName,
        [ref]$tokens,
        [ref]$parseErrors
      )
      $stage2Calls = @($ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'New-SprintStage2'
          }, $true))
      if ($stage2Calls.Count -eq 0) {
        continue
      }

      $hasMutatingCall = $false
      foreach ($stage2Call in $stage2Calls) {
        $parameterNames = @(
          $stage2Call.CommandElements |
            Where-Object { $_ -is [System.Management.Automation.Language.CommandParameterAst] } |
            ForEach-Object ParameterName
        )
        if ($parameterNames -notcontains 'DryRun' -and $parameterNames -notcontains 'WhatIf') {
          $hasMutatingCall = $true
          break
        }
      }

      if ($hasMutatingCall) {
        $source = Get-Content -LiteralPath $testFile.FullName -Raw
        if ($source -notmatch 'function\s+global:Set-PowerShell7ProfileSymlink\b') {
          $violations.Add($testFile.Name)
        }
      }
    }

    $violations | Should -BeNullOrEmpty
  }
}
