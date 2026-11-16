Describe 'SystemParityMonitor profile-settings guard (operator decision 2026-11-15, Option A)' -Tag 'Unit' {
  BeforeAll {
    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    # Reuse the promoted package when the harness preloads it; never force a second module copy.
    if (-not (Get-Module -Name 'ATAP.Utilities.SystemParityMonitor.PowerShell')) {
      Import-Module -Name (Join-Path $moduleRoot 'ATAP.Utilities.SystemParityMonitor.PowerShell.psd1')
    }
    $loadedModules = @(Get-Module -Name 'ATAP.Utilities.SystemParityMonitor.PowerShell')
    if ($loadedModules.Count -ne 1) { throw "Expected exactly one loaded SystemParityMonitor module; found $($loadedModules.Count)." }
    $scriptsRoot = Join-Path $loadedModules[0].ModuleBase 'scripts'
    . (Join-Path $scriptsRoot 'ParityScheduledTask.Common.ps1')
    . (Join-Path $scriptsRoot 'Invoke-ParityScheduledAuditTask.ps1')
    . (Join-Path $scriptsRoot 'Invoke-ParityScheduledCompareTask.ps1')

    function Invoke-ParityAudit { [CmdletBinding()] param([string] $StatePath, [string] $HostName) [pscustomobject]@{ SnapshotPath = 'fixture.snapshot.json'; CapturedAtUtc = '2026-11-16T00:00:00Z' } }
    function Compare-ParityAudits { param($LeftStatePath, $RightStatePath, $LeftHostName, $RightHostName, $ExpectedCadence, $StaleMultiplier) }
    function Get-SecretATAP { throw 'Secret resolution is forbidden in this test.' }

    # The guard reads two globals that the profile normally sets. Save the real values once and
    # put them back after every test, so the caller's session (often a profiled pwsh) is unchanged.
    $script:savedGlobals = @{}
    foreach ($name in 'settings', 'configRootKeys') {
      $variable = Get-Variable -Name $name -Scope Global -ErrorAction SilentlyContinue
      $script:savedGlobals[$name] = if ($variable) { @{ Present = $true; Value = $variable.Value } } else { @{ Present = $false } }
    }
    $script:savedRequire = [Environment]::GetEnvironmentVariable('ATAP_PARITY_REQUIRE_PROFILE_SETTINGS', 'Process')

    function Set-TestGlobals([bool] $Present) {
      foreach ($name in 'settings', 'configRootKeys') {
        Remove-Variable -Name $name -Scope Global -Force -ErrorAction SilentlyContinue
        if ($Present) { Set-Variable -Name $name -Scope Global -Value @{ Fixture = 'present' } }
      }
    }
  }

  AfterEach {
    foreach ($name in 'settings', 'configRootKeys') {
      Remove-Variable -Name $name -Scope Global -Force -ErrorAction SilentlyContinue
      if ($script:savedGlobals[$name].Present) { Set-Variable -Name $name -Scope Global -Value $script:savedGlobals[$name].Value }
    }
    [Environment]::SetEnvironmentVariable('ATAP_PARITY_REQUIRE_PROFILE_SETTINGS', $script:savedRequire, 'Process')
  }

  Context 'Assert-ParityProfileSettingsLoaded' {
    It 'does nothing when not required, even with no settings' {
      Set-TestGlobals -Present $false
      [Environment]::SetEnvironmentVariable('ATAP_PARITY_REQUIRE_PROFILE_SETTINGS', $null, 'Process')
      { Assert-ParityProfileSettingsLoaded } | Should -Not -Throw
    }

    It 'throws when -Required and the profile globals are missing, naming both' {
      Set-TestGlobals -Present $false
      [Environment]::SetEnvironmentVariable('ATAP_PARITY_REQUIRE_PROFILE_SETTINGS', $null, 'Process')
      { Assert-ParityProfileSettingsLoaded -Required } | Should -Throw '*$global:settings, $global:configRootKeys*'
    }

    It 'throws when the dispatcher environment variable is 1 and the globals are missing' {
      Set-TestGlobals -Present $false
      [Environment]::SetEnvironmentVariable('ATAP_PARITY_REQUIRE_PROFILE_SETTINGS', '1', 'Process')
      { Assert-ParityProfileSettingsLoaded } | Should -Throw '*did not load the ATAP settings*'
    }

    It 'treats an empty settings table as missing' {
      Set-TestGlobals -Present $true
      Set-Variable -Name settings -Scope Global -Value @{}
      { Assert-ParityProfileSettingsLoaded -Required } | Should -Throw '*$global:settings missing or empty*'
    }

    It 'passes when required and both globals are populated' {
      Set-TestGlobals -Present $true
      [Environment]::SetEnvironmentVariable('ATAP_PARITY_REQUIRE_PROFILE_SETTINGS', '1', 'Process')
      { Assert-ParityProfileSettingsLoaded -Required } | Should -Not -Throw
    }

    It 'works under Set-StrictMode when the globals were never assigned' {
      Set-TestGlobals -Present $false
      & {
        Set-StrictMode -Version Latest
        { Assert-ParityProfileSettingsLoaded -Required } | Should -Throw '*did not load the ATAP settings*'
      }
    }
  }

  Context 'scheduled task scripts' {
    BeforeEach {
      $script:fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('SPG_' + [guid]::NewGuid().ToString('N'))
      $script:statePath = Join-Path $script:fixtureRoot 'State'
      $script:resultPath = Join-Path $script:fixtureRoot 'Results'
      New-Item -ItemType Directory -Path $script:statePath, $script:resultPath -Force | Out-Null
      Mock -CommandName Import-Module
      Mock -CommandName Write-ParityScheduledTaskEvent -MockWith { [pscustomobject]@{ Success = $true; ErrorType = $null } }
      # The task reads both properties under StrictMode; keep the positive fixture contract complete.
      Mock -CommandName Invoke-ParityAudit -MockWith { [pscustomobject]@{ SnapshotPath = 'fixture.snapshot.json'; CapturedAtUtc = '2026-11-16T00:00:00Z' } }
    }

    It 'fails the audit run and records the failure when -RequireProfileSettings finds no settings' {
      Set-TestGlobals -Present $false
      [Environment]::SetEnvironmentVariable('ATAP_PARITY_REQUIRE_PROFILE_SETTINGS', $null, 'Process')
      { Invoke-ParityScheduledAuditTask -StatePath $script:statePath -HostName 'utat022' -ResultDirectory $script:resultPath -RequireProfileSettings } |
        Should -Throw '*did not load the ATAP settings*'
      Should -Invoke Invoke-ParityAudit -Times 0 -Exactly
      $result = Get-ChildItem -LiteralPath $script:resultPath -Filter 'ParityAuditTaskResult.*.json' | Get-Content -Raw | ConvertFrom-Json
      $result.Success | Should -BeFalse
      $result.ErrorMessage | Should -Match 'did not load the ATAP settings'
    }

    It 'fails the compare run when the dispatcher variable is set and settings are missing' {
      Set-TestGlobals -Present $false
      [Environment]::SetEnvironmentVariable('ATAP_PARITY_REQUIRE_PROFILE_SETTINGS', '1', 'Process')
      Mock -CommandName Compare-ParityAudits
      { Invoke-ParityScheduledCompareTask -LeftStatePath $script:statePath -RightStatePath $script:statePath -LeftHostName 'utat022' -RightHostName 'utat01' -ResultDirectory $script:resultPath } |
        Should -Throw '*did not load the ATAP settings*'
      Should -Invoke Compare-ParityAudits -Times 0 -Exactly
    }

    It 'runs the audit normally when the guard is not requested' {
      Set-TestGlobals -Present $false
      [Environment]::SetEnvironmentVariable('ATAP_PARITY_REQUIRE_PROFILE_SETTINGS', $null, 'Process')
      { Invoke-ParityScheduledAuditTask -StatePath $script:statePath -HostName 'utat022' -ResultDirectory $script:resultPath } | Should -Not -Throw
      Should -Invoke Invoke-ParityAudit -Times 1 -Exactly
    }
  }
}
