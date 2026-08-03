<#
.SYNOPSIS
  Enables PSFramework logging to a SEQ GELF (UDP) ingestor.
.DESCRIPTION
  Enables a named instance of the 'gelfudp' PSFramework Version2 logging provider, pointed
  at the SEQ GELF input (Seq.Input.Gelf / sqelf, UDP, default udp://127.0.0.1:12201). The
  provider itself is registered on demand by the private Register-SeqGelfUdpProvider.

  Task 14.62 moved this function out of ATAP.Utilities.PowerShell into this dedicated child
  module and gave it an explicit counterpart, Disable-SeqGelfLogging, plus a read-only
  Get-SeqGelfLoggingStatus. Previously the machine profile called Enable unconditionally on
  every non-SSH shell with no supported way to turn the sink off again, and the only way to
  find out whether it was on was to read PSFramework internals.

  Conventions honored (Rules Compendium.PowerShell, GELF rule set): one named instance per
  sink, instance naming 'SendTo<Sink>' (default 'SendToSEQ').

  The SEQ API key is referenced by SecretName only (never a literal). When -VerifyDelivery
  is requested the key is resolved via Get-SecretATAP and passed to SEQ as the X-Seq-ApiKey
  token header to read back the emitted marker event. If the secret cannot be resolved the
  function reports delivery as unverified rather than failing.
.PARAMETER GelfServer
  Host name or IP of the GELF UDP ingestor. Defaults to 127.0.0.1 (local sqelf).
.PARAMETER Port
  UDP port of the GELF ingestor. Defaults to 12201.
.PARAMETER InstanceName
  PSFramework logging-provider instance name. Defaults to 'SendToSEQ' per the
  'SendTo<Sink>' convention.
.PARAMETER MinLevel
  Minimum PSFramework message level routed to this instance (1 = most important). Default 1.
.PARAMETER MaxLevel
  Maximum PSFramework message level routed to this instance (9 = debug). Default 9.
.PARAMETER SeqServerUrl
  Base URL of the SEQ server API, used only for -VerifyDelivery reads.
  Defaults to http://localhost:5341.
.PARAMETER SeqApiKeySecretName
  SecretName (resolved via Get-SecretATAP) of the SEQ API key used as the X-Seq-ApiKey
  token for -VerifyDelivery reads. Defaults to 'SEQ.Admin.API.Key'. Never pass a literal key.
.PARAMETER VerifyDelivery
  After enabling, emit a marker message, flush, and query the SEQ events API for it. Sets
  DeliveryVerified: $true (found), $false (queried but absent), or $null (could not query).
.PARAMETER SendTestMarker
  Emit the marker message without querying SEQ for it.
.OUTPUTS
  PSCustomObject with ProviderName, InstanceName, GelfServer, Port, Enabled,
  ProviderInitialized, TestMarker, DeliveryVerified, and Notes.
.EXAMPLE
  Enable-SeqGelfLogging

  Enables the SendToSEQ instance against udp://127.0.0.1:12201.
.EXAMPLE
  Enable-SeqGelfLogging -GelfServer utat022 -Port 12201 -VerifyDelivery

  Enables logging to a remote ingestor and verifies a marker event arrives in SEQ
  (requires the SEQ.Admin.API.Key secret to be resolvable via Get-SecretATAP).
.NOTES
  Requires the PSGELF module (the same dependency as the built-in 'gelf' provider).
  AI assisted using Powershell.instructions.md as guidelines (Task 12.19 / SC-0230).
.LINK
  https://github.com/datalust/seq-input-gelf
#>
function Enable-SeqGelfLogging {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $GelfServer = '127.0.0.1',

    [Parameter(Position = 1, ValueFromPipelineByPropertyName = $true)]
    [ValidateRange(1, 65535)]
    [int] $Port = 12201,

    [Parameter(ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $InstanceName = 'SendToSEQ',

    [Parameter(ValueFromPipelineByPropertyName = $true)]
    [ValidateRange(1, 9)]
    [int] $MinLevel = 1,

    [Parameter(ValueFromPipelineByPropertyName = $true)]
    [ValidateRange(1, 9)]
    [int] $MaxLevel = 9,

    [Parameter(ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $SeqServerUrl = 'http://localhost:5341',

    [Parameter(ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $SeqApiKeySecretName = 'SEQ.Admin.API.Key',

    [switch] $VerifyDelivery,

    [switch] $SendTestMarker
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.Powershell.GELFLogging'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function'

    # This is a logging bootstrap: it must work before $global:settings is populated, so
    # parameter defaults are plain values rather than Get-PVal lookups.
    Assert-PSGelfAvailable
  }

  process {
    try {
      $null = Register-SeqGelfUdpProvider

      if (-not $PSCmdlet.ShouldProcess("$($GelfServer):$($Port)", "Enable PSFramework 'gelfudp' logging instance '$InstanceName'")) {
        return
      }

      Set-PSFLoggingProvider -Name 'gelfudp' -InstanceName $InstanceName `
        -GelfServer $GelfServer -Port $Port `
        -MinLevel $MinLevel -MaxLevel $MaxLevel -Enabled $true
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Enabled 'gelfudp' instance '$InstanceName' -> udp://$($GelfServer):$($Port)"

      $testMarker = $null
      if ($SendTestMarker -or $VerifyDelivery) {
        # The logging instance starts asynchronously in the PSFramework logging runspace,
        # and messages logged before it finishes starting are NOT replayed to it (the
        # instance's Initialized property also lags well behind actual readiness, so it
        # cannot be polled as a readiness signal - verified 2026-07-04). Emit the marker
        # across two flush cycles so at least one emission lands after instance start.
        $testMarker = "Enable-SeqGelfLogging marker $([guid]::NewGuid())"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $testMarker
        $null = Wait-PSFMessage -Timeout 5
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $testMarker
        $null = Wait-PSFMessage -Timeout 5
      }

      $providerInstance = Get-PSFLoggingProviderInstance -ProviderName 'gelfudp' -Name $InstanceName -ErrorAction SilentlyContinue
      $providerInitialized = [bool]($providerInstance -and $providerInstance.Enabled)

      # Optional read-back verification against the SEQ events API, using the API key
      # resolved by SecretName only (never a literal key in code or parameters).
      $deliveryVerified = $null
      $notes = @()
      if ($VerifyDelivery) {
        $seqApiKey = $null
        try {
          $seqApiKey = Get-SecretATAP -SecretName $SeqApiKeySecretName
        } catch {
          $notes += "SEQ API key secret '$SeqApiKeySecretName' could not be resolved via Get-SecretATAP; delivery is asserted, unverified. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message $notes[-1]
        }
        if ($seqApiKey) {
          $filter = [uri]::EscapeDataString("@Message like '%$testMarker%'")
          $eventsUri = "$($SeqServerUrl.TrimEnd('/'))/api/events?count=5&filter=$filter"
          try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $eventsUri" -Tag 'RestCall'
            $events = Invoke-RestMethod -Uri $eventsUri -Headers @{ 'X-Seq-ApiKey' = $seqApiKey } -TimeoutSec 15
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $eventsUri" -Tag 'RestCall'
            $deliveryVerified = [bool]($events | Measure-Object).Count
            if (-not $deliveryVerified) {
              $notes += 'SEQ events API reachable but the marker event was not found (allow ingestion latency and re-query, or check the Seq.Input.Gelf instance).'
            }
          } catch {
            $notes += "SEQ events API query failed; delivery is asserted, unverified. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message $notes[-1]
          } finally {
            $seqApiKey = $null
          }
        }
      }

      return [PSCustomObject]@{
        ProviderName        = 'gelfudp'
        InstanceName        = $InstanceName
        GelfServer          = $GelfServer
        Port                = $Port
        Enabled             = $true
        ProviderInitialized = $providerInitialized
        TestMarker          = $testMarker
        DeliveryVerified    = $deliveryVerified
        Notes               = ($notes -join ' | ')
      }
    } catch {
      $errorMessage = "Failed to enable SEQ GELF (UDP) logging for '$($GelfServer):$($Port)' instance '$InstanceName'. Exception: $($_.Exception.Message)"
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
