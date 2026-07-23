<#
.SYNOPSIS
Stores a Bitwarden Secrets Manager (bws) access token as a DPAPI file.

.DESCRIPTION
Initialize-BWSAccessToken is the write side of the per-host, per-Windows-account Secrets
Manager credential. It must run as the account that will later read the token because
DPAPI binds the encrypted file to the user identity.

The token purpose controls which common CI machine token slot is written:
ReadOnly maps to CommonCIForBitwardenReadOnly, and ReadWrite maps to
CommonCIForBitwardenReadWrite. The files are written independently, so updating one slot
does not overwrite or back up the other slot.

Purpose-specific files are named
`<COMPUTERNAME>_<SamAccountName>_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml` and
`<COMPUTERNAME>_<SamAccountName>_BWS_CommonCIForBitwardenReadWrite_AccessToken.xml` in
the protected credential directory, storing the access token as the password of a
PSCredential whose UserName is the literal 'BWS_ACCESS_TOKEN'.

This is the Secrets Manager analogue of the Password-Manager Update-ServiceAccountBWCredentialFile.
Unlike the bw model there is no login, unlock, master password, or session; the access
token alone authorizes `bws` to read or mutate its granted projects.

.PARAMETER AccessToken
SecureString containing the machine-account access token (format `0.<uuid>.<secret>...`).
Required.

.PARAMETER CredentialDirectory
Absolute path to the protected credential folder. Defaults to
`C:\ProgramData\ATAP\BitwardenCredentials\<SamAccountName>`.

.PARAMETER TokenPurpose
Selects the BWS common CI token slot to write. ReadOnly maps to
CommonCIForBitwardenReadOnly and is the default. ReadWrite maps to
CommonCIForBitwardenReadWrite and should be provisioned only for accounts that perform
secret provisioning, mutation, deletion, or rotation.

.OUTPUTS
PSCustomObject with Success (bool), Path (string), TokenPurpose (string), TokenLabel
(string), and Message (string).

.EXAMPLE
$tok = Read-Host 'CommonCIForBitwardenReadOnly token' -AsSecureString
Initialize-BWSAccessToken -AccessToken $tok -TokenPurpose ReadOnly

Writes the default read-only DPAPI token file.

.EXAMPLE
$tok = Read-Host 'CommonCIForBitwardenReadWrite token' -AsSecureString
Initialize-BWSAccessToken -AccessToken $tok -TokenPurpose ReadWrite

Writes the read/write DPAPI token file for provisioning, mutation, deletion, or rotation.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Must run as the owning Windows account itself (DPAPI is user-bound).

.LINK
https://bitwarden.com/help/secrets-manager-cli/

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Initialize-BWSAccessToken {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [Alias('Initialize-ServiceAccountBWSAccessToken')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNull()]
    [System.Security.SecureString]$AccessToken,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$CredentialDirectory,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet('ReadOnly', 'ReadWrite')]
    [string]$TokenPurpose = 'ReadOnly'
  )

  BEGIN {
    $fn = 'Initialize-BWSAccessToken'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started' -Tag 'bws-token'

    $tokenLabelByPurpose = @{
      ReadOnly = 'CommonCIForBitwardenReadOnly'
      ReadWrite = 'CommonCIForBitwardenReadWrite'
    }
    $tokenLabel = $tokenLabelByPurpose[$TokenPurpose]

    # Derive the account token from the running Windows identity (not $env:USERNAME) so
    # the filename matches the DPAPI key even under Start-Process -Credential / -NoProfile.
    $currentSamName = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\') | Select-Object -Last 1
    if ([string]::IsNullOrWhiteSpace($CredentialDirectory)) {
      $CredentialDirectory = "C:\ProgramData\ATAP\BitwardenCredentials\$currentSamName"
    }
    $tokenFileName = "$env:COMPUTERNAME`_$currentSamName`_BWS_$tokenLabel`_AccessToken.xml"
    $tokenPath = Join-Path $CredentialDirectory $tokenFileName
  }

  PROCESS {
    try {
      if (-not (Test-Path -LiteralPath $CredentialDirectory -PathType Container)) {
        $msg = "CredentialDirectory '$CredentialDirectory' does not exist. Create and ACL it first with Initialize-BWSCredentialDirectory (see NewComputerSetup.md section 9.4.10)."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'bws-token'
        return [PSCustomObject]@{
          Success = $false
          Path = $tokenPath
          TokenPurpose = $TokenPurpose
          TokenLabel = $tokenLabel
          Message = $msg
        }
      }

      if ($PSCmdlet.ShouldProcess($tokenPath, "Write DPAPI BWS $TokenPurpose access-token file")) {
        if (Test-Path -LiteralPath $tokenPath) {
          $backupPath = "$tokenPath.$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
          Copy-Item -LiteralPath $tokenPath -Destination $backupPath -Force -ErrorAction Stop
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Backed up existing $TokenPurpose token to '$backupPath'" -Tag 'bws-token'
        }

        $credential = New-Object System.Management.Automation.PSCredential('BWS_ACCESS_TOKEN', $AccessToken)
        $credential | Export-Clixml -LiteralPath $tokenPath -ErrorAction Stop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Saved DPAPI BWS $TokenPurpose access token for $tokenLabel to '$tokenPath'" -Tag 'bws-token'
        return [PSCustomObject]@{
          Success = $true
          Path = $tokenPath
          TokenPurpose = $TokenPurpose
          TokenLabel = $tokenLabel
          Message = "BWS $TokenPurpose access token stored"
        }
      }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Initialize-BWSAccessToken failed. Exception: $($_.Exception.Message)" -Tag 'bws-token'
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
