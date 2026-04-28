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
$secret = Get-BitwardenSecret -SecretName 'MyApiKey'
Retrieves the secret as a SecureString.

.EXAMPLE
$apiKey = Get-BitwardenSecret -SecretName 'MyApiKey' -AsPlainText
Retrieves the secret as plain text.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Get-BitwardenSecret {
  [CmdletBinding()]
  [OutputType([System.Security.SecureString], [string])]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$SecretName,

    [Parameter(Mandatory = $false, Position = 1)]
    [string]$VaultName = 'Bitwarden',

    [Parameter(Mandatory = $false)]
    [switch]$AsPlainText
  )

  BEGIN {
    $fn = 'Get-BitwardenSecret'
    $mn = 'ATAP.Utilities.Security.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Snippet: Check and populate simple parameter - SecretName
    # ToDo: Another kind of validation that doesn't look into global:settings?
    #$SecretName = Get-PVal SecretName $PSBoundParameters SecretName

    # ToDo: Another kind of validation that doesn't look into global:settings?
    # $VaultName = Get-PVal VaultName $PSBoundParameters VaultName

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

      # Check if BW_SESSION environment variable is set (vault already unlocked via CLI)
      if ($env:BW_SESSION) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'BW_SESSION environment variable detected'

        # Verify the vault is actually unlocked by checking status
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Verifying vault unlock status via bw status'
        try {
          $statusJson = bw status 2>&1
          $status = $statusJson | ConvertFrom-Json -ErrorAction SilentlyContinue
          if ($status.status -ne 'unlocked') {
            $errorMessage = "Bitwarden vault is not unlocked (status: $($status.status)). BW_SESSION may be stale. Run: `$env:BW_SESSION = (bw unlock --raw)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
          }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Vault status confirmed: $($status.status)"
        }
        catch {
          if ($_.Exception.Message -like '*Bitwarden vault is not unlocked*') {
            throw
          }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Could not verify vault status: $($_.Exception.Message)"
        }
      }
      else {
        # BW_SESSION not set - vault is definitely not unlocked
        $errorMessage = 'BW_SESSION environment variable is not set. The Bitwarden vault is not unlocked. Run: $env:BW_SESSION = (bw unlock --raw)'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
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

      # Use SilentlyContinue so the SecretManagement framework's type-validation message
      # ("Secret object returned for ... is of invalid type 'System.Boolean'") does not
      # short-circuit execution before we can inspect the returned value ourselves.
      $getSecretErrors = $null
      $secret = Get-Secret @getSecretParams -ErrorAction SilentlyContinue -ErrorVariable getSecretErrors

      # Re-throw any errors that are NOT the benign type-validation message; those are real failures.
      if ($getSecretErrors) {
        $realErrors = @($getSecretErrors | Where-Object {
            $_.Exception.Message -notlike 'Secret object returned for*'
          })
        if ($realErrors.Count -gt 0) {
          throw $realErrors[0].Exception
        }
      }

      # Boolean return means the vault extension signalled failure (vault locked / session expired).
      if ($secret -is [bool]) {
        $errorMessage = "Failed to retrieve secret '$SecretName'. The vault returned a Boolean instead of a secret object. The vault is likely locked or BW_SESSION has expired. Run: `$env:BW_SESSION = (bw unlock --raw)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }

      if ($null -eq $secret) {
        $errorMessage = "Secret '$SecretName' not found in vault '$VaultName'. Verify the secret name is correct and exists in Bitwarden."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Successfully retrieved secret '$SecretName'"

      return $secret
    }
    catch {
      # Provide more context in the error message
      $errorMessage = "Failed to retrieve secret '$SecretName' from vault '$VaultName'. Exception: $($_.Exception.Message)"
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
