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
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started' -Tag 'bws-token'

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
  }

  PROCESS {
    try {
      $resolvedTokenPath = $tokenPath
      if (-not (Test-Path -LiteralPath $resolvedTokenPath)) {
        if ($TokenPurpose -eq 'ReadOnly' -and (Test-Path -LiteralPath $legacyTokenPath)) {
          $resolvedTokenPath = $legacyTokenPath
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Using legacy BWS ReadOnly access-token file '$legacyTokenPath'. Re-provision CommonCIForBitwardenReadOnly with Initialize-BWSAccessToken -TokenPurpose ReadOnly." -Tag 'bws-token', 'migration'
        }
        else {
          $msg = "BWS $TokenPurpose access-token file for $tokenLabel not found at '$tokenPath'. Create and ACL the folder with Initialize-BWSCredentialDirectory, then provision the token with Initialize-BWSAccessToken -TokenPurpose $TokenPurpose (see NewComputerSetup.md section 9.4.10)."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'bws-token'
          throw $msg
        }
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Loading BWS $TokenPurpose access token from '$resolvedTokenPath'" -Tag 'bws-token'
      $credential = Import-Clixml -LiteralPath $resolvedTokenPath -ErrorAction Stop
      return $credential
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Get-BWSAccessToken failed. Exception: $($_.Exception.Message)" -Tag 'bws-token'
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn" -Tag 'bws-token'
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed' -Tag 'bws-token'
  }
}
