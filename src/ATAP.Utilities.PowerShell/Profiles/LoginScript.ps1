<#
.SYNOPSIS
Runs the ATAP interactive login Bitwarden startup flow.

.DESCRIPTION
Loads Initialize-BitwardenSession from the ATAP.Utilities.Powershell module source
and executes the login-time Bitwarden environment setup. The unlock function
lives in public/Initialize-BitwardenSession.ps1; this script remains the direct
startup-task entry point that records Event Log status and loads environment
variables from Profiles/BitwardenEnvVarConfig.json.

.NOTES
This script is designed to run automatically at user logon.
#>
$fn = 'LoginScript-ExecutionBlock'
$mn = 'ATAP.Utilities.Powershell'

function Import-LoginScriptFunction {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$FunctionName,

    [Parameter(Mandatory = $true)]
    [string]$RelativePath
  )

  if (Get-Command -Name $FunctionName -CommandType Function -ErrorAction SilentlyContinue) {
    return
  }

  Import-Module ATAP.Utilities.Powershell -ErrorAction SilentlyContinue
  if (Get-Command -Name $FunctionName -CommandType Function -ErrorAction SilentlyContinue) {
    return
  }

  $moduleRoot = Split-Path -Path $PSScriptRoot -Parent
  $sourcePath = Join-Path -Path $moduleRoot -ChildPath $RelativePath
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Required login function '$FunctionName' was not found at '$sourcePath'."
  }

  . $sourcePath
}

try {
  Import-LoginScriptFunction -FunctionName 'Initialize-BitwardenSession' -RelativePath 'public\Initialize-BitwardenSession.ps1'
  Import-LoginScriptFunction -FunctionName 'Set-EnvVarsFromBitWarden' -RelativePath 'public\Set-EnvVarsFromBitWarden.ps1'
} catch {
  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to load login script functions. Exception: $($_.Exception.Message)" -Tag 'startup'
  throw
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  try {
    if (-not [System.Diagnostics.EventLog]::SourceExists('BitwardenLogin')) {
      try {
        New-EventLog -LogName Application -Source 'BitwardenLogin'
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Could not create event log source: $($_.Exception.Message)" -Tag 'startup'
      }
    }

    try {
      Write-EventLog -LogName Application -Source 'BitwardenLogin' -EntryType Information -EventId 1000 -Message 'LoginScript execution started'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'LoginScript execution started' -Tag 'startup'
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Could not write start event to Event Log: $($_.Exception.Message)" -Tag 'startup'
    }

    $result = Initialize-BitwardenSession

    if (-not $result.Success) {
      $failureMessage = "LoginScript failed: Bitwarden session initialization failed. $($result.Message)"
      Write-EventLog -LogName Application -Source 'BitwardenLogin' -EntryType Error -EventId 2000 -Message $failureMessage
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $failureMessage -Tag 'startup'
      return
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $result.Message -Tag 'startup'

    $configFilePath = Join-Path $PSScriptRoot 'BitwardenEnvVarConfig.json'
    if (-not (Test-Path -LiteralPath $configFilePath -PathType Leaf)) {
      $errorMessage = "BitwardenEnvVarConfig.json not found at '$configFilePath'. Cannot load environment variable definitions."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'
      Write-EventLog -LogName Application -Source 'BitwardenLogin' -EntryType Error -EventId 2002 -Message $errorMessage
      return
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Loading env var configs from '$configFilePath'" -Tag 'startup'
    $envVarConfigs = Get-Content -LiteralPath $configFilePath -Raw | ConvertFrom-Json
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Loaded $($envVarConfigs.Count) env var configs from file" -Tag 'startup'

    $envVarResults = Set-EnvVarsFromBitWarden -EnvVarConfigs $envVarConfigs

    $successCount = 0
    $failureCount = 0
    $failureDetails = @()

    foreach ($envVarResult in $envVarResults) {
      if ($envVarResult.Success) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $envVarResult.Message -Tag 'startup'
        $successCount++
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "$($envVarResult.EnvVarName) retrieval failed: $($envVarResult.Message)" -Tag 'startup'
        $failureCount++
        $failureDetails += "$($envVarResult.EnvVarName): $($envVarResult.Message)"
      }
    }

    $successMessage = "LoginScript completed successfully. Bitwarden session established. Environment variables processed: $successCount succeeded, $failureCount failed."
    if ($failureCount -gt 0) {
      $successMessage += " Failures: $($failureDetails -join '; ')"
    }

    Write-EventLog -LogName Application -Source 'BitwardenLogin' -EntryType Information -EventId 1001 -Message $successMessage
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $successMessage -Tag 'startup'
  } catch {
    $errorMessage = "CRITICAL ERROR in LoginScript: $($_.Exception.Message). StackTrace: $($_.Exception.StackTrace)"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'

    try {
      Write-EventLog -LogName Application -Source 'BitwardenLogin' -EntryType Error -EventId 2001 -Message $errorMessage
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Could not write error to Event Log: $($_.Exception.Message)" -Tag 'startup'
    }
  }
}
