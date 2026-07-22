# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Adds ATAP.Utilities.RulesManagement key constants to $global:configRootKeys.

.DESCRIPTION
Appends the RulesManagement framework configuration key constants to the
$global:configRootKeys hashtable. These keys cover the RulesManagement database
connection, Flyway migration settings, documentation/compendium paths, and the
OtterScript rule-kind grammar paths and database settings. The values are assigned
later in $global:settings (host settings) and the IAC fragment files.

Requires $global:configRootKeys to already exist (initialized by Set-CoreConfigRootKeys
via Set-GlobalConfigRootKeys).

.OUTPUTS
None. Populates $global:configRootKeys as a side effect.

.EXAMPLE
Set-RulesManagementConfigRootKeys

Adds all RulesManagement key constants to $global:configRootKeys.

.EXAMPLE
Set-RulesManagementConfigRootKeys -WhatIf

Shows which operations would be performed without modifying $global:configRootKeys.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

function Set-RulesManagementConfigRootKeys {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias()]
  [OutputType([void])]
  param ()

  begin {
    $fn = 'Set-RulesManagementConfigRootKeys'
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
      if ($PSCmdlet.ShouldProcess('$global:configRootKeys', 'Add RulesManagement key constants')) {
        # Database connection
        $global:configRootKeys.Add('RulesManagementDatabaseHostConfigRootKey', 'RulesManagement.DatabaseHost')
        $global:configRootKeys.Add('RulesManagementDatabaseNameConfigRootKey', 'RulesManagement.DatabaseName')
        $global:configRootKeys.Add('RulesManagementCredentialsKeyConfigRootKey', 'RulesManagement.CredentialsKey')

        # Flyway
        $global:configRootKeys.Add('RulesManagementFlywayUrlConfigRootKey', 'RulesManagement.FlywayUrl')
        $global:configRootKeys.Add('RulesManagementFlywayExecutableConfigRootKey', 'RulesManagement.FlywayExecutable')
        $global:configRootKeys.Add('RulesManagementMigrationsPathConfigRootKey', 'RulesManagement.MigrationsPath')

        # Documentation paths
        $global:configRootKeys.Add('RulesManagementCompendiumPathConfigRootKey', 'RulesManagement.CompendiumPath')
        $global:configRootKeys.Add('RulesManagementCompendiumRelativePathConfigRootKey', 'RulesManagement.CompendiumRelativePath')
        $global:configRootKeys.Add('RulesManagementDocsRootConfigRootKey', 'RulesManagement.DocsRoot')

        # OtterScript rule-kind paths and DB settings
        $global:configRootKeys.Add('OtterScriptRulesDbConfigRootKey', 'RulesManagement.OtterScriptRules.DatabaseName')
        $global:configRootKeys.Add('OtterScriptRulesPrimitiveLanguageKindIdConfigRootKey', 'RulesManagement.OtterScriptRules.PrimitiveLanguageKindId')
        $global:configRootKeys.Add('OtterScriptRulesGrammarPathConfigRootKey', 'RulesManagement.OtterScriptRules.GrammarPath')
        $global:configRootKeys.Add('OtterScriptRulesCompendiumPathConfigRootKey', 'RulesManagement.OtterScriptRules.CompendiumPath')
        if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Added RulesManagement key constants.' }
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
