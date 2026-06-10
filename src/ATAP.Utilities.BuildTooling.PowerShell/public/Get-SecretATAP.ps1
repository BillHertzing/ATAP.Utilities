<#
.SYNOPSIS
Retrieves a single field from a secret in the configured ATAP secret store.

.DESCRIPTION
Get-SecretATAP is the vendor-agnostic wrapper used by ATAP code to read secrets.
The wrapper resolves the active secret-store implementation from
$global:settings (key 'SecretStoreType') when configured. If the setting is
blank or absent, service accounts whose process owner name starts with `Svc`
use Bitwarden Secrets Manager; developer accounts use Bitwarden Password
Manager.

The 'Bitwarden' and 'BitwardenSecretsManager' providers are implemented today.
Future stores (for example 'AzureKeyVault' or 'HashiCorpVault') plug into the
switch in PROCESS without changing any caller.

The function intentionally returns a single string, not an object. Callers that
need multiple values (UserName + Password + HostName + ...) must invoke
Get-SecretATAP once per field. This keeps the wrapper API stable across
secret-store implementations that expose fields differently.

.PARAMETER SecretName
The name (item key) of the secret to retrieve. Required. Also accepts
`-BuildMasterAdminApiKeySecretName` as an alias for BuildMaster helper calls.

.PARAMETER SecretField
The named field inside the secret to return. Defaults to 'password'.
Common values:
  - 'password'  : the primary credential value (login.password for Login items,
                  notes body for Secure Notes)
  - 'username'  : the login.username field
  - 'notes'     : the notes field
  - any custom-field name defined inside the item

.OUTPUTS
[string]
The plain-text value of the requested field.

.EXAMPLE
$apiKey = Get-SecretATAP -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key'
Returns the password/value field as a string.

.EXAMPLE
$user = Get-SecretATAP -SecretName 'utat022-SvcBuildmaster-Production' -SecretField 'username'
$pass = Get-SecretATAP -SecretName 'utat022-SvcBuildmaster-Production' -SecretField 'password'
Retrieves the username and password from one Bitwarden item via two calls.

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
    [Alias('BuildMasterAdminApiKeySecretName')]
    [string]$SecretName,

    [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$SecretField = 'password'
  )

  BEGIN {
    $fn = 'Get-SecretATAP'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
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

      $defaultStoreType = if ($accountLeafName.StartsWith('Svc', [System.StringComparison]::OrdinalIgnoreCase)) {
        'BitwardenSecretsManager'
      } else {
        'Bitwarden'
      }

      # Resolve the active secret-store provider from $global:settings; when
      # unset, select BWS for service accounts and Password Manager for users.
      $storeType = $defaultStoreType
      if ($global:settings) {
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
