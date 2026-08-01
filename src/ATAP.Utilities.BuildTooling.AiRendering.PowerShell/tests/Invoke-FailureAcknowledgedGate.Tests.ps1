# AI assisted using Powershell.instructions.md as guidelines
# Pester 5+ tests for Invoke-FailureAcknowledgedGate

BeforeAll {
  $functionName = 'Invoke-FailureAcknowledgedGate'
  $depName      = 'Test-FailureAcknowledgedGate'

  # Dot-source both functions when running outside the module.
  foreach ($name in @($depName, $functionName)) {
    if (-not (Get-Command -Name $name -CommandType Function -ErrorAction SilentlyContinue)) {
      $path = Join-Path $PSScriptRoot "../public/$name.ps1"
      if (Test-Path $path) {
        . $path
      }
      else {
        throw "Function file not found: $path"
      }
    }
  }

  $script:tempFiles = [System.Collections.Generic.List[string]]::new()

  function New-TempFile {
    param([string]$Content, [string]$Extension = '.xml')
    $p = Join-Path ([System.IO.Path]::GetTempPath()) ("iag-test-$([guid]::NewGuid().ToString('N'))$Extension")
    Set-Content -Path $p -Value $Content -Encoding UTF8
    $script:tempFiles.Add($p)
    return $p
  }

  function New-TempDir {
    $d = Join-Path ([System.IO.Path]::GetTempPath()) ("iag-dir-$([guid]::NewGuid().ToString('N'))")
    [void](New-Item -ItemType Directory -Path $d -Force)
    $script:tempFiles.Add($d)
    return $d
  }

  # Minimal JUnit XML with optional failures.
  function New-JUnitXml {
    param(
      [int]$TotalTests         = 3,
      [string[]]$FailingNames  = @(),
      [string]$Classname       = 'Suite.Tests'
    )
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine("<testsuite name='Suite' tests='$TotalTests'>")
    for ($i = 1; $i -le $TotalTests; $i++) {
      $n = "Test$i"
      if ($FailingNames -contains $n) {
        [void]$sb.AppendLine("  <testcase classname='$Classname' name='$n'>")
        [void]$sb.AppendLine("    <failure message='boom'/>")
        [void]$sb.AppendLine('  </testcase>')
      }
      else {
        [void]$sb.AppendLine("  <testcase classname='$Classname' name='$n' />")
      }
    }
    [void]$sb.AppendLine('</testsuite>')
    return $sb.ToString()
  }

  # Minimal TRX XML with optional failed UnitTestResults.
  function New-TrxXml {
    param(
      [hashtable[]]$Tests = @()   # Each entry: @{ Name='...'; ClassName='...'; Outcome='Passed'|'Failed' }
    )
    $defs = [System.Text.StringBuilder]::new()
    $results = [System.Text.StringBuilder]::new()
    foreach ($t in $Tests) {
      $id = [guid]::NewGuid().ToString()
      [void]$defs.AppendLine("    <UnitTest name='$($t.Name)' id='$id'>")
      [void]$defs.AppendLine("      <TestMethod className='$($t.ClassName)' name='$($t.Name)' adapterTypeName='executor'/>")
      [void]$defs.AppendLine('    </UnitTest>')
      [void]$results.AppendLine("    <UnitTestResult testId='$id' testName='$($t.Name)' outcome='$($t.Outcome)' />")
    }
    return @"
<?xml version="1.0" encoding="UTF-8"?>
<TestRun xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
  <TestDefinitions>
$($defs.ToString())
  </TestDefinitions>
  <Results>
$($results.ToString())
  </Results>
</TestRun>
"@
  }

  $script:defaultSchemaPath = Join-Path $PSScriptRoot '../Resources/FailureAcknowledged.schema.json'
}

AfterAll {
  foreach ($p in $script:tempFiles) {
    if (Test-Path $p) {
      Remove-Item -Recurse -Force $p -ErrorAction SilentlyContinue
    }
  }
}

Describe 'Invoke-FailureAcknowledgedGate' {

  It 'function exists' {
    Get-Command -Name 'Invoke-FailureAcknowledgedGate' | Should -Not -BeNullOrEmpty
  }

  # -----------------------------------------------------------------------
  # Schema validation
  # -----------------------------------------------------------------------
  Context 'schema validation — valid JSON' {
    It 'accepts a well-formed FailureAcknowledged.json with T2 tier entry' {
      $ackJson = '[{"testName":"Test1","tier":"T2","notes":"known flake"}]'
      $ackPath = New-TempFile -Content $ackJson -Extension '.json'
      $xml     = New-JUnitXml -TotalTests 3 -FailingNames @()
      $resPath = New-TempFile -Content $xml

      $r = Invoke-FailureAcknowledgedGate -ResultFile $resPath -AcknowledgedFile $ackPath -Tier 'Alpha' `
        -SchemaPath $script:defaultSchemaPath

      $r.GatePass | Should -BeTrue
    }

    It 'accepts an empty acknowledgement array []' {
      $ackPath = New-TempFile -Content '[]' -Extension '.json'
      $xml     = New-JUnitXml -TotalTests 2 -FailingNames @()
      $resPath = New-TempFile -Content $xml

      { Invoke-FailureAcknowledgedGate -ResultFile $resPath -AcknowledgedFile $ackPath -Tier 'Beta' `
          -SchemaPath $script:defaultSchemaPath } | Should -Not -Throw
    }
  }

  Context 'schema validation — invalid JSON' {
    It 'throws when an entry has an invalid tier (T6)' {
      $ackJson = '[{"testName":"Test1","tier":"T6"}]'
      $ackPath = New-TempFile -Content $ackJson -Extension '.json'
      $xml     = New-JUnitXml -TotalTests 1 -FailingNames @()
      $resPath = New-TempFile -Content $xml

      { Invoke-FailureAcknowledgedGate -ResultFile $resPath -AcknowledgedFile $ackPath -Tier 'Alpha' `
          -SchemaPath $script:defaultSchemaPath } | Should -Throw -ExpectedMessage '*T6*'
    }

    It 'throws when an entry is missing the required testName field' {
      $ackJson = '[{"tier":"T2"}]'
      $ackPath = New-TempFile -Content $ackJson -Extension '.json'
      $xml     = New-JUnitXml -TotalTests 1 -FailingNames @()
      $resPath = New-TempFile -Content $xml

      { Invoke-FailureAcknowledgedGate -ResultFile $resPath -AcknowledgedFile $ackPath -Tier 'Alpha' `
          -SchemaPath $script:defaultSchemaPath } | Should -Throw -ExpectedMessage "*testName*"
    }

    It 'throws when an entry is missing the required tier field' {
      $ackJson = '[{"testName":"Test1"}]'
      $ackPath = New-TempFile -Content $ackJson -Extension '.json'
      $xml     = New-JUnitXml -TotalTests 1 -FailingNames @()
      $resPath = New-TempFile -Content $xml

      { Invoke-FailureAcknowledgedGate -ResultFile $resPath -AcknowledgedFile $ackPath -Tier 'Alpha' `
          -SchemaPath $script:defaultSchemaPath } | Should -Throw -ExpectedMessage "*tier*"
    }
  }

  # -----------------------------------------------------------------------
  # Tier name mapping (OtterScript -> PS-tier)
  # -----------------------------------------------------------------------
  Context 'tier mapping — Experimental skips gate' {
    It 'returns GatePass=true and Skipped=true for Experimental tier' {
      $ackPath = New-TempFile -Content '[{"testName":"Test1","tier":"T1"}]' -Extension '.json'
      $xml     = New-JUnitXml -TotalTests 1 -FailingNames @('Test1')
      $resPath = New-TempFile -Content $xml

      $r = Invoke-FailureAcknowledgedGate -ResultFile $resPath -AcknowledgedFile $ackPath `
        -Tier 'Experimental' -SchemaPath $script:defaultSchemaPath

      $r.GatePass | Should -BeTrue
      $r.Skipped  | Should -BeTrue
    }
  }

  Context 'tier mapping — Development maps to Alpha' {
    It 'gates at Alpha level when Tier=Development and failure is unacknowledged' {
      $ackPath = New-TempFile -Content '[]' -Extension '.json'
      $xml     = New-JUnitXml -TotalTests 3 -FailingNames @('Test2')
      $resPath = New-TempFile -Content $xml

      $r = Invoke-FailureAcknowledgedGate -ResultFile $resPath -AcknowledgedFile $ackPath `
        -Tier 'Development' -SchemaPath $script:defaultSchemaPath

      $r.GatePass       | Should -BeFalse
      $r.Unacknowledged | Should -Be 1
    }
  }

  # -----------------------------------------------------------------------
  # TRX file input
  # -----------------------------------------------------------------------
  Context 'TRX single-file input' {
    It 'converts a TRX file and passes the gate when there are no failures' {
      $tests = @(
        @{ Name = 'PassingTest1'; ClassName = 'MyNS.MyClass'; Outcome = 'Passed' }
        @{ Name = 'PassingTest2'; ClassName = 'MyNS.MyClass'; Outcome = 'Passed' }
      )
      $trxContent = New-TrxXml -Tests $tests
      $trxPath    = New-TempFile -Content $trxContent -Extension '.trx'
      $ackPath    = New-TempFile -Content '[]' -Extension '.json'

      $r = Invoke-FailureAcknowledgedGate -ResultFile $trxPath -AcknowledgedFile $ackPath `
        -Tier 'Alpha' -SchemaPath $script:defaultSchemaPath

      $r.GatePass | Should -BeTrue
      $r.Failed   | Should -Be 0
    }

    It 'converts a TRX file and fails the gate when a failure is unacknowledged' {
      $tests = @(
        @{ Name = 'PassingTest1'; ClassName = 'MyNS.MyClass'; Outcome = 'Passed' }
        @{ Name = 'FailingTest1'; ClassName = 'MyNS.MyClass'; Outcome = 'Failed' }
      )
      $trxContent = New-TrxXml -Tests $tests
      $trxPath    = New-TempFile -Content $trxContent -Extension '.trx'
      $ackPath    = New-TempFile -Content '[]' -Extension '.json'

      $r = Invoke-FailureAcknowledgedGate -ResultFile $trxPath -AcknowledgedFile $ackPath `
        -Tier 'Alpha' -SchemaPath $script:defaultSchemaPath

      $r.GatePass       | Should -BeFalse
      $r.Unacknowledged | Should -Be 1
    }

    It 'passes gate when a TRX failure is acknowledged at T2 and tier is Alpha (rank 2)' {
      $tests = @(
        @{ Name = 'FailingTest1'; ClassName = 'MyNS.MyClass'; Outcome = 'Failed' }
      )
      $trxContent = New-TrxXml -Tests $tests
      $trxPath    = New-TempFile -Content $trxContent -Extension '.trx'
      $ackJson    = '[{"testName":"FailingTest1","tier":"T2"}]'
      $ackPath    = New-TempFile -Content $ackJson -Extension '.json'

      $r = Invoke-FailureAcknowledgedGate -ResultFile $trxPath -AcknowledgedFile $ackPath `
        -Tier 'Alpha' -SchemaPath $script:defaultSchemaPath

      $r.GatePass    | Should -BeTrue
      $r.Acknowledged | Should -Be 1
    }
  }

  Context 'TRX directory input' {
    It 'merges multiple TRX files in a directory and gates correctly' {
      $dir = New-TempDir
      # TRX 1: one passing test.
      $t1 = @(@{ Name = 'PassA'; ClassName = 'NS.A'; Outcome = 'Passed' })
      Set-Content -Path (Join-Path $dir 'results1.trx') -Value (New-TrxXml -Tests $t1) -Encoding UTF8
      # TRX 2: one failing test.
      $t2 = @(@{ Name = 'FailB'; ClassName = 'NS.B'; Outcome = 'Failed' })
      Set-Content -Path (Join-Path $dir 'results2.trx') -Value (New-TrxXml -Tests $t2) -Encoding UTF8

      $ackPath = New-TempFile -Content '[]' -Extension '.json'

      $r = Invoke-FailureAcknowledgedGate -ResultFile $dir -AcknowledgedFile $ackPath `
        -Tier 'Beta' -SchemaPath $script:defaultSchemaPath

      $r.GatePass       | Should -BeFalse
      $r.Unacknowledged | Should -Be 1
    }
  }

  # -----------------------------------------------------------------------
  # Missing AcknowledgedFile (non-fatal)
  # -----------------------------------------------------------------------
  Context 'missing AcknowledgedFile' {
    It 'runs gate without errors when AcknowledgedFile does not exist' {
      $xml     = New-JUnitXml -TotalTests 2 -FailingNames @()
      $resPath = New-TempFile -Content $xml
      $missingPath = Join-Path ([System.IO.Path]::GetTempPath()) "does-not-exist-$([guid]::NewGuid().ToString('N')).json"

      $r = Invoke-FailureAcknowledgedGate -ResultFile $resPath -AcknowledgedFile $missingPath `
        -Tier 'QA' -SchemaPath $script:defaultSchemaPath

      $r.GatePass | Should -BeTrue
    }
  }
}
