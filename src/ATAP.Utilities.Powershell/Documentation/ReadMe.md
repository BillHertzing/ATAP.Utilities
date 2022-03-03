# ReadMe for the ATAP.Utilities.Powershell Concept Documentation

## Overview

Profiles define the environment in which a powershell process executes. The machine profile sets values that are applicable for a specific machine. The user profile sets values that can override or supplement the machine profile on a per user basis. The profiles in the ATAP.Utilities.Powershell module, and the two `global` files, setup the environments for developer computers and computers that participate in the ATAP CI/CD pipeline

## Profiles

Important: This package currently only supplies profiles for Powershell Core (currently V7).

This package supplies multiple profiles and multiple settings files. One profile is for AllUsersAllHosts, and should be installed at the location as specified in `$profile.AllUsersAllHosts`. The other profile, CurrentUserAllHosts, is for a developer's computer, and should be installed for a developer user on the computer at the location as specified in `$profile.CurrentUserAllHosts`. Additional profiles for service accounts used in the CI/CD pipline should be installed to the service account's root folder, to setup the service account's profile

Important: Location of CurrentUserAllHosts will not always be at `~`. Sometimes a user will have moved their Documents folder from the default location. To determine the location of the user's Documents folder, use `[Environment]::GetFolderPath("MyDocuments")`

Location of `Program Files` may not always be at `C:\`. To determine the location of `Program Files`, use `$env:ProgramFiles`

| OS | Profile | Default location |
--- | --- | ---
| Windows 10/11 64bit | AllUsersAllHosts | join-path [Environment]::GetEnvironmentVariable('ProgramFiles') 'PowerShell' '7' 'profile.ps1' |
| Windows 10/11 64bit | CurrentUserAllHosts | join-path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell' 'Profile.ps1' |

### Using the profiles in this package

1) Install the ATAP.Utilities.Powershell package ([ATAP Powershell Module Installation](TBD link to anchor point))
1) Configure the `global_MachineAndNodeSettings.ps1` ([Machine and Node Settings](TBD link to anchor point`))
1) Test the AllUsersAllHosts profile with the new configuration ([Testing the machine profile and global settings[(TBD)])

    **always test them first in a safe environment (non-admin, firewalled, virus and malware detectors running).**
1) Copy the following files to the `$profile.AllUsersAllHosts` directory:

  a) `AllUsersAllHostsV7CoreProfile.ps1`

  a) `global_ConfigRootKeys.ps1`

  a) `global_MachineAndNodeSettings.ps1`

  a) `global_EnvironmentVariables.ps1`

1) Test the Developer's profile ([Testing the machine profile and global settings[(TBD)])
1) Copy `CurrentUserAllHostsV7CoreProfile.ps1` to (join-path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell' 'Profile.ps1')

Start new powershell sessions and validate the `Env:` values and the `global:settings` values are correct for the machine and user. Once they are correct and mirror the actual computer configuration, the development and CI/CD process for an ATAP-based app should 'just work'

#### Using Symbolic links instead of copying

If a developer is modifying these profile and settings files (and they are in a Git repository) it is easier to create a symbolic link at the desired subdirectory pointing back to the target files in the git repository. These Powershell one-liners will create the necessary symbolic links. Note the use of Join-path for all the full path names, to support both Windows and *nix

- ToDo: continue rework to support both windows and Linux
- ToDo: move into a function that will accept a -force, and have the function error if the profile already exists and -force is not specified, also include `-whatif`

- `Remove-Item -path (join-path ([Environment]::GetFolderPath("MyDocuments")) 'PowerShell' 'Microsoft.PowerShell_profile.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path ([Environment]::GetFolderPath("MyDocuments")) 'PowerShell' 'Microsoft.PowerShell_profile.ps1')  -Target (join-path ([Environment]::GetFolderPath("MyDocuments")} 'GitHub' 'ATAP.Utilities' 'src' 'ATAP.Utilities.PowerShell' 'profiles' 'CurrentUserAllHostsV7CoreProfile.ps1')`

- `Remove-Item -path (join-path $env:ProgramFiles 'PowerShell' '7' 'profile.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:ProgramFiles  'PowerShell' '7' 'profile.ps1') -Target (join-path ([Environment]::GetFolderPath("MyDocuments")} 'GitHub' 'ATAP.Utilities' 'src' 'ATAP.Utilities.PowerShell' 'profiles' 'AllUsersAllHostsV7CoreProfile.ps1')`

- `Remove-Item -path (join-path $env:ProgramFiles 'PowerShell' '7' 'global_ConfigRootKeys.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:ProgramFiles  'PowerShell' '7' 'global_ConfigRootKeys.ps1') -Target (join-path ([Environment]::GetFolderPath("MyDocuments")} 'GitHub' 'ATAP.Utilities' 'src' 'ATAP.Utilities.PowerShell' 'profiles' 'global_ConfigRootKeys.ps1')`

- `Remove-Item -path (join-path $env:ProgramFiles 'PowerShell' '7' 'global_MachineAndNodeSettings.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:ProgramFiles  'PowerShell' '7' 'global_MachineAndNodeSettings.ps1') -Target (join-path -path ([Environment]::GetFolderPath("MyDocuments")) -ChildPath 'GitHub' -AdditionalChildPath  @('ATAP.Utilities','src','ATAP.Utilities.PowerShell','profiles','global_MachineAndNodeSettings.ps1'))`

- `Remove-Item -path (join-path ($env:ProgramFiles) 'PowerShell' '7' 'global_EnvironmentVariables.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:ProgramFiles 'PowerShell' '7' 'global_EnvironmentVariables.ps1') -Target (join-path ([Environment]::GetFolderPath("MyDocuments")) 'GitHub' 'ATAP.Utilities' 'src' 'ATAP.Utilities.PowerShell' 'profiles' 'global_EnvironmentVariables.ps1')`


## MachineName and Roles

These are stored in `global_MachineAndNodeSettings.ps1`. It should be deployed, and found, in the same directory as the machine-wide profile. The purpose is to identify all of the machines used in the CI/CD pipeline for any ATAP-based application, identify the role of each machine in the pipeline, and specify the locations of the software components used for each role on that specific machine.

The `global_MachineAndNodeSettings.ps1` is a hash table keyed by `$env:COMPUTERNAME]`.

The `global_MachineAndNodeSettings.ps1` is dot-sourced into the `AllUsersAllHostsV7CoreProfile.ps1`. Then the `AllUsersAllHostsV7CoreProfile.ps1` process the hash table entry for its own `$env:COMPUTERNAME]`, setting up all `global:settings` entries and `ENV:` variables to be used by the processes identified by the roles to which the machine is assigned. After this is done, every CI/CD step should be able to find the information it needs to run on that specific machine

### Machine Profile

Uses its own machine name to match a machine in the list, and import those settings into the *global* scope. Then looks to see if those have additional settings to load, and loads them. Then looks into NodeAssignment to find its name, and loads those settings into the `$global:settings` hash. Roles can use any information from the `$global:settings` configured by the Machine profile in constructing their values

```plantuml
@start
Title: Machine profile flow
rectangle tbd
Caption: Figure 1

' ToDo: write reference diagram
@end
```

### User Profile

The development, test, documentation, reporting, distribution, deployment, monitoring, reporting, and feedback team members all have their own user profiles. The user profile here is one example, it can be altered to suit the human user's taste. However, the profile must define and set the Environment variables and $global:settings needed by each and every tool the human uses in heir role in producing the deliverable product.

The service accounts that are used to run the CI/CD tools have a standardized profile. The Role information loaded by the Machine profile identifies what information is expected for each tool and supplies that information for a specific machine's loadout (i.e., what tools, and how the tools have been installed into the machine that is running the service). The profile for a service reads its machine name, and gets the machine's *$global:settings*. The service profile has it's own *script:settings* file. These are the keys it needs to be content.  They are mapped to the flattened string names of the Role name and the setting, and its value. The service profile calls Get-Settings (Function defined in Machine profile), passes in the l$script:settings*, and assigns its results back into the *$script:settings*

```plantuml
@start
Title: Service profile flow
rectangle tbd
Caption: Figure 2

' ToDo: write reference diagram
@end
```

### Setting Up Environment Variables

Environment variables required by the application developer and the CI/CD pipeline processes are defined in the file `global_EnvironmentVariables.ps1`, which is placed in the machine profile location. This file defines a hash `$global:envVars`. each element defines a environment variable name and value. This file is dot-sourced at the END of the USER profile, and sets up the environment variables according to the current values in the `$global:settings` hash.

The machine-wide profile provides a function `Write-EnvironmentVariables` which will show all the Environment variables. [Todo: By default it shows Environment variables defined at the `Process` scope, but can be overriden to show `Machine`, `User`, `Process`, or any combination of those scopes]

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

## Public Functions and Cmdlets

### Add-BlogPostImages

This function created resized files appropriate for MediaQueries, and then creates DropBox links (sharing links) to the files

The Dropbox access token must be set in the environment for the dropbox link creation to work

[System.Environment]::SetEnvironmentVariable('DropBoxAccessToken','<paste token here>',[System.EnvironmentVariableTarget]::User)
```
