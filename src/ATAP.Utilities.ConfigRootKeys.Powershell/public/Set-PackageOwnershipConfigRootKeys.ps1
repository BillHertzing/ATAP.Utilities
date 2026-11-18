# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Adds PackageOwnership key constants to $global:configRootKeys.

.DESCRIPTION
Registers the canonical section, schema-version and ManagerOwnership key names
used by the host-local PackageOwnership configuration that ATAP.IAC publishes in
HostSettings.IAC.Fragment.PackageOwnership.ps1. ManagerOwnership declares which
package manager owns a package; SystemParityMonitor reads it to refuse Chocolatey
remediation of packages that another manager owns.

This is the narrow contract of WinGet Plan r21 section R19.4: the root, the schema
version and ManagerOwnership only. The DotNetBaseline key of the broader plan
(section 4, item 3) is deliberately NOT registered yet.

This function defines only configuration key constants; the owned package
identifiers and exclusion patterns remain in ATAP.IAC HostSettings.

Requires $global:configRootKeys to already exist (initialized by
Set-CoreConfigRootKeys through Set-GlobalConfigRootKeys).

.OUTPUTS
None. Populates $global:configRootKeys as a side effect.

.EXAMPLE
Set-PackageOwnershipConfigRootKeys

Adds the PackageOwnership key constants.

.EXAMPLE
Set-PackageOwnershipConfigRootKeys -WhatIf

Shows the operation without modifying $global:configRootKeys.

.NOTES
Settings shape published by ATAP.IAC (schema version 1):
  $global:settings['PackageOwnership'] = @{
    SchemaVersion    = 1
    ManagerOwnership = @{ WinGet = @(<WinGet package ids>); ChocolateyExcluded = @(<regex patterns>) }
  }

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

function Set-PackageOwnershipConfigRootKeys {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias()]
  [OutputType([void])]
  param()

  begin {
    $fn = 'Set-PackageOwnershipConfigRootKeys'
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
      if ($PSCmdlet.ShouldProcess('$global:configRootKeys', 'Add PackageOwnership key constants')) {
        $global:configRootKeys.Add('PackageOwnershipConfigRootKey', 'PackageOwnership')
        $global:configRootKeys.Add('PackageOwnershipSchemaVersionConfigRootKey', 'SchemaVersion')
        $global:configRootKeys.Add('PackageOwnershipManagerOwnershipConfigRootKey', 'ManagerOwnership')
        if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Added PackageOwnership key constants.' }
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
