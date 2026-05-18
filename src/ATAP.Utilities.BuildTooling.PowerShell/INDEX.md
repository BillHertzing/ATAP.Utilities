# ATAP.Utilities.BuildTooling.PowerShell - Project File Index

This index lists every file currently in the BuildTooling PowerShell project and gives a high-level purpose for each one. Regenerate it whenever files are added, removed, or moved.

## Project Shape

- `public/` contains exported cmdlets and developer-facing workflows.
- `private/` contains internal helpers dot-sourced by the module.
- `tools/` contains loose workstation or development setup scripts that are not exported cmdlets.
- `tests/` contains Pester coverage and fixtures.
- `Resources/`, `Documentation/`, and `Obsolete/` hold support files, docs, and retained historical scripts.

## .

| File | Purpose |
| --- | --- |
| [ATAP.Utilities.BuildTooling.Powershell.dll](ATAP.Utilities.BuildTooling.Powershell.dll) | Compiled helper assembly bundled with the module. |
| [ATAP.Utilities.BuildTooling.PowerShell.psd1](ATAP.Utilities.BuildTooling.PowerShell.psd1) | PowerShell module manifest. |
| [ATAP.Utilities.BuildTooling.PowerShell.psm1](ATAP.Utilities.BuildTooling.PowerShell.psm1) | Built module root that dot-sources public and private scripts. |
| [ATAP.Utilities.BuildTooling.PowerShell.pssproj](ATAP.Utilities.BuildTooling.PowerShell.pssproj) | PowerShell Studio project file for the module. |
| [INDEX.md](INDEX.md) | Generated inventory of every file in the BuildTooling PowerShell project. |
| [publish Profile that calls powershell.pubxml](<publish Profile that calls powershell.pubxml>) | Publish profile used by local tooling. |
| [ReadMe.md](ReadMe.md) | Module readme and quick-start documentation. |
| [ReleaseNotes.md](ReleaseNotes.md) | Release notes for the BuildTooling PowerShell module. |
| [tags.txt](tags.txt) | Reference notes or captured command output for module documentation. |
| [toc.yml](toc.yml) | Documentation table of contents metadata. |
| [version.json](version.json) | Nerdbank.GitVersioning configuration for the module. |

## _generated/PSModuleBuildLogs/ATAP.Utilities.BuildTooling.PowerShell

| File | Purpose |
| --- | --- |
| [ATAP.Utilities.BuildTooling.PowerShell_Publish_20260429_165903.log](_generated/PSModuleBuildLogs/ATAP.Utilities.BuildTooling.PowerShell/ATAP.Utilities.BuildTooling.PowerShell_Publish_20260429_165903.log) | Generated module build or publish log. |
| [ATAP.Utilities.BuildTooling.PowerShell_Publish_20260429_171452.log](_generated/PSModuleBuildLogs/ATAP.Utilities.BuildTooling.PowerShell/ATAP.Utilities.BuildTooling.PowerShell_Publish_20260429_171452.log) | Generated module build or publish log. |
| [ATAP.Utilities.BuildTooling.PowerShell_Publish_20260429_201413.log](_generated/PSModuleBuildLogs/ATAP.Utilities.BuildTooling.PowerShell/ATAP.Utilities.BuildTooling.PowerShell_Publish_20260429_201413.log) | Generated module build or publish log. |
| [ATAP.Utilities.BuildTooling.PowerShell_Publish_20260429_201708.log](_generated/PSModuleBuildLogs/ATAP.Utilities.BuildTooling.PowerShell/ATAP.Utilities.BuildTooling.PowerShell_Publish_20260429_201708.log) | Generated module build or publish log. |
| [ATAP.Utilities.BuildTooling.PowerShell_Publish_20260429_201809.log](_generated/PSModuleBuildLogs/ATAP.Utilities.BuildTooling.PowerShell/ATAP.Utilities.BuildTooling.PowerShell_Publish_20260429_201809.log) | Generated module build or publish log. |
| [ATAP.Utilities.BuildTooling.PowerShell_Publish_20260429_202454.log](_generated/PSModuleBuildLogs/ATAP.Utilities.BuildTooling.PowerShell/ATAP.Utilities.BuildTooling.PowerShell_Publish_20260429_202454.log) | Generated module build or publish log. |
| [ATAP.Utilities.BuildTooling.PowerShell_Publish_20260429_204501.log](_generated/PSModuleBuildLogs/ATAP.Utilities.BuildTooling.PowerShell/ATAP.Utilities.BuildTooling.PowerShell_Publish_20260429_204501.log) | Generated module build or publish log. |
| [ATAP.Utilities.BuildTooling.PowerShell_Publish_20260429_204935.log](_generated/PSModuleBuildLogs/ATAP.Utilities.BuildTooling.PowerShell/ATAP.Utilities.BuildTooling.PowerShell_Publish_20260429_204935.log) | Generated module build or publish log. |

## Documentation

| File | Purpose |
| --- | --- |
| [5Tier gaps.md](<Documentation/5Tier gaps.md>) | Documentation: 5-Tier Compliance Gaps — `module.build.ps1`. |
| [5tier Implementation plan.md](<Documentation/5tier Implementation plan.md>) | Documentation: 5-Tier Implementation Plan — `module.build.ps1`. |
| [5Tier tasks for module.build.ps1.md](<Documentation/5Tier tasks for module.build.ps1.md>) | Documentation: 5-Tier Swarm Tasks — `module.build.ps1`. |
| [AllInstallText.txt](Documentation/AllInstallText.txt) | Reference notes or captured command output for module documentation. |
| [Attribution.md](Documentation/Attribution.md) | Documentation: Attribution of ideas. |
| [Current VSC-Powershell environment.txt](<Documentation/Current VSC-Powershell environment.txt>) | Reference notes or captured command output for module documentation. |
| [Deep Dive on Building Modules and Publishing to Powershell Package Repositories.md](<Documentation/Deep Dive on Building Modules and Publishing to Powershell Package Repositories.md>) | Documentation: Deep Dive on Building Modules and Publishing to Powershell Package Repositories. |
| [GettingStarted.md](Documentation/GettingStarted.md) | Documentation: Getting Started. |
| [RepositoryStructures.drawio](Documentation/RepositoryStructures.drawio) | Draw.io diagram source for module documentation. |

## Documentation/DrawIO

| File | Purpose |
| --- | --- |
| [.$ProGet Repository Feeds.drawio.bkp](<Documentation/DrawIO/.$ProGet Repository Feeds.drawio.bkp>) | Backup copy of a diagram or documentation source file. |
| [ProGet Repository Feeds.drawio](<Documentation/DrawIO/ProGet Repository Feeds.drawio>) | Draw.io diagram source for module documentation. |

## Documentation/UML

| File | Purpose |
| --- | --- |
| [ProGet Feed structures.uml](<Documentation/UML/ProGet Feed structures.uml>) | UML diagram source for module documentation. |

## libs

| File | Purpose |
| --- | --- |
| [ATAP.Utilities.BuildTooling.Powershell.dll](libs/ATAP.Utilities.BuildTooling.Powershell.dll) | Compiled helper assembly bundled with the module. |

## Obsolete/public

| File | Purpose |
| --- | --- |
| [.gitkeep](Obsolete/public/.gitkeep) | Placeholder that keeps the directory in source control. |
| [Launch-BaGetPackageFeeds.ps1](Obsolete/public/Launch-BaGetPackageFeeds.ps1) | PowerShell helper for launch ba get package feeds. |
| [Set-ProGetServiceConfigPath.ps1](Obsolete/public/Set-ProGetServiceConfigPath.ps1) | Sets pro get service config path configuration. |
| [Test-ProGetServiceConfigPath.ps1](Obsolete/public/Test-ProGetServiceConfigPath.ps1) | Tests pro get service config path behavior or configuration. |

## Obsolete/tests

| File | Purpose |
| --- | --- |
| [.gitkeep](Obsolete/tests/.gitkeep) | Placeholder that keeps the directory in source control. |
| [Set-ProGetServiceConfigPath.Tests.ps1](Obsolete/tests/Set-ProGetServiceConfigPath.Tests.ps1) | Pester tests for set pro get service config path. |

## private

| File | Purpose |
| --- | --- |
| [Assert-GitAvailable.ps1](private/Assert-GitAvailable.ps1) | Throws if git is not available on PATH. |
| [Build-ProGetFeedEndpointURL.ps1](private/Build-ProGetFeedEndpointURL.ps1) | Builds or generates pro get feed endpoint url artifacts. |
| [BuildToolingSql.Helpers.ps1](private/BuildToolingSql.Helpers.ps1) | PowerShell helper for build tooling sql. |
| [Convert-ProgetFeedType.ps1](private/Convert-ProgetFeedType.ps1) | Converts proget feed type data between supported representations. |
| [ConvertTo-ProGetFeedNameAlternateForm.ps1](private/ConvertTo-ProGetFeedNameAlternateForm.ps1) | PowerShell helper for convert to pro get feed name alternate form. |
| [Find-SqlServerSetupExe.ps1](private/Find-SqlServerSetupExe.ps1) | Locates SQL Server Setup.exe for use by sprint lifecycle cmdlets. |
| [Get-CeilingFromPrereleaseLabel.ps1](private/Get-CeilingFromPrereleaseLabel.ps1) | Maps an NBGV prerelease label to the highest promotion tier allowed for the current pipeline run. |
| [Get-CurrentTierFromStage.ps1](private/Get-CurrentTierFromStage.ps1) | Maps a BuildMaster stage name to the canonical current tier name. |
| [Get-RepoRoot.ps1](private/Get-RepoRoot.ps1) | Returns the absolute path of the current Git repository root. |
| [Get-SharedVSCodeRootFromTemplateRef.ps1](private/Get-SharedVSCodeRootFromTemplateRef.ps1) | Resolves a templateRef string to the absolute path of the SharedVSCode worktree. |
| [Get-SprintTaskRepositoryNames.ps1](private/Get-SprintTaskRepositoryNames.ps1) | Extracts repository names from sprint TASKS.md task headers. |
| [Get-WorkspaceJson.ps1](private/Get-WorkspaceJson.ps1) | Reads a .code-workspace file and returns its parsed JSON object. |
| [New-GeneratedFileContent.ps1](private/New-GeneratedFileContent.ps1) | Wraps source file content with a generated-file header. |
| [New-HostSettingsForPackageRepositoryFeeds.ps1](private/New-HostSettingsForPackageRepositoryFeeds.ps1) | Creates new host settings for package repository feeds resources or scaffolding. |
| [New-SprintBitwardenConnectionStrings.ps1](private/New-SprintBitwardenConnectionStrings.ps1) | Creates Bitwarden secure-note items containing SQL Server connection strings for the sprint database instances. |
| [New-SprintBuildMasterBuilds.ps1](private/New-SprintBuildMasterBuilds.ps1) | Creates BuildMaster build configurations for sprint environments. |
| [New-SprintDatabaseInstances.ps1](private/New-SprintDatabaseInstances.ps1) | Creates the SQL Server database instance for the sprint's ephemeral experimental/development environment. |
| [Remove-SprintProGetFeeds.ps1](private/Remove-SprintProGetFeeds.ps1) | Deletes the per-sprint ProGet NuGet feeds created by New-SprintProGetFeeds. |
| [Resolve-ProGetFeedFromSettings.ps1](private/Resolve-ProGetFeedFromSettings.ps1) | Resolves canonical ProGet feed metadata from $global:Settings. |
| [Resolve-WorkspaceFiles.ps1](private/Resolve-WorkspaceFiles.ps1) | Resolves an array of workspace file paths to their full provider paths. |
| [Save-WorkspaceJson.ps1](private/Save-WorkspaceJson.ps1) | Serializes a PSCustomObject back to a .code-workspace file as JSON. |
| [Set-ClaudeSettingsSymlink.ps1](private/Set-ClaudeSettingsSymlink.ps1) | Creates (or replaces) a symlink from the SharedVSCode sprint branch claude-settings.json to the user-profile claude settings path. |
| [Test-CommandExists.ps1](private/Test-CommandExists.ps1) | Checks whether a command is available in the current session. |

## public

| File | Purpose |
| --- | --- |
| [Add-ScopeCreepIdea.ps1](public/Add-ScopeCreepIdea.ps1) | Capture a new scope-creep idea into ScopeCreep-Inbox.md. |
| [Add-SharedFileContent.ps1](public/Add-SharedFileContent.ps1) | Appends content to, or performs a regex find-and-replace within, a shared file under an exclusive file lock. |
| [Approve-BuildMasterStage.ps1](public/Approve-BuildMasterStage.ps1) | Approves a BuildMaster manual gate for a specific stage of a specific build. |
| [Assert-MainBranchTemplateRef.ps1](public/Assert-MainBranchTemplateRef.ps1) | Validates that all workspace files point to SharedVSCode "main". |
| [Build-CLAUDEPerRepository.ps1](public/Build-CLAUDEPerRepository.ps1) | Builds a combined CLAUDE.md file for each repository worktree in the current sprint. |
| [Build-ImageFromPlantUML.ps1](public/Build-ImageFromPlantUML.ps1) | Walk a directory and generate PlantUML images for supported files. |
| [Build-PSModuleManifest.ps1](public/Build-PSModuleManifest.ps1) | Copies a source PowerShell module manifest (.psd1) to an output path and updates it with version, prerelease, exported functions, aliases, assemblies, formats, and DSC resources. |
| [Build-PSModulePsm1.ps1](public/Build-PSModulePsm1.ps1) | Builds a consolidated PowerShell module (.psm1) file from the source files of a module. |
| [Clear-BuildMasterSprintVariables.ps1](public/Clear-BuildMasterSprintVariables.ps1) | Deletes the sprint-scoped BuildMaster Application Variables at sprint-end. |
| [Clear-NuGetCaches.ps1](public/Clear-NuGetCaches.ps1) | Clears NuGet package caches from common locations |
| [Clear-SprintGeneratedArtifacts.ps1](public/Clear-SprintGeneratedArtifacts.ps1) | Deletes the contents of the `_generated/` folder in every sprint worktree for the specified sprint number. |
| [Clear-VSCCaches.ps1](public/Clear-VSCCaches.ps1) | Clears one or more Visual Studio Code cache directories. |
| [Compare-ReleaseManifest.ps1](public/Compare-ReleaseManifest.ps1) | Compares two release manifests and summarizes support-relevant changes. |
| [Complete-PlanningSession.ps1](public/Complete-PlanningSession.ps1) | Finalize a planning session: update status files, generate amendments, commit, push, open a PR, squash-merge, pull main, and remove the worktree. |
| [Compress-PSModuleArtifacts.ps1](public/Compress-PSModuleArtifacts.ps1) | Compresses a PowerShell module's generated test-results, coverage, and packages folders into three .7z archives under artifacts/. |
| [Confirm-ChocolateyInstalls.ps1](public/Confirm-ChocolateyInstalls.ps1) | ToDo: write Help SYNOPSIS For this function |
| [Confirm-GitFSCK.ps1](public/Confirm-GitFSCK.ps1) | Confirm-GitFSCK is a PowerShell function that runs Git's fsck --full command across multiple Git repositories within a specified path. |
| [Confirm-RepositoryPackageProvider.ps1](public/Confirm-RepositoryPackageProvider.ps1) | Confirm that all the 3rd party tools and scripts needed to build, analyze, test, package and deploy both c# and powershell code are present, configured, and accessable, |
| [Confirm-RepositoryPackageSource.ps1](public/Confirm-RepositoryPackageSource.ps1) | Confirm that all the 3rd party tools and scripts needed to build, analyze, test, package and deploy both c# and powershell code are present, configured, and accessable, |
| [Confirm-Tools.ps1](public/Confirm-Tools.ps1) | Confirm that all the 3rd party tools and scripts needed to build, analyze, test, package and deploy both c# and powershell code are present, configured, and accessable, |
| [Convert-DiagramsToImages.ps1](public/Convert-DiagramsToImages.ps1) | Converts PlantUML / DrawIO include‑tags inside a Markdown file to static PNGs and ensures a following `![diagram]()` reference. |
| [Copy-Assets.ps1](public/Copy-Assets.ps1) | ToDo: write Help SYNOPSIS For this function |
| [Create-MCPJunction.ps1](public/Create-MCPJunction.ps1) | Creates a directory junction to the SharedVSCode MCP servers folder. |
| [Create-ServiceAccount.ps1](public/Create-ServiceAccount.ps1) | ToDo: write Help SYNOPSIS For this function |
| [Get-AllFilesChangedByCommit.ps1](public/Get-AllFilesChangedByCommit.ps1) | Returns all files changed by commit information. |
| [Get-ATAPIACConstant.ps1](public/Get-ATAPIACConstant.ps1) | Legacy bootstrap accessor for ATAP.IAC constant values. |
| [Get-BrokenGitSubDirs.ps1](public/Get-BrokenGitSubDirs.ps1) | Returns broken git sub dirs information. |
| [Get-BuildContext.ps1](public/Get-BuildContext.ps1) | Resolves the full build context for a BuildMaster pipeline run from either a release tag or a branch name, separating current stage tier from version-label promotion ceiling. |
| [Get-DeployedReleaseManifest.ps1](public/Get-DeployedReleaseManifest.ps1) | Reads and validates the manifest.json deployed with an AceCommander release. |
| [Get-IncorrectSymLinksAndJunctions.ps1](public/Get-IncorrectSymLinksAndJunctions.ps1) | Validates symbolic links and junctions in Git repository directories. |
| [Get-JenkinsEnvSettings.ps1](public/Get-JenkinsEnvSettings.ps1) | ToDo: write Help SYNOPSIS For this function |
| [Get-MergedPesterConfigurations.ps1](public/Get-MergedPesterConfigurations.ps1) | Discovers and merges PesterConfiguration.psd1 files. |
| [Get-ModuleAsSymbolicLink.ps1](public/Get-ModuleAsSymbolicLink.ps1) | Returns module as symbolic link information. |
| [Get-ModuleHighestVersion.ps1](public/Get-ModuleHighestVersion.ps1) | ToDo: write Help SYNOPSIS For this function |
| [Get-NumberOfFailingTestsFromTRX.ps1](public/Get-NumberOfFailingTestsFromTRX.ps1) | Returns number of failing tests from trx information. |
| [Get-NuSpecFromManifest.ps1](public/Get-NuSpecFromManifest.ps1) | ToDo: write Help SYNOPSIS For this function |
| [Get-ProjectsByActivity.ps1](public/Get-ProjectsByActivity.ps1) | Walks a directory tree and returns PowerShell and C#/.NET project roots sorted by most recently touched (most recently modified file in the tree). |
| [Get-ProjectsFromSLN.ps1](public/Get-ProjectsFromSLN.ps1) | Returns projects from sln information. |
| [Get-PSModuleVersionFromNBGV.ps1](public/Get-PSModuleVersionFromNBGV.ps1) | Resolve a PowerShell module's NBGV-derived version and translate it into the `ModuleVersion` / `Prerelease` pair that `Update-ModuleManifest` accepts. |
| [Get-RefactoringCandidates.ps1](public/Get-RefactoringCandidates.ps1) | Analyzes folder structure to identify refactoring opportunities for grouping related folders under parent containers. |
| [Get-RepositoryRoot.ps1](public/Get-RepositoryRoot.ps1) | Finds and returns the repository root directory using git. |
| [Get-SharedVSCodeContext.ps1](public/Get-SharedVSCodeContext.ps1) | Reads one or more workspace files and returns context objects describing the SharedVSCode assets each workspace points to. |
| [Get-SLNParts.ps1](public/Get-SLNParts.ps1) | Create structured representation of a .sln file |
| [Get-TableNamesFromGCode.ps1.save](public/Get-TableNamesFromGCode.ps1.save) | Saved reference copy retained for historical comparison. |
| [Get-TierFromNBGVLabel.ps1](public/Get-TierFromNBGVLabel.ps1) | Translate an NBGV prerelease label (or a full prerelease segment) into the corresponding promotion ceiling number, tier name, and target ProGet feed. |
| [Get-TierOrder.ps1](public/Get-TierOrder.ps1) | Returns the canonical ordered promotion tiers. |
| [Initialize-DownstreamSprintFromSharedVSCode.ps1](public/Initialize-DownstreamSprintFromSharedVSCode.ps1) | Points downstream workspace files at a SharedVSCode sprint worktree and applies the resulting context to the local Git repo. |
| [Initialize-ProGetSqlServiceLogin.ps1](public/Initialize-ProGetSqlServiceLogin.ps1) | Creates and grants SQL Server access for the ProGet Windows service account. |
| [Invoke-BuildToolingPesterDebug.ps1](public/Invoke-BuildToolingPesterDebug.ps1) | Runs BuildTooling Pester tests with debug-friendly defaults. |
| [Invoke-DotnetBuildWithRetry.ps1](public/Invoke-DotnetBuildWithRetry.ps1) | Invokes dotnet restore then dotnet build with automatic retry on NuGet cache failures. |
| [Invoke-FailureAcknowledgedGate.ps1](public/Invoke-FailureAcknowledgedGate.ps1) | Validates FailureAcknowledged.json against its schema, then runs the Failure-Acknowledged gate. |
| [Invoke-GitPostCheckoutHook.ps1](public/Invoke-GitPostCheckoutHook.ps1) | Runs the git post checkout hook workflow. |
| [Invoke-GitPostCommitHook.ps1](public/Invoke-GitPostCommitHook.ps1) | Runs the git post commit hook workflow. |
| [Invoke-GitPreCommitHook.ps1](public/Invoke-GitPreCommitHook.ps1) | Runs the git pre commit hook workflow. |
| [Invoke-ModuleBuildWithRetry.ps1](public/Invoke-ModuleBuildWithRetry.ps1) | Invokes Invoke-Build against a module.build.ps1 orchestrator with automatic retry. |
| [Invoke-MSBuildWithLists.ps1](public/Invoke-MSBuildWithLists.ps1) | ToDo: Repeatdly invoke msbuild, substituting propertis with lists of arguments |
| [Invoke-PromotedModuleTests.ps1](public/Invoke-PromotedModuleTests.ps1) | Runs tier-appropriate Pester tests against an already-promoted PowerShell module instead of a fresh from-source build. |
| [Invoke-PromotedPackageTests.ps1](public/Invoke-PromotedPackageTests.ps1) | Runs tier-appropriate C# tests against an already-promoted NuGet package instead of a fresh from-source build. |
| [Invoke-PSModulePesterTests.ps1](public/Invoke-PSModulePesterTests.ps1) | Runs Pester tests for a PowerShell module with tier-appropriate tag filters. |
| [Invoke-PSModulePSScriptAnalyzer.ps1](public/Invoke-PSModulePSScriptAnalyzer.ps1) | Runs PSScriptAnalyzer against a PowerShell module and emits NUnit-style XML. |
| [Invoke-WithFileLock.ps1](public/Invoke-WithFileLock.ps1) | Dot-source this file to load the Invoke-WithFileLock function, then call it to run a script block under an OS-level exclusive file-system lock. |
| [List-ProGetApiKeys.ps1](public/List-ProGetApiKeys.ps1) | Lists pro get api keys resources from the configured service. |
| [List-ProGetConnectors.ps1](public/List-ProGetConnectors.ps1) | Lists pro get connectors resources from the configured service. |
| [List-ProGetFeeds.ps1](public/List-ProGetFeeds.ps1) | Lists pro get feeds resources from the configured service. |
| [Merge-PesterConfiguration.ps1](public/Merge-PesterConfiguration.ps1) | Merges pester configuration configuration or data. |
| [Move-ProGetPackageInterTier.ps1](public/Move-ProGetPackageInterTier.ps1) | Moves a package between permanent ProGet feeds per the immutable promotion model. See `BuildMaster-Pipeline-Topology.md`. |
| [Move-ProGetPackageIntraTier.ps1](public/Move-ProGetPackageIntraTier.ps1) | Moves a package from a push feed to a pull feed within the same tier, after running a malware/quality scan (currently stubbed). |
| [New-BuildMasterApplication.ps1](public/New-BuildMasterApplication.ps1) | Creates or updates a BuildMaster application through the Application Management API. |
| [New-BuildMasterRelease.ps1](public/New-BuildMasterRelease.ps1) | Creates a BuildMaster release for an Application + ReleaseNumber + Pipeline triple via the Native API, idempotently. |
| [New-BuildMasterScript.ps1](public/New-BuildMasterScript.ps1) | Creates or updates a BuildMaster script in the default database raft. |
| [New-BundleProjectFiles.ps1](public/New-BundleProjectFiles.ps1) | Bundles _Planning repository documents into a single Markdown file. |
| [New-DocFilesIfNotPresent.ps1](public/New-DocFilesIfNotPresent.ps1) | ToDo: write Help SYNOPSIS For this function |
| [New-DocFolderIfNotPresent.ps1](public/New-DocFolderIfNotPresent.ps1) | ToDo: write Help SYNOPSIS For this function |
| [New-GitHubIssue.ps1](public/New-GitHubIssue.ps1) | Creates a new GitHub issue in the specified repository. |
| [New-HostSettingsForPackageRepositoryFeeds.ps1](public/New-HostSettingsForPackageRepositoryFeeds.ps1) | Writes a machine-scope settings file recording all known feed → URL → API-key mappings for the ten permanent ProGet feeds. |
| [New-MockTestFileStructure.ps1](public/New-MockTestFileStructure.ps1) | Creates new mock test file structure resources or scaffolding. |
| [New-OverviewSprintWorkspace.ps1](public/New-OverviewSprintWorkspace.ps1) | Creates a sprint-specific Overview code-workspace file. |
| [New-PermanentBitwardenSecrets.ps1](public/New-PermanentBitwardenSecrets.ps1) | Creates the permanent, per-workstation Bitwarden secure-note items containing SQL Server connection strings for the Integration, QA, and Production ecosystem tiers. |
| [New-PesterBasicUnitTestTemplate.ps1](public/New-PesterBasicUnitTestTemplate.ps1) | Creates a PesterFile model conforming to the Basic Unit Test RuleSet. |
| [New-PesterContextBlock.ps1](public/New-PesterContextBlock.ps1) | Creates a Context-block hashtable for use inside a Describe-block model. |
| [New-PesterDataDrivenTestTemplate.ps1](public/New-PesterDataDrivenTestTemplate.ps1) | Creates a PesterFile model conforming to the Data-Driven Unit Test RuleSet. |
| [New-PesterDescribeBlock.ps1](public/New-PesterDescribeBlock.ps1) | Creates a Describe-block hashtable for use in a PesterFile model. |
| [New-PesterFileModel.ps1](public/New-PesterFileModel.ps1) | Creates a new Pester file model hashtable representing a structured .Tests.ps1 file. |
| [New-PesterItBlock.ps1](public/New-PesterItBlock.ps1) | Creates an It-block hashtable for use inside a Describe or Context block model. |
| [New-PesterTestFile.ps1](public/New-PesterTestFile.ps1) | Synthesizes a valid Pester v5 .Tests.ps1 file from a PesterFile model. |
| [New-ProGetApiKey.ps1](public/New-ProGetApiKey.ps1) | Creates new pro get api key resources or scaffolding. |
| [New-ProGetConnector.ps1](public/New-ProGetConnector.ps1) | Creates new pro get connector resources or scaffolding. |
| [New-ProGetFeedSet.ps1](public/New-ProGetFeedSet.ps1) | Creates new pro get feed set resources or scaffolding. |
| [New-PSModuleNupkg.ps1](public/New-PSModuleNupkg.ps1) | Packs a PowerShell module folder into a .nupkg on disk without pushing it anywhere. |
| [New-ReleaseBundle.ps1](public/New-ReleaseBundle.ps1) | Builds a Release Bundle `.upack` archive from a release manifest. |
| [New-ReleaseManifest.ps1](public/New-ReleaseManifest.ps1) | Generates the Release Bundle manifest.json from a build context and DB release-unit YAML. |
| [New-SprintBitwardenSecrets.ps1](public/New-SprintBitwardenSecrets.ps1) | Creates per-sprint Bitwarden secure-note items containing SQL Server connection strings for the Development and Experimental instances. |
| [New-SprintSqlServerInstances.ps1](public/New-SprintSqlServerInstances.ps1) | Creates the `Dev<username>` and `Exp<username>` SQL Server named instances for the sprint environment and builds all target databases from scratch using Flyway migrations. |
| [New-SprintStage1.ps1](public/New-SprintStage1.ps1) | Bootstraps Stage 1 of a new sprint: determines the sprint number, creates SharedVSCode and _Planning branches/workTrees, creates NTFS junctions, and applies SharedVSCode context... |
| [New-SprintStage2.ps1](public/New-SprintStage2.ps1) | Creates downstream repo sprint branches, workTrees, NTFS junctions, applies SharedVSCode context, symlinks claude-settings.json, scaffolds BuildMaster sprint builds, creates Bit... |
| [New-WorktreeWithJunctions.ps1](public/New-WorktreeWithJunctions.ps1) | Creates a git worktree and recreates all junction points from the source repository. |
| [Promote-ProGetPackage.ps1](public/Promote-ProGetPackage.ps1) | Promotes a package from one ProGet feed to another by wrapping Move-ProGetPackageInterTier with the canonical immutable-pipeline parameter names (Name, Version, FromFeed, ToFeed... |
| [Publish-NuGetPackageToProGet.ps1](public/Publish-NuGetPackageToProGet.ps1) | Publishes a pre-built NuGet .nupkg to a ProGet feed via `dotnet nuget push`. Idempotent: always passes --skip-duplicate. |
| [Publish-PSModuleToProGet.ps1](public/Publish-PSModuleToProGet.ps1) | Publishes a pre-built PowerShell module .nupkg to the powershellget-experimental ProGet feed. |
| [Publish-PSModuleToProGetFeed.ps1](public/Publish-PSModuleToProGetFeed.ps1) | Publishes a PowerShell module .nupkg to the correct ProGet PowerShellGet feed for a given 5-Tier tier. |
| [Publish-PSPackage.ps1](public/Publish-PSPackage.ps1) | Publishes pspackage artifacts. |
| [Publish-UniversalPackageToProGet.ps1](public/Publish-UniversalPackageToProGet.ps1) | Publishes a Universal Package (.upack) to a ProGet Universal feed via HTTP PUT. Idempotent (server-side dedup of identical Group/Name/Version). |
| [Read-SourceAndCreateRules.ps1](public/Read-SourceAndCreateRules.ps1) | Reads source code files and creates Rules entries by parsing metadata from code structure and comments. |
| [Register-ProGetFeedSet.ps1](public/Register-ProGetFeedSet.ps1) | Registers all five permanent powershellget-* ProGet feeds as PSResource repositories on the developer workstation. |
| [Remove-BuildMasterApplication.ps1](public/Remove-BuildMasterApplication.ps1) | Removes or deactivates a BuildMaster application through the API. |
| [Remove-BuildMasterApplicationVariable.ps1](public/Remove-BuildMasterApplicationVariable.ps1) | Removes one or more BuildMaster application variables. |
| [Remove-BuildMasterScript.ps1](public/Remove-BuildMasterScript.ps1) | Removes a BuildMaster script from the default database raft. |
| [Remove-ObjAndBinSubDirectories.ps1](public/Remove-ObjAndBinSubDirectories.ps1) | ToDo: write Help SYNOPSIS For this function |
| [Remove-ProGetApiKeys.ps1](public/Remove-ProGetApiKeys.ps1) | Removes pro get api keys resources or generated state. |
| [Remove-ProGetFeeds.ps1](public/Remove-ProGetFeeds.ps1) | Removes pro get feeds resources or generated state. |
| [Remove-SprintBitwardenSecrets.ps1](public/Remove-SprintBitwardenSecrets.ps1) | Deletes per-sprint Bitwarden secure-note items for the Development and Experimental connection strings created by New-SprintBitwardenSecrets. |
| [Remove-SprintSqlServerInstances.ps1](public/Remove-SprintSqlServerInstances.ps1) | Removes the per-developer SQL Server named instances created at sprint start. |
| [Remove-VSComponentCache.ps1](public/Remove-VSComponentCache.ps1) | ToDo: write Help SYNOPSIS For this function |
| [Rename-ProGetFeed.ps1](public/Rename-ProGetFeed.ps1) | Renames a ProGet feed using the ProGet management API. |
| [Reset-DownstreamToSharedVSCodeMain.ps1](public/Reset-DownstreamToSharedVSCodeMain.ps1) | Resets downstream workspace files back to SharedVSCode main, re-applies context, and removes the sprint ProGet feeds for the completed sprint. |
| [Resolve-FeatureSlug.ps1](public/Resolve-FeatureSlug.ps1) | Resolves a Git feature-branch name into the PascalCase `$FeatureSlug` used by the BuildMaster pipeline. |
| [Resolve-PSModuleMetadata.ps1](public/Resolve-PSModuleMetadata.ps1) | Resolves metadata for a PowerShell module located at a given start path. |
| [Save-SprintWorkSession.ps1](public/Save-SprintWorkSession.ps1) | Archives the current Claude Code conversation JSONL and copies memory files for the current sprint work session. |
| [Set-BuildMasterApplicationVariables.ps1](public/Set-BuildMasterApplicationVariables.ps1) | Creates or updates BuildMaster application variables from a hashtable. |
| [Set-BuildMasterSprintVariables.ps1](public/Set-BuildMasterSprintVariables.ps1) | Sets BuildMaster Application Variables for a new sprint. |
| [Set-BuildMasterStableVariables.ps1](public/Set-BuildMasterStableVariables.ps1) | Sets the permanent (stable) BuildMaster Application Variables for all apps. |
| [Set-DownstreamSharedVSCodeContext.ps1](public/Set-DownstreamSharedVSCodeContext.ps1) | Applies SharedVSCode settings to the current downstream Git repository. |
| [Set-TaskComplete.ps1](public/Set-TaskComplete.ps1) | Marks one or more task items in TASKS.md as complete under an exclusive file lock. |
| [Set-WorkspaceSharedVSCodeReference.ps1](public/Set-WorkspaceSharedVSCodeReference.ps1) | Updates the atap.sharedVSCode.templateRef and profile in workspace files. |
| [Set-WorktreeJunctions.ps1](public/Set-WorktreeJunctions.ps1) | Gets junctions from a source repository and recreates matching junctions in an existing worktree. |
| [Start-BuildMasterPipeline.ps1](public/Start-BuildMasterPipeline.ps1) | Triggers a BuildMaster build for an existing Application + Release. |
| [Start-DebugPowerShell.ps1](public/Start-DebugPowerShell.ps1) | Starts the debug power shell workflow. |
| [Start-PlanningSession.ps1](public/Start-PlanningSession.ps1) | Begin a planning session: pull main, create a GitHub issue, open a worktree branch, generate the session document, and open VS Code — all in one command. |
| [Sync-BuildMasterPlans.ps1](public/Sync-BuildMasterPlans.ps1) | Synchronizes local OtterScript plan files into BuildMaster. |
| [Sync-RulesToCSV.ps1](public/Sync-RulesToCSV.ps1) | Exports Rules, RulePrimitives, and related tables from the database to CSV files for version control. |
| [Sync-WorktreeShared.ps1.archived](public/Sync-WorktreeShared.ps1.archived) | Archived PowerShell script retained for historical reference. |
| [Test-CodeCoverageGate.ps1](public/Test-CodeCoverageGate.ps1) | Evaluates the 5-Tier code-coverage gate against a Cobertura or JaCoCo XML coverage file. |
| [Test-FailureAcknowledgedGate.ps1](public/Test-FailureAcknowledgedGate.ps1) | Evaluates the 5-Tier Failure-Acknowledged gate against a Pester JUnit XML result file. |
| [Test-PowerShellSyntax.ps1](public/Test-PowerShellSyntax.ps1) | Parses a PowerShell script file and reports syntax errors. |
| [Test-PromotionWithinCeiling.ps1](public/Test-PromotionWithinCeiling.ps1) | Tests whether a stage or destination tier is within a promotion ceiling. |
| [Update-BlocksInCsproj.ps1](public/Update-BlocksInCsproj.ps1) | Updates blocks in csproj content or metadata. |
| [Update-PackageVersion.ps1](public/Update-PackageVersion.ps1) | ToDo: write Help SYNOPSIS For this function |
| [Validate-ProGetFeeds.ps1](public/Validate-ProGetFeeds.ps1) | Validates pro get feeds configuration or state. |

## Resources

| File | Purpose |
| --- | --- |
| [FailureAcknowledged.schema.json](Resources/FailureAcknowledged.schema.json) | JSON schema used to validate build tooling data. |
| [Module.Build.ps1.save](Resources/Module.Build.ps1.save) | Saved reference copy retained for historical comparison. |
| [NuGet.Config](Resources/NuGet.Config) | NuGet configuration used by module resources or tests. |

## tests

| File | Purpose |
| --- | --- |
| [Build-PSModuleManifest.Tests.ps1](tests/Build-PSModuleManifest.Tests.ps1) | Pester 5+ tests for Build-PSModuleManifest. |
| [Build-PSModulePsm1.Tests.ps1](tests/Build-PSModulePsm1.Tests.ps1) | Pester 5+ tests for Build-PSModulePsm1. |
| [Invoke-FailureAcknowledgedGate.Tests.ps1](tests/Invoke-FailureAcknowledgedGate.Tests.ps1) | Pester tests for invoke failure acknowledged gate. |
| [Invoke-PSModulePesterTests.Tests.ps1](tests/Invoke-PSModulePesterTests.Tests.ps1) | Pester tests for invoke psmodule pester tests. |
| [Invoke-PSModulePSScriptAnalyzer.Tests.ps1](tests/Invoke-PSModulePSScriptAnalyzer.Tests.ps1) | Pester tests for invoke psmodule psscript analyzer. |
| [New-SprintSqlServerInstances.Tests.ps1](tests/New-SprintSqlServerInstances.Tests.ps1) | Pester tests for new sprint sql server instances. |
| [Test-CodeCoverageGate.Tests.ps1](tests/Test-CodeCoverageGate.Tests.ps1) | Pester tests for test code coverage gate. |
| [Test-FailureAcknowledgedGate.Tests.ps1](tests/Test-FailureAcknowledgedGate.Tests.ps1) | Pester tests for test failure acknowledged gate. |

## tests/fixtures/db/sample/flyway

| File | Purpose |
| --- | --- |
| [R__views.sql](tests/fixtures/db/sample/flyway/R__views.sql) | Sample SQL migration or seed fixture for database release tests. |
| [V0.0.1__baseline.sql](tests/fixtures/db/sample/flyway/V0.0.1__baseline.sql) | Sample SQL migration or seed fixture for database release tests. |

## tests/fixtures/db/sample/releases

| File | Purpose |
| --- | --- |
| [0.0.1.yml](tests/fixtures/db/sample/releases/0.0.1.yml) | Project file for 0 0 1. |

## tests/fixtures/db/sample/seed

| File | Purpose |
| --- | --- |
| [R__seed_lookup.sql](tests/fixtures/db/sample/seed/R__seed_lookup.sql) | Sample SQL migration or seed fixture for database release tests. |
| [S0_0_1_roles_load.sql](tests/fixtures/db/sample/seed/S0_0_1_roles_load.sql) | Sample SQL migration or seed fixture for database release tests. |
| [S0_0_1_roles.csv](tests/fixtures/db/sample/seed/S0_0_1_roles.csv) | Sample CSV seed-data fixture for database release tests. |

## tests/fixtures/New-ReleaseBundle/manifest

| File | Purpose |
| --- | --- |
| [db-manifest.json](tests/fixtures/New-ReleaseBundle/manifest/db-manifest.json) | JSON fixture or configuration data used by tests or release tooling. |
| [manifest.json](tests/fixtures/New-ReleaseBundle/manifest/manifest.json) | JSON fixture or configuration data used by tests or release tooling. |

## tests/fixtures/New-ReleaseBundle/source/app/bin

| File | Purpose |
| --- | --- |
| [AceCommander.dll](tests/fixtures/New-ReleaseBundle/source/app/bin/AceCommander.dll) | Compiled helper assembly bundled with the module. |

## tests/fixtures/New-ReleaseBundle/source/db/flyway

| File | Purpose |
| --- | --- |
| [V1.4.0__baseline_schema.sql](tests/fixtures/New-ReleaseBundle/source/db/flyway/V1.4.0__baseline_schema.sql) | Sample SQL migration or seed fixture for database release tests. |

## tests/fixtures/New-ReleaseBundle/source/db/seed

| File | Purpose |
| --- | --- |
| [S1_4_0_roles_load.sql](tests/fixtures/New-ReleaseBundle/source/db/seed/S1_4_0_roles_load.sql) | Sample SQL migration or seed fixture for database release tests. |
| [S1_4_0_roles.csv](tests/fixtures/New-ReleaseBundle/source/db/seed/S1_4_0_roles.csv) | Sample CSV seed-data fixture for database release tests. |

## tests/fixtures/New-ReleaseBundle/source/docs

| File | Purpose |
| --- | --- |
| [RELEASE_NOTES.md](tests/fixtures/New-ReleaseBundle/source/docs/RELEASE_NOTES.md) | Documentation: Fixture Release Notes. |

## tests/fixtures/New-ReleaseBundle/source/installer

| File | Purpose |
| --- | --- |
| [Install-Application.ps1](tests/fixtures/New-ReleaseBundle/source/installer/Install-Application.ps1) | PowerShell helper for install application. |

## tests/fixtures/New-ReleaseBundle/source/tests

| File | Purpose |
| --- | --- |
| [unit-results.trx](tests/fixtures/New-ReleaseBundle/source/tests/unit-results.trx) | Sample test result fixture for release-bundle tests. |

## tests/fixtures/release-manifests

| File | Purpose |
| --- | --- |
| [acecommander-1.4.0-manifest.json](tests/fixtures/release-manifests/acecommander-1.4.0-manifest.json) | JSON fixture or configuration data used by tests or release tooling. |
| [acecommander-1.4.1-manifest.json](tests/fixtures/release-manifests/acecommander-1.4.1-manifest.json) | JSON fixture or configuration data used by tests or release tooling. |
| [invalid-schema-manifest.json](tests/fixtures/release-manifests/invalid-schema-manifest.json) | JSON fixture or configuration data used by tests or release tooling. |
| [malformed-manifest.json](tests/fixtures/release-manifests/malformed-manifest.json) | JSON fixture or configuration data used by tests or release tooling. |

## tests/Integration

| File | Purpose |
| --- | --- |
| [Directory.Build.Props.Properties.Tests.ps1](tests/Integration/Directory.Build.Props.Properties.Tests.ps1) | Pester tests for directory build props. |
| [New-ReleaseManifest.Integration.Tests.ps1](tests/Integration/New-ReleaseManifest.Integration.Tests.ps1) | Pester tests for new release manifest. |
| [VersionJsonAsCeiling.StageMatrix.Tests.ps1](tests/Integration/VersionJsonAsCeiling.StageMatrix.Tests.ps1) | Pester tests for version json as ceiling. |

## tests/Unit

| File | Purpose |
| --- | --- |
| [Approve-BuildMasterStage.Tests.ps1](tests/Unit/Approve-BuildMasterStage.Tests.ps1) | Pester tests for approve build master stage. |
| [Assert-GitAvailable.Tests.ps1](tests/Unit/Assert-GitAvailable.Tests.ps1) | Pester tests for assert git available. |
| [Assert-MainBranchTemplateRef.Tests.ps1](tests/Unit/Assert-MainBranchTemplateRef.Tests.ps1) | Pester tests for assert main branch template ref. |
| [ATAP.Utilities.BuildTooling.PowerShell.Tests.ps1](tests/Unit/ATAP.Utilities.BuildTooling.PowerShell.Tests.ps1) | Pester tests for atap utilities build tooling. |
| [BuildMasterConfigurationApi.Tests.ps1](tests/Unit/BuildMasterConfigurationApi.Tests.ps1) | Pester tests for build master configuration api. |
| [Compare-ReleaseManifest.Tests.ps1](tests/Unit/Compare-ReleaseManifest.Tests.ps1) | Pester tests for compare release manifest. |
| [Compress-PSModuleArtifacts.Tests.ps1](tests/Unit/Compress-PSModuleArtifacts.Tests.ps1) | Pester tests for compress psmodule artifacts. |
| [Confirm-Tools.Tests.ps1](tests/Unit/Confirm-Tools.Tests.ps1) | Pester tests for confirm tools. |
| [ConvertTo-ProGetFeedNameAlternateForm.Tests.ps1](tests/Unit/ConvertTo-ProGetFeedNameAlternateForm.Tests.ps1) | Pester tests for convert to pro get feed name alternate form. |
| [Get-BuildContext.Ceiling.Tests.ps1](tests/Unit/Get-BuildContext.Ceiling.Tests.ps1) | Pester tests for get build context. |
| [Get-BuildContext.Tests.ps1](tests/Unit/Get-BuildContext.Tests.ps1) | Pester tests for get build context. |
| [Get-DeployedReleaseManifest.Tests.ps1](tests/Unit/Get-DeployedReleaseManifest.Tests.ps1) | Pester tests for get deployed release manifest. |
| [Get-ModuleAsSymbolicLink.Tests.ps1](tests/Unit/Get-ModuleAsSymbolicLink.Tests.ps1) | Pester tests for get module as symbolic link. |
| [Get-NuSpecFromManifest.Tests.ps1](tests/Unit/Get-NuSpecFromManifest.Tests.ps1) | Pester tests for get nu spec from manifest. |
| [Get-PSModuleVersionFromNBGV.Tests.ps1](tests/Unit/Get-PSModuleVersionFromNBGV.Tests.ps1) | Pester tests for get psmodule version from nbgv. |
| [Get-RepoRoot.Tests.ps1](tests/Unit/Get-RepoRoot.Tests.ps1) | Pester tests for get repo root. |
| [Get-SharedVSCodeContext.Tests.ps1](tests/Unit/Get-SharedVSCodeContext.Tests.ps1) | Pester tests for get shared vscode context. |
| [Get-SharedVSCodeRootFromTemplateRef.Tests.ps1](tests/Unit/Get-SharedVSCodeRootFromTemplateRef.Tests.ps1) | Pester tests for get shared vscode root from template ref. |
| [Get-SprintTaskRepositoryNames.Tests.ps1](tests/Unit/Get-SprintTaskRepositoryNames.Tests.ps1) | Pester tests for get sprint task repository names. |
| [Get-TierFromNBGVLabel.Tests.ps1](tests/Unit/Get-TierFromNBGVLabel.Tests.ps1) | Pester tests for get tier from nbgvlabel. |
| [Get-WorkspaceJson.Tests.ps1](tests/Unit/Get-WorkspaceJson.Tests.ps1) | Pester tests for get workspace json. |
| [Initialize-DownstreamSprintFromSharedVSCode.Tests.ps1](tests/Unit/Initialize-DownstreamSprintFromSharedVSCode.Tests.ps1) | Pester tests for initialize downstream sprint from shared vscode. |
| [Initialize-ProGetSqlServiceLogin.Tests.ps1](tests/Unit/Initialize-ProGetSqlServiceLogin.Tests.ps1) | Pester tests for initialize pro get sql service login. |
| [Invoke-PromotedModuleTests.Tests.ps1](tests/Unit/Invoke-PromotedModuleTests.Tests.ps1) | Pester tests for invoke promoted module tests. |
| [Invoke-PromotedPackageTests.Tests.ps1](tests/Unit/Invoke-PromotedPackageTests.Tests.ps1) | Pester tests for invoke promoted package tests. |
| [Merge-PesterConfiguration.Tests.ps1](tests/Unit/Merge-PesterConfiguration.Tests.ps1) | Pester tests for merge pester configuration. |
| [Move-ProGetPackageInterTier.Tests.ps1](tests/Unit/Move-ProGetPackageInterTier.Tests.ps1) | Pester tests for move pro get package inter tier. |
| [Move-ProGetPackageIntraTier.Tests.ps1](tests/Unit/Move-ProGetPackageIntraTier.Tests.ps1) | Pester tests for move pro get package intra tier. |
| [New-BuildMasterRelease.Tests.ps1](tests/Unit/New-BuildMasterRelease.Tests.ps1) | Pester tests for new build master release. |
| [New-GeneratedFileContent.Tests.ps1](tests/Unit/New-GeneratedFileContent.Tests.ps1) | Pester tests for new generated file content. |
| [New-HostSettingsForPackageRepositoryFeeds.Tests.ps1](tests/Unit/New-HostSettingsForPackageRepositoryFeeds.Tests.ps1) | Pester tests for new host settings for package repository feeds. |
| [New-MockTestFileStructure.Tests.ps1](tests/Unit/New-MockTestFileStructure.Tests.ps1) | Pester tests for new mock test file structure. |
| [New-OverviewSprintWorkspace.Tests.ps1](tests/Unit/New-OverviewSprintWorkspace.Tests.ps1) | Pester tests for new overview sprint workspace. |
| [New-PesterFileModel.Tests.ps1](tests/Unit/New-PesterFileModel.Tests.ps1) | Pester tests for new pester file model. |
| [New-PesterRuleSetTemplates.Tests.ps1](tests/Unit/New-PesterRuleSetTemplates.Tests.ps1) | Pester tests for new pester rule set templates. |
| [New-PesterTestFile.Tests.ps1](tests/Unit/New-PesterTestFile.Tests.ps1) | Pester tests for new pester test file. |
| [New-ProGetFeedSet.Tests.ps1](tests/Unit/New-ProGetFeedSet.Tests.ps1) | Pester tests for new pro get feed set. |
| [New-PSModuleNupkg.Tests.ps1](tests/Unit/New-PSModuleNupkg.Tests.ps1) | Pester tests for new psmodule nupkg. |
| [New-ReleaseBundle.Tests.ps1](tests/Unit/New-ReleaseBundle.Tests.ps1) | Pester tests for new release bundle. |
| [New-ReleaseManifest.Tests.ps1](tests/Unit/New-ReleaseManifest.Tests.ps1) | Pester tests for new release manifest. |
| [New-SprintStageDryRun.Tests.ps1](tests/Unit/New-SprintStageDryRun.Tests.ps1) | Pester tests for new sprint stage dry run. |
| [Promote-ProGetPackage.Tests.ps1](tests/Unit/Promote-ProGetPackage.Tests.ps1) | Pester tests for promote pro get package. |
| [Publish-NuGetPackageToProGet.Tests.ps1](tests/Unit/Publish-NuGetPackageToProGet.Tests.ps1) | Pester tests for publish nu get package to pro get. |
| [Publish-PSModuleToProGet.Tests.ps1](tests/Unit/Publish-PSModuleToProGet.Tests.ps1) | Pester tests for publish psmodule to pro get. |
| [Publish-PSModuleToProGetFeed.Tests.ps1](tests/Unit/Publish-PSModuleToProGetFeed.Tests.ps1) | Pester tests for publish psmodule to pro get feed. |
| [Publish-UniversalPackageToProGet.Tests.ps1](tests/Unit/Publish-UniversalPackageToProGet.Tests.ps1) | Pester tests for publish universal package to pro get. |
| [Read-SourceAndCreateRules.Tests.ps1](tests/Unit/Read-SourceAndCreateRules.Tests.ps1) | Returns an example value. |
| [Remove-SprintBitwardenSecrets.Tests.ps1](tests/Unit/Remove-SprintBitwardenSecrets.Tests.ps1) | Pester tests for remove sprint bitwarden secrets. |
| [Remove-SprintSqlServerInstances.Tests.ps1](tests/Unit/Remove-SprintSqlServerInstances.Tests.ps1) | Pester tests for remove sprint sql server instances. |
| [Rename-ProGetFeed.Tests.ps1](tests/Unit/Rename-ProGetFeed.Tests.ps1) | Pester tests for rename pro get feed. |
| [Reset-DownstreamToSharedVSCodeMain.Tests.ps1](tests/Unit/Reset-DownstreamToSharedVSCodeMain.Tests.ps1) | Pester tests for reset downstream to shared vscode main. |
| [Resolve-FeatureSlug.Tests.ps1](tests/Unit/Resolve-FeatureSlug.Tests.ps1) | Pester tests for resolve feature slug. |
| [Resolve-PSModuleMetadata.Tests.ps1](tests/Unit/Resolve-PSModuleMetadata.Tests.ps1) | Pester tests for resolve psmodule metadata. |
| [Resolve-WorkspaceFiles.Tests.ps1](tests/Unit/Resolve-WorkspaceFiles.Tests.ps1) | Pester tests for resolve workspace files. |
| [Save-WorkspaceJson.Tests.ps1](tests/Unit/Save-WorkspaceJson.Tests.ps1) | Pester tests for save workspace json. |
| [Set-DownstreamSharedVSCodeContext.Tests.ps1](tests/Unit/Set-DownstreamSharedVSCodeContext.Tests.ps1) | Pester tests for set downstream shared vscode context. |
| [Set-ProGetServiceDependency.Tests.ps1](tests/Unit/Set-ProGetServiceDependency.Tests.ps1) | Pester tests for set pro get service dependency. |
| [Set-WorkspaceSharedVSCodeReference.Tests.ps1](tests/Unit/Set-WorkspaceSharedVSCodeReference.Tests.ps1) | Pester tests for set workspace shared vscode reference. |
| [Start-BuildMasterPipeline.Tests.ps1](tests/Unit/Start-BuildMasterPipeline.Tests.ps1) | Pester tests for start build master pipeline. |
| [Sync-BuildMasterPlans.Tests.ps1](tests/Unit/Sync-BuildMasterPlans.Tests.ps1) | Pester tests for sync build master plans. |
| [Sync-RulesToCSV.Tests.ps1](tests/Unit/Sync-RulesToCSV.Tests.ps1) | Pester tests for sync rules to csv. |
| [Test-CommandExists.Tests.ps1](tests/Unit/Test-CommandExists.Tests.ps1) | Pester tests for test command exists. |
| [Test-ModuleManifest.NotRight.ps1](tests/Unit/Test-ModuleManifest.NotRight.ps1) | ToDo: write Help SYNOPSIS For this function |
| [Test-MSBuildPropertyPropagation.Tests.ps1](tests/Unit/Test-MSBuildPropertyPropagation.Tests.ps1) | Pester tests for test msbuild property propagation. |
| [Test-PromotionWithinCeiling.Tests.ps1](tests/Unit/Test-PromotionWithinCeiling.Tests.ps1) | Pester tests for test promotion within ceiling. |

## tools

| File | Purpose |
| --- | --- |
| [install.ps1](tools/install.ps1) | PowerShell helper for install. |
| [Run7-InISE.ps1](tools/Run7-InISE.ps1) | PowerShell helper for run7 in ise. |
| [Setup-GitHubMCP.ps1](tools/Setup-GitHubMCP.ps1) | Helper script to configure GitHub MCP (Model Context Protocol) for VS Code |
| [Test-GitHubMCP.ps1](tools/Test-GitHubMCP.ps1) | Test the GitHub MCP server connection |
