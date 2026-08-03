<#
.SYNOPSIS
  Disables a SEQ GELF (UDP) PSFramework logging instance.
.DESCRIPTION
  Task 14.62. Enable-SeqGelfLogging previously had no counterpart: the machine profile
  turned the sink on for every non-SSH shell and nothing could turn it off, so a shell that
  should not ship telemetry (an offline host, a noisy loop, a diagnostic session) had to
  reach into PSFramework internals or restart.

  This disables the named instance and leaves the provider registered. That is deliberate:
  provider registration is process-wide and idempotent, so keeping it costs nothing and
  makes a later Enable a cheap toggle rather than a re-registration.

  Flushing is deliberate too. PSFramework's logging runspace is asynchronous, so messages
  already queued would be discarded when the instance stops. -Flush (the default) waits for
  the queue to drain first; -Flush:$false skips the wait when you want the sink off now and
  do not care about in-flight messages.

  Disabling an instance that is not enabled, or that never existed, is a no-op that reports
  WasEnabled = $false rather than throwing - so this is safe in profile teardown and in
  scripts that cannot know the current state.
.PARAMETER InstanceName
  PSFramework logging-provider instance name to disable. Defaults to 'SendToSEQ'.
.PARAMETER Flush
  Wait for queued messages to drain before disabling. Defaults to $true. Use -Flush:$false
  to stop immediately and discard whatever is still queued.
.PARAMETER FlushTimeoutSeconds
  Maximum seconds to wait for the queue to drain when flushing. Defaults to 5.
.OUTPUTS
  PSCustomObject with ProviderName, InstanceName, WasEnabled, Enabled, Flushed, and Notes.
.EXAMPLE
  Disable-SeqGelfLogging

  Flushes queued messages, then disables the SendToSEQ instance.
.EXAMPLE
  Disable-SeqGelfLogging -Flush:$false

  Stops shipping immediately, discarding anything still queued.
.NOTES
  Does NOT require the PSGELF module: turning the sink off must work on a host where the
  transport was never installed.
.LINK
  https://github.com/datalust/seq-input-gelf
#>
function Disable-SeqGelfLogging {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $InstanceName = 'SendToSEQ',

    [Parameter(ValueFromPipelineByPropertyName = $true)]
    [bool] $Flush = $true,

    [Parameter(ValueFromPipelineByPropertyName = $true)]
    [ValidateRange(0, 300)]
    [int] $FlushTimeoutSeconds = 5
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.GELFLogging.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function'
  }

  process {
    try {
      $notes = @()

      if (-not (Get-PSFLoggingProvider -Name 'gelfudp' -ErrorAction SilentlyContinue)) {
        # Never registered in this session: nothing is shipping, so report rather than throw.
        $notes += "Logging provider 'gelfudp' is not registered in this session; nothing to disable."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $notes[-1]
        return [PSCustomObject]@{
          ProviderName = 'gelfudp'
          InstanceName = $InstanceName
          WasEnabled   = $false
          Enabled      = $false
          Flushed      = $false
          Notes        = ($notes -join ' | ')
        }
      }

      $providerInstance = Get-PSFLoggingProviderInstance -ProviderName 'gelfudp' -Name $InstanceName -ErrorAction SilentlyContinue
      $wasEnabled = [bool]($providerInstance -and $providerInstance.Enabled)

      if (-not $wasEnabled) {
        $notes += "Instance '$InstanceName' is not enabled; nothing to disable."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $notes[-1]
        return [PSCustomObject]@{
          ProviderName = 'gelfudp'
          InstanceName = $InstanceName
          WasEnabled   = $false
          Enabled      = $false
          Flushed      = $false
          Notes        = ($notes -join ' | ')
        }
      }

      if (-not $PSCmdlet.ShouldProcess($InstanceName, "Disable PSFramework 'gelfudp' logging instance")) {
        return
      }

      $flushed = $false
      if ($Flush) {
        # Drain BEFORE disabling: once the instance stops, anything still queued for it is
        # dropped without a diagnostic.
        $null = Wait-PSFMessage -Timeout $FlushTimeoutSeconds
        $flushed = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Flushed queued messages (timeout ${FlushTimeoutSeconds}s) before disabling '$InstanceName'."
      } else {
        $notes += 'Flush skipped by caller; messages still queued for this instance were discarded.'
      }

      Set-PSFLoggingProvider -Name 'gelfudp' -InstanceName $InstanceName -Enabled $false
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Disabled 'gelfudp' instance '$InstanceName'."

      $afterInstance = Get-PSFLoggingProviderInstance -ProviderName 'gelfudp' -Name $InstanceName -ErrorAction SilentlyContinue
      $stillEnabled = [bool]($afterInstance -and $afterInstance.Enabled)
      if ($stillEnabled) {
        $notes += "PSFramework still reports instance '$InstanceName' as enabled after the disable call."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message $notes[-1]
      }

      return [PSCustomObject]@{
        ProviderName = 'gelfudp'
        InstanceName = $InstanceName
        WasEnabled   = $true
        Enabled      = $stillEnabled
        Flushed      = $flushed
        Notes        = ($notes -join ' | ')
      }
    } catch {
      $errorMessage = "Failed to disable SEQ GELF (UDP) logging instance '$InstanceName'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving PROCESS block'
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function'
  }
}
