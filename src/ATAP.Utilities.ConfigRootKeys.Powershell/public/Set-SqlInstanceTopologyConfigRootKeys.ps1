# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Adds SQL instance-topology key constants to $global:configRootKeys.

.DESCRIPTION
Registers the canonical key names used by the ATAP.IAC SQL instance-topology
HostSettings fragment. The keys address the topology root, host and instance
collections, lifecycle state, canonical name patterns, filesystem paths, and
fixed TCP ports without duplicating any host-specific values in this module.

.OUTPUTS
None. Populates $global:configRootKeys as a side effect.

.EXAMPLE
Set-SqlInstanceTopologyConfigRootKeys

Adds all SQL instance-topology key constants.

.EXAMPLE
Set-SqlInstanceTopologyConfigRootKeys -WhatIf

Shows the operation without changing $global:configRootKeys.

.NOTES
Host-specific topology values remain canonical in ATAP.IAC HostSettings.

.LINK
https://github.com/BillHertzing/ATAP.IAC
#>

function Set-SqlInstanceTopologyConfigRootKeys {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias()]
  [OutputType([void])]
  param()

  begin {
    $fn = 'Set-SqlInstanceTopologyConfigRootKeys'
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
      if ($PSCmdlet.ShouldProcess('$global:configRootKeys', 'Add SQL instance-topology key constants')) {
        $global:configRootKeys.Add('SqlInstanceTopologyConfigRootKey', 'SqlInstanceTopology')
        $global:configRootKeys.Add('SqlInstanceTopologySchemaVersionConfigRootKey', 'SchemaVersion')
        $global:configRootKeys.Add('SqlInstanceTopologyHostsConfigRootKey', 'Hosts')
        $global:configRootKeys.Add('SqlInstanceTopologyHostLifecycleConfigRootKey', 'Lifecycle')
        $global:configRootKeys.Add('SqlInstanceTopologyInstancesConfigRootKey', 'Instances')
        $global:configRootKeys.Add('SqlInstanceTopologyInstanceRoleConfigRootKey', 'Role')
        $global:configRootKeys.Add('SqlInstanceTopologyInstanceNameConfigRootKey', 'InstanceName')
        $global:configRootKeys.Add('SqlInstanceTopologyInstanceNamePatternConfigRootKey', 'InstanceNamePattern')
        $global:configRootKeys.Add('SqlInstanceTopologyProvisioningStateConfigRootKey', 'ProvisioningState')
        $global:configRootKeys.Add('SqlInstanceTopologyEngineBinariesPathConfigRootKey', 'EngineBinariesPath')
        $global:configRootKeys.Add('SqlInstanceTopologyDataPathConfigRootKey', 'DataPath')
        $global:configRootKeys.Add('SqlInstanceTopologyLogPathConfigRootKey', 'LogPath')
        $global:configRootKeys.Add('SqlInstanceTopologyBackupPathConfigRootKey', 'BackupPath')
        $global:configRootKeys.Add('SqlInstanceTopologyErrorLogPathConfigRootKey', 'ErrorLogPath')
        $global:configRootKeys.Add('SqlInstanceTopologyTcpPortConfigRootKey', 'TcpPort')
        if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Added SQL instance-topology key constants.' }
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
