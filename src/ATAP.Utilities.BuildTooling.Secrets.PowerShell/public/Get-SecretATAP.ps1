<#
.SYNOPSIS
Retrieves a single field from a secret in the configured ATAP secret store.

.DESCRIPTION
Get-SecretATAP is the vendor-agnostic wrapper used by ATAP code to read secrets.
The wrapper resolves the active secret-store implementation in this order:
1. The -SecretStoreType parameter when supplied (highest precedence).
2. $global:settings (key 'SecretStoreType') when configured.
3. Default: 'BitwardenSecretsManager' for ALL accounts (bws CLI + DPAPI-protected
   machine access token).

Bitwarden Secrets Manager is the default for every account (SC-0175). The
personal-vault Password Manager path (bw CLI + BW_SESSION) is opt-in only and
must be requested explicitly with -SecretStoreType 'Bitwarden' or by setting
$global:settings['SecretStoreType'] = 'Bitwarden'. Sprint lifecycle automation
therefore reads machine secrets with bws by default and never touches the
personal-vault BW_SESSION unless a caller deliberately opts in.

Even when the personal-vault path is explicitly selected, the provider
(Get-SecretATAPBitwarden) refuses CI/infrastructure secret names - connection
strings, API keys, ProGet/BuildMaster and service-account secrets - and throws
(Task 9.21). The personal-vault path is reserved for genuine per-user personal
secrets only; CI/infra secrets live exclusively in Bitwarden Secrets Manager.

The 'Bitwarden' and 'BitwardenSecretsManager' providers are implemented today.
Future stores (for example 'AzureKeyVault' or 'HashiCorpVault') plug into the
switch in PROCESS without changing any caller.

The function intentionally returns a single string, not an object. Callers that
need multiple values (UserName + Password + HostName + ...) must invoke
Get-SecretATAP once per field. This keeps the wrapper API stable across
secret-store implementations that expose fields differently.

.PARAMETER SecretName
The name (item key) of the secret to retrieve. Required.

.PARAMETER SecretField
The named field inside the secret to return. Defaults to 'password'.
Common values:
  - 'password'  : the primary credential value (login.password for Login items,
                  notes body for Secure Notes)
  - 'username'  : the login.username field
  - 'notes'     : the notes field
  - any custom-field name defined inside the item

.PARAMETER SecretStoreType
Optional explicit secret-store provider. Overrides $global:settings and the
account-based default. Implemented values: 'Bitwarden' (Password Manager,
bw CLI + BW_SESSION) and 'BitwardenSecretsManager' (Secrets Manager, bws CLI
+ machine access token).

.OUTPUTS
[string]
The plain-text value of the requested field.

.EXAMPLE
$serviceHost = $global:Settings[$global:configRootKeys['ServicePlacementMapConfigRootKey']]['BuildMaster']
$apiKey = Get-SecretATAP -SecretName "BuildMaster.Admin.API.Key.$serviceHost" -SecretField 'notes'
Returns the notes field (where the BuildMaster admin API key is stored). Per SC-0288 the
SecretName carries the host running the BuildMaster instance being authenticated against;
derive it from the placement map rather than hard-coding a host. This does not apply to the
BWS access token, which is caller-scoped and identical on every host.

.EXAMPLE
$user = Get-SecretATAP -SecretName 'utat022-SvcBuildmaster-Production' -SecretField 'username'
$pass = Get-SecretATAP -SecretName 'utat022-SvcBuildmaster-Production' -SecretField 'password'
Retrieves the username and password from one Bitwarden item via two calls.

.EXAMPLE
$connStr = Get-SecretATAP -SecretName 'dbConnectionString-ATAPUtilities-localhost-Dev-jsmith' -SecretStoreType 'BitwardenSecretsManager'
Sprint automation reads a per-sprint machine secret from Bitwarden Secrets Manager (no BW_SESSION).

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Get-SecretATAP {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$SecretName,

    [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$SecretField = 'password',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$SecretStoreType
  )

  BEGIN {
    $fn = 'Get-SecretATAP'
    $mn = 'ATAP.Utilities.BuildTooling.Secrets.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  PROCESS {
    try {
      $identityName = $null
      try {
        $identityName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
      } catch {
        $identityName = [Environment]::UserName
      }
      if ([string]::IsNullOrWhiteSpace($identityName)) {
        $identityName = [Environment]::UserName
      }
      $accountLeafName = [string]$identityName
      if ($accountLeafName.Contains('\')) {
        $accountLeafName = ($accountLeafName -split '\\')[-1]
      } elseif ($accountLeafName.Contains('@')) {
        $accountLeafName = ($accountLeafName -split '@')[0]
      }

      # Default to Bitwarden Secrets Manager (bws CLI + DPAPI-protected machine
      # access token) for ALL accounts (SC-0175). The personal-vault Password
      # Manager path (bw CLI + BW_SESSION) is opt-in only: callers must request
      # it with -SecretStoreType 'Bitwarden' or set $global:settings['SecretStoreType'].
      # This removes the prior account-name heuristic that silently routed
      # developer accounts through bw and required every caller to remember the
      # override.
      $defaultStoreType = 'BitwardenSecretsManager'

      # Resolve the active secret-store provider: explicit parameter first,
      # then $global:settings; when both are unset, default to BWS (above).
      $storeType = $defaultStoreType
      if (-not [string]::IsNullOrWhiteSpace($SecretStoreType)) {
        $storeType = $SecretStoreType
      } elseif ($global:settings) {
        $key = 'SecretStoreType'
        if ($global:configRootKeys) {
          $configuredKey = $global:configRootKeys['SecretStoreTypeConfigRootKey']
          if (-not [string]::IsNullOrWhiteSpace([string]$configuredKey)) {
            $key = [string]$configuredKey
          }
        }
        if ($global:settings.ContainsKey($key)) {
          $candidate = [string]$global:settings[$key]
          if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            $storeType = $candidate
          }
        }
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved secret store type: $storeType for process owner '$identityName'"

      switch ($storeType) {
        'Bitwarden' {
          if (-not (Get-Command -Name 'Get-SecretATAPBitwarden' -CommandType Function -ErrorAction SilentlyContinue)) {
            $sibling = Join-Path $PSScriptRoot 'Get-SecretATAPBitwarden.ps1'
            if (Test-Path -LiteralPath $sibling) { . $sibling }
          }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Dispatching to Get-SecretATAPBitwarden for '$SecretName' field '$SecretField'"
          return Get-SecretATAPBitwarden -SecretName $SecretName -SecretField $SecretField
        }
        'BitwardenSecretsManager' {
          # Load the sibling provider from source when not already available as a cmdlet.
          if (-not (Get-Command -Name 'Get-SecretATAPBitwardenSecretsManager' -CommandType Function -ErrorAction SilentlyContinue)) {
            $sibling = Join-Path $PSScriptRoot 'Get-SecretATAPBitwardenSecretsManager.ps1'
            if (Test-Path -LiteralPath $sibling) { . $sibling }
          }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Dispatching to Get-SecretATAPBitwardenSecretsManager for '$SecretName' field '$SecretField'"
          return Get-SecretATAPBitwardenSecretsManager -SecretName $SecretName -SecretField $SecretField
        }
        default {
          $msg = "Secret store type '$storeType' is not implemented. Supported: 'Bitwarden' (Password Manager) and 'BitwardenSecretsManager' (Secrets Manager)."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
          throw $msg
        }
      }
    }
    catch {
      $errorMessage = "Get-SecretATAP failed for secret '$SecretName' field '$SecretField'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
