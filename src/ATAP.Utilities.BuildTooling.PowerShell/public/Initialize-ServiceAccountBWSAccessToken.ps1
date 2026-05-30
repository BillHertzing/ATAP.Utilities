<#
.SYNOPSIS
Stores a Bitwarden Secrets Manager (bws) machine-account access token as a DPAPI file.

.DESCRIPTION
Initialize-ServiceAccountBWSAccessToken is the write side of the per-host, per-service-account
Secrets Manager credential. It must run **as the owning service account** (Task Scheduler
'Run As', or Start-Process -Credential) because DPAPI binds the encrypted file to the user
identity. It writes `<COMPUTERNAME>_<SamAccountName>_BWS_AccessToken.xml` into the protected
credential directory, storing the access token as the password of a PSCredential whose
UserName is the literal 'BWS_ACCESS_TOKEN'.

This is the Secrets Manager analogue of the Password-Manager Update-ServiceAccountBWCredentialFile.
Unlike the bw model there is no login, unlock, master password, or session — the access
token alone authorizes `bws` to read the machine account's projects.

.PARAMETER AccessToken
SecureString containing the machine-account access token (format `0.<uuid>.<secret>...`).
Required.

.PARAMETER CredentialDirectory
Absolute path to the protected credential folder. Defaults to
`C:\ProgramData\ATAP\BitwardenCredentials\<SamAccountName>`.

.OUTPUTS
PSCustomObject with Success (bool), Path (string), and Message (string).

.EXAMPLE
$tok = Read-Host 'BWS access token' -AsSecureString
Initialize-ServiceAccountBWSAccessToken -AccessToken $tok

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Must run as the owning service account itself (DPAPI is user-bound).

.LINK
https://bitwarden.com/help/secrets-manager-cli/

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Initialize-ServiceAccountBWSAccessToken {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNull()]
    [System.Security.SecureString]$AccessToken,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$CredentialDirectory
  )

  BEGIN {
    $fn = 'Initialize-ServiceAccountBWSAccessToken'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started' -Tag 'serviceaccount-bws'

    # Derive the account token from the running Windows identity (not $env:USERNAME) so
    # the filename matches the DPAPI key even under Start-Process -Credential / -NoProfile.
    $currentSamName = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\') | Select-Object -Last 1
    if ([string]::IsNullOrWhiteSpace($CredentialDirectory)) {
      $CredentialDirectory = "C:\ProgramData\ATAP\BitwardenCredentials\$currentSamName"
    }
    $tokenFileName = "$env:COMPUTERNAME`_$currentSamName`_BWS_AccessToken.xml"
    $tokenPath = Join-Path $CredentialDirectory $tokenFileName
  }

  PROCESS {
    try {
      if (-not (Test-Path -LiteralPath $CredentialDirectory -PathType Container)) {
        $msg = "CredentialDirectory '$CredentialDirectory' does not exist. Create + ACL it first (see NewComputerSetup.md section 9.4.1)."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'serviceaccount-bws'
        return [PSCustomObject]@{ Success = $false; Path = $tokenPath; Message = $msg }
      }

      if ($PSCmdlet.ShouldProcess($tokenPath, 'Write DPAPI BWS access-token file')) {
        if (Test-Path -LiteralPath $tokenPath) {
          $backupPath = "$tokenPath.$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
          Copy-Item -LiteralPath $tokenPath -Destination $backupPath -Force -ErrorAction Stop
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Backed up existing token to '$backupPath'" -Tag 'serviceaccount-bws'
        }

        $credential = New-Object System.Management.Automation.PSCredential('BWS_ACCESS_TOKEN', $AccessToken)
        $credential | Export-Clixml -LiteralPath $tokenPath -ErrorAction Stop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Saved DPAPI BWS access token to '$tokenPath'" -Tag 'serviceaccount-bws'
        return [PSCustomObject]@{ Success = $true; Path = $tokenPath; Message = 'BWS access token stored' }
      }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Initialize-ServiceAccountBWSAccessToken failed. Exception: $($_.Exception.Message)" -Tag 'serviceaccount-bws'
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn" -Tag 'serviceaccount-bws'
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed' -Tag 'serviceaccount-bws'
  }
}
