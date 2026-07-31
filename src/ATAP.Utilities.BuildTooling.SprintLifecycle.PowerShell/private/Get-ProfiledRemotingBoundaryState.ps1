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
    [string]$ConfigurationName = 'ATAP.PS7.Profiled',

    [string]$PowerShellHome = $PSHOME,

    [scriptblock]$SessionConfigurationProvider
  )

  $probeError = $null
  $configurations = @()
  $commandAvailable = [bool](Get-Command -Name Get-PSSessionConfiguration -ErrorAction SilentlyContinue)
  $usingDefaultSessionConfigurationProvider = $null -eq $SessionConfigurationProvider
  if ($usingDefaultSessionConfigurationProvider) {
    $SessionConfigurationProvider = {
      Get-PSSessionConfiguration -ErrorAction Stop
    }
  }

  $providerAvailable = -not $usingDefaultSessionConfigurationProvider -or $commandAvailable
  if ($providerAvailable) {
    try {
      $configurations = @(& $SessionConfigurationProvider)
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

  # PowerShell 7's canonical plug-in binary is installed beside pwsh.exe. Do
  # not infer a versioned Windows\System32\PowerShell path from the engine
  # version: servicing can leave that copied path stale while the installed
  # $PSHOME payload remains valid.
  $canonicalPluginPath = Join-Path $PowerShellHome 'pwrshplugin.dll'
  $canonicalPluginPresent = Test-Path -LiteralPath $canonicalPluginPath -PathType Leaf -ErrorAction SilentlyContinue
  $brokenPowerShell7Configurations = @(
    foreach ($configuration in $configurations) {
      $configurationEnabled = [string]$configuration.Enabled -eq 'True'
      if ($configuration.Name -notlike 'PowerShell.7*' -or -not $configurationEnabled) {
        continue
      }

      $registeredPluginPath = [Environment]::ExpandEnvironmentVariables([string]$configuration.Filename)
      if ([string]::IsNullOrWhiteSpace($registeredPluginPath) -or -not (Test-Path -LiteralPath $registeredPluginPath -PathType Leaf -ErrorAction SilentlyContinue)) {
        [PSCustomObject]@{
          Name                 = [string]$configuration.Name
          RegisteredPluginPath = $registeredPluginPath
          CanonicalPluginPath  = $canonicalPluginPath
          CanonicalPluginPresent = [bool]$canonicalPluginPresent
          RepairCommand        = "Set-Item -LiteralPath 'WSMan:\localhost\Plugin\$($configuration.Name)\Filename' -Value '$($canonicalPluginPath.Replace("'", "''"))' -Force"
        }
      }
    }
  )

  $repairGuidance = if ($brokenPowerShell7Configurations.Count -gt 0 -and $canonicalPluginPresent) {
    @($brokenPowerShell7Configurations.RepairCommand) + 'Restart-Service -Name WinRM -Force'
  } else {
    @()
  }

  [PSCustomObject]@{
    ConfigurationName            = $ConfigurationName
    CommandAvailable             = $commandAvailable
    ProbeSucceeded               = ($providerAvailable -and [string]::IsNullOrWhiteSpace($probeError))
    ConfigurationCount           = $configurations.Count
    RemotingSurfacePresent       = ($providerAvailable -and [string]::IsNullOrWhiteSpace($probeError) -and $configurations.Count -gt 0)
    ManagedConfigurationPresent  = $managedConfigurationPresent
    ManagedRegistryPresent       = $managedRegistryPresent
    ManagedMarkerPresent         = $managedMarkerPresent
    ManagedEndpointStatePresent  = ($managedConfigurationPresent -or $managedRegistryPresent -or $managedMarkerPresent)
    ManagedMarkerPath            = $managedMarkerPath
    CanonicalPluginPath          = $canonicalPluginPath
    CanonicalPluginPresent       = [bool]$canonicalPluginPresent
    BrokenPowerShell7Configurations = $brokenPowerShell7Configurations
    BrokenPowerShell7ConfigurationCount = $brokenPowerShell7Configurations.Count
    RepairGuidance               = $repairGuidance
    ProbeError                   = $probeError
  }
}
