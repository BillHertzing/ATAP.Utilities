<#
.SYNOPSIS
Replaces the DPAPI Bitwarden credential files for a Windows service account.

.DESCRIPTION
Update-ServiceAccountBWCredentialFile is the rotation function that re-keys the
per-(host, service-account) DPAPI credential files when any of these change:

  - the Bitwarden login password
  - the Bitwarden master/unlock password
  - the service account's Windows password (DPAPI key is re-derived on next logon,
    invalidating existing files)
  - the host (credential files do not migrate across machines)

The function wraps `Get-BitWardenCredential -Replace` and adds:
  - explicit security context guard (the current user must equal -ServiceAccount,
    otherwise DPAPI binds the new files to the wrong identity)
  - SecureString parameter shape so the new Bitwarden passwords never live as
    plain-text shell history
  - structured PSCustomObject result for logging and downstream automation

After the credential files are rewritten, immediately trigger
Refresh-BWSession -ForceReunlock so the live BW_SESSION reflects the new credentials.

.PARAMETER ServiceAccount
Local Windows account name that owns the credential files (e.g. 'SvcBuildmaster').
Required. Must match $env:USERNAME at runtime.

.PARAMETER CredentialDirectory
Absolute path to the protected credential folder. Defaults to
`C:\ProgramData\ATAP\BitwardenCredentials\<ServiceAccount>\`.

.PARAMETER BitwardenUserName
Bitwarden login email bound to the service account. Required.

.PARAMETER BitWardenLoginPassword
SecureString containing the new Bitwarden login password. Required.

.PARAMETER BitWardenUnlockPassword
SecureString containing the new Bitwarden master/unlock password. Required.

.PARAMETER NoRefresh
Switch. Skip the post-rotation Refresh-BWSession step. Use when the live session must
be manually reset later (e.g. when the operator will reboot the host).

.OUTPUTS
PSCustomObject with fields:
  - ServiceAccount      : the local account name
  - CredentialDirectory : absolute path to the credential folder
  - Replaced            : [bool] whether -Replace was honored
  - BackupFiles         : array of *.bak file paths created by Get-BitWardenCredential
  - SessionRefreshed    : [bool] whether the post-rotation Refresh-BWSession ran
  - Success             : [bool]
  - Message             : human-readable summary

.EXAMPLE
$login = Read-Host 'New BW login password' -AsSecureString
$unlock = Read-Host 'New BW master password' -AsSecureString
Update-ServiceAccountBWCredentialFile -ServiceAccount 'SvcBuildmaster' `
  -BitwardenUserName 'buildmaster@example.com' `
  -BitWardenLoginPassword $login -BitWardenUnlockPassword $unlock

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Must run as the owning service account itself (DPAPI is user-bound).

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Update-ServiceAccountBWCredentialFile {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$ServiceAccount,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$CredentialDirectory,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$BitwardenUserName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [System.Security.SecureString]$BitWardenLoginPassword,

    [Parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [System.Security.SecureString]$BitWardenUnlockPassword,

    [Parameter(Mandatory = $false)]
    [switch]$NoRefresh
  )

  BEGIN {
    $fn = 'Update-ServiceAccountBWCredentialFile'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    if (-not (Get-Command -Name 'Get-BitWardenCredential' -CommandType Function -ErrorAction SilentlyContinue)) {
      Import-ATAPModuleFromProGet -ModuleName 'ATAP.Utilities.Security.Powershell' -RequiredCommand 'Get-BitWardenCredential'
    }
    if (-not (Get-Command -Name 'Refresh-BWSession' -CommandType Function -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot 'Refresh-BWSession.ps1')
    }

    if ([string]::IsNullOrWhiteSpace($CredentialDirectory)) {
      $CredentialDirectory = "C:\ProgramData\ATAP\BitwardenCredentials\$ServiceAccount"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Defaulted CredentialDirectory to '$CredentialDirectory'"
    }
  }

  PROCESS {
    try {
      # 1. Security guard: the running process's security identity must equal
      #    -ServiceAccount, else DPAPI will encrypt the new files for the wrong identity.
      #    Use WindowsIdentity (not $env:USERNAME) because env vars are inherited from
      #    the launching process and do not refresh when Start-Process -Credential
      #    switches the security token, especially under -NoProfile.
      $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
      $currentSamName = ($currentIdentity -split '\\') | Select-Object -Last 1
      if ($currentSamName -ne $ServiceAccount) {
        $msg = "Update-ServiceAccountBWCredentialFile must run AS the service account '$ServiceAccount'. Current Windows identity is '$currentIdentity'. Relaunch with Start-Process -Credential (or psexec/Task Scheduler) running as '$ServiceAccount'."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Running as Windows identity '$currentIdentity' — guard passed"

      # 2. Verify the credential directory exists and is writable.
      if (-not (Test-Path -LiteralPath $CredentialDirectory -PathType Container)) {
        $msg = "CredentialDirectory '$CredentialDirectory' does not exist. Create + ACL it first (see NewComputerSetup.md §9.4.1)."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }

      # 3. Capture pre-rotation .bak set so we can report which backups Get-BitWardenCredential added.
      $preExistingBaks = @(Get-ChildItem -LiteralPath $CredentialDirectory -Filter '*.bak' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)

      if ($PSCmdlet.ShouldProcess("$ServiceAccount @ $CredentialDirectory", 'Rotate DPAPI Bitwarden credential files')) {
        # 4. Decode SecureStrings to plain text only for the duration of the call.
        $loginPlain = [System.Net.NetworkCredential]::new('', $BitWardenLoginPassword).Password
        $unlockPlain = [System.Net.NetworkCredential]::new('', $BitWardenUnlockPassword).Password

        try {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Calling Get-BitWardenCredential -Replace for '$ServiceAccount'"
          $null = Get-BitWardenCredential `
            -CredentialDirectory $CredentialDirectory `
            -BitWardenUserName $BitwardenUserName `
            -BitWardenLoginPassword $loginPlain `
            -BitWardenUnlockPassword $unlockPlain `
            -Replace
        }
        finally {
          $loginPlain = $null
          $unlockPlain = $null
        }

        # 5. Identify newly created .bak files.
        $postBaks = @(Get-ChildItem -LiteralPath $CredentialDirectory -Filter '*.bak' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
        $newBaks = @($postBaks | Where-Object { $_ -notin $preExistingBaks })

        # 6. Trigger a forced session refresh so the running service picks up the new credentials.
        $sessionRefreshed = $false
        if (-not $NoRefresh) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Forcing BW session refresh against rotated credential files'
          $refreshResult = Refresh-BWSession -CredentialDirectory $CredentialDirectory -ForceReunlock
          $sessionRefreshed = [bool]$refreshResult.Success
          if (-not $sessionRefreshed) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Post-rotation Refresh-BWSession failed: $($refreshResult.Message)"
          }
        }

        return [PSCustomObject]@{
          ServiceAccount      = $ServiceAccount
          CredentialDirectory = $CredentialDirectory
          Replaced            = $true
          BackupFiles         = $newBaks
          SessionRefreshed    = $sessionRefreshed
          Success             = ($NoRefresh -or $sessionRefreshed)
          Message             = if ($NoRefresh) {
            "Credentials rotated for '$ServiceAccount'. -NoRefresh set; live BW_SESSION not updated."
          }
          elseif ($sessionRefreshed) {
            "Credentials rotated for '$ServiceAccount' and BW_SESSION refreshed."
          }
          else {
            "Credentials rotated for '$ServiceAccount' but BW_SESSION refresh FAILED. Investigate immediately."
          }
        }
      }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Update-ServiceAccountBWCredentialFile failed for '$ServiceAccount'. Exception: $($_.Exception.Message)"
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
