# ReadMe for the ATAP.Utilities.Powershell Concept Documentation

## Overview

ToDo: Write content

## Profiles

Important: This package only supplies profiles for Powershell Core (currently V7)

This package supplies two profiles  and multiple settings files. One profile is for AllUsersAllHosts, and should be installed at the location as specified in `$profile.AllUsersAllHosts`. The other profile is for CurrentUserAllHosts, and should be installed at the location as specified in `$profile.CurrentUserAllHosts`.

Important: Location of CurrentUserAllHosts will not always be at ~!. Sometimes a user will have moved their Documents folder from the default location. To determine the location of the user's Documents folder, use `[Environment]::GetFolderPath("MyDocuments")`

Location of `Program Files` may not always be at `C:`. to determine the location of `Program Files`, use `$env:ProgramFiles`

| OS | Profile | Default location |
--- | --- | ---
| Windows 10 64bit | AllUsersAllHosts | C:\Program Files\PowerShell\7\profile.ps1 |
| Windows 10 64bit | CurrentUserAllHosts | [Environment]::GetFolderPath("MyDocuments")\PowerShell\Microsoft.PowerShell_profile.ps1 |

To use the profiles in this package, install the ATAP.Utilities.Powershell package `TBD`, then run these commands in an **non-administrative** powershell core prompt. To use, always run them first in a safe environment (non-admin, firewalled, virus and malware detectors running). :

- ToDo: refactor Target to use settings or environment variables that specify the location to which the package has been installed
- ToDo: rework to support both windows and Linux
- ToDo: move into a function that will accept a -force, and have the function error if the profile already exists and -force is not specified, also include whatif

- `Remove-Item -path (join-path ([Environment]::GetFolderPath("MyDocuments")) '\PowerShell\Microsoft.PowerShell_profile.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path ([Environment]::GetFolderPath("MyDocuments")) '\PowerShell\Microsoft.PowerShell_profile.ps1')  -Target "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.PowerShell\profiles\CurrentUserAllHostsV7CoreProfile.ps1"`

- `Remove-Item -path (join-path $env:ProgramFiles '\PowerShell\7\profile.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:ProgramFiles  '\PowerShell\7\profile.ps1') -Target "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.PowerShell\profiles\AllUsersAllHostsV7CoreProfile.ps1"`

After ensuring there are no critical errors, and the information messages from -WhatIf match what you expect the profile to do, then run them in a terminal running with elevated permissions.

Machine Profile:
ToDo: write reference diagram

User Profile:
ToDo: write reference diagram

## Testing

Jenkins orchestrates the CI/CD pipeline. The resources on which stages run are named nodes. Node characteristics, and node identifiers are created in $Settings, and the node identifiers are used in Jenkins as named Nodes, which can be started and stopped. Nodes can have multiple Roles, and Roles are a set of identifiers and characteristics. The Role identifiers match Jenkins Node label value with the set #ToDo add cxref processing for the machine profile `$JenkinsNodeRoles = @('WindowsCodeBuildJenkinsNode', 'WindowsDocumentationBuildJenkinsNode')`. This cross-product does not scale well for millions of machines and thousands of Roles; the twin concepts of Locality and Connectivity can reduce this. Since this is just version 1, The testing portion of the Jenkins pipeline depends on the node label set Development, .*Test, Production, ProductionWithTracing, and the machine set has only three machines. The machine set of Ids and characteristics is regular. Small experimenters can populate the machine lists manually , and development teams should be able to automate the machine set as machines are brought online and aged-out. Automation would center around AD, and the development team should work with the AD adminisrative team to take full use of the Powershell cmdlets around DNS and AD that are granted to the developers.

ToDo: Write content

## Packaging and Distribution

ToDo: Write content
