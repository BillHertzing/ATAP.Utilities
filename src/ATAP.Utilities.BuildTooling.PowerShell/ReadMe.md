# ATAP.Utilities.BuildTooling.PowerShell

If you are viewing this `ReadMe.md` in GitHub, [here is this same ReadMe on the documentation site]()

## Introduction

This package provides PowerShell goodies make it easier when developing for .Net, and especially inside of Visual Studio.

## Autoloading

The .psm1 file handles dot-sourcing all the .ps1 scripts in the `private` and `public` subdirectories. But for Autoload to work, the functions and cmdlets should be listed in the .psd1 file. Here's a one-liner that will get you the function names

` (gci C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\*.ps1).basename -join,"','"`

## Building/Installation Note

Production versions of the modules goes through testing and packaging, along with deployment to a local chocolatey Repository Server, from which the new production version of the package is deployed internally to the organization using Chocolatey.

When developing new functions for the module, symbolic links make it easy to have the source development files linked to the production location of the module somewhere in the `$PSModulePath`, specifically in the user's Powershell modules directory. Doing so will ensure that the latest dev code is running when the module is autoloaded.

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

Script files called by Git Hooks must be in the `.git/hooks` subdirectory. (ToDo: explain why allowing arbitrary paths implies opinionated directory structures). But files here are not under SCM in the repository. But a symbolic link from a file somewhere in the repository (`ATAP.Utilities.BuildTooling.Powershell/public/Git-PreCommitHook.ps1`)

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

## Symbolic Links for VSC settings, tasks, launch configurations

### User Settings symbolic link

The `settings.json` file at (e.g) `C:\Users\<username>\AppData\Roaming\Code\User` holds the final fallback to all VSC settings. It applies to all repositories and workspaces. Every developer on a host needs to link to the organizations common settings. to do this, run the following command:

```Powershell

New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\UserSettings.jsonc" -symbolicLinkPath "C:\Users\<username>\AppData\Roaming\Code\User\settings.json" -force

```

### Repository symbolic links

The organization has multiple GIT repositories. Every repository that uses Visual Studio Code as the IDE, needs a subirecory `.vscode`, which contains the three files

```text
Launch.json
tasks.json
settings.json
```

This directory and these files need to be present at the root of each repository, and need to be source-controlled and versioned. Having multiple independent copies is prone to errors and misconfigurations. Therefore, we have created a repository named `SharedVSCode`, and placed the source-of-truth copies of these files in this git-versioned repository.

We then create symbolic links from the files in this repository to symblinks that reside in the .vscode directory under every other repository.

In every new repository, after runing `git init`, run these commands (as an administrator) in the root folder of the repository:

```Powershell
  $null = New-Item -ItemType Directory -Force '.vscode'
  # The New-SymbolicLink cmdlet is found in the ATAP.Utilities.Powershell module
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.vscode\extensions.json"  -symbolicLinkPath ".\.vscode\extensions.json" -force
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.vscode\tasks.json"  -symbolicLinkPath ".\.vscode\tasks.json" -force
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.vscode\cspell.json"  -symbolicLinkPath ".\.vscode\cspell.json" -force
```

## Symbolic Links for Prettier formatting rules, CSpell, eslint rules

The organization has multiple GIT repositories. Every repository that uses Visual Studio Code as the IDE, needs a `.prettierrc.yml` with formatting rules and an `eslintrc.yml` with linting rules for Javascript at the repository base. We use the YAML format in order to support comments in the file.

Every repository that uses Visual Studio Code as the IDE, needs a `cspell.json` with spelling rules ToDo: We use the YAML format in order to support comments in the file.

In every new repository, after creating the .vscode directory and its contents, run this command (as an administrator) in the root folder of the repository:

```Powershell
  # The New-SymbolicLink cmdlet is found in the ATAP.Utilities.Powershell module
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.prettierrc.yml"  -symbolicLinkPath ".\.prettierrc.yml" -force
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.eslintrc.js"  -symbolicLinkPath ".\.eslintrc.js" -force
```

### project-specific symbolic links

#### VSC Extension development symbolic links

Place these symbolic links in the .vscode subdirecotry of any project that builds a VSC extension.

```Powershell
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.vscode\launch4Extension.jsonc"  -symbolicLinkPath ".\.vscode\launch.json" -force
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.vscode\tasks4Extension.jsonc"  -symbolicLinkPath ".\.vscode\tasks.json" -force
```

## Symbolic Links and cloud-synchronization

The ATAP organizations use Dropbox to sync development environments across desktops and laptops. Dropbox DOES NOT sync symbolic links. The current workaround is to ensure that symbolic links are created, manually, on every host participating in the development environment.

ToDO: Use Ansible to ensure creation, update, and removal of symbolic links occur on all hosts that participate in the development process
