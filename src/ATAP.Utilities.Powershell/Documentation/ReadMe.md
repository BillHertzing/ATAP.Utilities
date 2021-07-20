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

To use the profiles in this package, install the ATAP.Utilities.Powershell package `TBD`, then run these commands in an administrative powershell core prompt:

- ToDo: refactor Target to use settings or environment variables that specify the location to which the package has been installed
- ToDo: rework to support both windows and Linux
- ToDo: move into a function that will accept a -force, and have the function error if the rofile already exists and -force is not specified, also include whatif

- `Remove-Item -path (join-path ([Environment]::GetFolderPath("MyDocuments")) '\PowerShell\Microsoft.PowerShell_profile.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path ([Environment]::GetFolderPath("MyDocuments")) '\PowerShell\Microsoft.PowerShell_profile.ps1')  -Target "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.PowerShell\profiles\CurrentUserAllHostsV7CoreProfile.ps1"`

- `Remove-Item -path (join-path $env:ProgramFiles '\PowerShell\7\profile.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:ProgramFiles  '\PowerShell\7\profile.ps1') -Target "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.PowerShell\profiles\AllUsersAllHostsV7CoreProfile.ps1"`

## Testing

ToDo: Write content

## Packaging and Distribution

ToDo: Write content
