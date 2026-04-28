###################################################
## GlobalConfigRootKeys.ps1 — RulesManagement Section (Phase 1)
## Drop-in replacement for the RulesManagement-related keys.
## This section defines string constants used as dictionary keys
## throughout the settings system. Values are assigned in HostSettings.ps1
## and the IAC Fragment files.
##
###################################################

# ── ATAP.Utilities.RulesManagement.PowerShell — ConfigRootKeys ───────────────

# Database connection
$global:configRootKeys['RulesManagementDatabaseHostConfigRootKey'] = 'RulesManagement.DatabaseHost'
$global:configRootKeys['RulesManagementDatabaseNameConfigRootKey'] = 'RulesManagement.DatabaseName'
$global:configRootKeys['RulesManagementCredentialsKeyConfigRootKey'] = 'RulesManagement.CredentialsKey'

# Flyway
$global:configRootKeys['RulesManagementFlywayUrlConfigRootKey'] = 'RulesManagement.FlywayUrl'
$global:configRootKeys['RulesManagementFlywayExecutableConfigRootKey'] = 'RulesManagement.FlywayExecutable'
$global:configRootKeys['RulesManagementMigrationsPathConfigRootKey'] = 'RulesManagement.MigrationsPath'

# Documentation paths
$global:configRootKeys['RulesManagementCompendiumPathConfigRootKey'] = 'RulesManagement.CompendiumPath'
$global:configRootKeys['RulesManagementCompendiumRelativePathConfigRootKey'] = 'RulesManagement.CompendiumRelativePath'
$global:configRootKeys['RulesManagementDocsRootConfigRootKey'] = 'RulesManagement.DocsRoot'
