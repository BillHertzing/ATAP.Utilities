# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Adds the ATAPUtilities database-name key constant to $global:configRootKeys.

.DESCRIPTION
Appends the per-database-instance key constant for the ATAPUtilities database to the
$global:configRootKeys hashtable. This is the explicit per-database fragment for the
ATAPUtilities database; it is invoked by name from Add-DatabasesConfigRootKeys rather
than discovered by a directory scan.

Requires $global:configRootKeys to already exist (initialized by Set-CoreConfigRootKeys
via Set-GlobalConfigRootKeys).

.OUTPUTS
None. Populates $global:configRootKeys as a side effect.

.EXAMPLE
Set-DatabasesATAPUtilitiesConfigRootKeys

Adds the ATAPUtilities database-name key constant to $global:configRootKeys.

.EXAMPLE
Set-DatabasesATAPUtilitiesConfigRootKeys -WhatIf

Shows which operations would be performed without modifying $global:configRootKeys.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

function Set-DatabasesATAPUtilitiesConfigRootKeys {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias()]
  [OutputType([void])]
  param ()

  begin {
    $fn = 'Set-DatabasesATAPUtilitiesConfigRootKeys'
    $mn = 'ATAP.Utilities.ConfigRootKeys.PowerShell'
    Write-ConfigRootKeysMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    if ($null -eq $global:configRootKeys) {
      $errorMessage = '$global:configRootKeys is not initialized. Run Set-GlobalConfigRootKeys (which loads Set-CoreConfigRootKeys first).'
      Write-ConfigRootKeysMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }
  }

  process {
    try {
      if ($PSCmdlet.ShouldProcess('$global:configRootKeys', 'Add ATAPUtilities database-name key constant')) {
        $global:configRootKeys.Add('DatabaseATAPUtilitiesNameConfigRootKey', 'ATAPUtilities')
        Write-ConfigRootKeysMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Added ATAPUtilities database-name key constant.'
      }
    } catch {
      $errorMessage = "Unhandled error in $fn. Exception: $($_.Exception.Message)"
      Write-ConfigRootKeysMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    } finally {
      Write-ConfigRootKeysMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving process block in $fn"
    }
  }

  end {
    Write-ConfigRootKeysMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
