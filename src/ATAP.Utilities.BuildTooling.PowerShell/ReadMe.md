# ATAP.Utilities.BuildTooling.PowerShell

If you are viewing this `ReadMe.md` in GitHub, [here is this same ReadMe on the documentation site]()

## 🗪 Test Coverage & Results

- **Coverage:** $Coverage% of code paths covered
- **Tests run:** $Total total
  - ✅ Passed: $Passed
  - ❌ Failed: $Failed
  - ⚠️ Skipped: $Skipped

## Introduction

This package provides PowerShell goodies make it easier when developing Powershell modules for .Net, and especially inside of Visual Studio Code.

## Autoloading

The .psm1 file handles dot-sourcing all the .ps1 scripts in the `private` and `public` subdirectories. But for Autoload to work, the functions and cmdlets should be listed in the .psd1 file. Here's a one-liner that will get you the function names

```Powershell

 (gci C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\*.ps1).basename -join,"','"

```

## Building/Installation Note

Production versions of the modules goes through testing and packaging, along with deployment to a local chocolatey Repository Server, from which the new production version of the package is deployed internally to the organization using Chocolatey.

When developing new functions for the module, on the developers workstation, symbolic links make it easy to have the source development files linked to the production location of the module somewhere in the `$PSModulePath`, specifically in the user's Powershell modules directory. Doing so will ensure that the latest dev code is running when the module is autoloaded.

Work great, except... PowerShell will not autoload a symlinked .psd1 file. Its OK to symlink the .psm1 file, and the `public` and `private` subdirectories of the module, you just can't symlink the .psd1 file.

Cmdlets are found in their eponymous script files

### Get-ModuleAsSymbolicLink

This function takes a module `$Name`, module `$Version`, and the `$sourcePath` to the root of the module's code. It creates a subdirectory under the user's Powershell modules' path (), for the module `$Name`, and under that a subdirectory for the `$Version`. In the `$Version` subdirectory, it creates three symbolic links, for `public` and `private` subdirectories, and the `$Name.psm1` file. It also copies any `$Name.psd1` files from the `$sourcePath` to the `$Version` subdirectory

## SymbolicLink Developing functions for Build Tooling

Create a symbolic link from the script under development, to the root of the jenkins job's workspace
After initial development, the script will be part of a new release of the module, and the symbolic link won't be needed anymore

`$env:Workspace` is the root of the Jenkins workspace, per node and per job
`$localRepoRoot` is the absolute path to the root of the local repo
`$moduleName` is the name of the Powershell Module where the script resides
`$scriptName` is the name of the script file
`$relativeScriptDirectory` is the relative path from the repo root to the directory where the script source resides

When testing, this is needed in the administrative (Elevated) PowerShell terminal:
`$env:Workspace = 'C:\JenkinsAgentNode\utat022Node\workspace\Package-PowershellModule' `
`$env:Workspace = 'D:\Jenkins\ncat016\workspace\Package-PowershellModule' `

$scriptName = 'Publish-PSPackage.ps1'; $moduleName ='ATAP.Utilities.BuildTooling.PowerShell';  $relativeScriptDirectory= join-path 'src' $ModuleName 'public';$localRepoRoot = join-path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'ATAP.Utilities'; Remove-Item -path (join-path $env:Workspace $scriptname) -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:Workspace $scriptname) -Target (join-path $localRepoRoot $relativeScriptDirectory $scriptName)

$sourceScriptName = 'Update-PackageVersion.ps1';
$sourceModuleName ='ATAP.Utilities.Buildtooling.Powershell';
$sourceRepoRoot = join-path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'ATAP.Utilities';
$targetScriptName = $sourceScriptName;
$targetScriptDirectory ='.';
$relativeScriptSourceDirectory = join-path 'src' $sourceModuleName 'public';
Remove-Item -path (join-path $targetScriptDirectory $targetScriptName) -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $targetScriptDirectory $sourceScriptName) -Target (join-path $sourceRepoRoot $relativeScriptSourceDirectory $sourceScriptName)

$scriptName = 'Update-PackageVersion.ps1'; $moduleName ='ATAP.Utilities.BuildTooling.PowerShell';  $relativeScriptDirectory= join-path 'src' $ModuleName 'public';$localRepoRoot = join-path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'ATAP.Utilities'; Remove-Item -path (join-path $env:Workspace $scriptname) -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:Workspace $scriptname) -Target (join-path $localRepoRoot $relativeScriptDirectory $scriptName)

## SymbolicLinks for Git Hooks

Script files called by Git Hooks must be in the `.git/hooks` subdirectory. (ToDo: explain why allowing arbitrary paths implies opinionated directory structures). But files here are not under SCM in the SoftwareRepository. But a symbolic link from a file somewhere in the repository (`ATAP.Utilities.BuildTooling.Powershell/public/Git-PreCommitHook.ps1`)

$scriptSourceName = 'Git-PreCommitHook.ps1'; $scriptTargetName = 'PreCommitHook.ps1'; $moduleName ='ATAP.Utilities.BuildTooling.PowerShell'; $sourceRepoRoot = join-path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'ATAP.Utilities'; $targetRepoRoot = join-path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'MSBuildPlayground';  $relativeScriptSourceDirectory = join-path 'src' $ModuleName 'public';$targetScriptDirectory = join-path $targetRepoRoot '.git' 'hooks'; Remove-Item -path (join-path $targetScriptDirectory $scriptTargetName) -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $targetScriptDirectory $scriptSourceName) -Target (join-path $sourceRepoRoot $relativeScriptSourceDirectory $scriptTargetName)

### Run this command in the .git/hooks subdirectory of the $targetRepoRoot (as administrator)

Modify arguments for $targetModuleName, $targetRepoRoot.

$targetModuleName ='ExamplePSModule';
$targetRepoRoot = join-path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'PlaygroundGitHooks';
$targetScriptDirectory = join-path $targetRepoRoot '.git' 'hooks'
$sourceModuleName ='ATAP.Utilities.Buildtooling.Powershell';
$sourceRepoRoot = join-path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'ATAP.Utilities';
  $relativeScriptSourceDirectory = join-path 'src' $sourceModuleName 'public';
(@{'scriptSourceName'='Invoke-GitPreCommitHook.ps1';'scriptTargetName' = 'Invoke-GitPreCommitHook.ps1';},
@{'scriptSourceName'='Invoke-GitPostCommitHook.ps1';'scriptTargetName' = 'Invoke-GitPostCommitHook.ps1';},
@{'scriptSourceName'='Invoke-GitPostCheckoutHook.ps1';'scriptTargetName' = 'Invoke-GitPostCheckoutHook.ps1';}) | %{$ht = $\_;
$scriptSourceName = $ht['scriptSourceName'];
$scriptTargetName = $ht['scriptTargetName'];
Remove-Item -path (join-path $targetScriptDirectory $scriptTargetName) -ErrorAction SilentlyContinue;
New-Item -ItemType SymbolicLink -path (join-path $targetScriptDirectory $scriptTargetName) -Target (join-path $sourceRepoRoot $relativeScriptSourceDirectory $scriptSourceName )
}

## Symbolic Links for VSC settings, tasks, launch configurations, and testing

### User Settings symbolic link

The `settings.json` file at (e.g) `C:\Users\<username>\AppData\Roaming\Code\User` holds the final fallback to all VSC settings. It applies to all repositories and workspaces. Every developer on a host needs to link to the organizations common settings. to do this,replace <username> with the actual user name in the following command and run it.

```Powershell
# ToDo: must get the username for the specific computer form a vault
New-SymbolicLink -targetPath `
$(Join-Path $global:settings[$global:configRootKeys['CloudBasePathConfigRootKey']] 'whertzing' `
'GitHub', 'SharedVSCode', 'UserSettings.jsonc') `
-symbolicLinkPath $(Join-Path 'C:' 'Users' 'whertzing56','AppData','Roaming','Code', 'User', 'UserSettings.jsonc') -force

```

### Repository symbolic links

The organization has multiple GIT repositories. Every repository that uses Visual Studio Code as the IDE, needs a subdirectory `.vscode`, which contains these five files

```text
Launch.json
tasks.json
settings.json
cspell.json
extensions.json
iis.json (optional)
```

This directory and these files need to be present at the root of each repository, and need to be source-controlled and versioned. Having multiple independent copies is prone to errors and misconfigurations. Therefore, we have created a repository named `SharedVSCode`, and placed the source-of-truth copies of these files in this git-versioned repository.

We then create symbolic links from the files in this repository to symblinks that reside in the .vscode directory under every other repository.

In every new repository, after running `git init`, run these commands (as an administrator) in the root folder of the repository:

```Powershell
# use a directory junction instead of individual symlinks
$null = New-Item -Path ./.vscode -ItemType Junction -Target $(Join-Path $global:settings[$global:configRootKeys['CloudBasePathConfigRootKey']] 'whertzing' 'GitHub', 'SharedVSCode', '.vscode')  # $null = New-Item -ItemType Directory -Force '.vscode'
  # # The New-SymbolicLink cmdlet is found in the ATAP.Utilities.Powershell module
  # New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.vscode\tasks.json"  -symbolicLinkPath ".\.vscode\tasks.json" -force
  # New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.vscode\launch.json"  -symbolicLinkPath ".\.vscode\launch.json" -force
  # New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.vscode\extensions.json"  -symbolicLinkPath ".\.vscode\extensions.json" -force
  # New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.vscode\cspell.json"  -symbolicLinkPath ".\.vscode\cspell.json" -force
```

## Symbolic Links for Prettier formatting rules, CSpell, eslint rules, building Powershell; modules (Invoke-Build) and Mocha

The organization has multiple GIT repositories. Every repository that uses Visual Studio Code as the IDE, needs a `.prettierrc.yml` with formatting rules and an `.eslintrc.js` with linting rules for Javascript at the repository base. We use the YAML format in order to support comments in the file.

Every repository that uses Visual Studio Code as the IDE, needs a `cspell.json` with spelling rules ToDo: We use the YAML format in order to support comments in the file.

Every Repository that creates Powershell modules in a sub-project needs a `module.build.ps1` file. We create a symbolic link in the repository root to a copy of this file that is present in the module `ATAP.Utilities.Buildtooling.Powershell`. Installing this module brings in a read-only copy of that file. We create a symbolic link to this file
ToDo: until the buildtooling package is created and installed, symlink to the source code

Every repository that uses Mocha to test Javascript code, including repositories for VSC Extensions, needs a .mocharc.mjs file.

In every new repository, after creating the .vscode directory and its contents, run this command (as an administrator) in the root folder of the repository:

```Powershell
  # The New-SymbolicLink cmdlet is found in the ATAP.Utilities.Powershell module
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.prettierrc.yml"  -symbolicLinkPath ".\.prettierrc.yml" -force
  # Every projects in a repository needs a ReadMe.md
  'ReadMe file for ' | write-file -path './ReadMe.md'

  # this command is only needed for repositories that have projects that use javascript or typescript
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.eslintrc.js"  -symbolicLinkPath ".\.eslintrc.js" -force
  # this command only for repositories that use mocha for testing JavaScript
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.mocharc.yaml"  -symbolicLinkPath ".\.mocharc.yaml" -force

```

### Additional project-specific directories

Projects are created under the 'src' directory of the repository. Projects are individual code workspaces.
Put the project name into a local setting

```Powershell
  # set the local project name
  $projectName = 'ATAP.Console.QueryChatGPT.Powershell'
  # set the local project full path

  $projectDirectory = . pwd
  # the code-workspace file
@'
{
  "folders": [
    {
      "path": "."
    }
  ],
  "settings": {
    "dotnet-test-explorer.testProjectPath": "{workspacefolder}/tests",
    "pester.pesterModulePath": "{workspacefolder}",
    "powershell.pester.codeLens": false,
    "powershell.pester.useLegacyCodeLens": false,
    "powershell.pester.outputVerbosity": "Diagnostic",
    "powershell.enableProfileLoading": true
  }
}
'@ | Out-File -FilePath "./$projectName.code-workspace" # UTF8 encoding via a parameter default
```

```Powershell
  # the subdirectory where all generated files are placed
  $null = New-Item -ItemType Directory -Force $global:settings[$global:configRootKeys['GeneratedRelativePathConfigRootKey']];
  # the subdirectory for documentation source
  $null = New-Item -ItemType Directory -Force './Documentation';
  # The following are for Powershell specific projects
  $null = New-Item -ItemType Directory -Force './public';
  $null = New-Item -ItemType Directory -Force './private';
  # Powershell tests are found as peers of powershell private and public subdirectories
  $null = New-Item -ItemType Directory -Force './tests';
  # these commands are only needed for repositories that have projects that create Powershell modules.
# ToDo: use an installed package path for the latest (?) BuildTooling.Powershell module
  New-SymbolicLink -Force -symbolicLinkPath './module.build.ps1' -targetPath $(Join-Path $global:settings[$global:configRootKeys['CloudBasePathConfigRootKey']] 'whertzing' 'GitHub', 'ATAP.Utilities','src','ATAP.Utilities.BuildTooling.PowerShell','module.build.ps1');
  New-SymbolicLink -Force -symbolicLinkPath './tests/PesterConfiguration.psd1' -targetPath  $(Join-Path $global:settings[$global:configRootKeys['CloudBasePathConfigRootKey']] 'whertzing' 'GitHub', 'SharedVSCode', 'PesterConfiguration.psd1')
  $null = New-Item -ItemType Directory -Force './Releases';
  "ReadMe file for $projectName" | Out-File -FilePath './ReadMe.md'
  "Release Notes file for $projectName" | Out-File -FilePath './ReleaseNotes.md'
# Create the development .psm1 file
# ToDo: Make this a template somewhere...
@'
# ToDo : Module comment-based help

# get the fileIO info for each file in the public and private subdirectories
$publicFunctions = @(Get-ChildItem -Path $PSScriptRoot\public\*.ps1 -ErrorAction SilentlyContinue)

$privateFunctions = @(Get-ChildItem -Path $PSScriptRoot\private\*.ps1 -ErrorAction SilentlyContinue)
$allFunctions = $publicFunctions + $privateFunctions
# Dot-source the public and private files.
foreach ($import in $allFunctions) {
    try {
        Write-Verbose "Importing $($import.FullName)"
        . $import.FullName
    } catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}
# list the public cmdlet and function names for including into a .psd1 file (ToDo: automate the .psd1 file creation as part of the CI/CD/CD pipeline)
# list the private cmdlet names for including into a .psd1 file (ToDo: automate the .psd1 file creation as part of the CI/CD/CD pipeline)
'@ |Out-File -FilePath "./$projectName.psm1"

# module manifest file ().psd1 file)
# a new guid in the proper format for a .psd1 file
$newGuid = [Guid]::NewGuid().ToString().ToUpper()
# ToDo: make this come ro a template somewhere
@"
#
# Module manifest for module 'ATAP.Utilities.Powershell'

@{

# Script module or binary module file associated with this manifest.
RootModule = "$projectName.psm1"

# Version number of this module.
ModuleVersion = '0.0.1'

# Supported PSEditions
CompatiblePSEditions = 'Desktop', 'Core'

# ID used to uniquely identify this module
GUID = $newGuid

# Author of this module
Author = 'Bill Hertzing for ATAPUtilities.org'

# Company or vendor of this module
CompanyName = 'ATAPUtilities.org'

# Copyright statement for this module
Copyright = '(c) 2018 - 2025  Bill Hertzing . All rights reserved. All code is under the MIT license'

# Description of the functionality provided by this module
# Description = ''

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = '*'

# Cmdlets to export from this module
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        # Tags = @()

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        # ProjectUri = ''

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

        # Prerelease string of this module
        # Prerelease = 'Alpha001'

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

"@ |Out-File -FilePath "./$projectName.psd1"

```

### project-specific symbolic links

#### VSC Extension development symbolic links

Place these symbolic links in the .vscode subdirectory of any project that builds a VSC extension.

```Powershell
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.vscode\launch4Extension.jsonc"  -symbolicLinkPath ".\.vscode\launch.json" -force
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.vscode\tasks4Extension.jsonc"  -symbolicLinkPath ".\.vscode\tasks.json" -force
```

## Symbolic Links and cloud-synchronization

The ATAP organizations use Dropbox to sync development environments across desktops and laptops. Dropbox DOES NOT sync symbolic links. The current workaround is to ensure that symbolic links are created, manually, on every host participating in the development environment.

ToDO: Use Ansible to ensure creation, update, and removal of symbolic links occur on all hosts that participate in the development process
