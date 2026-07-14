Describe 'DPOM primary-role marker' {
  BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\..\ATAP.Utilities.SystemParityMonitor.PowerShell.psd1'
    Import-Module -Name $modulePath -Force
    $sinceUtc = [DateTimeOffset]::Parse('2026-07-14T21:00:00.0000000Z')
    $journalEntryId = [guid] '11111111-1111-1111-1111-111111111111'
  }

  BeforeEach {
    $testRoot = Join-Path ([IO.Path]::GetTempPath()) "ATAP-PrimaryRole-$([guid]::NewGuid())"
  }

  AfterEach {
    if (Test-Path -LiteralPath $testRoot) {
      Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
  }

  It 'creates the canonical Task 12.59 Class A marker' {
    $result = Set-ParityPrimaryRole `
      -StatePath $testRoot `
      -PrimaryRole 'UTAT01' `
      -PlannedAbsenceHostName 'UTAT022' `
      -SinceUtc $sinceUtc `
      -Reason 'first Class A test' `
      -AuthorizedBy 'Bill Hertzing' `
      -JournalEntryId $journalEntryId `
      -Confirm:$false

    $result.Action | Should -Be 'Created'
    $result.Changed | Should -BeTrue
    $marker = Get-ParityPrimaryRole -StatePath $testRoot -ErrorIfMissing
    $marker.SchemaVersion | Should -Be 1
    $marker.PrimaryRole | Should -Be 'utat01'
    $marker.PlannedAbsence.HostName | Should -Be 'utat022'
    $marker.PlannedAbsence.SinceUtc | Should -Be '2026-07-14T21:00:00.0000000+00:00'
    $marker.PlannedAbsence.Reason | Should -Be 'first Class A test'
    $marker.AuthorizedBy | Should -Be 'Bill Hertzing'
    $marker.JournalEntryId | Should -Be $journalEntryId.ToString()
  }

  It 'is idempotent for an identical marker' {
    $parameters = @{
      StatePath = $testRoot
      PrimaryRole = 'utat01'
      PlannedAbsenceHostName = 'utat022'
      SinceUtc = $sinceUtc
      Reason = 'first Class A test'
      AuthorizedBy = 'Bill Hertzing'
      JournalEntryId = $journalEntryId
      Confirm = $false
    }
    Set-ParityPrimaryRole @parameters | Out-Null

    $result = Set-ParityPrimaryRole @parameters

    $result.Action | Should -Be 'AlreadyCurrent'
    $result.Changed | Should -BeFalse
  }

  It 'is visible to both host views through one shared state path' {
    Set-ParityPrimaryRole `
      -StatePath $testRoot `
      -PrimaryRole 'utat01' `
      -PlannedAbsenceHostName 'utat022' `
      -SinceUtc $sinceUtc `
      -Reason 'first Class A test' `
      -AuthorizedBy 'Bill Hertzing' `
      -JournalEntryId $journalEntryId `
      -Confirm:$false | Out-Null

    $utat01View = Get-ParityPrimaryRole -StatePath $testRoot -ErrorIfMissing
    $utat022View = Get-ParityPrimaryRole -StatePath $testRoot -ErrorIfMissing

    $utat01View.PrimaryRole | Should -Be 'utat01'
    ($utat01View | ConvertTo-Json -Depth 8 -Compress) | Should -Be ($utat022View | ConvertTo-Json -Depth 8 -Compress)
  }

  It 'writes a normal-operation exit marker without a planned absence' {
    $result = Set-ParityPrimaryRole `
      -StatePath $testRoot `
      -PrimaryRole 'utat022' `
      -Reason 'DPOM exit' `
      -AuthorizedBy 'Bill Hertzing' `
      -JournalEntryId $journalEntryId `
      -Confirm:$false

    $result.Action | Should -Be 'Created'
    $marker = Get-ParityPrimaryRole -StatePath $testRoot -ErrorIfMissing
    $marker.PrimaryRole | Should -Be 'utat022'
    $marker.PlannedAbsence | Should -BeNullOrEmpty
  }

  It 'does not write under WhatIf' {
    $result = Set-ParityPrimaryRole `
      -StatePath $testRoot `
      -PrimaryRole 'utat01' `
      -PlannedAbsenceHostName 'utat022' `
      -SinceUtc $sinceUtc `
      -Reason 'first Class A test' `
      -AuthorizedBy 'Bill Hertzing' `
      -JournalEntryId $journalEntryId `
      -WhatIf

    $result.Action | Should -Be 'WhatIf'
    $result.Changed | Should -BeFalse
    Test-Path -LiteralPath (Join-Path $testRoot 'PrimaryRole.json') | Should -BeFalse
  }

  It 'rejects a primary host that is also the planned absence' {
    {
      Set-ParityPrimaryRole `
        -StatePath $testRoot `
        -PrimaryRole 'utat01' `
        -PlannedAbsenceHostName 'UTAT01' `
        -Reason 'invalid fixture' `
        -AuthorizedBy 'Bill Hertzing' `
        -JournalEntryId $journalEntryId `
        -Confirm:$false
    } | Should -Throw '*must identify different hosts*'
  }

  It 'rejects a malformed existing marker instead of overwriting it' {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    '{ "SchemaVersion": 99 }' | Set-Content -LiteralPath (Join-Path $testRoot 'PrimaryRole.json') -Encoding utf8

    {
      Set-ParityPrimaryRole `
        -StatePath $testRoot `
        -PrimaryRole 'utat01' `
        -PlannedAbsenceHostName 'utat022' `
        -Reason 'first Class A test' `
        -AuthorizedBy 'Bill Hertzing' `
        -JournalEntryId $journalEntryId `
        -Confirm:$false
    } | Should -Throw '*missing required property*'
  }

  It 'exports the canonical reader and writer' {
    Get-Command -Module ATAP.Utilities.SystemParityMonitor.PowerShell -Name Get-ParityPrimaryRole | Should -Not -BeNullOrEmpty
    Get-Command -Module ATAP.Utilities.SystemParityMonitor.PowerShell -Name Set-ParityPrimaryRole | Should -Not -BeNullOrEmpty
  }
}
