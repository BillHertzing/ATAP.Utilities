# ReadMe for the ATAP.Utilities.Powershell Concept Documentation

## Overview

Profiles define the environment in which a powershell process executes. The machine profile sets values that are applicable for a specific machine. The values define what a machine can do, and where the executables reside. The user profile sets values that can override or supplement the machineprofile

## Profiles

Important: This package currently only supplies profiles for Powershell Core (currently V7)

This package supplies two profiles and multiple settings files. One profile is for AllUsersAllHosts, and should be installed at the location as specified in `$profile.AllUsersAllHosts`. The other profile is for CurrentUserAllHosts, and should be installed at the location as specified in `$profile.CurrentUserAllHosts`.

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

## MachineName and Roles

These are stored in `global_MachineAndNodeSettings.ps1`. It should be deployed, and found, in the same directory as the machine-wide profile.

Machine Profile:

Uses its own machine name to match a machine in the list, and import those settings into the *global* scope. Then looks to see if those have additional settings to load, and loads them. Then looks into NodeAssignment to find its name, and loads those settings into *$global:settings*. Roles can use any information from the Machine $global:settings* in constructing their values

```plantuml
@start
Title: Machine profile flow
rectangle tbd
Caption: Figure 1

' ToDo: write reference diagram
@end
```

User Profile:

The development, test, documentation, reporting, distribution, deployment, monitoring, reporting, and feedback team members all have their own user profiles. The user profile here is one example, it can be altered to suit the human user's taste. However, the profile must define and set the Environment variables and $settings needed by each and every tool the human uses in heir role in producing the deliverable product.

The service accounts that are used to run the CI/CD tools have a standardized profile. The Role information loaded by the Machine profile identifies what information is expected for each tool and supplies that information for a specific machine's loadout (i.e., what tools, and how the tools have been installed into the machine that is running the service). The profile for a service reads its machine name, and gets the machine's *$global:settings*. The service profile has it's own *script:settings* file. These are the keys it needs to be content.  They are mapped to the flattened string names of the Role name and the setting, and its value. The service profile calls Get-Settings (Function defined in Machine profile), passes in the l$script:settings*, and assigns its results back into the *$script:settings*

```plantuml
@start
Title: Service profile flow
rectangle tbd
Caption: Figure 2

' ToDo: write reference diagram
@end
```

## Testing

Jenkins orchestrates the CI/CD pipeline. The resources on which stages run are named nodes. Node characteristics, and node identifiers are created in $Settings, and the node identifiers are used in Jenkins as named Nodes, which can be started and stopped. Nodes can have multiple Roles, and Roles are a set of identifiers and characteristics. The Role identifiers match Jenkins Node label value with the set #ToDo add cxref processing for the machine profile `$JenkinsNodeRoles = @('WindowsCodeBuildJenkinsNode', 'WindowsDocumentationBuildJenkinsNode')`. This cross-product does not scale well for millions of machines and thousands of Roles; the twin concepts of Locality and Connectivity can reduce this. Since this is just version 1, The testing portion of the Jenkins pipeline depends on the node label set Development, .*Test, Production, ProductionWithTracing, and the machine set has only three machines. The machine set of Ids and characteristics is regular. Small experimenters can populate the machine lists manually , and development teams should be able to automate the machine set as machines are brought online and aged-out. Automation would center around AD, and the development team should work with the AD administrative team to take full use of the Powershell cmdlets around DNS and AD that are granted to the developers.

The main purpose of the CI/CD pipeline is ensuring quality in the final product.

Testing is a great big part of this. Testing takes place across multiple OS, multiple hardware, multiple configurations and edge cases. Don't Repeat Yourself (DRY) is critical to a manageable test suite. The SCM and nonSCM pipelines have their testing stages setup inside a groovy loop that is enumerating the crossproduct of all possible values from every specific build characteristic. Version 1 of this repository uses the following  on

| `
|


## Packaging and Distribution

ToDo: Write content


## Nodes and Roles

### Roles
https://www.nuget.org/packages/PlantUmlClassDiagramGenerator
dotnet tool install --global PlantUmlClassDiagramGenerator

`JenkinsRoles.ps1` defines the different roles a machine may take on

```powershell
$JenkinsRoles = @{
DocumentationBuild = @{
DocFxExePath = docfx
JavaExePath = java
PlantUMLJarPath = tbd
}
WindowsBuild = @{}
LinuxBuild = @{}
MacOSBuild = @{}
AndroidBuild = @{}
iOSBuild = @{}
WindowsUnitTest = @{}
LinuxUnitTest = @{}
MacOSUnitTest = @{}
AndroidUnitTest = @{}
iOSUnitTest = @{}
MSSQLDataBaseIntegrationTest = @{}
MySQLDataBaseIntegrationTest = @{}
SQLiteDataBaseIntegrationTest = @{}
ServiceStackMSSQLDataBaseIntegrationTest = @{}
ServiceStackMySQLDataBaseIntegrationTest = @{}
ServiceStackSQLiteDataBaseIntegrationTest = @{}
DapperMSSQLDataBaseIntegrationTest = @{}
DapperMySQLDataBaseIntegrationTest = @{}
DapperSQLiteDataBaseIntegrationTest = @{}
EFCoreMSSQLDataBaseIntegrationTest = @{}
DynamicDataBaseIntegrationTest = @{}
SystemTextJsonSerializerIntegrationTest = @{}
NewstonsoftSerializerIntegrationTest = @{}
ServiceStackSerializerIntegrationTest = @{}
SystemTextJsonSerializerIntegrationTest = @{}
SystemTextJsonSerializerIntegrationTest = @{}
DynamicSerializerIntegrationTest = @{}
}
```

### machine level nodes

`MachineNodes.ps1` defines the machines that are part of the cooperative network used for development and production.

```powershell
$machineNodes = @{
    ncat016 = @{

     JenkinsRoles = @(DocumentationBuild, WindowsBuild, WindowsUnitTest) # add all databaseintegration roles
    }
    ncat40 = @{
     JenkinsRoles = @()
    }
    'ncat-ltjo' = @{
     JenkinsRoles = @()
    }
    'ncat-ltb1' = @{
     JenkinsRoles = @(WindowsBuild, WindowsUnitTest)
    }
    utat01 = @{
     JenkinsRoles = @(DocumentationBuild, WindowsBuild, WindowsUnitTest) # add all databaseintegration roles
    }
}

```
