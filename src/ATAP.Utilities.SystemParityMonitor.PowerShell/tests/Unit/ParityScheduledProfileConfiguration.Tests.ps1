Describe 'SystemParityMonitor scheduled package-manager profile configuration' -Tag 'Unit' {
  BeforeAll {
    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $scriptsRoot = Join-Path $moduleRoot 'scripts'
    . (Join-Path $scriptsRoot 'Register-ParityScheduledTasks.ps1')
    . (Join-Path $scriptsRoot 'ParityScheduledTask.Common.ps1')
    . (Join-Path $scriptsRoot 'Invoke-ParityScheduledAuditTask.ps1')

    function Invoke-ParityAudit {
      [CmdletBinding()]
      param(
        [string] $StatePath,
        [string] $HostName,
        [object[]] $PackageManagerProfiles = @(),
        [hashtable] $ExpectedSurfaceMinimumCounts
      )
    }

    function Write-TestPackageManagerProfileConfiguration {
      param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [int] $SchemaVersion,

        [AllowEmptyCollection()]
        [object[]] $Profiles = @(),

        [hashtable] $ExpectedSurfaceMinimumCounts = @{ SQL = 1; PackageManager = 1 }
      )

      New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
      [ordered]@{
        SchemaVersion = $SchemaVersion
        Profiles = @($Profiles)
        ExpectedSurfaceMinimumCounts = $ExpectedSurfaceMinimumCounts
      } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding utf8
    }
  }

  BeforeEach {
    $fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $statePath = Join-Path $fixtureRoot 'Parity State With Spaces'
    $resultPath = Join-Path $fixtureRoot 'Task Results'
    New-Item -ItemType Directory -Path $statePath, $resultPath -Force | Out-Null
    $script:scheduledTaskRegistrations = @()
    $script:s4uRegistrations = @()
    $script:capturedProfiles = $null

    Mock -CommandName Get-Command -ParameterFilter { $Name -eq 'pwsh' } -MockWith {
      [pscustomobject]@{ Source = 'C:\Program Files\PowerShell\7\pwsh.exe' }
    }
    Mock -CommandName New-ScheduledTaskAction -MockWith {
      param($Execute, $Argument)
      [pscustomobject]@{ Execute = $Execute; Arguments = $Argument }
    }
    Mock -CommandName New-ScheduledTaskTrigger -MockWith {
      [pscustomobject]@{ CimClass = [pscustomobject]@{ CimClassName = 'MSFT_TaskDailyTrigger' } }
    }
    Mock -CommandName New-ScheduledTaskSettingsSet -MockWith {
      [pscustomobject]@{ StartWhenAvailable = $true }
    }
    Mock -CommandName New-ScheduledTaskPrincipal -MockWith {
      param($UserId, $LogonType, $RunLevel)
      [pscustomobject]@{ UserId = $UserId; LogonType = $LogonType; RunLevel = $RunLevel }
    }
    Mock -CommandName Register-ScheduledTask -MockWith {
      param($TaskName, $TaskPath, $Action, $Trigger, $Settings, $Principal, [switch] $Force, $ErrorAction)
      $script:scheduledTaskRegistrations += [pscustomobject]@{
        TaskName = $TaskName
        TaskPath = $TaskPath
        Action = $Action
        Trigger = $Trigger
        Settings = $Settings
        Principal = $Principal
      }
    }
    Mock -CommandName Register-ParityScheduledTaskS4U -MockWith {
      param($TaskName, $TaskPath, $PwshPath, $Arguments, $Cadence, $At, $BiWeeklyDaysOfWeek, $UserId, $Credential, $RunLevel)
      $script:s4uRegistrations += [pscustomobject]@{
        TaskName = $TaskName
        TaskPath = $TaskPath
        PwshPath = $PwshPath
        Arguments = $Arguments
        UserId = $UserId
        Credential = $Credential
        RunLevel = $RunLevel
      }
    }
    Mock -CommandName Import-Module
    Mock -CommandName Write-ParityScheduledTaskEvent -MockWith {
      param($EntryType, $EventId, $Message, $LogName, $Source)
      [pscustomobject]@{
        Success = $true
        EntryType = $EntryType
        EventId = $EventId
        Message = $Message
        LogName = $LogName
        Source = $Source
      }
    }
  }

  Context 'registration materialization and action transport' {
    It 'auto-resolves profiles and minima from registered global settings and transports one JSON path to both tasks' {
      $savedSettings = $global:settings
      $savedKeys = $global:configRootKeys
      try {
        $global:configRootKeys = @{
          SystemParityMonitorConfigRootKey = 'SystemParityMonitor'
          SystemParityMonitorPackageManagerProfilesConfigRootKey = 'PackageManagerProfiles'
          SystemParityMonitorExpectedSurfaceMinimumCountsConfigRootKey = 'ExpectedSurfaceMinimumCounts'
        }
        $global:settings = @{
          SystemParityMonitor = @{
            PackageManagerProfiles = @([pscustomobject]@{ Identity = 'ATAP\Developer'; PipPath = 'C:\pip' })
            ExpectedSurfaceMinimumCounts = @{ SQL = 2; PackageManager = 1 }
          }
        }

        $credential = [pscredential]::new(
          'UTAT022\SvcParityAudit',
          (ConvertTo-SecureString 'fixture-password' -AsPlainText -Force)
        )
        Register-ParityScheduledTasks -TaskSet AuditAndCompare -StatePath $statePath `
          -HostName 'utat022' -UserId 'UTAT022\SvcParityAudit' -Credential $credential -Confirm:$false

        $configurationPath = Join-Path $statePath 'Configuration\PackageManagerProfiles.v1.json'
        $configuration = Get-Content -LiteralPath $configurationPath -Raw | ConvertFrom-Json
        $configuration.ExpectedSurfaceMinimumCounts.SQL | Should -Be 2
        $script:s4uRegistrations | Should -HaveCount 2
        $script:s4uRegistrations[0].Arguments | Should -Match '-PackageManagerProfilesPath'
        $script:s4uRegistrations[1].Arguments | Should -Match '-PackageManagerProfilesPath'
      } finally {
        $global:settings = $savedSettings
        $global:configRootKeys = $savedKeys
      }
    }

    It 'rejects null, non-integer, and sub-one minimum values before writing' {
      foreach ($invalid in @(@{ SQL = 0 }, @{ SQL = '1.5' })) {
        {
          Register-ParityScheduledTasks -TaskSet AuditOnly -StatePath $statePath `
            -PackageManagerProfiles @() -ExpectedSurfaceMinimumCounts $invalid -Confirm:$false
        } | Should -Throw '*integer of at least one*'
      }
    }

    It 'materializes valid schema-v1 JSON and puts only its quoted path on the command line' {
      $profiles = @(
        [pscustomobject]@{
          Identity = 'ATAP\Developer'
          PipPath = 'C:\Profiles With Spaces\Developer\site-packages'
          NpmPrefix = 'C:\Profiles With Spaces\Developer\npm'
          NuGetToolPath = 'C:\Profiles With Spaces\Developer\.dotnet\tools'
        }
      )
      $credential = [pscredential]::new(
        'UTAT01\SvcParityAudit',
        (ConvertTo-SecureString 'fixture-password' -AsPlainText -Force)
      )

      Register-ParityScheduledTasks `
        -TaskSet AuditOnly `
        -StatePath $statePath `
        -HostName 'utat01' `
        -UserId 'UTAT01\SvcParityAudit' `
        -Credential $credential `
        -PackageManagerProfiles $profiles `
        -Confirm:$false

      $configurationPath = Join-Path $statePath 'Configuration\PackageManagerProfiles.v1.json'
      Test-Path -LiteralPath $configurationPath -PathType Leaf | Should -BeTrue
      $configuration = Get-Content -LiteralPath $configurationPath -Raw | ConvertFrom-Json
      $configuration.SchemaVersion | Should -Be 1
      @($configuration.Profiles) | Should -HaveCount 1
      $configuration.Profiles[0].Identity | Should -Be 'ATAP\Developer'
      $configuration.ExpectedSurfaceMinimumCounts.PackageManager | Should -Be 1

      $script:scheduledTaskRegistrations | Should -HaveCount 0
      $script:s4uRegistrations | Should -HaveCount 1
      $arguments = $script:s4uRegistrations[0].Arguments
      $arguments | Should -Match ('-PackageManagerProfilesPath "' + [regex]::Escape($configurationPath) + '"')
      $arguments | Should -Match '-NoProfile'
      $arguments | Should -Not -Match 'ATAP\\Developer|SchemaVersion|\{'
    }

    It 'materializes an explicitly empty array for fail-closed downstream handling' {
      $credential = [pscredential]::new(
        'UTAT01\SvcParityAudit',
        (ConvertTo-SecureString 'fixture-password' -AsPlainText -Force)
      )
      Register-ParityScheduledTasks `
        -TaskSet AuditOnly `
        -StatePath $statePath `
        -HostName 'utat01' `
        -UserId 'UTAT01\SvcParityAudit' `
        -Credential $credential `
        -PackageManagerProfiles @() `
        -Confirm:$false

      $configurationPath = Join-Path $statePath 'Configuration\PackageManagerProfiles.v1.json'
      $configuration = Get-Content -LiteralPath $configurationPath -Raw | ConvertFrom-Json
      @($configuration.Profiles) | Should -HaveCount 0
      $script:s4uRegistrations[0].Arguments | Should -Match '-PackageManagerProfilesPath'
    }

    It 'rejects duplicate identities case-insensitively before writing' {
      {
        Register-ParityScheduledTasks `
          -TaskSet AuditOnly `
          -StatePath $statePath `
          -PackageManagerProfiles @(
            [pscustomobject]@{ Identity = 'ATAP\Developer'; PipPath = 'C:\pip' },
            [pscustomobject]@{ Identity = 'atap\developer'; PipPath = 'D:\pip' }
          ) `
          -Confirm:$false
      } | Should -Throw '*configured more than once*'

      Test-Path -LiteralPath (Join-Path $statePath 'Configuration\PackageManagerProfiles.v1.json') |
        Should -BeFalse
    }

    It 'rejects relative profile paths before writing' {
      {
        Register-ParityScheduledTasks `
          -TaskSet AuditOnly `
          -StatePath $statePath `
          -PackageManagerProfiles @(
            [pscustomobject]@{ Identity = 'ATAP\Developer'; PipPath = '.\pip' }
          ) `
          -Confirm:$false
      } | Should -Throw '*must be a fully qualified path*'
    }

    It 'preserves a prior valid file when a rewrite fails read-back validation' {
      $configurationPath = Join-Path $statePath 'Configuration\PackageManagerProfiles.v1.json'
      Write-TestPackageManagerProfileConfiguration `
        -Path $configurationPath `
        -SchemaVersion 1 `
        -Profiles @([pscustomobject]@{ Identity = 'ATAP\Original'; PipPath = 'C:\original' })
      $beforeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $configurationPath).Hash

      Mock -CommandName Read-ParityPackageManagerProfilesRegistrationConfiguration -MockWith {
        throw [InvalidOperationException]::new('fixture read-back failure')
      }

      {
        Register-ParityScheduledTasks `
          -TaskSet AuditOnly `
          -StatePath $statePath `
          -PackageManagerProfiles @(
            [pscustomobject]@{ Identity = 'ATAP\Replacement'; PipPath = 'C:\replacement' }
          ) `
          -Confirm:$false
      } | Should -Throw '*fixture read-back failure*'

      (Get-FileHash -Algorithm SHA256 -LiteralPath $configurationPath).Hash | Should -Be $beforeHash
      @(Get-ChildItem -LiteralPath (Split-Path -Parent $configurationPath) -Filter '*.tmp') |
        Should -HaveCount 0
    }
  }

  Context 'scheduled audit wrapper validation and pass-through' {
    BeforeEach {
      Mock -CommandName Invoke-ParityAudit -MockWith {
        param($StatePath, $HostName, $PackageManagerProfiles, $ExpectedSurfaceMinimumCounts)
        $script:capturedProfiles = @($PackageManagerProfiles | Where-Object { $null -ne $_ })
        $script:capturedMinimumCounts = $ExpectedSurfaceMinimumCounts
        [pscustomobject]@{
          SnapshotPath = Join-Path $StatePath 'snapshot.json'
          CapturedAtUtc = '2026-08-09T00:00:00Z'
        }
      }
    }

    It 'passes valid profiles unchanged when the config path contains spaces' {
      $configurationPath = Join-Path $statePath 'Configuration With Spaces\PackageManagerProfiles.v1.json'
      Write-TestPackageManagerProfileConfiguration `
        -Path $configurationPath `
        -SchemaVersion 1 `
        -Profiles @([pscustomobject]@{ Identity = 'ATAP\Developer'; PipPath = 'C:\profile with spaces\pip' })
      $originalUserName = $env:USERNAME
      try {
        $env:USERNAME = 'UnrelatedRuntimeIdentity'
        Invoke-ParityScheduledAuditTask `
          -StatePath $statePath `
          -HostName 'utat022' `
          -ResultDirectory $resultPath `
          -PackageManagerProfilesPath $configurationPath
      } finally {
        $env:USERNAME = $originalUserName
      }

      $script:capturedProfiles | Should -HaveCount 1
      $script:capturedProfiles[0].Identity | Should -Be 'ATAP\Developer'
      $script:capturedProfiles[0].PipPath | Should -Be 'C:\profile with spaces\pip'
      Should -Invoke -CommandName Invoke-ParityAudit -ParameterFilter {
        @($PackageManagerProfiles).Count -eq 1 -and
        $PackageManagerProfiles[0].Identity -eq 'ATAP\Developer'
      } -Times 1
    }

    It 'passes an empty array so audit coverage remains fail-closed downstream' {
      $configurationPath = Join-Path $statePath 'Configuration\PackageManagerProfiles.v1.json'
      Write-TestPackageManagerProfileConfiguration -Path $configurationPath -SchemaVersion 1 -Profiles @()

      Invoke-ParityScheduledAuditTask `
        -StatePath $statePath `
        -HostName 'utat022' `
        -ResultDirectory $resultPath `
        -PackageManagerProfilesPath $configurationPath

      $script:capturedProfiles | Should -HaveCount 0
      Should -Invoke -CommandName Invoke-ParityAudit -ParameterFilter {
        @($PackageManagerProfiles | Where-Object { $null -ne $_ }).Count -eq 0
      } -Times 1
    }

    It 'rejects a missing configuration distinctly' {
      $missingPath = Join-Path $statePath 'Configuration\missing.json'
      {
        Invoke-ParityScheduledAuditTask `
          -StatePath $statePath `
          -HostName 'utat022' `
          -ResultDirectory $resultPath `
          -PackageManagerProfilesPath $missingPath
      } | Should -Throw '*was not found*'
      Should -Invoke -CommandName Invoke-ParityAudit -Times 0
    }

    It 'rejects malformed JSON distinctly' {
      $configurationPath = Join-Path $statePath 'Configuration\malformed.json'
      New-Item -ItemType Directory -Path (Split-Path -Parent $configurationPath) -Force | Out-Null
      Set-Content -LiteralPath $configurationPath -Value '{not-json' -Encoding utf8

      {
        Invoke-ParityScheduledAuditTask `
          -StatePath $statePath `
          -HostName 'utat022' `
          -ResultDirectory $resultPath `
          -PackageManagerProfilesPath $configurationPath
      } | Should -Throw '*unreadable or malformed*'
    }

    It 'rejects an unsupported schema version distinctly' {
      $configurationPath = Join-Path $statePath 'Configuration\unsupported.json'
      Write-TestPackageManagerProfileConfiguration -Path $configurationPath -SchemaVersion 2 -Profiles @()

      {
        Invoke-ParityScheduledAuditTask `
          -StatePath $statePath `
          -HostName 'utat022' `
          -ResultDirectory $resultPath `
          -PackageManagerProfilesPath $configurationPath
      } | Should -Throw '*unsupported SchemaVersion*'
    }

    It 'rejects a non-array Profiles value distinctly' {
      $configurationPath = Join-Path $statePath 'Configuration\null-profiles.json'
      New-Item -ItemType Directory -Path (Split-Path -Parent $configurationPath) -Force | Out-Null
      Set-Content -LiteralPath $configurationPath -Value '{"SchemaVersion":1,"Profiles":null}' -Encoding utf8

      {
        Invoke-ParityScheduledAuditTask `
          -StatePath $statePath `
          -HostName 'utat022' `
          -ResultDirectory $resultPath `
          -PackageManagerProfilesPath $configurationPath
      } | Should -Throw '*Profiles as an array*'
    }

    It 'reports an unreadable file distinctly without exposing file content' {
      $configurationPath = Join-Path $statePath 'Configuration\unreadable.json'
      Write-TestPackageManagerProfileConfiguration -Path $configurationPath -SchemaVersion 1 -Profiles @()
      Mock -CommandName Get-Content -ParameterFilter { $LiteralPath -eq $configurationPath } -MockWith {
        throw [UnauthorizedAccessException]::new('fixture access denied')
      }

      {
        Invoke-ParityScheduledAuditTask `
          -StatePath $statePath `
          -HostName 'utat022' `
          -ResultDirectory $resultPath `
          -PackageManagerProfilesPath $configurationPath
      } | Should -Throw '*unreadable or malformed*'
    }

    It 'preserves second-consecutive-failure alerting for configuration failures' {
      $missingPath = Join-Path $statePath 'Configuration\missing.json'

      {
        Invoke-ParityScheduledAuditTask `
          -StatePath $statePath `
          -HostName 'utat022' `
          -ResultDirectory $resultPath `
          -PackageManagerProfilesPath $missingPath
      } | Should -Throw
      Should -Invoke -CommandName Write-ParityScheduledTaskEvent -Times 0

      {
        Invoke-ParityScheduledAuditTask `
          -StatePath $statePath `
          -HostName 'utat022' `
          -ResultDirectory $resultPath `
          -PackageManagerProfilesPath $missingPath
      } | Should -Throw
      Should -Invoke -CommandName Write-ParityScheduledTaskEvent -ParameterFilter {
        $EventId -eq 12380 -and $Message -match 'second consecutive'
      } -Times 1
    }
  }
}
