function Get-ProfiledRemotingBoundaryState {
  <#
  .SYNOPSIS
  Probes the local, read-only state needed by the sprint-boundary remoting policy.

  .DESCRIPTION
  Enumerates PowerShell session configurations and checks the managed endpoint's
  registry and hash-marker state. It never enables remoting and never changes
  WinRM or session configurations.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [string]$ConfigurationName = 'ATAP.PS7.Profiled'
  )

  $probeError = $null
  $configurations = @()
  $commandAvailable = [bool](Get-Command -Name Get-PSSessionConfiguration -ErrorAction SilentlyContinue)
  if ($commandAvailable) {
    try {
      $configurations = @(Get-PSSessionConfiguration -ErrorAction Stop)
    } catch {
      $probeError = $_.Exception.Message
    }
  } else {
    $probeError = 'Get-PSSessionConfiguration is not available.'
  }

  $managedConfigurationPresent = [bool](@($configurations | Where-Object { $_.Name -eq $ConfigurationName }).Count -gt 0)
  $managedRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Plugin\$ConfigurationName"
  $managedRegistryPresent = [bool](Test-Path -LiteralPath $managedRegistryPath -ErrorAction SilentlyContinue)

  $programData = [Environment]::GetEnvironmentVariable('ProgramData', 'Process')
  if ([string]::IsNullOrWhiteSpace($programData)) {
    $programData = [Environment]::GetEnvironmentVariable('ProgramData', 'Machine')
  }
  $managedMarkerPath = if ([string]::IsNullOrWhiteSpace($programData)) {
    $null
  } else {
    Join-Path $programData 'ATAP\RemotingEndpoints\WithProfiles.pssc.registered-sha256'
  }
  $managedMarkerPresent = [bool]($managedMarkerPath -and (Test-Path -LiteralPath $managedMarkerPath -PathType Leaf -ErrorAction SilentlyContinue))

  [PSCustomObject]@{
    ConfigurationName            = $ConfigurationName
    CommandAvailable             = $commandAvailable
    ProbeSucceeded               = ($commandAvailable -and [string]::IsNullOrWhiteSpace($probeError))
    ConfigurationCount           = $configurations.Count
    RemotingSurfacePresent       = ($commandAvailable -and [string]::IsNullOrWhiteSpace($probeError) -and $configurations.Count -gt 0)
    ManagedConfigurationPresent  = $managedConfigurationPresent
    ManagedRegistryPresent       = $managedRegistryPresent
    ManagedMarkerPresent         = $managedMarkerPresent
    ManagedEndpointStatePresent  = ($managedConfigurationPresent -or $managedRegistryPresent -or $managedMarkerPresent)
    ManagedMarkerPath            = $managedMarkerPath
    ProbeError                   = $probeError
  }
}
