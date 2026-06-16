# PowerShell Files Needing Fix

## Files in \*Powershell/public|private without a top-level function

> **ConfigRootKeys module — FIXED (Sprint 0009, Task 9.24).** The four
> `*.ConfigRootKeys.ps1` fragment files below were renamed to eponymous
> `Set-*ConfigRootKeys` advanced functions, the fragment-discovery practice was
> removed in favor of explicit ordered invocation, and an in-module sibling-resolution
> guard was added. See
> `src/ATAP.Utilities.ConfigRootKeys.Powershell/INDEX.md` and
> `SolutionDocumentation/ConfigRootKeys-and-HostSettings.md`.
>
> - ~~`...\ATAP.Utilities.ConfigRootKeys.Powershell\public\BuildMaster.ConfigRootKeys.ps1`~~ → `Set-BuildMasterConfigRootKeys.ps1`
> - ~~`...\ATAP.Utilities.ConfigRootKeys.Powershell\public\Databases.AceCommander.ConfigRootKeys.ps1`~~ → `Set-DatabasesAceCommanderConfigRootKeys.ps1`
> - ~~`...\ATAP.Utilities.ConfigRootKeys.Powershell\public\Databases.ATAPUtilities.ConfigRootKeys.ps1`~~ → `Set-DatabasesATAPUtilitiesConfigRootKeys.ps1`
> - ~~`...\ATAP.Utilities.ConfigRootKeys.Powershell\public\RulesManagement.ConfigRootKeys.ps1`~~ → `Set-RulesManagementConfigRootKeys.ps1`

- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Obsolete\afterVersioned\_\_ImportData.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Obsolete\ATAPUtilities_Database_BackupDropAndRecreate.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Obsolete\ATAPUtilities_Database_BulkDataOut.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.FileIO.PowerShell\public\Get-DropBoxAllFolderCursors-Nightly.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.IAC.Ansible.Powershell\public\BuildServerTasks.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.IAC.Ansible.Powershell\public\Get-IACReport.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.IAC.Ansible.Powershell\public\MapUserShellFoldersToDropBox.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.IAC.Ansible.Powershell\public\OS_WindowsTasksCreate.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.IAC.Ansible.Powershell\public\OS_WindowsTemplatesCreate.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.IAC.Ansible.Powershell\public\RoleFeatureDefenderScript.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.PowerShell\public\Test-Copilot.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.PowerShell\public\testIcomparer.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.PowerShell\public\Type-PSLSA.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.Security.Powershell\public\SecretVaultTesting.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.Security.Powershell\public\SecTesting.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.Security.Powershell\public\Test-SecretVault.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.Speech.Powershell\public\AOE IV Keyboad shortcuts practice phrases.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.VennDiagramGenerator.Powershell\public\Generate-DrawIO.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.Gmail\ATAP.Utilities.Gmail.Powershell\public\Rebuild-All.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.Philote\Powershell\public\Rebuild-All.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.Tags\ATAP.Utilities.Tags.Powershell\public\Rebuild-All.ps1

## .ps1 files not in a project whose name ends in Powershell

- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.BuildTooling.BuildMaster\Plans\BuildMasterRunContext.Common.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.BuildTooling.BuildMaster\Plans\Initialize-CSharpPackageBuildContext.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.BuildTooling.BuildMaster\Plans\Initialize-PowerShellModuleBuildContext.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.BuildTooling.BuildMaster\Plans\Initialize-ReleaseBundleBuildContext.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.BuildTooling.BuildMaster\Plans\Invoke-PowerShellModuleBuildMasterStage.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.BuildTooling.BuildMaster\Plans\New-ReleaseBundleBuildMasterPackage.ps1

- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.BuildTooling.Jenkins\src\Get-JenkinsPlugins.ps1
- C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\ATAP.Utilities.FinancialAPI\public\Get-FinancialModelingData.ps1
