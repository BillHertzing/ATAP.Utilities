<#
.SYNOPSIS
  Reports whether SEQ GELF (UDP) logging is registered and enabled.
.DESCRIPTION
  Task 14.62. Completes the explicit enable/disable/query trio. Before this, answering
  "is this shell shipping telemetry to SEQ, and where to?" meant calling PSFramework's
  Get-PSFLoggingProvider / Get-PSFLoggingProviderInstance directly and knowing which
  provider name and instance-name convention to ask for.

  This is strictly READ-ONLY: it never registers the provider and never imports PSGELF, so
  asking the question cannot change the answer or pull in the transport module. On a host
  where nothing has ever been enabled it reports Registered = $false rather than throwing.
.PARAMETER InstanceName
  PSFramework logging-provider instance name to report on. Defaults to 'SendToSEQ'.
.OUTPUTS
  PSCustomObject with ProviderName, Registered, InstanceName, InstanceExists, Enabled,
  GelfServer, Port, and Endpoint.
.EXAMPLE
  Get-SeqGelfLoggingStatus

  Reports the state of the default SendToSEQ instance.
.EXAMPLE
  if ((Get-SeqGelfLoggingStatus).Enabled) { Disable-SeqGelfLogging }

  Turns the sink off only when it is actually on.
.LINK
  https://github.com/datalust/seq-input-gelf
#>
function Get-SeqGelfLoggingStatus {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $InstanceName = 'SendToSEQ'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.Powershell.GELFLogging'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function'
  }

  process {
    $registered = [bool](Get-PSFLoggingProvider -Name 'gelfudp' -ErrorAction SilentlyContinue)

    $providerInstance = $null
    if ($registered) {
      $providerInstance = Get-PSFLoggingProviderInstance -ProviderName 'gelfudp' -Name $InstanceName -ErrorAction SilentlyContinue
    }

    $gelfServer = $null
    $port = $null
    if ($providerInstance) {
      # Instance properties are surfaced by PSFramework as configuration entries under the
      # provider's ConfigurationRoot; read them defensively so a shape change downgrades to
      # a null endpoint rather than throwing out of a status query.
      $gelfServer = (Get-PSFConfigValue -FullName "PSFramework.Logging.GelfUdp.$InstanceName.GelfServer" -Fallback $null)
      $port = (Get-PSFConfigValue -FullName "PSFramework.Logging.GelfUdp.$InstanceName.Port" -Fallback $null)
    }

    $endpoint = if ($gelfServer -and $port) { "udp://$($gelfServer):$($port)" } else { $null }

    [PSCustomObject]@{
      ProviderName   = 'gelfudp'
      Registered     = $registered
      InstanceName   = $InstanceName
      InstanceExists = [bool]$providerInstance
      Enabled        = [bool]($providerInstance -and $providerInstance.Enabled)
      GelfServer     = $gelfServer
      Port           = $port
      Endpoint       = $endpoint
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function'
  }
}
