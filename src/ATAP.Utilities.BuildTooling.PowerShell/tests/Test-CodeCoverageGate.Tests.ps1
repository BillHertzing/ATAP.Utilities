# AI assisted using Powershell.instructions.md as guidelines
# Pester 5+ tests for Test-CodeCoverageGate

BeforeAll {
    $functionName = 'Test-CodeCoverageGate'
    if (-not (Get-Command -Name $functionName -CommandType Function -ErrorAction SilentlyContinue)) {
        $functionPath = Join-Path $PSScriptRoot -ChildPath "../public/$functionName.ps1"
        if (Test-Path $functionPath) {
            . $functionPath
        }
        else {
            throw "Function file not found: $functionPath"
        }
    }

    function New-TempFile {
        param([string]$Content, [string]$Extension = '.xml')
        $path = Join-Path ([System.IO.Path]::GetTempPath()) ("cov-gate-" + [guid]::NewGuid().ToString('N') + $Extension)
        Set-Content -Path $path -Value $Content -Encoding UTF8
        return $path
    }

    $script:tempFiles = [System.Collections.Generic.List[string]]::new()

    $script:CoberturaAbove = @'
<?xml version="1.0" encoding="UTF-8"?>
<coverage line-rate="0.85" branch-rate="0.80" version="1.9" timestamp="1234567890">
  <packages>
    <package name="ModuleA" line-rate="0.85" branch-rate="0.80">
      <classes />
    </package>
  </packages>
</coverage>
'@

    $script:CoberturaBelow = @'
<?xml version="1.0" encoding="UTF-8"?>
<coverage line-rate="0.42" branch-rate="0.30" version="1.9" timestamp="1234567890">
  <packages>
    <package name="ModuleA" line-rate="0.42" branch-rate="0.30">
      <classes />
    </package>
  </packages>
</coverage>
'@

    # JaCoCo: 80 covered / 20 missed = 80%
    $script:JaCoCoSample = @'
<?xml version="1.0" encoding="UTF-8"?>
<report name="ModuleA">
  <counter type="INSTRUCTION" missed="50" covered="450" />
  <counter type="LINE" missed="20" covered="80" />
  <counter type="COMPLEXITY" missed="10" covered="40" />
  <counter type="METHOD" missed="5" covered="45" />
  <counter type="CLASS" missed="0" covered="10" />
</report>
'@
}

AfterAll {
    foreach ($p in $script:tempFiles) {
        if (Test-Path $p) {
            Remove-Item -Path $p -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Test-CodeCoverageGate' {

    It 'function exists' {
        Get-Command -Name 'Test-CodeCoverageGate' | Should -Not -BeNullOrEmpty
    }

    It 'passes when Cobertura coverage is above threshold' {
        $path = New-TempFile -Content $script:CoberturaAbove
        $script:tempFiles.Add($path)

        $result = Test-CodeCoverageGate -CoverageFile $path -Tier 'QA' -Threshold 70.0

        $result.Skipped | Should -BeFalse
        $result.CoveragePct | Should -Be 85.0
        $result.Threshold | Should -Be 70.0
        $result.GatePass | Should -BeTrue
    }

    It 'fails when Cobertura coverage is below threshold' {
        $path = New-TempFile -Content $script:CoberturaBelow
        $script:tempFiles.Add($path)

        $result = Test-CodeCoverageGate -CoverageFile $path -Tier 'Production' -Threshold 70.0

        $result.Skipped | Should -BeFalse
        $result.CoveragePct | Should -Be 42.0
        $result.GatePass | Should -BeFalse
    }

    It 'parses a JaCoCo coverage report correctly' {
        $path = New-TempFile -Content $script:JaCoCoSample
        $script:tempFiles.Add($path)

        $result = Test-CodeCoverageGate -CoverageFile $path -Tier 'QA' -Threshold 70.0

        $result.Skipped | Should -BeFalse
        # covered=80, missed=20 -> 80/(80+20) = 80%
        $result.CoveragePct | Should -Be 80.0
        $result.GatePass | Should -BeTrue
    }

    It 'is skipped at Alpha tier regardless of coverage content' {
        $path = New-TempFile -Content $script:CoberturaBelow
        $script:tempFiles.Add($path)

        $result = Test-CodeCoverageGate -CoverageFile $path -Tier 'Alpha' -Threshold 70.0

        $result.Skipped | Should -BeTrue
        $result.GatePass | Should -BeTrue
        $result.CoveragePct | Should -BeNullOrEmpty
    }

    It 'throws a clear error if the coverage file is missing at QA tier' {
        $missing = Join-Path ([System.IO.Path]::GetTempPath()) ("missing-cov-" + [guid]::NewGuid().ToString('N') + '.xml')
        { Test-CodeCoverageGate -CoverageFile $missing -Tier 'QA' } | Should -Throw -ExpectedMessage '*not found*'
    }
}
