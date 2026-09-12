BeforeAll {
  $moduleRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
  $protectPath = Join-Path $moduleRoot 'public\Protect-SqlServerBackupArtifact.ps1'
  $restorePath = Join-Path $moduleRoot 'public\Restore-SqlServerBackupArtifact.ps1'
  $schedulerPath = Join-Path $moduleRoot 'public\Install-ProductionDatabaseBackupScheduledTasks.ps1'
  $invokePath = Join-Path $moduleRoot 'public\Invoke-SqlServerBackup.ps1'
  $healthPath = Join-Path $moduleRoot 'public\Test-DatabaseBackupHealth.ps1'
  . $protectPath
  . $restorePath
  . $schedulerPath
  function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message, $Tag) }
}

Describe 'Production backup artifact protection' {
  BeforeEach {
    Mock Get-SecretATAP { 'unit-test-only-secret-material' }
  }

  It 'round-trips bytes and resolves the fixed SecretName internally' {
    $input = Join-Path $TestDrive 'source.bak'
    $encrypted = Join-Path $TestDrive 'source.bak.gz.atapenc'
    $restored = Join-Path $TestDrive 'restored.bak'
    [IO.File]::WriteAllBytes($input, [Text.Encoding]::UTF8.GetBytes(('ATAPUtilities backup payload ' * 1000)))

    $protected = Protect-SqlServerBackupArtifact -InputPath $input -OutputPath $encrypted -Confirm:$false
    $result = Restore-SqlServerBackupArtifact -InputPath $encrypted -OutputPath $restored -Confirm:$false

    $protected.EncryptionVerified | Should -BeTrue
    $result.AuthenticationVerified | Should -BeTrue
    (Get-FileHash $restored).Hash | Should -Be (Get-FileHash $input).Hash
    foreach ($sourcePath in @($protectPath, $restorePath)) {
      $source = Get-Content -LiteralPath $sourcePath -Raw
      $source | Should -Match 'Get-SecretATAP'
      $source | Should -Match 'dbEncryption\.ATAPUtilities\.Production'
      $source | Should -Match 'BitwardenSecretsManager'
    }
  }

  It 'rejects tampering before writing plaintext' {
    $input = Join-Path $TestDrive 'tamper-source.bak'
    $encrypted = Join-Path $TestDrive 'tamper-source.bak.gz.atapenc'
    $output = Join-Path $TestDrive 'must-not-exist.bak'
    [IO.File]::WriteAllBytes($input, [Text.Encoding]::UTF8.GetBytes('tamper test'))
    Protect-SqlServerBackupArtifact -InputPath $input -OutputPath $encrypted -Confirm:$false | Out-Null
    $bytes = [IO.File]::ReadAllBytes($encrypted)
    $bytes[$bytes.Length - 1] = $bytes[$bytes.Length - 1] -bxor 1
    [IO.File]::WriteAllBytes($encrypted, $bytes)

    { Restore-SqlServerBackupArtifact -InputPath $encrypted -OutputPath $output -Confirm:$false } | Should -Throw '*authentication failed*'
    Test-Path -LiteralPath $output | Should -BeFalse
  }
}

Describe 'Production-only scheduling contract' {
  BeforeEach {
    Mock Get-ScheduledTask { $null }
    Mock Get-Module { [pscustomobject]@{ Version = [version]'0.1.22' } }

    Mock Register-ScheduledTask { [pscustomobject]@{} }
  }
  It 'returns exactly two fixed Production tasks under WhatIf without resolving credentials' {
    Mock Get-SecretATAP { throw 'must not run under WhatIf' }
    $result = @(Install-ProductionDatabaseBackupScheduledTasks -WhatIf)
    $result | Should -HaveCount 2
    $result.BackupType | Should -Contain 'Full'
    $result.BackupType | Should -Contain 'Differential'
    Should -Invoke Get-SecretATAP -Times 0
  }

  It 'contains no alternate database, tier, or encryption SecretName in the scheduler source' {
    $source = Get-Content -LiteralPath $schedulerPath -Raw
    $source | Should -Match "DatabaseName 'ATAPUtilities'"
    $source | Should -Match "Environment 'Production'"
    $source | Should -Match "localhost,50020"
    $source | Should -Match 'dbEncryption\.ATAPUtilities\.Production'
    $source | Should -Not -Match '(?i)BuildSets|BuildMaster|ProGet|QA|Integration|Development|Experimental'
  }

  It 'derives the local Windows identity and uses a scalar secret only as its Task Scheduler password' {
    Mock Get-SecretATAP { 'unit-test-task-password' }

    $result = @(Install-ProductionDatabaseBackupScheduledTasks -ModuleVersion '0.1.22' -Confirm:$false)

    $result | Should -HaveCount 2
    Should -Invoke Register-ScheduledTask -Times 2 -ParameterFilter {
      $User -eq "$env:COMPUTERNAME\SvcSQLServer" -and $Password -eq 'unit-test-task-password'
    }
  }
}

Describe 'Production-only invocation and health contracts' {
  It 'guards protected publication to Production ATAPUtilities' {
    $source = Get-Content -LiteralPath $invokePath -Raw
    $source | Should -Match "ProtectAndPublish is restricted to database ATAPUtilities on the Production endpoint localhost,50020"
    $source | Should -Match 'Checksum\s*=\s*\$true'
    $source | Should -Match 'Restore-SqlServerBackupArtifact'
    $source | Should -Match 'Publish-SqlServerBackupArtifact'
    $source | Should -Match 'Connect-DbaInstance[\s\S]*-EncryptConnection[\s\S]*-TrustServerCertificate[\s\S]*-AllowTrustServerCertificate'
    $source | Should -Match 'TrustServerCertificate is restricted to the Production-only ProtectAndPublish workflow'
    $source | Should -Match 'Publish-SqlServerBackupArtifact[^\r\n]*-AllowNonRedirectingReparsePoints'
    (Get-Content -LiteralPath $schedulerPath -Raw) | Should -Match 'Invoke-SqlServerBackup[^\r\n]*-TrustServerCertificate'
    $source | Should -Match 'Join-Path \(Join-Path \$LocalDBsRoot \$Environment\.ToUpperInvariant\(\)\) ''Backup'''
    $source | Should -Not -Match 'FastTempBasePathConfigRootKey'
  }

  It 'defaults health to only Production ATAPUtilities with 24-hour coverage and SIMPLE recovery' {
    $source = Get-Content -LiteralPath $healthPath -Raw
    $source | Should -Match '\$SqlInstances\s*=\s*@\(''localhost,50020''\)'
    $source | Should -Match '\$ProtectedDatabases\s*=\s*@\(''ATAPUtilities''\)'
    $source | Should -Match '\$MaxDiffAgeHours = 24'
    $source | Should -Match '\$ExpectedRecoveryModel = ''SIMPLE'''
    $source | Should -Match 'IncompatibleDifferentialBase'
    $source | Should -Not -Match 'BuildSets'
  }

  It 'exports every production backup command and prepares package version 0.1.22' {
    $manifest = Import-PowerShellDataFile (Join-Path $moduleRoot 'ATAP.Utilities.DatabaseManagement.Powershell.psd1')
    $version = Get-Content -LiteralPath (Join-Path $moduleRoot 'version.json') -Raw | ConvertFrom-Json
    $version.version | Should -Be '0.1.22'
    foreach ($name in @('Invoke-SqlServerBackup','Protect-SqlServerBackupArtifact','Restore-SqlServerBackupArtifact','Publish-SqlServerBackupArtifact','Install-ProductionDatabaseBackupScheduledTasks','Test-DatabaseBackupHealth')) {
      $manifest.FunctionsToExport | Should -Contain $name
    }
  }
}
