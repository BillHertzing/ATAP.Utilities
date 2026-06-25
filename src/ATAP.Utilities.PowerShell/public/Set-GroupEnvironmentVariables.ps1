function Set-GroupEnvironmentVariables {
  <#
  .SYNOPSIS
    Projects a group of ConfigRootKeys into process-scope environment variables, sourcing
    each value from $global:settings.
  .DESCRIPTION
    For every ConfigRootKey name supplied, this function resolves:
      - the environment-variable NAME  from  $global:configRootKeys[<ConfigRootKey>]
      - the environment-variable VALUE from  $global:settings[$global:configRootKeys[<ConfigRootKey>]]
    then sets a Process-scope environment variable with that name and value.

    It is the programmatic replacement for symlinking
    `Profiles\global_EnvironmentVariables.ps1` into the machine PowerShell profile
    directory. Instead of a per-worktree symlink whose target must be retargeted at every
    sprint boundary (H09 / SC-0188), a caller — a profile, an agent bootstrap, or a
    BuildMaster pipeline — invokes this function with the specific group of ConfigRootKeys
    it needs, reading authoritative values from the already-bootstrapped `$global:settings`.

    Resolution is StrictMode-safe and fails loud when no configuration source exists: an
    absent `$global:configRootKeys` / `$global:settings` (and no override supplied) means the
    ATAP profile did not run, which is an environment fault rather than a missing key.

    Secrets and API keys are intentionally NOT projected: callers resolve those by canonical
    setting name through `Get-PVal` / `Get-SecretATAP`. Only pass non-secret ConfigRootKeys.
  .PARAMETER ConfigRootKeys
    One or more ConfigRootKey names (keys into `$global:configRootKeys`), e.g.
    `'FastTempBasePathConfigRootKey'`. Accepts pipeline input.
  .PARAMETER ConfigRootKeyMap
    Optional override for `$global:configRootKeys` (the ConfigRootKey -> env-var-name map).
    Primarily for testability; defaults to `$global:configRootKeys`.
  .PARAMETER Settings
    Optional override for `$global:settings` (the env-var-name -> value map). Primarily for
    testability; defaults to `$global:settings`.
  .OUTPUTS
    System.Management.Automation.PSCustomObject summarizing requested/set/skipped counts and a
    per-key result list (ConfigRootKey, EnvVarName, Status). Values are not emitted.
  .EXAMPLE
    Set-GroupEnvironmentVariables -ConfigRootKeys 'FastTempBasePathConfigRootKey','DropBoxBasePathConfigRootKey'
  .EXAMPLE
    @('ENVIRONMENTConfigRootKey','VAULT_ADDRConfigRootKey') | Set-GroupEnvironmentVariables -WhatIf
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [Alias('ConfigRootKey')]
    [string[]]$ConfigRootKeys,

    [Parameter()]
    [hashtable]$ConfigRootKeyMap,

    [Parameter()]
    [hashtable]$Settings
  )

  begin {
    $fn = 'Set-GroupEnvironmentVariables'
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Resolve the effective ConfigRootKey map. Use Get-Variable existence tests rather than
    # bare $global:configRootKeys reads so that under Set-StrictMode -Version Latest an absent
    # global throws our intended loud error rather than a strict-mode error.
    if ($PSBoundParameters.ContainsKey('ConfigRootKeyMap') -and $ConfigRootKeyMap) {
      $effectiveConfigRootKeys = $ConfigRootKeyMap
    } else {
      $globalConfigRootKeysVariable = Get-Variable -Name configRootKeys -Scope Global -ErrorAction SilentlyContinue
      if ($null -ne $globalConfigRootKeysVariable -and $globalConfigRootKeysVariable.Value -is [hashtable] -and $globalConfigRootKeysVariable.Value.Count -gt 0) {
        $effectiveConfigRootKeys = $globalConfigRootKeysVariable.Value
      } else {
        throw "Set-GroupEnvironmentVariables cannot resolve ConfigRootKeys: `$global:configRootKeys is not populated and no -ConfigRootKeyMap was supplied. This usually means pwsh was started with -NoProfile; the ATAP profile builds `$global:configRootKeys. Re-run with profiles loaded, bootstrap with Initialize-ATAPConfigurationGlobals, or pass -ConfigRootKeyMap."
      }
    }

    if ($PSBoundParameters.ContainsKey('Settings') -and $Settings) {
      $effectiveSettings = $Settings
    } else {
      $globalSettingsVariable = Get-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue
      if ($null -ne $globalSettingsVariable -and $globalSettingsVariable.Value -is [hashtable] -and $globalSettingsVariable.Value.Count -gt 0) {
        $effectiveSettings = $globalSettingsVariable.Value
      } else {
        throw "Set-GroupEnvironmentVariables cannot resolve Settings: `$global:settings is not populated and no -Settings was supplied. This usually means pwsh was started with -NoProfile; the ATAP profile builds `$global:settings. Re-run with profiles loaded, bootstrap with Initialize-ATAPConfigurationGlobals, or pass -Settings."
      }
    }

    $results = [System.Collections.Generic.List[object]]::new()
  }

  process {
    foreach ($configRootKey in $ConfigRootKeys) {
      if ([string]::IsNullOrWhiteSpace($configRootKey)) { continue }

      # Resolve the environment-variable name from the ConfigRootKey.
      if (-not $effectiveConfigRootKeys.ContainsKey($configRootKey)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "ConfigRootKey '$configRootKey' is not present in the ConfigRootKeys map; skipping."
        $results.Add([PSCustomObject]@{ ConfigRootKey = $configRootKey; EnvVarName = $null; Status = 'SkippedNoKey' })
        continue
      }
      $envVarName = [string]$effectiveConfigRootKeys[$configRootKey]
      if ([string]::IsNullOrWhiteSpace($envVarName)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "ConfigRootKey '$configRootKey' maps to an empty environment-variable name; skipping."
        $results.Add([PSCustomObject]@{ ConfigRootKey = $configRootKey; EnvVarName = $null; Status = 'SkippedNoName' })
        continue
      }

      # Resolve the value from settings (keyed by the resolved env-var name).
      if (-not $effectiveSettings.ContainsKey($envVarName)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "No settings value found for '$envVarName' (ConfigRootKey '$configRootKey'); skipping."
        $results.Add([PSCustomObject]@{ ConfigRootKey = $configRootKey; EnvVarName = $envVarName; Status = 'SkippedNoValue' })
        continue
      }
      $envVarValue = [string]$effectiveSettings[$envVarName]

      if ($PSCmdlet.ShouldProcess("Process environment variable '$envVarName'", "Set from settings[$envVarName] (ConfigRootKey '$configRootKey')")) {
        [System.Environment]::SetEnvironmentVariable($envVarName, $envVarValue, [System.EnvironmentVariableTarget]::Process)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Set process environment variable '$envVarName' from ConfigRootKey '$configRootKey'." -Tag 'EnvVar'
        $results.Add([PSCustomObject]@{ ConfigRootKey = $configRootKey; EnvVarName = $envVarName; Status = 'Set' })
      } else {
        $results.Add([PSCustomObject]@{ ConfigRootKey = $configRootKey; EnvVarName = $envVarName; Status = 'WhatIf' })
      }
    }
  }

  end {
    $setCount = @($results | Where-Object { $_.Status -eq 'Set' }).Count
    $skippedCount = @($results | Where-Object { $_.Status -like 'Skipped*' }).Count
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Function completed: set $setCount, skipped $skippedCount of $($results.Count) requested."
    [PSCustomObject]@{
      RequestedCount = $results.Count
      SetCount       = $setCount
      SkippedCount   = $skippedCount
      Results        = @($results)
    }
  }
}
