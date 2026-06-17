# ============================================================================
# RETIRED (Task 9.21, Sprint 0009) — BW_SESSION / personal-vault machinery.
# This was part of the bw login/unlock/BW_SESSION service-account machinery that
# existed only to support reading/writing CI secrets from a personal Bitwarden
# Password Manager vault. CI/infrastructure secrets now live exclusively in
# Bitwarden Secrets Manager (bws + DPAPI machine access token via
# Get-BWSAccessToken / Initialize-BWSAccessToken). Moved out of public/ so it is
# no longer imported or exported. Any scheduled tasks that invoked this script
# should be removed as host-infrastructure cleanup. Kept here for history only.
# ============================================================================

<#
.SYNOPSIS
Establishes a Bitwarden session for a Windows service account at host startup.

.DESCRIPTION
Initialize-ServiceAccountBitwardenSession is the service-account analogue of
Initialize-BitwardenSession in LoginScript.ps1. It is registered as a per-service-account
Task Scheduler job that runs `At Startup` under the owning service account's identity.

The script:
1. Reads the DPAPI-encrypted login + unlock credential files for the running service
   account from the configured credential directory.
2. Writes the master/unlock password to a short-lived clear-text file inside the
   protected credential directory and calls `bw unlock --raw --passwordfile <path>`.
   The temp file is deleted in a finally block; the directory ACL ensures only the
   owning service account, SYSTEM, and Administrators can read it.
3. Writes the resulting `BW_SESSION` to the **User scope** for the service account so
   subsequent processes started as that account inherit a valid session.
4. Logs each phase via PSFramework and writes start/success/failure events to the
   Windows Application Event Log (source `ATAPServiceAccountBW`).

The script must be invoked **as the service account itself** (Task Scheduler 'Run As',
or `Start-Process -Credential` from an admin shell). DPAPI binds to the user identity,
so the credential files are unreadable from any other account.

.PARAMETER CredentialDirectory
Absolute path to the directory holding the service account's DPAPI credential files.
Conventional location:
  C:\ProgramData\ATAP\BitwardenCredentials\<ServiceAccount>\
Required.

.PARAMETER BitwardenUserName
Optional override for the Bitwarden login email. When omitted, the username is read
from the DPAPI login credential file.

.OUTPUTS
PSCustomObject with Success (bool) and Message (string) properties.

.EXAMPLE
Initialize-ServiceAccountBitwardenSession -CredentialDirectory 'C:\ProgramData\ATAP\BitwardenCredentials\SvcBuildmaster'

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Runs as the service account via Task Scheduler 'At Startup' trigger.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Initialize-ServiceAccountBitwardenSession {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$CredentialDirectory,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$BitwardenUserName
  )

  begin {
    $fn = 'Initialize-ServiceAccountBitwardenSession'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    Set-PSFLoggingProvider -Name logfile `
      -Enabled $true `
      -FilePath 'C:\Temp\PSFramework\Logs\service-account-bw-init.log' `
      -IncludeTags 'serviceaccount-bw' -ErrorAction SilentlyContinue

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started' -Tag 'serviceaccount-bw'

    if (-not (Get-Command -Name 'Get-BitWardenCredential' -CommandType Function -ErrorAction SilentlyContinue)) {
      Import-ATAPModuleFromProGet -ModuleName 'ATAP.Utilities.Security.Powershell' -RequiredCommand 'Get-BitWardenCredential'
    }
  }

  process {
    $tempPasswordFile = $null
    try {
      # 0. Defensively clear OPENSSL_CONF / OPENSSL_HOME / RANDFILE from the
      #    process environment before invoking bw.exe. The host's interactive
      #    profile points these into a per-user Dropbox folder that service
      #    accounts cannot read, which causes bw.exe's bundled OpenSSL to fail
      #    during init (BIO_new_file Input/output error). With these unset,
      #    bw.exe uses its internal defaults and works under any account.
      foreach ($v in @('OPENSSL_CONF', 'OPENSSL_HOME', 'RANDFILE')) {
        if (Test-Path -LiteralPath "Env:$v") {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Clearing inherited Process env '$v' before bw invocation" -Tag 'serviceaccount-bw'
          Remove-Item -LiteralPath "Env:$v" -Force -ErrorAction SilentlyContinue
        }
      }

      # 1. Verify the bw CLI is on PATH for this service account's session.
      $bwCommand = Get-Command -Name 'bw' -ErrorAction SilentlyContinue
      if (-not $bwCommand) {
        $msg = 'Bitwarden CLI (bw.exe) not found in PATH for the service account session.'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'serviceaccount-bw'
        return [PSCustomObject]@{ Success = $false; Message = $msg }
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "bw CLI found at: $($bwCommand.Source)" -Tag 'serviceaccount-bw'

      # 2. Verify the credential directory exists.
      if (-not (Test-Path -LiteralPath $CredentialDirectory -PathType Container)) {
        $msg = "CredentialDirectory '$CredentialDirectory' does not exist or is not a directory."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'serviceaccount-bw'
        return [PSCustomObject]@{ Success = $false; Message = $msg }
      }

      if ($PSCmdlet.ShouldProcess('Bitwarden vault', 'Login + unlock as service account, store session key in User scope')) {
        # 3. Read DPAPI-protected credentials. Running user must own these files.
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Reading DPAPI credentials from '$CredentialDirectory'" -Tag 'serviceaccount-bw'
        $credentials = Get-BitWardenCredential -CredentialDirectory $CredentialDirectory
        $loginCredential = $credentials['LoginCredential']
        $unlockCredential = $credentials['UnlockCredential']

        $loginEmail = if ([string]::IsNullOrWhiteSpace($BitwardenUserName)) { $loginCredential.UserName } else { $BitwardenUserName }
        $loginPassword = $loginCredential.GetNetworkCredential().Password
        $unlockPassword = $unlockCredential.GetNetworkCredential().Password

        # 4. Login if needed.
        $statusOutput = & bw status 2>&1
        $status = $null
        try { $status = $statusOutput | ConvertFrom-Json -ErrorAction Stop } catch { $status = $null }
        $isLoggedIn = $status -and $status.status -ne 'unauthenticated'

        if (-not $isLoggedIn) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Calling bw login for '$loginEmail'" -Tag 'serviceaccount-bw'
          $env:BW_PASSWORD = $loginPassword
          $loginOutput = & bw login $loginEmail --passwordenv BW_PASSWORD 2>&1
          $loginExit = $LASTEXITCODE
          Remove-Item Env:BW_PASSWORD -ErrorAction SilentlyContinue
          if ($loginExit -ne 0) {
            $msg = "bw login failed (exit $loginExit). Output: $loginOutput"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'serviceaccount-bw'
            return [PSCustomObject]@{ Success = $false; Message = $msg }
          }
        }

        # 5. Materialize the short-lived password file inside the protected credential
        #    directory. Pass it to bw via --passwordfile, then delete in finally block.
        $tempPasswordFile = Join-Path $CredentialDirectory ('.bw-unlock-' + ([guid]::NewGuid().ToString('N')) + '.tmp')
        Set-Content -LiteralPath $tempPasswordFile -Value $unlockPassword -NoNewline -Encoding utf8

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Calling bw unlock --raw with passwordfile' -Tag 'serviceaccount-bw'
        $sessionKey = & bw unlock --raw --passwordfile $tempPasswordFile 2>&1
        $unlockExit = $LASTEXITCODE

        $unlockPassword = $null
        $loginPassword = $null

        $sessionKeyStr = if ($sessionKey) { $sessionKey.ToString() } else { $null }

        if ($unlockExit -eq 0 -and -not [string]::IsNullOrWhiteSpace($sessionKeyStr)) {
          $env:BW_SESSION = $sessionKeyStr
          [System.Environment]::SetEnvironmentVariable('BW_SESSION', $sessionKeyStr, 'User')
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Bitwarden vault unlocked and BW_SESSION stored in User scope' -Tag 'serviceaccount-bw'
          return [PSCustomObject]@{ Success = $true; Message = 'BW_SESSION established for service account' }
        } else {
          $msg = "bw unlock failed (exit $unlockExit). Output: $sessionKeyStr"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'serviceaccount-bw'
          return [PSCustomObject]@{ Success = $false; Message = $msg }
        }
      }
    } catch {
      $errorMessage = "Initialize-ServiceAccountBitwardenSession failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'serviceaccount-bw'
      throw
    } finally {
      if ($tempPasswordFile -and (Test-Path -LiteralPath $tempPasswordFile)) {
        Remove-Item -LiteralPath $tempPasswordFile -Force -ErrorAction SilentlyContinue
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Removed temporary password file: $tempPasswordFile" -Tag 'serviceaccount-bw'
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn" -Tag 'serviceaccount-bw'
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed' -Tag 'serviceaccount-bw'
  }
}

# ============================================================================
# Script execution block — fires ONLY when this file is run as the top-level
# script (e.g. `pwsh -File`, the scheduled-task invocation). It is skipped on
# dot-source ('.'), module import, and the call operator ('&'), so merely
# loading or dot-sourcing this file never executes the function.
# ============================================================================

if (-not $MyInvocation.MyCommand.ScriptBlock.Module -and
  $MyInvocation.InvocationName -ne '.' -and
  $MyInvocation.InvocationName -ne '&') {
  $execFn = 'Initialize-ServiceAccountBitwardenSession-ExecutionBlock'
  $execMn = 'ATAP.Utilities.BuildTooling.PowerShell'

  if (-not [System.Diagnostics.EventLog]::SourceExists('ATAPServiceAccountBW')) {
    try { New-EventLog -LogName Application -Source 'ATAPServiceAccountBW' } catch { }
  }

  try {
    Write-EventLog -LogName Application -Source 'ATAPServiceAccountBW' -EntryType Information -EventId 3000 `
      -Message "Initialize-ServiceAccountBitwardenSession started for user '$env:USERNAME'"
  } catch { }

  $cliBound = @{}
  for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -match '^-(\w+)$') {
      $name = $Matches[1]
      $next = if ($i + 1 -lt $args.Count) { $args[$i + 1] } else { $null }
      if ($next -and $next -notmatch '^-\w+$') { $cliBound[$name] = $next; $i++ } else { $cliBound[$name] = $true }
    }
  }

  try {
    $result = Initialize-ServiceAccountBitwardenSession @cliBound
    $eventId = if ($result.Success) { 3001 } else { 3002 }
    $entryType = if ($result.Success) { 'Information' } else { 'Error' }
    try {
      Write-EventLog -LogName Application -Source 'ATAPServiceAccountBW' -EntryType $entryType `
        -EventId $eventId -Message "Initialize-ServiceAccountBitwardenSession result: $($result.Message)"
    } catch { }
  } catch {
    Write-PSFMessage -FunctionName $execFn -ModuleName $execMn -Level Error -Message "Critical error: $($_.Exception.Message)" -Tag 'serviceaccount-bw'
    try {
      Write-EventLog -LogName Application -Source 'ATAPServiceAccountBW' -EntryType Error `
        -EventId 3003 -Message "Initialize-ServiceAccountBitwardenSession crashed: $($_.Exception.Message)"
    } catch { }
  }
}
