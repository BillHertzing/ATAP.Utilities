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
}
