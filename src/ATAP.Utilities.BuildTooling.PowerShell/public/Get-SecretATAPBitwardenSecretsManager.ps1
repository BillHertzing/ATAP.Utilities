<#
.SYNOPSIS
Retrieves a secret value from Bitwarden Secrets Manager using the bws CLI.

.DESCRIPTION
Get-SecretATAPBitwardenSecretsManager is the Bitwarden Secrets Manager (BWS) provider behind
Get-SecretATAP. It shells out to the `bws` CLI authenticated with a machine-account access
token and returns a single secret value by its key.

Token resolution (in order):
1. Process-scope `$env:BWS_ACCESS_TOKEN`.
2. The DPAPI access-token file for the running account (Get-ServiceAccountBWSAccessToken).

Unlike the Password-Manager provider there is no login, unlock, master password, or
BW_SESSION; the access token alone authorizes reads of the machine account's projects.

Lookup: `bws secret list --output json` is parsed and the entry whose `key` matches
SecretName (case-insensitive) is selected.

Field extraction:
  - BWS secrets are single-valued. If the value parses as a JSON object and SecretField
    names one of its properties (case-insensitive), that property is returned.
  - Otherwise the raw secret value is returned and SecretField is ignored.

The function never logs secret values; only the secret name and chosen field are logged.

.PARAMETER SecretName
The Bitwarden Secrets Manager secret key. Required. Also accepts
`-BuildMasterAdminApiKeySecretName` as an alias for BuildMaster helper calls.

.PARAMETER SecretField
Optional field name to extract from a JSON-structured value. Defaults to 'password'.
Ignored when the value is not JSON or has no matching property.

.OUTPUTS
[string] The plain-text secret value (or extracted field).

.EXAMPLE
Get-SecretATAPBitwardenSecretsManager -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key'

.EXAMPLE
Get-SecretATAPBitwardenSecretsManager -SecretName 'Windows.ServiceAccount.BuildMaster' -SecretField 'password'

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://bitwarden.com/help/secrets-manager-cli/

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Get-SecretATAPBitwardenSecretsManager {
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
    $fn = 'Get-SecretATAPBitwardenSecretsManager'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Retrieving field '$SecretField' from BWS secret '$SecretName'"

    # Load the sibling token-reader from source when not already available as a cmdlet.
    if (-not (Get-Command -Name 'Get-ServiceAccountBWSAccessToken' -CommandType Function -ErrorAction SilentlyContinue)) {
      $sibling = Join-Path $PSScriptRoot 'Get-ServiceAccountBWSAccessToken.ps1'
      if (Test-Path -LiteralPath $sibling) { . $sibling }
    }
  }

  PROCESS {
    $tokenWasSetHere = $false
    try {
      # 1. Confirm the bws CLI is available.
      if (-not (Get-Command -Name 'bws' -ErrorAction SilentlyContinue)) {
        $msg = 'Bitwarden Secrets Manager CLI (bws) was not found on PATH. Install it before using Get-SecretATAPBitwardenSecretsManager (see NewComputerSetup.md section 9.4.10.1).'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }

      # 2. Resolve the access token: process scope first, then the DPAPI file.
      $token = $env:BWS_ACCESS_TOKEN
      if ([string]::IsNullOrWhiteSpace($token)) {
        $cred = Get-ServiceAccountBWSAccessToken -ErrorAction Stop
        $token = $cred.GetNetworkCredential().Password
        $env:BWS_ACCESS_TOKEN = $token
        $tokenWasSetHere = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'BWS access token resolved from DPAPI file'
      }
      if ([string]::IsNullOrWhiteSpace($token)) {
        $msg = 'No BWS access token in $env:BWS_ACCESS_TOKEN or the DPAPI token file. Provision it with Initialize-ServiceAccountBWSAccessToken (see NewComputerSetup.md section 9.4.10).'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }

      # 3. List secrets (bws reads $env:BWS_ACCESS_TOKEN).
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Calling bws secret list' -Tag 'BWSCall'
      $listOutput = & bws secret list --output json 2>&1
      $listExit = $LASTEXITCODE
      if ($listExit -ne 0) {
        $msg = "bws secret list failed (exit $listExit). Output: $listOutput"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }

      $secrets = $null
      try { $secrets = $listOutput | ConvertFrom-Json -ErrorAction Stop }
      catch {
        $msg = "Failed to parse JSON from 'bws secret list'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }

      # 4. Match by key (case-insensitive).
      $match = @($secrets | Where-Object { $_.key -and ($_.key.ToLowerInvariant() -eq $SecretName.ToLowerInvariant()) })
      if ($match.Count -eq 0) {
        $msg = "No Bitwarden Secrets Manager secret found with key '$SecretName' in the machine account's projects."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }
      $rawValue = [string]$match[0].value

      # 5. Field extraction: try JSON object, else return the raw value.
      $value = $rawValue
      if (-not [string]::IsNullOrWhiteSpace($SecretField)) {
        $parsed = $null
        try { $parsed = $rawValue | ConvertFrom-Json -ErrorAction Stop } catch { $parsed = $null }
        if ($parsed -is [psobject] -and ($parsed.PSObject.Properties.Name | Where-Object { $_.ToLowerInvariant() -eq $SecretField.ToLowerInvariant() })) {
          $propName = ($parsed.PSObject.Properties.Name | Where-Object { $_.ToLowerInvariant() -eq $SecretField.ToLowerInvariant() } | Select-Object -First 1)
          $value = [string]$parsed.$propName
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Extracted field '$SecretField' from JSON-structured value"
        }
        else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Value is not JSON with field '$SecretField'; returning raw secret value"
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Successfully retrieved BWS secret '$SecretName' (value redacted)"
      return $value
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Get-SecretATAPBitwardenSecretsManager failed for '$SecretName' field '$SecretField'. Exception: $($_.Exception.Message)"
      throw
    }
    finally {
      if ($tokenWasSetHere) { Remove-Item Env:BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
