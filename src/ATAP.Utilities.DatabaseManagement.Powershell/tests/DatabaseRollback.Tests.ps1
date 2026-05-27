#Requires -Version 7.0
#Requires -Modules Pester, PSFramework

Describe 'DatabaseRollback — Test-DatabaseRollbackReadiness' {

  BeforeAll {
    # Helper: write a valid evidence JSON to $TestDrive
    function New-FakeEvidence {
      param(
        [string]$BackupFile,
        [datetime]$Timestamp = [datetime]::UtcNow,
        [string]$FlywayVersion = '1.5.0'
      )
      $ev = [ordered]@{
        application   = 'TestApp'
        databaseName  = 'TestDb'
        sqlInstance   = 'localhost\SQLEXPRESS'
        backupFile    = $BackupFile
        backupSizeMB  = 42.5
        sha256        = 'abc123'
        timestamp     = $Timestamp.ToString('o')
        flywayVersion = $FlywayVersion
      }
      $evidencePath = Join-Path $TestDrive 'pre-migration-snapshot-evidence.json'
      $ev | ConvertTo-Json -Depth 4 | Set-Content -Path $evidencePath -Encoding UTF8
      return $evidencePath
    }

    # Helper: create a zero-byte .bak placeholder
    function New-FakeBak {
      $bakPath = Join-Path $TestDrive 'TestDb_PREMIG_fake.bak'
      [System.IO.File]::WriteAllBytes($bakPath, @())
      return $bakPath
    }

    Import-Module (Resolve-Path (Join-Path $PSScriptRoot '..' 'ATAP.Utilities.DatabaseManagement.Powershell.psd1')) `
      -Force -ErrorAction Stop
  }

  Context 'IsReady = $true — fresh evidence with existing backup' {
    It 'Returns IsReady = $true when evidence is recent and backup file exists' {
      $bakPath = New-FakeBak
      $evidencePath = New-FakeEvidence -BackupFile $bakPath

      $result = Test-DatabaseRollbackReadiness -EvidencePath $evidencePath -MaxAgeMinutes 60

      $result.IsReady    | Should -Be $true
      $result.Reason     | Should -BeNullOrEmpty
      $result.BackupFile | Should -Be $bakPath
    }
  }

  Context 'IsReady = $false — stale snapshot' {
    It 'Returns IsReady = $false when evidence is older than MaxAgeMinutes' {
      $bakPath = New-FakeBak
      $staleTime = [datetime]::UtcNow.AddMinutes(-90)
      $evidencePath = New-FakeEvidence -BackupFile $bakPath -Timestamp $staleTime

      $result = Test-DatabaseRollbackReadiness -EvidencePath $evidencePath -MaxAgeMinutes 60

      $result.IsReady | Should -Be $false
      $result.Reason  | Should -Match 'minutes old'
    }
  }

  Context 'IsReady = $false — missing backup file' {
    It 'Returns IsReady = $false when backup file path does not exist' {
      $missingBak = Join-Path $TestDrive 'does-not-exist.bak'
      $evidencePath = New-FakeEvidence -BackupFile $missingBak

      $result = Test-DatabaseRollbackReadiness -EvidencePath $evidencePath

      $result.IsReady | Should -Be $false
      $result.Reason  | Should -Match 'does not exist'
    }
  }

  Context 'IsReady = $false — evidence file missing' {
    It 'Returns IsReady = $false when evidence file does not exist' {
      $missingEvidence = Join-Path $TestDrive 'no-such-file.json'

      $result = Test-DatabaseRollbackReadiness -EvidencePath $missingEvidence

      $result.IsReady | Should -Be $false
      $result.Reason  | Should -Match 'not found'
    }
  }

  Context 'IsReady = $false — malformed evidence JSON' {
    It 'Returns IsReady = $false when evidence file is not valid JSON' {
      $badEvidencePath = Join-Path $TestDrive 'bad-evidence.json'
      Set-Content -Path $badEvidencePath -Value 'NOT JSON { }'

      $result = Test-DatabaseRollbackReadiness -EvidencePath $badEvidencePath

      $result.IsReady | Should -Be $false
      $result.Reason  | Should -Match 'parsed'
    }
  }
}

Describe 'DatabaseRollback — New-DatabasePreMigrationSnapshot (parser check)' {
  It 'Function New-DatabasePreMigrationSnapshot exists after module import' {
    Import-Module (Resolve-Path (Join-Path $PSScriptRoot '..' 'ATAP.Utilities.DatabaseManagement.Powershell.psd1')) `
      -Force -ErrorAction Stop
    Get-Command 'New-DatabasePreMigrationSnapshot' -ErrorAction Stop | Should -Not -BeNullOrEmpty
  }
}

Describe 'DatabaseRollback — Restore-DatabaseFromSnapshot (parser check)' {
  It 'Function Restore-DatabaseFromSnapshot exists after module import' {
    Import-Module (Resolve-Path (Join-Path $PSScriptRoot '..' 'ATAP.Utilities.DatabaseManagement.Powershell.psd1')) `
      -Force -ErrorAction Stop
    Get-Command 'Restore-DatabaseFromSnapshot' -ErrorAction Stop | Should -Not -BeNullOrEmpty
  }
}
