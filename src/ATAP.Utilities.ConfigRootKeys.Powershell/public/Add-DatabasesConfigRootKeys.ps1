# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Adds database-related key constants to $global:configRootKeys.

.DESCRIPTION
Appends the standard set of database configuration key constants to the
$global:configRootKeys hashtable. These keys are used throughout the codebase
to look up database connection settings from $global:settings.

Also scans the same directory for sub-fragment files matching the pattern
'Databases.*.ConfigRootKeys.ps1' and dot-sources each one. Sub-fragments add
per-database-instance key constants (e.g., Databases.ATAPUtilities.ConfigRootKeys.ps1).

Requires $global:configRootKeys to already exist (initialized by Set-CoreConfigRootKeys
via Set-GlobalConfigRootKeys).

.OUTPUTS
None. Populates $global:configRootKeys as a side effect.

.EXAMPLE
Add-DatabasesConfigRootKeys

Adds all standard database key constants and loads any Databases.* sub-fragments
found alongside this script.

.EXAMPLE
Add-DatabasesConfigRootKeys -WhatIf

Shows which operations would be performed without modifying $global:configRootKeys.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

function Add-DatabasesConfigRootKeys {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias()]
  [OutputType([void])]
  param ()

  begin {
    $fn = 'Add-DatabasesConfigRootKeys'
    $mn = 'ATAP.Utilities.ConfigRootKeys.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    if ($null -eq $global:configRootKeys) {
      $errorMessage = '$global:configRootKeys is not initialized. Run Set-GlobalConfigRootKeys (which loads Set-CoreConfigRootKeys.ps1 first).'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    $scriptFile = $MyInvocation.MyCommand.ScriptBlock.File
    $scriptDir = if (-not [string]::IsNullOrEmpty($scriptFile)) {
      [System.IO.Path]::GetDirectoryName($scriptFile)
    } else {
      $PWD.ProviderPath
    }
  }

  process {
    try {
      if ($PSCmdlet.ShouldProcess('$global:configRootKeys', 'Add database key constants')) {
        $global:configRootKeys.Add('DatabaseHostConfigRootKey', 'DatabaseHost')
        $global:configRootKeys.Add('ConnectionMethodConfigRootKey', 'ConnectionMethod')
        $global:configRootKeys.Add('SqlInstanceConfigRootKey', 'SqlInstance')
        $global:configRootKeys.Add('DatabasePathConfigRootKey', 'DatabasePath')
        $global:configRootKeys.Add('ProvisioningScriptsPathConfigRootKey', 'ProvisioningScriptsPath')
        $global:configRootKeys.Add('FlywayBasePathConfigRootKey', 'FlywayBasePath')
        $global:configRootKeys.Add('FlywaySqlMigrationsPathConfigRootKey', 'FlywaySqlMigrationsPath')
        $global:configRootKeys.Add('FlywaySharedSqlMigrationsPathConfigRootKey', 'FlywaySharedSqlMigrationsPath')
        $global:configRootKeys.Add('FlywayTomlPathConfigRootKey', 'FlywayTomlPath')
        $global:configRootKeys.Add('UseNamedLoginConfigRootKey', 'UseNamedLogin')
        $global:configRootKeys.Add('LoginNameConfigRootKey', 'LoginName')
        $global:configRootKeys.Add('LoginPasswordCredentialsKeyConfigRootKey', 'LoginPasswordCredentialsKey')
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Added core database key constants.'
      }

      # Discover and load per-database-instance sub-fragment files
      $subFragments = @(
        Get-ChildItem -LiteralPath $scriptDir -Filter 'Databases.*.ConfigRootKeys.ps1' -File -ErrorAction SilentlyContinue |
          Sort-Object Name
      )

      if ($subFragments.Count -eq 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "No Databases.*.ConfigRootKeys.ps1 sub-fragments found in '$scriptDir'."
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Found $($subFragments.Count) database sub-fragment(s) to load."

        if ($PSCmdlet.ShouldProcess('$global:configRootKeys', 'Add DatabasesCollection key and load sub-fragments')) {
          $global:configRootKeys.Add('DatabasesCollectionConfigRootKey', 'DatabasesCollection')
        }

        foreach ($subFragment in $subFragments) {
          if ($PSCmdlet.ShouldProcess($subFragment.FullName, 'Dot-source database sub-fragment')) {
            try {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Dot-sourcing '$($subFragment.FullName)'" -Tag 'ConfigRootKeys'
              . $subFragment.FullName
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Loaded '$($subFragment.Name)'"
            } catch {
              $errorMessage = "Failed to dot-source '$($subFragment.FullName)'. Exception: $($_.Exception.Message)"
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
              throw
            }
          }
        }
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
