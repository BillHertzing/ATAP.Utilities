<#
.SYNOPSIS
Reads the DPAPI-protected Bitwarden Secrets Manager (bws) access token for the running account.

.DESCRIPTION
Get-BWSAccessToken loads a DPAPI-encrypted Bitwarden Secrets Manager access-token
credential file for the current Windows identity and returns it as a PSCredential whose
password is the BWS access token. It is the read side of Initialize-BWSAccessToken.

The token purpose controls which common CI machine token slot is read:
ReadOnly maps to CommonCIForBitwardenReadOnly, and ReadWrite maps to
CommonCIForBitwardenReadWrite. ReadOnly is the default for ordinary secret reads.

Purpose-specific files are named
`<COMPUTERNAME>_<SamAccountName>_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml` and
`<COMPUTERNAME>_<SamAccountName>_BWS_CommonCIForBitwardenReadWrite_AccessToken.xml` in
the account's protected credential directory. DPAPI binds each file to the user identity,
so it can only be decrypted by the same account on the same host. The SAM name is derived
from [WindowsIdentity]::GetCurrent() (not $env:USERNAME) so it is correct even when the
process was launched with Start-Process -Credential under -NoProfile.

During migration only, ReadOnly may fall back to the legacy
`<COMPUTERNAME>_<SamAccountName>_BWS_AccessToken.xml` file and logs a PSFramework warning.
ReadWrite never falls back to the legacy file.

.PARAMETER CredentialDirectory
Absolute path to the directory holding the DPAPI token file. Defaults to
`C:\ProgramData\ATAP\BitwardenCredentials\<SamAccountName>`.

.PARAMETER TokenPurpose
Selects the BWS common CI token slot to read. ReadOnly maps to
CommonCIForBitwardenReadOnly and is the default. ReadWrite maps to
CommonCIForBitwardenReadWrite and is reserved for provisioning, mutation, deletion, and
rotation workflows.

.OUTPUTS
System.Management.Automation.PSCredential
UserName is the literal 'BWS_ACCESS_TOKEN'; Password is the access token.

.EXAMPLE
$cred = Get-BWSAccessToken
$env:BWS_ACCESS_TOKEN = $cred.GetNetworkCredential().Password

Reads the default CommonCIForBitwardenReadOnly token slot.

.EXAMPLE
$cred = Get-BWSAccessToken -TokenPurpose ReadWrite
$env:BWS_ACCESS_TOKEN = $cred.GetNetworkCredential().Password

Reads the CommonCIForBitwardenReadWrite token slot for a write/rotation workflow.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Runs as the owning Windows account itself (DPAPI is user-bound).
Handled failures publish fixed ATAP.SecretRead.Token stage codes and a fresh
ErrorRecord without the original message, target or inner exception. This does
not clear internal PowerShell error history or sanitize errors inside other code.

.LINK
https://bitwarden.com/help/secrets-manager-cli/

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Get-BWSAccessToken {
  [CmdletBinding()]
  [Alias('Get-ServiceAccountBWSAccessToken')]
  [OutputType([System.Management.Automation.PSCredential])]
  param(
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$CredentialDirectory,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet('ReadOnly', 'ReadWrite')]
    [string]$TokenPurpose = 'ReadOnly'
  )

  BEGIN {
    $fn = 'Get-BWSAccessToken'
    $mn = 'ATAP.Utilities.BuildTooling.Secrets.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started' -Tag 'bws-token'
  }

  PROCESS {
    $failureStage = 'ResolvePath'
    try {
      # Path/identity failures must not escape the public sanitizing boundary.
      $tokenLabelByPurpose = @{
        ReadOnly = 'CommonCIForBitwardenReadOnly'
        ReadWrite = 'CommonCIForBitwardenReadWrite'
      }
      $tokenLabel = $tokenLabelByPurpose[$TokenPurpose]

      $currentSamName = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\') | Select-Object -Last 1
      if ([string]::IsNullOrWhiteSpace($CredentialDirectory)) {
        $CredentialDirectory = "C:\ProgramData\ATAP\BitwardenCredentials\$currentSamName"
      }
      $tokenFileName = "$env:COMPUTERNAME`_$currentSamName`_BWS_$tokenLabel`_AccessToken.xml"
      $tokenPath = Join-Path $CredentialDirectory $tokenFileName
      $legacyTokenFileName = "$env:COMPUTERNAME`_$currentSamName`_BWS_AccessToken.xml"
      $legacyTokenPath = Join-Path $CredentialDirectory $legacyTokenFileName

      $failureStage = 'LocateCredential'
      $resolvedTokenPath = $tokenPath
      if (-not (Test-Path -LiteralPath $resolvedTokenPath)) {
        if ($TokenPurpose -eq 'ReadOnly' -and (Test-Path -LiteralPath $legacyTokenPath)) {
          $resolvedTokenPath = $legacyTokenPath
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message 'Using legacy BWS ReadOnly access-token file. Re-provision CommonCIForBitwardenReadOnly with Initialize-BWSAccessToken -TokenPurpose ReadOnly.' -Tag 'bws-token', 'migration'
        }
        else {
          throw 'BWS access-token credential file not found.'
        }
      }
      $failureStage = 'ReadCredential'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Loading BWS access-token credential' -Tag 'bws-token'
      $credential = Import-Clixml -LiteralPath $resolvedTokenPath -ErrorAction Stop
      return $credential
    }
    catch {
      # Do not forward Import-Clixml/native provider data into PSF or public errors.
      $failureCode = 'ATAP.SecretRead.Token.' + $failureStage
      # Purpose labels come only from the fixed map and validated purpose set.
      $errorMessage = "BWS $tokenLabel access-token read failed [$failureCode]."
      $publicError = [System.Management.Automation.ErrorRecord]::new(
        [System.InvalidOperationException]::new($errorMessage),
        $failureCode, [System.Management.Automation.ErrorCategory]::InvalidOperation, $null)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -ErrorRecord $publicError -Tag 'bws-token'
      $PSCmdlet.ThrowTerminatingError($publicError)
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn" -Tag 'bws-token'
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed' -Tag 'bws-token'
  }
}
