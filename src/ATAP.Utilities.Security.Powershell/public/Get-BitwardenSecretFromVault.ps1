<#
.SYNOPSIS
Retrieves a secret from Bitwarden using SecretManagement.

.DESCRIPTION
Uses Microsoft.PowerShell.SecretManagement to retrieve secrets from a registered
Bitwarden vault. Ensures the vault is unlocked before attempting retrieval.

.PARAMETER SecretName
The name of the secret to retrieve from Bitwarden.

.PARAMETER VaultName
The name of the registered SecretManagement vault. Default is 'BitwardenVault'.

.PARAMETER AsPlainText
Switch to return the secret as plain text instead of SecureString.

.OUTPUTS
System.Security.SecureString or System.String
Returns the secret value.

.EXAMPLE
$secret = Get-BitwardenSecretFromVault -SecretName 'MyApiKey'
Retrieves the secret as a SecureString.

.EXAMPLE
$apiKey = Get-BitwardenSecretFromVault -SecretName 'MyApiKey' -AsPlainText
Retrieves the secret as plain text.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Get-BitwardenSecretFromVault {
  [CmdletBinding()]
  [OutputType([System.Security.SecureString], [string])]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [string]$SecretName,

    [Parameter(Mandatory = $false, Position = 1)]
    [string]$VaultName = 'BitwardenVault',

    [Parameter(Mandatory = $false)]
    [switch]$AsPlainText
  )

  BEGIN {
    $fn = 'Get-BitwardenSecretFromVault'
    $mn = 'ATAP.Utilities.Security.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Snippet: Check and populate simple parameter - SecretName
    $SecretName = Get-PVal SecretName $PSBoundParameters SecretName

    # Snippet: Check and populate simple parameter - VaultName
    $VaultName = Get-PVal VaultName $PSBoundParameters VaultName

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Retrieving secret '$SecretName' from vault '$VaultName'"
  }

  PROCESS {
    # Snippet: Try-Catch-Finally
    try {
      # Verify the vault is registered
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Checking if vault '$VaultName' is registered"
      $vault = Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue

      if (-not $vault) {
        $errorMessage = "Vault '$VaultName' is not registered. Please register the vault first using Register-SecretVault."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Vault '$VaultName' found and registered"

      # Attempt to unlock the vault if needed
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Attempting to unlock vault '$VaultName'"
      $unlockResult = Unlock-SecretVault -Name $VaultName -ErrorAction SilentlyContinue

      if ($unlockResult) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Vault '$VaultName' unlocked successfully"
      }

      # Retrieve the secret
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Retrieving secret '$SecretName'"

      $getSecretParams = @{
        Name  = $SecretName
        Vault = $VaultName
      }

      if ($AsPlainText) {
        $getSecretParams.AsPlainText = $true
      }

      $secret = Get-Secret @getSecretParams -ErrorAction Stop

      if (-not $secret) {
        $errorMessage = "Secret '$SecretName' not found in vault '$VaultName'"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Successfully retrieved secret '$SecretName'"

      return $secret
    }
    catch {
      $errorMessage = "Failed to retrieve secret from Bitwarden. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      # ToDo: accumulate the errors; potentially add to 'Problems'
      throw # the unadorned throw will throw the $_ exception and keep the stack trace intact
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
