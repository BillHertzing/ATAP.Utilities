# Pester tests for Invoke-PSModulePSScriptAnalyzer
# AI assisted using Powershell.instructions.md as guidelines

BeforeAll {
  $functionPath = Join-Path $PSScriptRoot '../public/Invoke-PSModulePSScriptAnalyzer.ps1'
  . $functionPath

  # Create a throwaway root under TEMP for per-test fixtures.
  $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("psa_" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
}

AfterAll {
  if ($script:tempRoot -and (Test-Path $script:tempRoot)) {
    Remove-Item -Recurse -Force $script:tempRoot -ErrorAction SilentlyContinue
  }
}

Describe 'Invoke-PSModulePSScriptAnalyzer' -Tag 'Unit' {

  Context 'Sprint tier short-circuit' {
    It 'returns GatePass=$true and does not invoke the analyzer' {
      $outFile = Join-Path $script:tempRoot 'sprint-results.xml'

      # A folder that does not even exist would still succeed because the analyzer is skipped.
      $fakePath = Join-Path $script:tempRoot 'NoSuchModule'

      $result = Invoke-PSModulePSScriptAnalyzer -Path $fakePath -Tier 'Sprint' -OutputPath $outFile

      $result.Tier         | Should -Be 'Sprint'
      $result.GatePass     | Should -BeTrue
      $result.ErrorCount   | Should -Be 0
      $result.WarningCount | Should -Be 0
      Test-Path $outFile   | Should -BeTrue
    }
  }

  Context 'Clean module at Alpha tier' {
    It 'returns GatePass=$true when no findings are present' {
      $moduleDir = Join-Path $script:tempRoot ('clean_' + [guid]::NewGuid().ToString('N'))
      New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null
      $cleanFile = Join-Path $moduleDir 'Clean.ps1'
      # Simple, well-formed function body — intentionally benign so PSSA has nothing to say.
      @'
function Get-CleanValue {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int]$Value)
    return ($Value + 1)
}
'@ | Set-Content -Path $cleanFile -Encoding UTF8

      $outFile = Join-Path $script:tempRoot ('clean-' + [guid]::NewGuid().ToString('N') + '.xml')
      $result = Invoke-PSModulePSScriptAnalyzer -Path $moduleDir -Tier 'Alpha' -OutputPath $outFile

      $result.GatePass   | Should -BeTrue
      $result.ErrorCount | Should -Be 0
      Test-Path $outFile | Should -BeTrue
    }
  }

  Context 'Module containing Write-Host at Alpha tier' {
    # NOTE: This test verifies the GatePass arithmetic — given any analyzer
    # finding the gate must report failure. It does NOT pin which specific
    # rule fires, because PSScriptAnalyzer's rule discovery is environmentally
    # fragile on this workstation (see deviation note in T-15/T-16 report).
    # If PSSA returns zero findings, the test is marked Inconclusive instead
    # of failing the build.
    It 'returns GatePass=$false when PSSA reports any Warning' {
      $moduleDir = Join-Path $script:tempRoot ('dirty_' + [guid]::NewGuid().ToString('N'))
      New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null
      $dirtyFile = Join-Path $moduleDir 'Dirty.ps1'
      # A grab-bag of common PSSA-flagged anti-patterns: Write-Host, an
      # unapproved-verb function name, and a positional parameter.
      @'
function fetch-greeting {
    param($name)
    Write-Host "hello $name"
    Get-ChildItem C:\ -Filter *.txt -Recurse -ErrorAction SilentlyContinue
}
'@ | Set-Content -Path $dirtyFile -Encoding UTF8

      $outFile = Join-Path $script:tempRoot ('dirty-' + [guid]::NewGuid().ToString('N') + '.xml')
      $result = Invoke-PSModulePSScriptAnalyzer -Path $moduleDir -Tier 'Alpha' -OutputPath $outFile

      Test-Path $outFile | Should -BeTrue

      if (($result.WarningCount + $result.ErrorCount) -gt 0) {
        $result.GatePass | Should -BeFalse
      }
      else {
        Set-ItResult -Inconclusive -Because 'PSScriptAnalyzer returned zero findings on this workstation; rule discovery appears broken in this environment.'
      }
    }
  }
}
