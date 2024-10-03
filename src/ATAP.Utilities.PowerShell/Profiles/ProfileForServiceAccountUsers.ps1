<#
.SYNOPSIS
PowerShell V7 profile template for individual users
.DESCRIPTION
Settings specific for a user, whose values represent the tasks and environments the user is doing
Details in [powerShell ReadMe](src\ATAP.Utilities.Powershell\Documentation\ReadMe.md)
.INPUTS
None
.OUTPUTS
None
.EXAMPLE
None
.LINK
http://www.somewhere.com/attribution.html
.LINK
<Another link>
.ATTRIBUTION
[Customize Prompt](https://www.networkadm.in/customize-pscmdprompt/) adding info to the prompt and terminal window
ToDo: Need attribution for Console Settings
<Where the ideas came from>
.SCM
<Configuration Management Keywords>
#>

# Set these for debugging the profile
# Don't Print any debug messages to the console
$DebugPreference = 'SilentlyContinue'
# Don't Print any verbose messages to the console
$VerbosePreference = 'SilentlyContinue' # SilentlyContinue Continue

########################################################
# Generic PowerShell Profile for Windows Service Accounts
# (e.g. Jenkins agents, MSSQL Server Agent)
########################################################
# [powerShell ReadMe](src\ATAP.Utilities.Powershell\Documentation\ReadMe.md for details)
# The following ordered list of module paths come from ATAP and 3rd-party modules that have been selected by this user
$UserPSModulePaths = @(

  # ATAP Powershell is part of the machine profile
  # 'Modules that are in DevelopmentLifecycle Phase, for which I am involved'
  # 'Modules that are in Unit Test Lifecycle Phase, for which I am involved ("I" may be a user or a CI/CD service)'
  # 'Modules that are in Integration Test Lifecycle Phase, for which I am involved'
  # 'Modules that are in RTM Lifecycle Phase, for which I am involved'
  # 'All Production modules for Scripts I use day-to-day' - These should reference modules in
  # Image manipulation scripts for blog posts
  # DropBox api scripts for blog posts
  # Future: scripts to manipulate FreeVideoEditor VSDC
)
# ToDo:  Ensure that the following modules are imported
# Always Last step - set the environment variables for this user
. (Join-Path -Path $PSHome -ChildPath 'global_EnvironmentVariables.ps1')
Set-EnvironmentVariablesProcess # This function should be defined in the AllUsersAllHosts profile

#testing
Write-EnvironmentVariablesIndented | set-content -Path 'D:\temp\EnvVarsFromLastServiceAcctLogin.txt'
