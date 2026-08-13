# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Adds SystemParityMonitor key constants to $global:configRootKeys.

.DESCRIPTION
Registers the canonical section, schema-version, package-manager profile, and
expected-surface-minimum key
names used by host-local SystemParityMonitor configuration. This function defines
only configuration key constants; host-specific identities and paths remain in
ATAP.IAC HostSettings.

Requires $global:configRootKeys to already exist (initialized by
Set-CoreConfigRootKeys through Set-GlobalConfigRootKeys).

.OUTPUTS
None. Populates $global:configRootKeys as a side effect.

.EXAMPLE
Set-SystemParityMonitorConfigRootKeys

Adds the SystemParityMonitor key constants.

.EXAMPLE
Set-SystemParityMonitorConfigRootKeys -WhatIf

Shows the operation without modifying $global:configRootKeys.

.NOTES
The exact contract is schema version plus an identity-explicit ordered
PackageManagerProfiles collection below the SystemParityMonitor section.

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

function Set-SystemParityMonitorConfigRootKeys {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias()]
  [OutputType([void])]
  param()

  begin {
    $fn = 'Set-SystemParityMonitorConfigRootKeys'
    $mn = 'ATAP.Utilities.ConfigRootKeys.PowerShell'
    if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn" }

    if ($null -eq $global:configRootKeys) {
      $errorMessage = '$global:configRootKeys is not initialized. Run Set-GlobalConfigRootKeys (which loads Set-CoreConfigRootKeys first).'
      if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage }
      throw $errorMessage
    }
  }

  process {
    try {
      if ($PSCmdlet.ShouldProcess('$global:configRootKeys', 'Add SystemParityMonitor key constants')) {
        $global:configRootKeys.Add('SystemParityMonitorConfigRootKey', 'SystemParityMonitor')
        $global:configRootKeys.Add('SystemParityMonitorSchemaVersionConfigRootKey', 'SchemaVersion')
        $global:configRootKeys.Add('SystemParityMonitorPackageManagerProfilesConfigRootKey', 'PackageManagerProfiles')
        $global:configRootKeys.Add('SystemParityMonitorExpectedSurfaceMinimumCountsConfigRootKey', 'ExpectedSurfaceMinimumCounts')
        if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Added SystemParityMonitor key constants.' }
      }
    } catch {
      $errorMessage = "Unhandled error in $fn. Exception: $($_.Exception.Message)"
      if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage }
      throw
    } finally {
      if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving process block in $fn" }
    }
  }

  end {
    if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn" }
  }
}
