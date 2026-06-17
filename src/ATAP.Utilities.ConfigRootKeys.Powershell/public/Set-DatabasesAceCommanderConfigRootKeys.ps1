# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Adds the AceCommander database-name key constant to $global:configRootKeys.

.DESCRIPTION
Appends the per-database-instance key constant for the AceCommander database to the
$global:configRootKeys hashtable. This is the explicit per-database fragment for the
AceCommander database; it is invoked by name from Add-DatabasesConfigRootKeys rather
than discovered by a directory scan.

Requires $global:configRootKeys to already exist (initialized by Set-CoreConfigRootKeys
via Set-GlobalConfigRootKeys).

.OUTPUTS
None. Populates $global:configRootKeys as a side effect.

.EXAMPLE
Set-DatabasesAceCommanderConfigRootKeys

Adds the AceCommander database-name key constant to $global:configRootKeys.

.EXAMPLE
Set-DatabasesAceCommanderConfigRootKeys -WhatIf

Shows which operations would be performed without modifying $global:configRootKeys.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

function Set-DatabasesAceCommanderConfigRootKeys {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias()]
  [OutputType([void])]
  param ()

  begin {
    $fn = 'Set-DatabasesAceCommanderConfigRootKeys'
    $mn = 'ATAP.Utilities.ConfigRootKeys.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    if ($null -eq $global:configRootKeys) {
      $errorMessage = '$global:configRootKeys is not initialized. Run Set-GlobalConfigRootKeys (which loads Set-CoreConfigRootKeys first).'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }
  }

  process {
    try {
      if ($PSCmdlet.ShouldProcess('$global:configRootKeys', 'Add AceCommander database-name key constant')) {
        $global:configRootKeys.Add('DatabaseAceCommanderNameConfigRootKey', 'AceCommander')
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Added AceCommander database-name key constant.'
      }
    } catch {
      $errorMessage = "Unhandled error in $fn. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving process block in $fn"
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
