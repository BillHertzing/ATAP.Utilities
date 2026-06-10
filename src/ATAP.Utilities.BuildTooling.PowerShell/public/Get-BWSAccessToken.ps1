<#
.SYNOPSIS
Reads the DPAPI-protected Bitwarden Secrets Manager (bws) access token for the running account.

.DESCRIPTION
Get-BWSAccessToken loads the DPAPI-encrypted `BWS_AccessToken` credential file for the
current Windows identity and returns it as a PSCredential whose password is the BWS access
token. It is the read side of Initialize-BWSAccessToken.

The file is named `<COMPUTERNAME>_<SamAccountName>_BWS_AccessToken.xml` and lives in the
account's protected credential directory. DPAPI binds the file to the user identity, so it
can only be decrypted by the same account on the same host. The SAM name is derived from
[WindowsIdentity]::GetCurrent() (not $env:USERNAME) so it is correct even when the process
was launched with Start-Process -Credential under -NoProfile.

.PARAMETER CredentialDirectory
Absolute path to the directory holding the DPAPI token file. Defaults to
`C:\ProgramData\ATAP\BitwardenCredentials\<SamAccountName>`.

.OUTPUTS
System.Management.Automation.PSCredential
UserName is the literal 'BWS_ACCESS_TOKEN'; Password is the access token.

.EXAMPLE
$cred = Get-BWSAccessToken
$env:BWS_ACCESS_TOKEN = $cred.GetNetworkCredential().Password

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
  [OutputType([System.Management.Automation.PSCredential])]
  param(
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$CredentialDirectory
  )

  BEGIN {
    $fn = 'Get-BWSAccessToken'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started' -Tag 'bws-token'

    $currentSamName = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\') | Select-Object -Last 1
    if ([string]::IsNullOrWhiteSpace($CredentialDirectory)) {
      $CredentialDirectory = "C:\ProgramData\ATAP\BitwardenCredentials\$currentSamName"
    }
    $tokenFileName = "$env:COMPUTERNAME`_$currentSamName`_BWS_AccessToken.xml"
    $tokenPath = Join-Path $CredentialDirectory $tokenFileName
  }

  PROCESS {
    try {
      if (-not (Test-Path -LiteralPath $tokenPath)) {
        $msg = "BWS access-token file not found at '$tokenPath'. Create and ACL the folder with Initialize-BWSCredentialDirectory, then provision the token with Initialize-BWSAccessToken (see NewComputerSetup.md section 9.4.10)."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'bws-token'
        throw $msg
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Loading BWS access token from '$tokenPath'" -Tag 'bws-token'
      $credential = Import-Clixml -LiteralPath $tokenPath -ErrorAction Stop
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
