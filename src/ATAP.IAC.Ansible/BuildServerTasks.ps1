return @'
---
# code: language=ansible
# Tasks to create a BuildServer (lint, compile, link, test, package, sign, SHA, deploy)

# prerequisites
# - common tasks for the Operating System of the computer / container, all of which runas a user who is a member of the administrators group
   # - tasks to setup Network adapter properties
   # - tasks to setup Firewall Rules
   # - tasks to setup WinRM
   # - tasks to setup Powershell profile files
   # - tasks to setup PackageManagement, NuGet, PowershellGet, and ChocolateyGet, repositories, and sources
   # - tasks to setup SSH Server
   # - tasks to setup SSH Client
   # - tasks to setup a Powershell Secrets Management
   # - tasks to setup a Powershell Hashicorp vault
   # - tasks to setup / recognize a Certificate Authority
# - common tasks for managing the users of the computer / container
   # - tasks to assign security roles to a user
# - tasks for setting up a Jenkins Agent
  # - tasks for setting up a user account (service account) for running the Jenkins Agent
# - tasks to setup MSBuild
# - tasks to setup Git
  # - tasks to setup the commit hooks
# - tasks to setup Powershell PSScriptAnalyzer
# - tasks to setup Powershell packaging
# - tasks to setup a Code Signing certificate
'@


