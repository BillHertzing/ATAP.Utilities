function Resolve-DabMcpConnectionString {
  <#
  .SYNOPSIS
    Resolves one DAB connection string from Bitwarden Secrets Manager, serialized across
    concurrently starting MCP connectors and retried only on the service's rate-limit reply.
  .DESCRIPTION
    An agent harness starts every catalogued DAB connector at once, and each one resolves its
    own connection-string secret. Bitwarden Secrets Manager answers the burst with
    "[429 Too Many Requests] Slow down!" and several connectors die at startup (Task 15.196.l,
    corrected root cause: shared-quota contention, not per-connector misconfiguration).

    Two controls, both bounded:
    - A session-local named mutex serializes the resolutions, so ten connectors make ten
      spaced calls instead of one burst. Waiting for the mutex is capped by -MutexTimeout.
    - When the reply is still the rate-limit signature, the call is retried with a capped
      exponential delay. Any other failure is rethrown unchanged on the first attempt: a
      missing secret or a bad token is not a contention symptom and must not be masked.

    The value is returned to the caller and never logged; log lines carry only the
    SecretName, attempt number, and delay.
  .PARAMETER SecretName
    Bitwarden SecretName to resolve.
  .PARAMETER MaximumAttempts
    Total attempts including the first (default 5).
  .PARAMETER InitialRetryDelay
    Delay before the second attempt; doubles each retry (default 1 s), capped at -MaximumRetryDelay.
  .PARAMETER MaximumRetryDelay
    Ceiling for one retry delay (default 8 s).
  .PARAMETER MutexTimeout
    Longest wait for the serialization mutex before resolving unserialized (default 45 s).
  .OUTPUTS
    System.String — the resolved connection string.
  .EXAMPLE
    Resolve-DabMcpConnectionString -SecretName 'dbConnectionString.ATAPUtilities.utat01.Exp.whertzing'
  .NOTES
    Task 15.196.l item (1). Function-only file; no top-level executable code.
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $SecretName,

    [ValidateRange(1, 10)]
    [int] $MaximumAttempts = 5,

    [ValidateRange(0, 60)]
    [double] $InitialRetryDelaySeconds = 1,

    [ValidateRange(0, 120)]
    [double] $MaximumRetryDelaySeconds = 8,

    [ValidateRange(0, 600)]
    [double] $MutexTimeoutSeconds = 45
  )

  begin {
    $fn = 'Resolve-DabMcpConnectionString'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    $rateLimitPattern = '429|Too Many Requests|Slow down'
  }

  process {
    $mutex = $null
    $owned = $false
    try {
      # Local\ scopes the mutex to this logon session, which is where the agent's connectors
      # all live. A stale abandoned mutex from a killed connector is still acquirable.
      try {
        $mutex = [System.Threading.Mutex]::new($false, 'Local\ATAP.DabMcp.BwsSecretResolution')
        try {
          $owned = $mutex.WaitOne([TimeSpan]::FromSeconds($MutexTimeoutSeconds))
        } catch [System.Threading.AbandonedMutexException] {
          $owned = $true
        }
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Secret-resolution mutex unavailable; resolving '$SecretName' unserialized. $($_.Exception.Message)"
      }
      if (-not $owned -and $null -ne $mutex) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Secret-resolution mutex not acquired within ${MutexTimeoutSeconds}s; resolving '$SecretName' unserialized."
      }

      $delay = $InitialRetryDelaySeconds
      for ($attempt = 1; $attempt -le $MaximumAttempts; $attempt++) {
        try {
          $value = Get-SecretATAP -SecretName $SecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
          if ([string]::IsNullOrWhiteSpace($value)) {
            throw "BWS returned an empty connection string for '$SecretName'."
          }
          return [string]$value
        } catch {
          $message = $_.Exception.Message
          if ($message -notmatch $rateLimitPattern -or $attempt -ge $MaximumAttempts) {
            throw
          }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "BWS rate-limited resolving '$SecretName' (attempt $attempt of $MaximumAttempts); retrying in ${delay}s."
          Start-Sleep -Milliseconds ([int]($delay * 1000))
          $delay = [Math]::Min($delay * 2, $MaximumRetryDelaySeconds)
        }
      }
    }
    finally {
      if ($owned -and $null -ne $mutex) { try { $mutex.ReleaseMutex() } catch { } }
      if ($null -ne $mutex) { $mutex.Dispose() }
    }
  }
}
