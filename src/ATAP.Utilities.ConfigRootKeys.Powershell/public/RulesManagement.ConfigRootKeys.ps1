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


