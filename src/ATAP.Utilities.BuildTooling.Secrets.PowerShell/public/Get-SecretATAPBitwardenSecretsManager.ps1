<#
.SYNOPSIS
Retrieves a secret value from Bitwarden Secrets Manager using the bws CLI.

.DESCRIPTION
Get-SecretATAPBitwardenSecretsManager is the Bitwarden Secrets Manager (BWS) provider behind
Get-SecretATAP. It shells out to the `bws` CLI authenticated with a machine-account access
token and returns a single secret value by its key.

Token resolution (in order):
1. Process-scope `$env:BWS_ACCESS_TOKEN`.
2. The CommonCIForBitwardenReadOnly DPAPI access-token file for the running account (Get-BWSAccessToken -TokenPurpose ReadOnly).

Unlike the Password-Manager provider there is no login, unlock, master password, or
BW_SESSION; the CommonCIForBitwardenReadOnly access token authorizes reads of the granted projects.

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
$serviceHost = $global:Settings[$global:configRootKeys['ServicePlacementMapConfigRootKey']]['BuildMaster']
Get-SecretATAPBitwardenSecretsManager -BuildMasterAdminApiKeySecretName "BuildMaster.Admin.API.Key.$serviceHost"
Per SC-0288 the SecretName carries the BuildMaster placement host. The BWS access token used to
reach Bitwarden is caller-scoped and is never host-suffixed.

.EXAMPLE
Get-SecretATAPBitwardenSecretsManager -SecretName 'Windows.ServiceAccount.BuildMaster' -SecretField 'password'

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Native, parsing and provider failures are published with fixed ATAP.SecretRead.Bws
stage codes, without the original output, target or exception chain. Successful
secret values remain in-memory return values. Internal error history and logging
inside the token reader or CLI are outside this function's public-error boundary.

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
    $mn = 'ATAP.Utilities.BuildTooling.Secrets.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Retrieving BWS secret field'
  }

  PROCESS {
    $tokenWasSetHere = $false
    $failureStage = 'LoadTokenReader'
    try {
      # Keep source-loading errors inside the same sanitizing boundary.
      if (-not (Get-Command -Name 'Get-BWSAccessToken' -CommandType Function -ErrorAction SilentlyContinue)) {
        $sibling = Join-Path $PSScriptRoot 'Get-BWSAccessToken.ps1'
        if (Test-Path -LiteralPath $sibling) { . $sibling }
      }
      # 1. Confirm the bws CLI is available.
      $failureStage = 'DiscoverNative'
      if (-not (Get-Command -Name 'bws' -ErrorAction SilentlyContinue)) {
        $msg = 'Bitwarden Secrets Manager CLI (bws) was not found on PATH. Install it before using Get-SecretATAPBitwardenSecretsManager (see NewComputerSetup.md section 9.4.10.1).'
        throw $msg
      }

      # 2. Resolve the access token: process scope first, then the DPAPI file.
      $failureStage = 'ReadToken'
      $token = $env:BWS_ACCESS_TOKEN
      if ([string]::IsNullOrWhiteSpace($token)) {
        $cred = Get-BWSAccessToken -TokenPurpose ReadOnly -ErrorAction Stop
        $token = $cred.GetNetworkCredential().Password
        $env:BWS_ACCESS_TOKEN = $token
        $tokenWasSetHere = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'BWS ReadOnly access token resolved from CommonCIForBitwardenReadOnly DPAPI file'
      }
      if ([string]::IsNullOrWhiteSpace($token)) {
        $msg = 'No BWS access token in $env:BWS_ACCESS_TOKEN or the CommonCIForBitwardenReadOnly DPAPI token file. Provision it with Initialize-BWSAccessToken -TokenPurpose ReadOnly (see NewComputerSetup.md section 9.4.10).'
        throw $msg
      }

      # 3. List secrets (bws reads $env:BWS_ACCESS_TOKEN).
      $failureStage = 'NativeRead'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Calling bws secret list' -Tag 'BWSCall'
      $listOutput = & bws secret list --output json --color no 2>&1
      $listExit = $LASTEXITCODE
      if ($listExit -ne 0) {
        throw 'BWS native read failed.'
      }

      $secrets = $null
      $failureStage = 'ParseResponse'
      $secrets = $listOutput | ConvertFrom-Json -ErrorAction Stop

      # 4. Match by key (case-insensitive).
      $failureStage = 'MatchSecret'
      $match = @($secrets | Where-Object { $_.key -and ($_.key.ToLowerInvariant() -eq $SecretName.ToLowerInvariant()) })
      if ($match.Count -eq 0) {
        throw 'No Bitwarden Secrets Manager secret found.'
      }
      $rawValue = [string]$match[0].value

      # 5. Field extraction: try JSON object, else return the raw value.
      $failureStage = 'ExtractValue'
      $value = $rawValue
      if (-not [string]::IsNullOrWhiteSpace($SecretField)) {
        $parsed = $null
        try { $parsed = $rawValue | ConvertFrom-Json -ErrorAction Stop } catch { $parsed = $null }
        if ($parsed -is [psobject] -and ($parsed.PSObject.Properties.Name | Where-Object { $_.ToLowerInvariant() -eq $SecretField.ToLowerInvariant() })) {
          $propName = ($parsed.PSObject.Properties.Name | Where-Object { $_.ToLowerInvariant() -eq $SecretField.ToLowerInvariant() } | Select-Object -First 1)
          $value = [string]$parsed.$propName
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Extracted field from JSON-structured value'
        }
        else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Returning raw secret value'
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Successfully retrieved BWS secret (value redacted)'
      return $value
    }
    catch {
      # Publish a fresh error without the native/parser/provider exception tree.
      $failureCode = 'ATAP.SecretRead.Bws.' + $failureStage
      $errorMessage = if ($failureStage -eq 'MatchSecret') {
        "No Bitwarden Secrets Manager secret found [$failureCode]."
      } else {
        "Secret read failed [$failureCode]."
      }
      $publicError = [System.Management.Automation.ErrorRecord]::new(
        [System.InvalidOperationException]::new($errorMessage),
        $failureCode, [System.Management.Automation.ErrorCategory]::InvalidOperation, $null)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -ErrorRecord $publicError
      $PSCmdlet.ThrowTerminatingError($publicError)
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
