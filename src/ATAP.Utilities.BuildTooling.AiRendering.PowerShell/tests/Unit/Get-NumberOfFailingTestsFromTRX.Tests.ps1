BeforeAll {
  . "$PSScriptRoot\..\..\public\Get-NumberOfFailingTestsFromTRX.ps1"
}

Describe 'Get-NumberOfFailingTestsFromTRX [public]' -Tag 'Unit' {
  It 'returns the failed counter from a namespaced TRX document' {
    $trx = Join-Path $TestDrive 'results.trx'
    @'
<?xml version="1.0" encoding="utf-8"?>
<TestRun xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
  <ResultSummary outcome="Failed">
    <Counters total="7" executed="7" passed="5" failed="2" />
  </ResultSummary>
</TestRun>
'@ | Set-Content -LiteralPath $trx

    Get-NumberOfFailingTestsFromTRX -xmlInputFile $trx | Should -Be 2
  }
}
