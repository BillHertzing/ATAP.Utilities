<#
.SYNOPSIS
Validates and, if needed, renews the User-scope BW_SESSION for the current account.

.DESCRIPTION
Refresh-BWSession is the periodic refresh counterpart to
Initialize-ServiceAccountBitwardenSession. It is registered as a per-service-account
Task Scheduler job that runs on a recurring trigger (typically every hour).

Behavior:
1. Reads BW_SESSION from process scope; falls back to User scope.
2. Calls `bw unlock --check --session $token`. If the vault is still unlocked, exits
   success without touching credentials.
3. Otherwise, decrypts the DPAPI login + unlock credential files in the configured
   credential directory, performs the full `bw login` (if needed) + `bw unlock --raw
   --passwordfile <temp>` sequence, deletes the temp file in a finally block, and
   rewrites the User-scope BW_SESSION.

The script never logs secret values. It logs each phase via PSFramework and writes
verbose/error events to the Application Event Log (source `ATAPServiceAccountBW`).

.PARAMETER CredentialDirectory
Absolute path to the directory holding the service account's DPAPI credential files.
Required.

.PARAMETER ForceReunlock
Switch. When set, skip the `bw unlock --check` short-circuit and always re-unlock.
Useful immediately after `Update-ServiceAccountBWCredentialFile` or for monitoring
drills.

.OUTPUTS
PSCustomObject with Success (bool), RefreshPerformed (bool), and Message (string).

.EXAMPLE
Refresh-BWSession -CredentialDirectory 'C:\ProgramData\ATAP\BitwardenCredentials\SvcBuildmaster'

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Refresh-BWSession {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$CredentialDirectory,

    [Parameter(Mandatory = $false)]
    [switch]$ForceReunlock
  )

  BEGIN {
    $fn = 'Refresh-BWSession'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    Set-PSFLoggingProvider -Name logfile `
      -Enabled $true `
      -FilePath 'C:\Temp\PSFramework\Logs\service-account-bw-refresh.log' `
      -IncludeTags 'serviceaccount-bw' -ErrorAction SilentlyContinue

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started' -Tag 'serviceaccount-bw'

    if (-not (Get-Command -Name 'Get-BitWardenCredential' -CommandType Function -ErrorAction SilentlyContinue)) {
      # Resolve sibling module path relative to this script (works in worktree + stable).
      $siblingGetBWCred = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\ATAP.Utilities.Security.Powershell\public\Get-BitWardenCredential.ps1') -ErrorAction Stop
      . $siblingGetBWCred.ProviderPath
    }
    if (-not (Get-Command -Name 'Initialize-ServiceAccountBitwardenSession' -CommandType Function -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot 'Initialize-ServiceAccountBitwardenSession.ps1')
    }
  }

  PROCESS {
    try {
      # 0. Defensively clear OPENSSL_CONF / OPENSSL_HOME / RANDFILE from the
      #    process environment before invoking bw.exe — see the same block in
      #    Initialize-ServiceAccountBitwardenSession.ps1 for full rationale.
      foreach ($v in @('OPENSSL_CONF','OPENSSL_HOME','RANDFILE')) {
        if (Test-Path -LiteralPath "Env:$v") {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Clearing inherited Process env '$v' before bw invocation" -Tag 'serviceaccount-bw'
          Remove-Item -LiteralPath "Env:$v" -Force -ErrorAction SilentlyContinue
        }
      }

      # 1. Resolve current session.
      $bwSession = $env:BW_SESSION
      if ([string]::IsNullOrWhiteSpace($bwSession)) {
        $bwSession = [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'User')
        if (-not [string]::IsNullOrWhiteSpace($bwSession)) {
          $env:BW_SESSION = $bwSession
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'BW_SESSION resolved from User scope' -Tag 'serviceaccount-bw'
        }
      }

      # 2. If a session exists and we're not forcing, check whether it's still valid.
      if (-not $ForceReunlock -and -not [string]::IsNullOrWhiteSpace($bwSession)) {
        $bwCheckOutput = & bw unlock --check --session $bwSession 2>&1
        $bwCheckExit = $LASTEXITCODE
        if ($bwCheckExit -eq 0) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'BW_SESSION is still valid; no refresh needed' -Tag 'serviceaccount-bw'
          return [PSCustomObject]@{
            Success          = $true
            RefreshPerformed = $false
            Message          = 'BW_SESSION still valid; no refresh performed'
          }
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "bw unlock --check returned exit $bwCheckExit; re-unlocking" -Tag 'serviceaccount-bw'
      }

      # 3. Re-unlock by delegating to Initialize-ServiceAccountBitwardenSession.
      if ($PSCmdlet.ShouldProcess('Bitwarden vault', 'Re-unlock and rewrite User-scope BW_SESSION')) {
        $initResult = Initialize-ServiceAccountBitwardenSession -CredentialDirectory $CredentialDirectory
        if ($initResult.Success) {
          return [PSCustomObject]@{
            Success          = $true
            RefreshPerformed = $true
            Message          = "Refresh succeeded: $($initResult.Message)"
          }
        }
        else {
          return [PSCustomObject]@{
            Success          = $false
            RefreshPerformed = $true
            Message          = "Refresh failed: $($initResult.Message)"
          }
        }
      }
    }
    catch {
      $errorMessage = "Refresh-BWSession failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'serviceaccount-bw'
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn" -Tag 'serviceaccount-bw'
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed' -Tag 'serviceaccount-bw'
  }
}

# ============================================================================
# Script execution block — fires when invoked via `pwsh -File`
# ============================================================================

if ($MyInvocation.InvocationName -ne '.') {
  if (-not [System.Diagnostics.EventLog]::SourceExists('ATAPServiceAccountBW')) {
    try { New-EventLog -LogName Application -Source 'ATAPServiceAccountBW' } catch { }
  }

  $cliBound = @{}
  for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -match '^-(\w+)$') {
      $name = $Matches[1]
      $next = if ($i + 1 -lt $args.Count) { $args[$i + 1] } else { $null }
      if ($next -and $next -notmatch '^-\w+$') { $cliBound[$name] = $next; $i++ } else { $cliBound[$name] = $true }
    }
  }

  try {
    $result = Refresh-BWSession @cliBound
    $eventId = if ($result.Success) { 3010 } else { 3012 }
    $entryType = if ($result.Success) { 'Information' } else { 'Error' }
    try {
      Write-EventLog -LogName Application -Source 'ATAPServiceAccountBW' -EntryType $entryType `
        -EventId $eventId -Message "Refresh-BWSession (refreshed=$($result.RefreshPerformed)): $($result.Message)"
    } catch { }
  }
  catch {
    try {
      Write-EventLog -LogName Application -Source 'ATAPServiceAccountBW' -EntryType Error `
        -EventId 3013 -Message "Refresh-BWSession crashed: $($_.Exception.Message)"
    } catch { }
  }
}
