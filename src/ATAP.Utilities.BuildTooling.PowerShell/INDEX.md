# ATAP.Utilities.BuildTooling.PowerShell — Script Index

This module provides PowerShell build tooling for the ATAP ecosystem: ProGet feed management,
sprint lifecycle automation, Pester test scaffolding, MSBuild integration, and repository
maintenance utilities.

---

## Diagrams

### Private-to-Public Dependency Map

> **[PLACEHOLDER]** A diagram showing which private helper functions are called by which public cmdlets.
> Suggested tool: PlantUML component diagram or Draw.io.
> Expected relationships to illustrate:
>
> - `Build-ProGetFeedEndpointURL` ← used by ProGet feed cmdlets
> - `Convert-ProGetFeedType` ← used by feed creation/listing cmdlets
> - `ConvertTo-ProGetFeedNameAlternateForm` ← used by feed naming cmdlets and New-SprintProGetFeeds
> - `New-HostSettingsForPackageRepositoryFeeds` ← used by Register-ProGetFeedSet
> - `New-SprintBitwardenConnectionStrings` ← used by New-SprintStage2
> - `New-SprintBuildMasterBuilds` ← used by New-SprintStage2
> - `New-SprintDatabaseInstances` ← used by New-SprintStage2
> - `New-SprintProGetFeeds` ← used by New-SprintStage2

---

### Test Coverage Map

> **[PLACEHOLDER]** A matrix or diagram showing which `.Tests.ps1` files cover which public/private scripts.
> Suggested format: table with public scripts as rows, test files as columns, with checkmarks.
> See the Tests section below for the current test file inventory.

---

## Public Scripts (`public/`)

| Script                                                                                                    | Description                                                                                                     |
| --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| [Build-CLAUDEPerRepository.ps1](public/Build-CLAUDEPerRepository.ps1)                                     | Assembles per-repository `CLAUDE.md` files by combining base and local fragments.                               |
| [Build-ImageFromPlantUML.ps1](public/Build-ImageFromPlantUML.ps1)                                         | Renders a PlantUML `.puml` source file into an image (PNG/SVG) using the PlantUML JAR.                          |
| [Build-PSModuleManifest.ps1](public/Build-PSModuleManifest.ps1)                                           | Generates or updates a PowerShell module manifest (`.psd1`) from module metadata.                               |
| [Build-PSModulePsm1.ps1](public/Build-PSModulePsm1.ps1)                                                   | Builds the root `.psm1` file by dot-sourcing all public and private scripts.                                    |
| [check-syntax.ps1](public/check-syntax.ps1)                                                               | Parses a target `.ps1` file with the PowerShell AST parser and reports syntax errors. (Dev/debug utility.)      |
| [Clear-NuGetCaches.ps1](public/Clear-NuGetCaches.ps1)                                                     | Clears local NuGet HTTP caches, global packages, and temp folders.                                              |
| [Clear-VSCCaches.ps1](public/Clear-VSCCaches.ps1)                                                         | Removes VS Code extension host and workspace storage caches.                                                    |
| [Compress-PSModuleArtifacts.ps1](public/Compress-PSModuleArtifacts.ps1)                                   | Packages built module output into a `.zip` or `.nupkg` artifact for distribution.                               |
| [Confirm-ChocolateyInstalls.ps1](public/Confirm-ChocolateyInstalls.ps1)                                   | Verifies that required Chocolatey packages are installed at the expected versions.                              |
| [Confirm-GitFSCK.ps1](public/Confirm-GitFSCK.ps1)                                                         | Runs `git fsck` on one or more repositories and reports any integrity issues.                                   |
| [Confirm-RepositoryPackageProvider.ps1](public/Confirm-RepositoryPackageProvider.ps1)                     | Ensures the correct PowerShell package provider (e.g., NuGet) is registered.                                    |
| [Confirm-RepositoryPackageSource.ps1](public/Confirm-RepositoryPackageSource.ps1)                         | Ensures the correct package source (ProGet feed) is registered in the PowerShell package repository.            |
| [Confirm-Tools.ps1](public/Confirm-Tools.ps1)                                                             | Validates that required external tools (dotnet, git, bw, flyway, etc.) are available on `$env:PATH`.            |
| [Convert-DiagramsToImages.ps1](public/Convert-DiagramsToImages.ps1)                                       | Batch-converts all PlantUML diagram files in a directory tree to image files.                                   |
| [Copy-Assets.ps1](public/Copy-Assets.ps1)                                                                 | Copies build output assets to their target deployment locations.                                                |
| [Create-MCPJunction.ps1](public/Create-MCPJunction.ps1)                                                   | Creates an NTFS directory junction from the repository root to the SharedVSCode MCP servers folder.             |
| [Create-ServiceAccount.ps1](public/Create-ServiceAccount.ps1)                                             | Creates a Windows local service account with the minimum required privileges for running a service.             |
| [Get-AllFilesChangedByCommit.ps1](public/Get-AllFilesChangedByCommit.ps1)                                 | Returns the list of files affected by a specific git commit hash.                                               |
| [Get-BrokenGitSubDirs.ps1](public/Get-BrokenGitSubDirs.ps1)                                               | Scans for git repositories in subdirectories that have broken or detached HEAD states.                          |
| [Get-IncorrectSymLinksAndJunctions.ps1](public/Get-IncorrectSymLinksAndJunctions.ps1)                     | Finds symlinks and junctions in the workspace that point to missing or incorrect targets.                       |
| [Get-JenkinsEnvSettings.ps1](public/Get-JenkinsEnvSettings.ps1)                                           | Retrieves environment settings and build parameters from a Jenkins job context.                                 |
| [Get-MergedPesterConfigurations.ps1](public/Get-MergedPesterConfigurations.ps1)                           | Merges multiple `PesterConfiguration` objects into a single resolved configuration.                             |
| [Get-ModuleAsSymbolicLink.ps1](public/Get-ModuleAsSymbolicLink.ps1)                                       | Returns the resolved path of a PowerShell module that is installed as a symbolic link.                          |
| [Get-ModuleHighestVersion.ps1](public/Get-ModuleHighestVersion.ps1)                                       | Finds the highest installed version of a named PowerShell module.                                               |
| [Get-NumberOfFailingTestsFromTRX.ps1](public/Get-NumberOfFailingTestsFromTRX.ps1)                         | Parses a Visual Studio `.trx` test results file and returns the count of failing tests.                         |
| [Get-NuSpecFromManifest.ps1](public/Get-NuSpecFromManifest.ps1)                                           | Generates a NuGet `.nuspec` XML file from a PowerShell module manifest (`.psd1`).                               |
| [Get-ProjectsFromSLN.ps1](public/Get-ProjectsFromSLN.ps1)                                                 | Parses a Visual Studio `.sln` file and returns the list of included project paths.                              |
| [Get-PSModuleVersionFromNBGV.ps1](public/Get-PSModuleVersionFromNBGV.ps1)                                 | Reads the module version from Nerdbank.GitVersioning (`nbgv`) output.                                           |
| [Get-RefactoringCandidates.ps1](public/Get-RefactoringCandidates.ps1)                                     | Analyzes folder structure to identify groups of related folders that should be nested under a parent container. |
| [Get-RepositoryRoot.ps1](public/Get-RepositoryRoot.ps1)                                                   | Returns the root path of the current git repository.                                                            |
| [Get-SLNParts.ps1](public/Get-SLNParts.ps1)                                                               | Parses a `.sln` file into structured objects (projects, solution folders, configurations).                      |
| [Get-TierFromNBGVLabel.ps1](public/Get-TierFromNBGVLabel.ps1)                                             | Extracts the tier identifier from an NBGV pre-release label (e.g., `alpha`, `beta`, `stable`).                  |
| [Initialize-DownstreamSprintFromSharedVSCode.ps1](public/Initialize-DownstreamSprintFromSharedVSCode.ps1) | Initializes a downstream repo's sprint worktree by copying SharedVSCode configuration references.               |
| [Initialize-ProGetSqlServiceLogin](public/Initialize-ProGetSqlServiceLogin.ps1)                           | Autoloaded function that creates the SQL Server login and database user for the ProGet Windows service account. |
| [Invoke-BuildToolingPesterDebug.ps1](public/Invoke-BuildToolingPesterDebug.ps1)                           | Runs Pester tests for this module with verbose debug output for troubleshooting.                                |
| [Invoke-DotnetBuildWithRetry.ps1](public/Invoke-DotnetBuildWithRetry.ps1)                                 | Invokes `dotnet restore` and `dotnet build` with automatic retry on NuGet cache failures.                       |
| [Invoke-GitPostCheckoutHook.ps1](public/Invoke-GitPostCheckoutHook.ps1)                                   | Git `post-checkout` hook: updates worktree junctions and state after a branch switch.                           |
| [Invoke-GitPostCommitHook.ps1](public/Invoke-GitPostCommitHook.ps1)                                       | Git `post-commit` hook: runs post-commit actions such as tagging or CI notifications.                           |
| [Invoke-GitPreCommitHook.ps1](public/Invoke-GitPreCommitHook.ps1)                                         | Git `pre-commit` hook: runs linting and script analysis before allowing a commit.                               |
| [Invoke-ModuleBuildWithRetry.ps1](public/Invoke-ModuleBuildWithRetry.ps1)                                 | Invokes `Invoke-Build` against `module.build.ps1` with automatic retry on PSResourceGet/network failures.       |
| [Invoke-MSBuildWithLists.ps1](public/Invoke-MSBuildWithLists.ps1)                                         | Invokes MSBuild on a set of projects, passing additional property lists as arguments.                           |
| [Invoke-PSModulePesterTests.ps1](public/Invoke-PSModulePesterTests.ps1)                                   | Discovers and runs Pester tests for a specified PowerShell module using the module's configuration.             |
| [Invoke-PSModulePSScriptAnalyzer.ps1](public/Invoke-PSModulePSScriptAnalyzer.ps1)                         | Runs PSScriptAnalyzer on a module's source files and returns a structured results object.                       |
| [List-ProGetApiKeys.ps1](public/List-ProGetApiKeys.ps1)                                                   | Lists all API keys configured in ProGet via the management API.                                                 |
| [List-ProGetConnectors.ps1](public/List-ProGetConnectors.ps1)                                             | Lists all connectors defined in ProGet via the management API.                                                  |
| [List-ProGetFeeds.ps1](public/List-ProGetFeeds.ps1)                                                       | Lists all feeds in ProGet via the management API, with optional filtering.                                      |
| [Merge-PesterConfiguration.ps1](public/Merge-PesterConfiguration.ps1)                                     | Merges two `PesterConfiguration` objects, with the second overriding values in the first.                       |
| [Move-ProGetPackageInterTier](public/Move-ProGetPackageInterTier.ps1)                                     | Autoloaded function that promotes a package from one tier's pull feed to the next higher tier's feed.           |
| [Move-ProGetPackageIntraTier](public/Move-ProGetPackageIntraTier.ps1)                                     | Autoloaded function that moves a package from a push feed to its pull feed within the same tier.                |
| [New-AssemblyInfoFiles.ps1](public/New-AssemblyInfoFiles.ps1)                                             | Generates `AssemblyInfo.cs` files for C# projects based on module/version metadata.                             |
| [New-DocFilesIfNotPresent.ps1](public/New-DocFilesIfNotPresent.ps1)                                       | Creates stub documentation files (`.md`) for a module if they don't already exist.                              |
| [New-DocFolderIfNotPresent.ps1](public/New-DocFolderIfNotPresent.ps1)                                     | Creates the documentation folder structure for a module if it doesn't already exist.                            |
| [New-GitHubIssue.ps1](public/New-GitHubIssue.ps1)                                                         | Creates a new GitHub issue in a specified repository using the GitHub CLI or REST API.                          |
| [New-MockTestFileStructure.ps1](public/New-MockTestFileStructure.ps1)                                     | Creates a mock directory and file structure for use in Pester tests that require file system fixtures.          |
| [New-PesterBasicUnitTestTemplate.ps1](public/New-PesterBasicUnitTestTemplate.ps1)                         | Generates a basic Pester unit test file template for a given function.                                          |
| [New-PesterContextBlock.ps1](public/New-PesterContextBlock.ps1)                                           | Generates a Pester `Context` block scaffold with standard structure.                                            |
| [New-PesterDataDrivenTestTemplate.ps1](public/New-PesterDataDrivenTestTemplate.ps1)                       | Generates a Pester test template that uses `TestCases` for data-driven tests.                                   |
| [New-PesterDescribeBlock.ps1](public/New-PesterDescribeBlock.ps1)                                         | Generates a Pester `Describe` block scaffold with standard structure.                                           |
| [New-PesterFileModel.ps1](public/New-PesterFileModel.ps1)                                                 | Builds an in-memory model (object graph) representing the structure of a Pester test file.                      |
| [New-PesterItBlock.ps1](public/New-PesterItBlock.ps1)                                                     | Generates a Pester `It` block scaffold for a single test case.                                                  |
| [New-PesterTestFile.ps1](public/New-PesterTestFile.ps1)                                                   | Writes a complete Pester test file to disk from a `PesterFileModel`.                                            |
| [New-ProGetApiKey.ps1](public/New-ProGetApiKey.ps1)                                                       | Creates a new API key in ProGet with specified permissions via the management API.                              |
| [New-ProGetConnector.ps1](public/New-ProGetConnector.ps1)                                                 | Creates a new connector in ProGet pointing to an upstream package source.                                       |
| [New-ProGetFeedSet.ps1](public/New-ProGetFeedSet.ps1)                                                     | Creates a complete set of ProGet feeds for a given tier (integration, testing, stable).                         |
| [New-SprintStage1.ps1](public/New-SprintStage1.ps1)                                                       | Stage 1 of sprint bootstrap: creates SharedVSCode and \_Planning branches and workTrees.                        |
| [New-SprintStage2.ps1](public/New-SprintStage2.ps1)                                                       | Stage 2 of sprint bootstrap: creates downstream repo branches/workTrees, ProGet feeds, and BuildMaster builds.  |
| [New-WorktreeWithJunctions.ps1](public/New-WorktreeWithJunctions.ps1)                                     | Creates a new git worktree for a branch and sets up required NTFS junctions within it.                          |
| [Publish-PSModuleToProGetFeed.ps1](public/Publish-PSModuleToProGetFeed.ps1)                               | Publishes a packaged PowerShell module to a specified ProGet feed.                                              |
| [Publish-PSPackage.ps1](public/Publish-PSPackage.ps1)                                                     | Publishes a `.nupkg` package to a ProGet feed using NuGet or PowerShellGet.                                     |
| [Read-SourceAndCreateRules.ps1](public/Read-SourceAndCreateRules.ps1)                                     | Parses source code files and creates RRSBS Rules entries by extracting metadata from code and comments.         |
| [Register-ProGetFeedSet.ps1](public/Register-ProGetFeedSet.ps1)                                           | Registers all feeds in a ProGet feed set as PowerShell package sources in `$global:settings`.                   |
| [Remove-ObjAndBinSubDirectories.ps1](public/Remove-ObjAndBinSubDirectories.ps1)                           | Recursively deletes all `obj/` and `bin/` subdirectories under a given path.                                    |
| [Remove-ProGetApiKeys.ps1](public/Remove-ProGetApiKeys.ps1)                                               | Deletes one or more API keys from ProGet via the management API.                                                |
| [Remove-ProGetFeeds.ps1](public/Remove-ProGetFeeds.ps1)                                                   | Deletes one or more feeds from ProGet via the management API.                                                   |
| [Remove-VSComponentCache.ps1](public/Remove-VSComponentCache.ps1)                                         | Clears the Visual Studio component model cache to fix extension load failures.                                  |
| [Rename-ProGetFeed.ps1](public/Rename-ProGetFeed.ps1)                                                     | Renames an existing ProGet feed using the management API.                                                       |
| [Reset-DownstreamToSharedVSCodeMain.ps1](public/Reset-DownstreamToSharedVSCodeMain.ps1)                   | Resets all downstream repository workTrees to track the SharedVSCode `main` branch.                             |
| [Resolve-PSModuleMetadata.ps1](public/Resolve-PSModuleMetadata.ps1)                                       | Resolves and returns a structured metadata object for a PowerShell module from its manifest.                    |
| [Set-DownstreamSharedVSCodeContext.ps1](public/Set-DownstreamSharedVSCodeContext.ps1)                     | Configures a downstream repository worktree to reference the correct SharedVSCode branch context.               |
| [Set-WorktreeJunctions.ps1](public/Set-WorktreeJunctions.ps1)                                             | Creates or repairs all required NTFS junctions (e.g., `.claude`) in a worktree.                                 |
| [Start-DebugPowerShell.ps1](public/Start-DebugPowerShell.ps1)                                             | Launches an interactive PowerShell session with the module dot-sourced for manual debugging.                    |
| [Sync-RulesToCSV.ps1](public/Sync-RulesToCSV.ps1)                                                         | Exports RRSBS Rules, RulePrimitives, and related tables from the database to CSV files for version control.     |
| [Test-CodeCoverageGate.ps1](public/Test-CodeCoverageGate.ps1)                                             | Fails the build if Pester code coverage falls below a configured threshold.                                     |
| [Test-FailureAcknowledgedGate.ps1](public/Test-FailureAcknowledgedGate.ps1)                               | Checks whether all currently failing tests have been acknowledged (have a recorded known-failure entry).        |
| [Update-BlocksInCsproj.ps1](public/Update-BlocksInCsproj.ps1)                                             | Updates `<ItemGroup>` or `<PropertyGroup>` blocks in a `.csproj` file.                                          |
| [Update-PackageVersion.ps1](public/Update-PackageVersion.ps1)                                             | Updates the package version in a manifest or `.nuspec` to the value from NBGV.                                  |
| [Validate-ProGetFeeds.ps1](public/Validate-ProGetFeeds.ps1)                                               | Validates that all expected ProGet feeds exist and have the correct configuration.                              |

---

## Private Scripts (`private/`)

These are internal helpers not exported from the module.

| Script                                                                                                 | Description                                                                                                 |
| ------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| [Build-ProGetFeedEndpointURL.ps1](private/Build-ProGetFeedEndpointURL.ps1)                             | Constructs the full endpoint URL for a ProGet feed from scheme, host, port, and feed name components.       |
| [Convert-ProgetFeedType.ps1](private/Convert-ProgetFeedType.ps1)                                       | Maps ATAP feed type strings to the ProGet API's feed type identifiers (e.g., `nuget`, `powershell`).        |
| [ConvertTo-ProGetFeedNameAlternateForm.ps1](private/ConvertTo-ProGetFeedNameAlternateForm.ps1)         | Converts feed name components (tier, type, direction) into the canonical ProGet feed name string.           |
| [New-HostSettingsForPackageRepositoryFeeds.ps1](private/New-HostSettingsForPackageRepositoryFeeds.ps1) | Generates `$global:settings` entries for all ProGet feed endpoints for a given sprint.                      |
| [New-SprintBitwardenConnectionStrings.ps1](private/New-SprintBitwardenConnectionStrings.ps1)           | Creates Bitwarden secure-note items containing SQL Server connection strings for sprint database instances. |
| [New-SprintBuildMasterBuilds.ps1](private/New-SprintBuildMasterBuilds.ps1)                             | (Draft) Creates BuildMaster build configurations for sprint environments via the BuildMaster API.           |
| [New-SprintDatabaseInstances.ps1](private/New-SprintDatabaseInstances.ps1)                             | Creates SQL Server database instances for a sprint's Testing, Integration, and Development environments.    |
| [New-SprintProGetFeeds.ps1](private/New-SprintProGetFeeds.ps1)                                         | Creates all ProGet NuGet and PowerShellGet feeds for a sprint's tier environments.                          |

---

## Tests (`tests/`)

| Test File                                                                                                            | Covers                                                                                                              |
| -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| [ATAP.Utilities.BuildTooling.PowerShell.Tests.ps1](tests/ATAP.Utilities.BuildTooling.PowerShell.Tests.ps1)           | Module-level smoke tests: manifest loads, all public functions export correctly.                                    |
| [Build-PSModuleManifest.Tests.ps1](tests/Build-PSModuleManifest.Tests.ps1)                                           | `Build-PSModuleManifest` — manifest generation and field correctness.                                               |
| [Build-PSModulePsm1.Tests.ps1](tests/Build-PSModulePsm1.Tests.ps1)                                                   | `Build-PSModulePsm1` — `.psm1` file generation and dot-source completeness.                                         |
| [Compress-PSModuleArtifacts.Tests.ps1](tests/Compress-PSModuleArtifacts.Tests.ps1)                                   | `Compress-PSModuleArtifacts` — artifact compression and output validation.                                          |
| [Confirm-Tools.Tests.ps1](tests/Confirm-Tools.Tests.ps1)                                                             | `Confirm-Tools` — detection of present and missing tools.                                                           |
| [Get-ModuleAsSymbolicLink.Tests.ps1](tests/Get-ModuleAsSymbolicLink.Tests.ps1)                                       | `Get-ModuleAsSymbolicLink` — symlink resolution and path correctness.                                               |
| [Get-NuSpecFromManifest.Tests.ps1](tests/Get-NuSpecFromManifest.Tests.ps1)                                           | `Get-NuSpecFromManifest` — `.nuspec` XML generation from `.psd1` manifests.                                         |
| [Get-PSModuleVersionFromNBGV.Tests.ps1](tests/Get-PSModuleVersionFromNBGV.Tests.ps1)                                 | `Get-PSModuleVersionFromNBGV` — version extraction from NBGV output.                                                |
| [Get-TierFromNBGVLabel.Tests.ps1](tests/Get-TierFromNBGVLabel.Tests.ps1)                                             | `Get-TierFromNBGVLabel` — tier label parsing.                                                                       |
| [Initialize-DownstreamSprintFromSharedVSCode.Tests.ps1](tests/Initialize-DownstreamSprintFromSharedVSCode.Tests.ps1) | `Initialize-DownstreamSprintFromSharedVSCode` — downstream worktree initialization.                                 |
| [Invoke-PSModulePesterTests.Tests.ps1](tests/Invoke-PSModulePesterTests.Tests.ps1)                                   | `Invoke-PSModulePesterTests` — test discovery and invocation behavior.                                              |
| [Invoke-PSModulePSScriptAnalyzer.Tests.ps1](tests/Invoke-PSModulePSScriptAnalyzer.Tests.ps1)                         | `Invoke-PSModulePSScriptAnalyzer` — analyzer invocation and result structure.                                       |
| [Merge-PesterConfiguration.Tests.ps1](tests/Merge-PesterConfiguration.Tests.ps1)                                     | `Merge-PesterConfiguration` — configuration merge and override precedence.                                          |
| [New-MockTestFileStructure.Tests.ps1](tests/New-MockTestFileStructure.Tests.ps1)                                     | `New-MockTestFileStructure` — mock file system fixture creation.                                                    |
| [New-PesterFileModel.Tests.ps1](tests/New-PesterFileModel.Tests.ps1)                                                 | `New-PesterFileModel` — file model object graph structure.                                                          |
| [New-PesterRuleSetTemplates.Tests.ps1](tests/New-PesterRuleSetTemplates.Tests.ps1)                                   | Pester rule set template generation (covers `New-PesterBasicUnitTestTemplate`, `New-PesterDataDrivenTestTemplate`). |
| [New-PesterTestFile.Tests.ps1](tests/New-PesterTestFile.Tests.ps1)                                                   | `New-PesterTestFile` — end-to-end test file write-to-disk.                                                          |
| [Publish-PSModuleToProGetFeed.Tests.ps1](tests/Publish-PSModuleToProGetFeed.Tests.ps1)                               | `Publish-PSModuleToProGetFeed` — publish flow with mocked ProGet endpoint.                                          |
| [Rename-ProGetFeed.Tests.ps1](tests/Rename-ProGetFeed.Tests.ps1)                                                     | `Rename-ProGetFeed` — API call construction, URL resolution, and error handling.                                    |
| [Reset-DownstreamToSharedVSCodeMain.Tests.ps1](tests/Reset-DownstreamToSharedVSCodeMain.Tests.ps1)                   | `Reset-DownstreamToSharedVSCodeMain` — repo reset logic.                                                            |
| [Resolve-PSModuleMetadata.Tests.ps1](tests/Resolve-PSModuleMetadata.Tests.ps1)                                       | `Resolve-PSModuleMetadata` — metadata resolution from manifest.                                                     |
| [Set-DownstreamSharedVSCodeContext.Tests.ps1](tests/Set-DownstreamSharedVSCodeContext.Tests.ps1)                     | `Set-DownstreamSharedVSCodeContext` — context configuration.                                                        |
| [Set-ProGetServiceDependency.Tests.ps1](tests/Set-ProGetServiceDependency.Tests.ps1)                                 | `Set-ProGetServiceDependency` — service dependency configuration.                                                   |
| [Test-CodeCoverageGate.Tests.ps1](tests/Test-CodeCoverageGate.Tests.ps1)                                             | `Test-CodeCoverageGate` — threshold pass/fail logic.                                                                |
| [Test-FailureAcknowledgedGate.Tests.ps1](tests/Test-FailureAcknowledgedGate.Tests.ps1)                               | `Test-FailureAcknowledgedGate` — known-failure acknowledgment lookup.                                               |
| [Test-ModuleManifest.NotRight.ps1](tests/Test-ModuleManifest.NotRight.ps1)                                           | Scratch/diagnostic script for manual module manifest validation (not a Pester test).                                |

---

## Scripts Without Tests

> **[PLACEHOLDER]** The following public scripts currently have no corresponding test file.
> This list can be used to prioritize test coverage work.
>
> _(Generate this list by diffing the public/ files against the tests/ coverage map above.)_

---

_Last updated: auto-generated — see `INDEX.md` generation tooling._
