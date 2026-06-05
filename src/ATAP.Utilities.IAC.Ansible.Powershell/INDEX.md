# ATAP.Utilities.IAC.Ansible.PowerShell — Script Index

PowerShell module for generating and managing Ansible IAC artifacts: directory structures, playbooks, roles, and host inventory for Windows-based infrastructure. Integrates with the ATAP IAC `.dll` library (Enumerations, Interfaces, Models, StringConstants) and the `$global:settings` configuration system.

---

## Diagrams

Editable diagram sources live under `Documentation/`. Generated images are
written under
`_generated/diagrams/src/ATAP.Utilities.IAC.Ansible.Powershell/Documentation`.
Regenerate them from the repository root with `Convert-DiagramsToImages`; see
[`SolutionDocumentation/Generated-Diagram-Pipeline.md`](../../SolutionDocumentation/Generated-Diagram-Pipeline.md)
for the exact command and renderer prerequisites.

- [`Documentation/Overview.drawio`](Documentation/Overview.drawio) — module
  structure and data flow.
- [`Documentation/GenerateAnsibleDirectory.drawio`](Documentation/GenerateAnsibleDirectory.drawio)
  — Ansible directory generation lifecycle.
- [`Documentation/UML/Proget Feeds.uml`](Documentation/UML/Proget%20Feeds.uml)
  — ProGet feed relationships.

---

## Public Scripts (`public/`)

44 scripts. Naming conventions: `New-Role*` create Ansible role directory structures, `Role*` generate Ansible YAML content via StringBuilder, `Scriptblock*` are helpers (private), `Get-Chocolatey*` inspect installed packages, `Test-*` return boolean results.

| Script                                                 | Description                                                                                                                                                                                                                              |
| ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `BuildServerTasks.ps1`                                 | Returns YAML heredoc template listing Ansible task prerequisites for setting up a build server (lint, compile, link, test, package, sign, deploy)                                                                                        |
| `Create-AnsibleDirectory.ps1`                          | Creates a single Ansible directory; uses `ATAP.IAC.Ansible` namespace; reads inventory from filesystem (`FromFilesystem`) or vault parameter sets; dotsources `convertFromYamlWithErrorHandling` helper                                  |
| `Create-AnsibleDirectoryStructure.ps1`                 | Creates the full Ansible directory structure for IAC per [charlesreid1 layout](https://charlesreid1.com/wiki/Ansible/Directory_Layout/Details); loads `ATAP.IAC.Ansible.dll`; dotsources `New-PlaybooksTop.ps1`                          |
| `Get-AnsibleBuildoutInventory.ps1`                     | _(stub)_ Placeholder with standard `.SYNOPSIS` template — not yet implemented                                                                                                                                                            |
| `Get-AnsibleCertificates.ps1`                          | Retrieves Ansible-managed certificates for named computers; supports KeePass, SecretStore, or HashiCorp vault parameter sets                                                                                                             |
| `Get-AnsibleVaultFromPowershellVault.ps1`              | _(stub)_ Placeholder with standard `.SYNOPSIS` template — not yet implemented                                                                                                                                                            |
| `Get-ChocolateyInstalledPackages.ps1`                  | Alias `Get-ChocoInstalledPackages`; retrieves installed Chocolatey packages from on-host path files or remote computers; filters `.install` suffix packages                                                                              |
| `Get-ChocolateyPackagesFromAnsibleInventoryObject.ps1` | Reads Ansible inventory object (from a dotsourced script), extracts `ChocolateyPackageNames` across all groups, deduplicates, writes and returns sorted list                                                                             |
| `Get-ChocolateyPackagesNeedingUpdate.ps1`              | Parses `choco outdated` output; returns objects with `Id`, `Version`, `AvailableVersion`, `Pinned` fields                                                                                                                                |
| `Get-DropboxSelectiveSyncConflicts.ps1`                | Scans `C:\Dropbox` for folders with `SelectiveSync` in their name; returns hashtable of conflict folder + original folder pairs                                                                                                          |
| `Get-HostSettings.ps1`                                 | _(stub)_ Placeholder with standard `.SYNOPSIS` template — not yet implemented                                                                                                                                                            |
| `Get-IACReport.ps1`                                    | Inline script gathering infrastructure report data: inventory paths, services registry scan (`HKLM:\SYSTEM\CurrentControlSet\Services`), PS interpreter info, profile files, environment variables                                       |
| `Get-ServicePathBin.ps1`                               | Retrieves `Win32_Service.PathName` for one or more named services via CIM; returns `{ServiceName, PathName}` objects; logs errors via PSFMessage                                                                                         |
| `host_vars.ps1`                                        | Generates Ansible `host_vars` YAML files from a template, a directory path, and a names list; uses `StringBuilder`; defines vars, encrypted vars folder structure                                                                        |
| `MapUserShellFoldersToDropBox.ps1`                     | Maps Windows User Shell Folders (Documents, Favorites, Music, Photos, Videos, Downloads) to Dropbox-relative paths via `HKCU\…\User Shell Folders` registry keys                                                                         |
| `New-CheckForNewPackagesStartupTask.ps1`               | Creates a scheduled task (AtStartup + 5 min delay, repeating every 6 hours) to check ProGet feeds for new packages and send email notifications; depends on `Register-StartupScheduledTask`                                              |
| `New-PlaybookInfrastructureReporting.ps1`              | Generates Ansible playbook YAML for infrastructure reporting (GatherRegistrySettings, etc.) from parsed inventory and SwCfgInfos hashtable; uses SharedStringBuilder                                                                     |
| `New-PlaybooksNamed.ps1`                               | _(stub)_ Placeholder with standard `.SYNOPSIS` template — not yet implemented                                                                                                                                                            |
| `New-PlaybooksTop.ps1`                                 | _(stub)_ Placeholder with standard `.SYNOPSIS` template — not yet implemented                                                                                                                                                            |
| `New-Role.ps1`                                         | Creates an Ansible role directory structure; takes `roleName` and `template` parameters; uses namespace `ATAP.IAC.Ansible`                                                                                                               |
| `New-RoleAuthenticatedPKIHostWindows.ps1`              | Creates Ansible role to configure a Windows host as an authenticated participant in the organization's PKI                                                                                                                               |
| `New-RoleDittoClipboardManagerWindows.ps1`             | Creates Ansible role to install and configure Ditto Clipboard Manager on Windows                                                                                                                                                         |
| `New-RoleJavaInterpreterWindows.ps1`                   | Creates Ansible role to install Java Interpreter on Windows                                                                                                                                                                              |
| `New-RoleJenkinsControllerWindows.ps1`                 | Creates Ansible role to install and configure Jenkins Controller on Windows                                                                                                                                                              |
| `New-RoleProGetPackageRepositoryProviderWindows.ps1`   | Creates Ansible role to install and configure ProGet Package Repository Provider on Windows                                                                                                                                              |
| `New-RolePythonInterpreterWindows.ps1`                 | Creates Ansible role to install Python Interpreter on Windows                                                                                                                                                                            |
| `New-RoleRubyInterpreterWindows.ps1`                   | Creates Ansible role to install Ruby Interpreter on Windows                                                                                                                                                                              |
| `OS_WindowsTasksCreate.ps1`                            | Returns YAML heredoc of Ansible tasks for Windows OS setup: WinRM, network, firewall, PS profiles, package management, SSH server/client, secrets management, Hashicorp vault, Certificate Authority, user security roles, Jenkins agent |
| `OS_WindowsTemplatesCreate.ps1`                        | Creates a `sample.conf.j2` Jinja2 template file for use in Windows OS Ansible templates                                                                                                                                                  |
| `PlaybookAnsibleSetup.ps1`                             | Generates Ansible playbook YAML to set up an Ansible Controller on a WSL2 container in a Windows host; builds content via `StringBuilder`                                                                                                |
| `RoleChocolateyInstallAndConfigure.ps1`                | Generates Ansible role tasks YAML to install Chocolatey via `win_chocolatey` and configure it via `win_dsc` (`cChocoConfig`)                                                                                                             |
| `RoleFeatureDefender.ps1`                              | Generates Ansible role tasks YAML to query Windows Defender services state using `ansible.windows.win_powershell` / `pwsh.exe`                                                                                                           |
| `RoleFeatureDefenderScript.ps1`                        | Standalone script: queries Windows Defender-related services from `HKLM:\SYSTEM\CurrentControlSet\Services`; outputs JSON with Name, Start, Description                                                                                  |
| `RoleFeatureSSH.Server.ps1`                            | Generates Ansible role tasks YAML to install and configure OpenSSH Server on Windows; uses `ContentsTask` helper                                                                                                                         |
| `RoleJenkinsAgentWindows.ps1`                          | Generates Ansible role files (meta, templates, tasks via StringBuilder) for Jenkins Agent on Windows                                                                                                                                     |
| `RolePKICertificationAuthority.ps1`                    | Generates Ansible role for PKI Certification Authority on Windows; uses StringBuilder for role content generation                                                                                                                        |
| `Set-Autounattend.ps1`                                 | _(stub)_ Populates a Windows `autounattend.xml` from a template with organizationName, computerName, WindowsBaseVersion; accepts secrets for WindowsProductKey                                                                           |
| `Set-ServicePathBin.ps1`                               | Sets Windows service `binPath` via `sc.exe config`; supports `-WhatIf`; reports success or failure via PSFMessage                                                                                                                        |
| `Test-ChocoPackageUpdatesFromYaml.ps1`                 | Tests whether Chocolatey packages defined in a YAML file need updates; supports `ByPath` and `ByHandle` (stream) parameter sets; supports `-WhatIf`                                                                                      |
| `Test-ServiceBinPath.ps1`                              | Tests whether a Windows service's `PathName` (command line) matches a regex pattern; returns `$true`/`$false`                                                                                                                            |
| `Update-ChocolateyPackageInfo.ps1`                     | Reads existing package info from `chocolateyPackageInfoPath` (YAML) and reconciles it against currently installed packages from on-host files or remote computers                                                                        |
| `Validate-WakeTimersEnabled.ps1`                       | _(WIP)_ Validates wake timers setting for each power plan via `powercfg /q`; AC/DC distinction complicates resolution; returns hashtable of plan → enabled state                                                                         |
| `WebServersfiles.ps1`                                  | Returns DSC-based web server configuration YAML content (IIS install via `PSDesiredStateConfiguration`/`WindowsFeature`)                                                                                                                 |
| `WebServerstasks.ps1`                                  | Returns Ansible tasks YAML to copy a DSC configuration script to the target system                                                                                                                                                       |

---

## Private Scripts (`private/`)

15 files. The `Scriptblock*` helpers are dispatched by convention from `RoleComponentTask` (the function name is derived from the play's `Kind` field by replacing `AnsiblePlayBlock` with `Scriptblock`).

| File                                          | Description                                                                                                                                                                          |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Get-ChocolateyPackagesScriptBlock.ps1`       | _(stub)_ Placeholder with standard `.SYNOPSIS` template — not yet implemented                                                                                                        |
| `InstalledChocolateyPackages.json`            | JSON data file: reference inventory of installed Chocolatey packages for validation                                                                                                  |
| `New_ExampleHostCompleteBuildoutPlaybook.yml` | Example Ansible YAML playbook for a complete host buildout (reference/template)                                                                                                      |
| `Rebuild-Chocolatey.ps1`                      | Parses `ApprovedChocolateyPackagesInfo.yml` and Ansible playbook YAML to discover package list; installs latest version of each via `choco install`; supports `-WhatIf`              |
| `RoleComponentMeta.ps1`                       | `RoleComponentMeta` function: generates `galaxy_info` YAML block (`author`, `company`, `role_name`, `license`, `min_ansible_version`, `dependencies`) for an Ansible role            |
| `RoleComponentTask.ps1`                       | `RoleComponentTask` function: iterates `playInfos`, dispatches to matching `Scriptblock*` function by naming convention; passes name, items, tagnames, StringBuilder                 |
| `ScriptblockChocolateyPackages.ps1`           | `ScriptblockChocolateyPackages` function: generates `win_chocolatey` Ansible task YAML loop for a list of package items                                                              |
| `ScriptblockCopyFiles.ps1`                    | `ScriptblockCopyFiles` function: generates `win_copy` Ansible task YAML for file copy operations with `loop`                                                                         |
| `ScriptblockPinToTaskbar.ps1`                 | `ScriptblockPinToTaskbar` function: generates Ansible task YAML to pin items to Windows taskbar via `ansible.windows.win_powershell` / `pwsh.exe`                                    |
| `ScriptblockRegistrySettings.ps1`             | `ScriptblockRegistrySettings` function: generates `win_regedit` Ansible task YAML with a `loop` over registry setting items (path, name, data, type)                                 |
| `ScriptblockShortcut.ps1`                     | `ScriptblockShortcut` function: generates Ansible task YAML to create Windows shortcuts via `ansible.windows.win_powershell`                                                         |
| `ScriptblockSymbolicLinks.ps1`                | `ScriptblockSymbolicLinks` function: generates Ansible task YAML to create symbolic links via `New-Item -ItemType SymbolicLink` on remote Windows hosts                              |
| `ScriptblockUserWindows.ps1`                  | `ScriptblockUserWindows` function: generates `ansible.windows.win_user` task YAML for Windows user management (username, fullname, description, groups, password)                    |
| `SubstituteConfigRootKey.ps1`                 | `SubstituteConfigRootKey` function: replaces `$global:configRootKeys['key']` literal references with their resolved values in a string                                               |
| `Validate-ChocolateyPackages.ps1`             | Compares `InstalledChocolateyPackages.json` expected package list against actually installed Chocolatey packages; reports missing, unexpected, and forbidden packages via PSFMessage |

---

## Tests (`tests/Unit/`)

| File                                              | Description                                                                                                                          |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `ATAP.Utilities.IAC.Ansible.Powershell.Tests.ps1` | Pester V5 general module test file; installs Assert module (`Install-Module -Name Assert -Force`); uses `namespace ATAP.IAC.Ansible` |

---

## Playbooks (`Playbooks/`)

Sample and utility Ansible YAML playbooks for direct use or reference.

| File                                    | Description                                                   |
| --------------------------------------- | ------------------------------------------------------------- |
| `7ZipPresent.yml`                       | Verifies or ensures 7-Zip is present on target hosts          |
| `GetDateFromRemote.yml`                 | Retrieves current date/time from remote hosts                 |
| `GetPowershellInformation.yml`          | Gathers PowerShell version and module information from hosts  |
| `InstallOrUpdateChocolateyPackages.yml` | Installs or updates Chocolatey packages on Windows hosts      |
| `InstallOrUpdatePS7Modules.yml`         | Installs or updates PowerShell 7 modules on Windows hosts     |
| `PowershellHelloWorld.yml`              | Minimal hello-world playbook executed via PowerShell          |
| `refresh-hostfile-pause-1min2.yml`      | Refreshes the host file on targets with a 1-minute pause step |
| `Win_EnvironmentTest1.yml`              | Windows environment connectivity and state test playbook      |

---

## lib (`lib/`)

Compiled .NET assemblies providing the IAC Ansible type system consumed by PS scripts via `Add-Type`.

| Assembly                                         | Description                                      |
| ------------------------------------------------ | ------------------------------------------------ |
| `ATAP.Utilities.IAC.Ansible.Enumerations.dll`    | Enumeration types for IAC Ansible domain model   |
| `ATAP.Utilities.IAC.Ansible.Interfaces.dll`      | Interface contracts for IAC Ansible domain model |
| `ATAP.Utilities.IAC.Ansible.Models.dll`          | Concrete model classes for IAC Ansible domain    |
| `ATAP.Utilities.IAC.Ansible.StringConstants.dll` | String constant definitions for IAC Ansible      |

---

## Resources (`Resources/`)

Reference data files, templates, and default configuration YAML used by the module's generation scripts.

| File                                                | Description                                                                           |
| --------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `AnsibleAdminFirstLogonScript.ps1`                  | PowerShell script for Ansible admin user first-logon initialization                   |
| `ATAP autounattend for utat022 win 11 Template.xml` | Windows 11 Autounattend XML template for unattended OS installation on host `utat022` |
| `DefaultAnsibleRolesInfo.yml`                       | Default Ansible roles information YAML — baseline role inventory                      |
| `DefaultChocolateyPackagesInfo.yml`                 | Default Chocolatey packages information YAML — baseline package inventory             |
| `DefaultPowershellModulesInfo.yml`                  | Default PowerShell modules information YAML — baseline PS module inventory            |
| `DefaultRegistrySettingsInfo.yml`                   | Default registry settings information YAML — baseline registry configuration          |
| `DefaultWindowsFeaturesInfo.yml`                    | Default Windows features information YAML — baseline Windows feature set              |

---

## Documentation (`Documentation/`)

| File                                         | Description                                                                                                                                                                                       |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GenerateAnsibleDirectory.drawio`            | Draw.io diagram illustrating Ansible directory generation process                                                                                                                                 |
| `Overview.drawio`                            | Draw.io overview diagram of the IAC Ansible module architecture                                                                                                                                   |
| `Starting an organization infrastructure.md` | Architecture doc: initializing a new computer in the organization's infrastructure; describes Ansible controller setup, WSL2, and how IAC data + PS module interact to generate the Ansible image |
| `toc.yml`                                    | Documentation table of contents                                                                                                                                                                   |
| `UML/Proget Feeds.uml`                       | UML diagram for ProGet feed relationships                                                                                                                                                         |

---

## Module Root Files

| File                                                                 | Description                                                                                                                                                      |
| -------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ATAP.Utilities.IAC.Ansible.PowerShell.psd1`                         | Module manifest: exports, dependencies, GUID, version                                                                                                            |
| `ATAP.Utilities.IAC.Ansible.PowerShell.psm1`                         | Module root: dot-sources public and private scripts                                                                                                              |
| `Module.Build.ps1`                                                   | Module build script                                                                                                                                              |
| `ReadMe.md`                                                          | IAC Ansible concept overview: IAC using Ansible for managing organization Windows hosts; relationship to ATAP project database; Ansible controller setup on WSL2 |
| `Summary of instructions to remove and reinstall Ubuntu on WSL2.txt` | Plain-text step-by-step instructions for removing and reinstalling Ubuntu on WSL2                                                                                |
| `version.json`                                                       | Module semantic version definition                                                                                                                               |

---

## Scripts Without Dedicated Tests

All 44 public scripts and 15 private scripts currently lack dedicated individual test files. The only test file (`ATAP.Utilities.IAC.Ansible.Powershell.Tests.ps1`) is a general module-level test stub.

Scripts most likely to benefit from test coverage (complex logic or PSFMessage/ShouldProcess patterns):

- `Get-ChocolateyInstalledPackages.ps1`
- `Get-ChocolateyPackagesNeedingUpdate.ps1`
- `Get-DropboxSelectiveSyncConflicts.ps1`
- `Get-ServicePathBin.ps1`
- `Set-ServicePathBin.ps1`
- `SubstituteConfigRootKey.ps1`
- `Test-ChocoPackageUpdatesFromYaml.ps1`
- `Test-ServiceBinPath.ps1`
- `Update-ChocolateyPackageInfo.ps1`
- `Validate-ChocolateyPackages.ps1`
