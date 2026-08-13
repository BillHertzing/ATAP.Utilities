<#
.SYNOPSIS
  Registers the PSFramework 'gelfudp' Version2 logging provider (idempotent).
.DESCRIPTION
  Task 14.62: extracted from Enable-SeqGelfLogging so that enabling, disabling, and
  querying the sink all share one provider definition. Registration is process-wide and
  happens at most once per session; Enable/Disable only toggle named INSTANCES of it.

  Why this provider exists at all (Task 12.19 / SC-0230): PSFramework's built-in 'gelf'
  provider is hard-coded to PSGELF\Send-PSGelfTCP - TCP only. The organization's SEQ GELF
  input listens on UDP only, so the built-in provider can never reach it, and the widely
  documented 'PSFramework.logging.gelf.protocol' configuration key does not exist
  (Set-PSFConfig creates it; nothing reads it). This provider closes that gap.
.OUTPUTS
  System.Boolean - $true when this call performed the registration, $false when the
  provider was already registered.
#>
function Register-SeqGelfUdpProvider {
  [CmdletBinding()]
  [OutputType([bool])]
  param()

  $fn = $MyInvocation.MyCommand.Name
  $mn = 'ATAP.Utilities.GELFLogging.Powershell'

  if (Get-PSFLoggingProvider -Name 'gelfudp' -ErrorAction SilentlyContinue) {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Logging provider 'gelfudp' is already registered."
    return $false
  }

  # Modeled on PSFramework's built-in gelf provider, with Send-PSGelfUDP replacing the
  # TCP-only Send-PSGelfTCP and no Encrypt property (GELF over UDP has no TLS).
  $messageEvent = {
    param ($Message)

    # Resolve config per message rather than caching it in a StartEvent: the StartEvent
    # cache races the first instance start (config not yet visible), which silently drops
    # every message until the instance is re-enabled (reproduced 2026-07-04 - a fresh
    # session's first enable never delivered, and a second Set-PSFLoggingProvider healed it).
    $gelfParams = @{
      'GelfServer' = Get-ConfigValue -Name 'GelfServer'
      'Port'       = Get-ConfigValue -Name 'Port'
    }
    $gelfParams['ShortMessage'] = $Message.LogMessage
    $gelfParams['HostName'] = $Message.ComputerName
    $gelfParams['DateTime'] = $Message.Timestamp

    $gelfParams['Level'] = switch ($Message.Level) {
      'Critical' { 1 }
      'Important' { 1 }
      'Output' { 3 }
      'Host' { 4 }
      'Significant' { 5 }
      'VeryVerbose' { 6 }
      'Verbose' { 6 }
      'SomewhatVerbose' { 6 }
      'System' { 6 }
      default { 7 }
    }

    if ($Message.ErrorRecord) {
      $gelfParams['FullMessage'] = $Message.ErrorRecord | ConvertTo-Json
    }

    $gelfProperties = $Message.PSObject.Properties | Where-Object {
      $_.Name -notin @('Message', 'LogMessage', 'ComputerName', 'Timestamp', 'Level', 'ErrorRecord')
    }
    $gelfParams['AdditionalField'] = @{ }
    foreach ($gelfProperty in $gelfProperties) {
      $gelfParams['AdditionalField'][$gelfProperty.Name] = $gelfProperty.Value
    }

    PSGELF\Send-PSGelfUDP @gelfParams
  }

  $configurationSettings = {
    Set-PSFConfig -Module PSFramework -Name 'Logging.GelfUdp.GelfServer' -Value '' -Initialize -Validation string -Description 'The GELF UDP server (SEQ ingestor) to send logs to'
    Set-PSFConfig -Module PSFramework -Name 'Logging.GelfUdp.Port' -Value '' -Initialize -Validation string -Description 'The UDP port the GELF server listens on'
  }

  $paramRegister = @{
    Name                  = 'gelfudp'
    Version2              = $true
    ConfigurationRoot     = 'PSFramework.Logging.GelfUdp'
    InstanceProperties    = 'GelfServer', 'Port'
    MessageEvent          = $messageEvent
    ConfigurationSettings = $configurationSettings
  }
  Register-PSFLoggingProvider @paramRegister
  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Registered logging provider 'gelfudp'."
  return $true
}
