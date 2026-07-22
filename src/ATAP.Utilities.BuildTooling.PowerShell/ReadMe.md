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

The bounded BWS ReadOnly bootstrap commands provision only `SvcBuildMaster`,
`SvcProGet`, and `SvcSQLServer` for the fixed `CI-Shared` ReadOnly purpose. See
[BWSReadOnlyBootstrap.md](Documentation/BWSReadOnlyBootstrap.md) for the public-certificate
CMS envelope flow, canonical account paths, Password-logon task isolation under
`\ATAP\`, idempotency statuses, and fail-closed recovery rules.

Full-repository C# MSBuild property audits live outside this module at
`tests\RepoHealth` and run through `Build\Invoke-RepoHealthGate.ps1`. They are
not part of `module.build.ps1` for this PowerShell module because they enumerate
C# projects across the repository.

Sprint lifecycle plumbing in this module now resolves downstream Git context from
the workspace file paths being retargeted instead of the caller's current
directory. Generated `.gitattributes` and `.gitconfig.shared` content also
replaces any existing generated header before writing a fresh one, so repeated
retargeting refreshes metadata without stacking header blocks.

SprintStart verifies the owner of each newly created worktree's exact `.git`
pointer before the first commit. A mismatch is repaired only on that pointer,
re-read, and failed closed if ownership still differs from the interactive
operator; the workflow never adds parent-wide or wildcard `safe.directory`
trust. Sprint overview developer identity is the composite `(username, host)`
pair, so one developer may be assigned to multiple hosts. Regeneration preserves
explicit or existing multi-host assignments deterministically instead of
deduplicating by username.

SprintStart and SprintEnd now use `Invoke-SprintAIAdapterLifecycle`, which calls
the SharedVSCode registry-backed settings/permissions renderer and drift audit.
SprintStart defaults to project-only writes; SprintEnd audits before teardown and
leaves sprint links intact when drift requires promote/regenerate review. Live
user/global replacement requires explicit approval and checkpoint confirmation.
The underlying canonical commands are
`Render-AIAdapters -Domain settings,permissions` at Start and
`Test-AIAdapterDrift -Domain settings,permissions` at End, in fixed caller order
Antigravity → Codex → Claude Code → Copilot. Runtime and MCP state remain
preserve/defer surfaces, and all lifecycle evidence/backups belong under
`_generated/`. Task 10.26.k removed the settings-named transition wrapper; all
callers now use the adapter lifecycle.

`Set-SprintBoundaryContext` now closes the remaining SprintEnd boundary gaps from
Tasks 11.7.f-h. In addition to machine-level profile deployment and HostSettings retargeting, it
deploys developer profiles from the resolved closing-sprint Overview workspace
(`Overview.Sprint.NNNN.code-workspace` when present, otherwise an explicitly
supported legacy sprint-workspace spelling) and service

The same Start and End orchestration treats the Task 12.59 DPOM role marker as
stable operational state. `Sync-SprintBoundaryPrimaryRoleMarker` validates the
single Dropbox-synchronized marker at
`C:\Dropbox\whertzing\ATAP\ParityState\PrimaryRole.json`; if only the legacy
`C:\ProgramData\ATAP\ParityState\PrimaryRole.json` exists, it atomically copies
that record to the shared location. It never changes an authorized role and
stops the boundary when shared and legacy records disagree.
account profiles from host settings into each identity's
`Documents\PowerShell\profile.ps1`. The cmdlet also refreshes the SharedVSCode
settings render at both boundaries so `permissions.additionalDirectories` and
hook command paths in `settings.overlay.json` follow the sprint or stable target
before user settings are relinked. `Test-SprintEndBoundaryState` auto-discovers
those managed profiles when `-ProfilePaths` is omitted and verifies that each is
stable-sourced, readable, and free of stale `-wt-` references after SprintEnd.
Both developer and service-account source discovery resolves only the canonical
`ATAP.IAC\Windows\ProfileTemplates` payloads; validation never recreates the
retired `ATAP.Utilities.PowerShell\Profiles` payload targets.
SprintEnd stable junction retargeting is now intentionally narrower: by default
it recreates only the supported `.vscode` junction and does not reintroduce
obsolete rendered `.claude` / `.github` links. For one-time stable maintenance,
`Convert-StableWorktreeToConcreteAdapters` removes legacy `.claude` /
`.github` junctions from a stable repo root and restores the tracked concrete
content from `HEAD`; it refuses staged changes and leaves `.vscode` alone by
design.

**Managed user-scope profiles (Task 12.49).** `Set-UserScopeProfile` renders
the canonical ATAP.IAC developer or service-account template to
`Documents\PowerShell\profile.ps1`. Developer profiles dot-source the selected
ATAP.Utilities core profile; service-account profiles are minimal and contain
no `bw`/`bws`, browser, or secret-resolution path. Existing profiles without
the managed marker require `-Force`; each live mutation journals through
`Add-ParityChangeEntry`. For Task 12.49, the complete service-account scope for
both a managed profile and Bitwarden ReadOnly access is `SvcBuildMaster`,
`SvcProGet`, `SvcSeq`, `SvcSQLServer`, and `SvcParityAudit`.
`Set-SprintBoundaryUserProfiles` uses this cmdlet for the approved developer and
service identities, leaving peer provisioning to the hardened remoting path.

**SprintEnd typed close (Task 10.6 / 11.7.c-e).** `Invoke-SprintEndLifecycle` now composes
structured command-surface, module-promotion/deployment, worktree-state,
AIAdapter/template reset, GitHub PR/issue, dotted-history, Overview, HANDOFF,
database/BuildMaster cleanup, retrospective notebook gates, and final-boundary phases. PR bodies receive the
originating issue closing keyword; check results are classified into required,
informational, and CodeSee planning signals. The GitHub close path now runs a
token-scope preflight before any GraphQL-backed PR calls and fails early with
clear remediation when the active `gh` token lacks either `read:org` or
`read:discussion`, which avoids the late `slug`-field permission failure seen
during SprintEnd close. HANDOFF stable pulls use an R-31
overlap gate and `pull --ff-only` with editor suppression. The lifecycle always
keeps the active `_Planning` worktree in the close plan, even if the caller omits
it from `-WorktreePaths`, so dry-runs show `_Planning` alongside the other PR,
merge, branch-delete, and worktree-removal targets. Generated handoffs now use
the sprint-specific `HANDOFF.SprintNNNN.md` naming pattern and emit parser-safe
splatting for boundary verification and self-removal commands. Generated
`.gitattributes` and `.gitconfig.shared` headers are timestamp-free and
byte-idempotent. `Test-SprintCheckpointCoverage` verifies final checkpoints
entirely from canonical Planning roots; `Save-SprintEndSessionTail` creates the
scoped post-merge stable Planning commit without pushing.
`Get-SprintHistoryReconstruction` reconstructs the latest completed sprint from
retrospective notebooks, SprintHistory folders, task artifact sets, snapshots,
and close commits, then reports source disagreements as structured warnings.
`New-SprintStage1` uses that aggregate instead of trusting one weak signal when
auto-detecting the next sprint number. `Restore-SprintHistoryArtifacts` remains
the explicit one-off path for reconstructing pre-dotted history from reviewed Git
revisions. It writes exact Git blob bytes, preserves repository-relative paths,
records the resolved commit as provenance, and preserves different existing
content. SprintEnd removes sprint databases while retaining permanent
developer SQL Server instances, never deletes Bitwarden secrets, and never
invokes a synthetic sprint-completion task. The structured result reports
`DatabaseCleanupMode = 'SprintDatabasesOnly'` and
`SqlInstancesRetained = true`.

Sprint planning also now has an explicit markdown-to-board path: use
`Convert-TasksMdToSprintBoard` to regenerate a sprint `TASKS.html` board from the
authoritative `TASKS.md` file after task edits or status updates. Indented lettered
subtasks (`N.M.a/b/c`) are emitted as their own board cards — numbered distinctly,
not indented — and inherit the `[Repo]` tag from their umbrella task. Single-line tasks are parsed safely without scalar unrolling.

Stage 2 database startup is now safe for non-interactive agent shells (Tasks
10.4 and 10.5). `Test-SprintPrerequisites` and `New-SprintStage2` call the
source-first `Initialize-ATAPConfigurationGlobals` helper when
`$global:configRootKeys` or `$global:settings` is absent or incomplete. The
normal reset path passes the newly created ATAP.Utilities worktree root and its
current `SharedSQL` provisioning folder to `Reset-SprintDatabases`, with
`-Confirm:$false`, so an installed BuildTooling module cannot fall back to stale
module-relative Flyway or `DropAndCreateDatabase.sql` content.
`Reset-SprintDatabases` imports `dbatools` before resolving
`Build-DatabaseWithFlyway`, preventing `Microsoft.Data.SqlClient` assembly
load-order conflicts during Stage 2 database resets. Connection-part resets
default to Windows integrated security when no connection-string secret or
credential key is resolved, and each instance uses an instance-scoped fallback
database-file path under `C:\LocalDBs\<InstanceName>\<DatabaseName>` when no
settings value supplies `DatabasePath`. Use `-SkipDatabaseReset` to bypass both
the Dev/Exp instance guard and reset during granular recovery, and
`-IncludeRepos` to provision repositories that have no task-board marker.

**Stage 1 creates a content-fresh sprint task set (Task 10.11).** After the
`_Planning` worktree exists, `New-SprintStage1` reads the immediately prior
sprint's task markdown only to validate and recover its stream structure. It
generates `Tasks.Sprint<NNNN>.md` with current-sprint scaffold text and no prior
task content, calls `Convert-TasksMdToSprintBoard` to synchronize
`Tasks.Sprint<NNNN>.html`, creates empty
`Tasks.Sprint<NNNN>.Accomplished.html` and
`Tasks.Sprint<NNNN>.ProceduralDetails.html` companions, and removes the
prior-sprint root artifacts after templating. Stage 1 now creates only the
supported `.vscode` junction in `_Planning` by default; `.claude` and `.github`
surfaces are owned by AIAdapter materialization. Legacy `TASKS.md` and
`TasksSprint<NNNN>.md` inputs remain accepted for the first transition. The sprint
numbering is now robustly detected from the max numbering across artifact families,
and `-WhatIf` context is correctly propagated through all nested operations.

**Stage 2 generates the sprint Overview workspace (Task 10.14.a).** After every
downstream sprint worktree exists, `New-SprintStage2` calls
`New-OverviewSprintWorkspace` to produce `Overview.Sprint.NNNN.code-workspace` in
the GitHub root and then runs a verification gate — the file must exist and must
resolve at least one `*-wt-<n>-Sprint-<NNNN>-work-items` folder. Earlier sprints
created this file only through a documentation-only agent step, so a live run
that deviated from the runbook left it missing and blocked
`Build-CLAUDEPerRepository` / CLAUDE.md propagation at Sprint 0010 start
(SC-0193). Generating it inside Stage 2 makes the step unskippable; the result
carries `infrastructure.overviewWorkspacePath`,
`infrastructure.overviewWorkspaceVerified`, and
`infrastructure.overviewWorkspaceError`. The gate is non-fatal — a verification
failure is reported in `overviewWorkspaceError` without aborting the rest of
Stage 2 — and the step is skipped under `-DryRun`/`-WhatIf`.
SprintEnd now resolves the exact closing sprint artifact by sprint number and
prefers `Overview.Sprint.NNNN.code-workspace`,
instead of accidentally touching stale older overview files.

**Stage 2 distributes AI instructions through one orchestration (Task 10.34).**
Immediately after the Overview workspace verification gate,
`New-SprintStage2` calls `Build-AIInstructionsPerRepository` once. The
orchestrator parses the workspace and computes stable-worktree skips once, then
passes that shared context to the existing Claude, AGENTS/Codex, and
agent-specific lanes. Its aggregate is returned as
`infrastructure.aiInstructions`, with failures in
`infrastructure.aiInstructionsError`. A dry run reports the single planned
distribution step without invoking any builder. The four resulting surfaces are
`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, and
`.github/copilot-instructions.md`; compare-before-write behavior makes a second
run a true no-op, and agent-specific bases are rejected if they duplicate the
shared core body.

`New-MarkdownChangeTrackingReport` audits the change-tracking hygiene of a
documentation tree. It recursively scans `-Path` for `*.md` files, reads the
first ten lines of each, and flags whether a change-tracking header is present
(an `<!-- change-tracking:` comment, a `change-tracking:` line, or a
`last-updated:` line). The result is a single self-contained HTML report written
to `-Output` (with a sticky folder navigation pane, per-file preview cards, and a
scanned / tracked / untracked summary banner); all previewed file content is
HTML-encoded before embedding. Pass `-SolutionDocumentationOnly` to limit the
scan to `SolutionDocumentation` folders. Per SC-0033, target an `-Output` path
under the repository `_generated/` folder.

`Invoke-GitCommit` now supports task-scoped grouped commits (Task 9.24).
A cohesive dirty tree can still produce one Conventional Commit, while mixed
trees can pass explicit path groups so each group stages only its own paths, runs
the sensitive-file and lock-file guards, appends a `Co-Authored-By` footer, and
leaves unrelated dirty files unstaged.

`Build-PSModulePsm1` produces self-contained package modules without carrying
source-only export declarations into the generated `.psm1` (Task 10.1). It
strips direct top-level `Export-ModuleMember` statements and export-only
`if ($MyInvocation.MyCommand.ScriptBlock.Module)` wrappers while preserving the
source files, nested commands, and unrelated module guards. The generated
manifest remains the single authority for `FunctionsToExport`.

`Build-PSModuleManifest` regenerates package manifests with core
`New-ModuleManifest` parameters instead of copying a manifest and calling
PowerShellGet's `Update-ModuleManifest`; prerelease metadata is supplied through
`-Prerelease`, and malformed source manifests now fail as terminating errors.

Checkpoint saves now also append a lightweight session roster entry under the
sprint `_Planning` worktree at
`SprintWorkSessionRoster/SprintWorkSessionRoster-<NNNN>.jsonl`, which gives
SprintEnd a concrete list of worktree session names to validate against the
archived conversation set.

`Save-SprintWorkSession` checkpoints **four** AI coding-agent families via the
`-Agent` parameter (Task 9.32): `ClaudeCode` (default; transcript JSONL under
`~\.claude\projects`), `Antigravity` (`-ConversationId`; transcript + memory
artifacts under `~\.gemini\antigravity\brain\<id>`, with the SQLite conversation
DB recorded when present), `Codex` (`-SessionId`; rollout transcript under
`~\.codex\sessions`, falling back to `~\.codex\archived_sessions`), and `Copilot`
(`-ConversationFile`; delegates to `Save-CopilotCheckpoint` since Copilot writes
no on-disk transcript). Every agent path, including Copilot, writes the canonical
sprint-session roster entry. Antigravity and Codex auto-detect the newest
conversation/rollout when the id argument is omitted. The roster entry records the
`Agent`, `AgentSessionKey`, and `ConversationDbPath` for each save. For
ClaudeCode, the project slug directory is resolved from the actual on-disk child
folder before searching transcripts or copying `memory\`, so drive-letter casing
differences in Claude's project folder names do not cause false memory-copy skips.

**BuildMaster PowerShell Module Release Naming (Task 9.37).** To support building multiple arbitrary PowerShell modules within the single consolidated BuildMaster application (`ATAP.Utilities-PowerShell`) without collisions, the BuildMaster `ReleaseNumber` is generated uniquely per module. The release number appends the module name as a suffix (e.g., `0.1.0-ATAP.Utilities.PowerShell` for stable versions, and `0.1.0-Alpha.6.ATAP.Utilities.PowerShell` for prerelease versions), which is fully SemVer 2.0.0 compliant. This naming is strictly internal to BuildMaster and does not bleed into the built package's name, version, or manifest (`.psd1`) file.

**BuildMaster sprint-variable application targeting (Task 10.12).** A single repository can map to one or more BuildMaster applications whose names do **not** match the repository name — the `ATAP.Utilities` repo builds both `ATAP.Utilities-CSharp` and `ATAP.Utilities-PowerShell`, so POSTing to `/api/variables/application/ATAP.Utilities/...` returns 404. `Set-BuildMasterSprintVariables` and `Clear-BuildMasterSprintVariables` therefore (1) drive the worked set from the sprint's **actual** repositories (the keys of `-SprintBranchNames`/`-SourcePaths`, never a fixed `AceCommander`/`ATAP.Utilities` list, so repos outside the sprint are never touched) and (2) resolve each repository to its real BuildMaster application name(s) through `-RepositoryApplicationMap`. Repositories that participate in the sprint but have no BuildMaster application (e.g. `_Planning`, `SharedVSCode`) are absent from the map and are reported in the `skippedRepositories` result field rather than 404-ing. `New-SprintStage2` passes repo-name-keyed branch/source-path maps built from its `$repoResults`, so the in-sprint applications are set without 404s and AceCommander is no longer targeted when it is not in the sprint.

**Batch module pipeline driver (Task 10.33).** `Start-BuildMasterModulePipelineBatch` releases several PowerShell modules in one call without releasing any of them by hand. It accepts an ordered `[string[]] -ModuleName`, normalizes duplicates while preserving caller order, and **preflights every module before creating any BuildMaster release**: it resolves `src/<ModuleName>` (requiring a project-adjacent `version.json` via `Resolve-BuildMasterPackageProjectPath`), computes the immutable package version and `CeilingTier` through `Get-BuildContext`, and resolves each module's BuildMaster application from `-ApplicationByModule` or reviewed configuration — it never guesses when a mapping is absent. Only after all modules pass preflight does it invoke `Start-BuildMasterPackagePipeline` once per module on `global::PowerShellModule-5Stage`, passing the resolved identity and the module's ceiling as the `$CeilingTier` build variable so BuildMaster builds/packages once in Experimental, runs the applicable promoted-module tests, promotes the same immutable bytes through ProGet, and skips every stage above that module's ceiling (`Sprint`/feature → Experimental, `Alpha` → Development, `Beta` → Integration, `QA` → QA, no prerelease label → Production/stable). Modules run sequentially and the batch fails fast unless `-ContinueOnError` is supplied; it supports `-WhatIf`, passes only a secret *name* for BuildMaster credentials, and returns one structured aggregate whose ordered `Results` carry each module's application, project path, package version, ceiling, BuildMaster release/build/execution identifiers, terminal tier, success, and failure detail. The batch only queues and observes BuildMaster work — it never reimplements packaging, tests, feed promotion, or ceiling decisions locally.

**Profileless BuildMaster promotion runners.** `Promote-ProGetPackage` accepts explicit `-ProGetBaseUrl` and the non-secret `-ProGetApiKeySecretName`, forwarding the SecretName to `Move-ProGetPackageInterTier`. The authenticated leaf resolves it through `Get-SecretATAP`; runners never receive a raw key or use an environment fallback. Explicit promotion inputs bypass profile-populated global settings, including when `$global:settings` is absent or lacks the promotion keys.

**ProGet administration SecretName boundary (Task 13.62).** Administration
cmdlets accept only the non-secret `ProGet.Admin.API.Key` name and resolve it
inside the authenticated leaf. See
[ProGetAdministrationSecretNameBoundary.md](Documentation/ProGetAdministrationSecretNameBoundary.md)
for the covered command surface and fail-closed verification contract.

Scope-creep capture (`Add-ScopeCreepIdea`) now resolves the target `_Planning`
worktree through `Resolve-PlanningWorktreeRoot` (Task 9.23). Resolution is
anchored on the **Sprint token** (`Sprint-<NNNN>-work-items`) shared across
repos — not the per-repo issue number, which differs (e.g.
`ATAP.Utilities-wt-110-…` pairs with `_Planning-wt-18-…`). From a sprint shell it
finds the sibling `_Planning*-wt-*-Sprint-<NNNN>-work-items` worktree (with a
widened, case-insensitive `OverView*.code-workspace` fallback). When a sprint
context is detected but no sprint `_Planning` worktree can be found, it **throws
rather than silently writing to the stable (main) worktree**; pass
`-PlanningRoot` to target a worktree explicitly. This fixes the prior silent
fall-back that wrote scope-creep ideas to the stable `_Planning` worktree.

Sprint lifecycle secret automation (`New-SprintBitwardenSecrets`,
`Remove-SprintBitwardenSecrets`, `Test-SprintPrerequisites`,
`Test-SprintInfrastructureHealth`) authenticates to Bitwarden Secrets Manager
with the `bws` CLI and a machine access token (`$env:BWS_ACCESS_TOKEN` or a
purpose-specific DPAPI token file via `Get-BWSAccessToken`). `ReadOnly` maps to
CommonCIForBitwardenReadOnly and is the default for reads; ReadWrite maps to
CommonCIForBitwardenReadWrite and is reserved for secret creation, deletion,
and rotation. BW_SESSION is personal-vault-only and is never required by sprint
automation (SC-0175). Reads of per-sprint machine secrets go through
Get-SecretATAP -SecretStoreType 'BitwardenSecretsManager'.

For human provisioning, every developer or service account that reads BWS secrets should
have a local ReadOnly DPAPI token file. A second ReadWrite DPAPI token file exists so
secret-maintenance workflows can be authorized separately; provision it only on trusted
maintainer or provisioning identities and only on hosts that actually perform write/delete
or rotation work.

**DB connection-string secrets (Task 10.7 cleanup).** Development and
Experimental DB connection strings are normal Bitwarden Secrets Manager entries,
not personal-vault items and not reader-side deterministic fallbacks.
`New-SprintBitwardenSecrets` uses `bws` plus process `$env:BWS_ACCESS_TOKEN` override or the
`CommonCIForBitwardenReadWrite` DPAPI token file to create/check the expected `dbConnectionString.*` entries in
the `CI-Shared` project. `Get-DbConnectionStringSecretDescriptor` remains the
single source of truth for the canonical name and can generate the
Integrated-Security value only when a provisioning caller explicitly opts into
`-DerivableTier @('Dev','Exp')`. Runtime reads use `Get-SecretATAP
-SecretStoreType 'BitwardenSecretsManager'` (or `Resolve-DatabaseSqlConnection`)
and fail if BWS cannot return the value. The compatibility
`-WriteDerivableToVault` switch is retained but persistence is now the default.

**Personal-vault / `bw` purge (Task 9.21).** CI/infrastructure secrets must
never live in a developer's personal Bitwarden Password Manager vault. The
`bw`/`BW_SESSION` writer and service-account session machinery
(`New-PermanentBitwardenSecrets`, `Initialize-ServiceAccountBitwardenSession`,
`Refresh-BWSession`, `Update-ServiceAccountBWCredentialFile`) was retired to
`Obsolete/public/` and removed from the exported surface. The personal-vault
read provider `Get-SecretATAPBitwarden` remains only as an opt-in path for
genuine per-user personal secrets and now **refuses CI/infra secret names**
(connection strings, API keys, ProGet/BuildMaster and service-account secrets),
directing callers to Bitwarden Secrets Manager. If a host still has scheduled
tasks invoking the retired session scripts, remove them as infrastructure
cleanup.

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
`$env:Workspace = 'C:\JenkinsAgentNode\utat022Node\workspace\Package-PowershellModule'`
`$env:Workspace = 'D:\Jenkins\ncat016\workspace\Package-PowershellModule'`

$scriptName = 'Publish-PSPackage.ps1'; $moduleName ='ATAP.Utilities.BuildTooling.PowerShell';  $relativeScriptDirectory= join-path 'src' $ModuleName 'public';$localRepoRoot = join-path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'ATAP.Utilities'; Remove-Item -path (join-path $env:Workspace $scriptname) -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:Workspace $scriptname) -Target (join-path $localRepoRoot $relativeScriptDirectory $scriptName)

$sourceScriptName = 'Update-PackageVersion.ps1';
$sourceModuleName ='ATAP.Utilities.Buildtooling.Powershell';
$sourceRepoRoot = join-path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'ATAP.Utilities';
$targetScriptName = $sourceScriptName;
$targetScriptDirectory ='.';
$relativeScriptSourceDirectory = join-path 'src' $sourceModuleName 'public';
Remove-Item -path (join-path $targetScriptDirectory $targetScriptName) -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $targetScriptDirectory $sourceScriptName) -Target (join-path $sourceRepoRoot $relativeScriptSourceDirectory $sourceScriptName)

$scriptName = 'Update-PackageVersion.ps1'; $moduleName ='ATAP.Utilities.BuildTooling.PowerShell';  $relativeScriptDirectory= join-path 'src' $ModuleName 'public';$localRepoRoot = join-path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'ATAP.Utilities'; Remove-Item -path (join-path $env:Workspace $scriptname) -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:Workspace $scriptname) -Target (join-path $localRepoRoot $relativeScriptDirectory $scriptName)

## Symbolic Links for Git Hooks

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

## Filesystem junctions

Sprint 0012 Task 12.1 retired the old three-folder junction model. The current
boundary model is:

- `.claude`, `.github`, `.codex`, `.agents`, and `.gemini` are concrete,
  git-visible AIAdapter materialization folders.
- `.vscode` remains the SharedVSCode junction because it carries workstation IDE
  behavior that should follow the active SharedVSCode target.
- `Set-SprintBoundaryContext -Boundary Start` retargets only `.vscode`, applies
  downstream SharedVSCode context, then materializes the concrete AIAdapter
  folders.
- `Set-SprintBoundaryContext -Boundary End` audits AIAdapter drift before
  teardown and recreates only the supported stable `.vscode` junction.
- `Convert-StableWorktreeToConcreteAdapters` is the one-time repair tool for
  legacy stable worktrees that still have `.claude` or `.github` as junctions;
  it removes the junction safely and restores tracked concrete content from
  `HEAD`. It intentionally leaves `.vscode` alone.

The old copy-based `Sync-WorktreeShared.ps1` approach remains archived. The old
`.claude` / `.github` junction guidance is historical only and must not be used
for sprint boundaries.

### Junction safety rules

1. Never use `Remove-Item -Recurse` on a junction. Use `cmd /c rmdir` or remove
   the reparse point itself without recursion.
2. Never recurse-delete a parent folder until every junction below it has been
   removed or proven absent.
3. At sprint close, enumerate junctions before `git worktree remove`. The
   expected SharedVSCode-managed junction is `.vscode`; treat any `.claude` or
   `.github` junction as legacy drift requiring review or the
   `Convert-StableWorktreeToConcreteAdapters` repair path.

### Process-lock-aware worktree teardown

Use `Remove-SprintWorktreeSafely` only after the SprintEnd boundary reset and
repository close steps have succeeded. The cmdlet verifies the exact Git
worktree registration, refuses removal while the current shell, Codex, or VS
Code references that worktree, and limits Git removal to a caller-selected
number of attempts (three by default). If removal remains blocked, it writes a
minimal handoff containing only the remaining teardown command.

Adapter cleanup is opt-in. Pass only direct-child placeholder paths known to be
safe, such as `.codex`; each candidate must be an empty ordinary directory at
execution time. Reparse points, nested paths, non-empty directories, and paths
outside the exact worktree are preserved and reported. The implementation never
uses recursive deletion.

```powershell
# Supported sprint-boundary junction set
$junctionFolderNames = @('.vscode')

Set-WorktreeJunctions `
  -SourceRepoPath $stableRepoRoot `
  -WorktreePath $worktreePath `
  -DevSourceRepoPath $sharedVSCodeSprintRoot `
  -SourceRepoFolderNames $junctionFolderNames `
  -DevSourceRepoFolderNames $junctionFolderNames
```

### Filesystem junction for .vscode folder

The organization has multiple Git repositories. Every repository that uses Visual
Studio Code as the IDE needs a `.vscode` directory with shared workspace
configuration such as dictionaries, launch/tasks files, CSpell settings, and
extension recommendations. That folder remains junctioned to the matching
SharedVSCode worktree.

AI-agent instruction surfaces are no longer provided through `.claude` or
`.github` junctions. They are rendered as concrete files and folders by the
AIAdapter lifecycle and move between branches through normal git history.

### Repository symbolic links

<Author's Note> the following is obsolete. Claude.md is created in every repository by a process that combines a Claude-local.md (for each repository) with a Claude-body.md found ins the SharedVSCode repositories' main branch worktree. </Author's Note>

#### Claude.md AI Agent symbolic link

The file CLAUDE.md should be placed at the repository root

```Powershell
  # The New-SymbolicLink cmdlet is found in the ATAP.Utilities.Powershell module
  # ToDo: Fix after packaging is working
  if (!${get-command New-SymbolicLink}) {
    . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\New-SymbolicLink.ps1'
  }

  cd $repositoryRoot
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\CLAUDE.md"  -symbolicLinkPath ".\CLAUDE.md" -force

```

#### User Settings symbolic link

The `settings.json` file at (e.g) `C:\Users\<username>\AppData\Roaming\Code\User` holds the final fallback to all VSC settings. It applies to all repositories and workspaces. Every developer on a host needs to link to the organization's common settings. to do this,replace the value of $username with the actual user name in the following command and run it.

There are also language-specific snippets files stored on a per-user basis. These should be linked to the organization's common settings.

```Powershell
# ToDo: must get the username for the specific computer from a vault
$username = 'whertzing'
New-SymbolicLink -targetPath `
$(Join-Path $global:settings[$global:configRootKeys['CloudBasePathConfigRootKey']] $username `
'GitHub', 'SharedVSCode', 'UserSettings.jsonc') `
-symbolicLinkPath $(Join-Path 'C:' 'Users' $username,'AppData','Roaming','Code', 'User', 'UserSettings.jsonc') -force
New-SymbolicLink -targetPath `
$(Join-Path $global:settings[$global:configRootKeys['CloudBasePathConfigRootKey']] $username `
'GitHub', 'SharedVSCode', 'UserSnippetsPowershell.jsonc') `
-symbolicLinkPath $(Join-Path 'C:' 'Users' $username,'AppData','Roaming','Code', 'User', 'snippets','powershell.json') -force
# .yml and .yaml requires us to use two symlinks
New-SymbolicLink -targetPath `
$(Join-Path $global:settings[$global:configRootKeys['CloudBasePathConfigRootKey']] $username `
'GitHub', 'SharedVSCode', 'UserSnippetsYAML.jsonc') `
-symbolicLinkPath $(Join-Path 'C:' 'Users' $username,'AppData','Roaming','Code', 'User', 'snippets','yaml.json') -force
# New-SymbolicLink -targetPath `
# $(Join-Path $global:settings[$global:configRootKeys['CloudBasePathConfigRootKey']] $username `
# 'GitHub', 'SharedVSCode', 'UserSnippetsYAML.jsonc') `
# -symbolicLinkPath $(Join-Path 'C:' 'Users' $username,'AppData','Roaming','Code', 'User', 'snippets','yml.json') -force
New-SymbolicLink -targetPath `
$(Join-Path $global:settings[$global:configRootKeys['CloudBasePathConfigRootKey']] $username `
'GitHub', 'SharedVSCode', 'UserSnippetsSQL.jsonc') `
-symbolicLinkPath $(Join-Path 'C:' 'Users' $username,'AppData','Roaming','Code', 'User', 'snippets','sql.json') -force

```

## Managed render for ~/.claude/settings.json

The `settings.json` file at `C:\Users\<username>\.claude\settings.json` holds
Claude Code user-scope settings. It is a real JSON file rendered from
`SharedVSCode\.ai\config\claudecode\settings.overlay.json`; the retired
SharedVSCode root `claude-settings.json` file is no longer a target.

Live user-global writes require both an explicit write gate and a confirmed
checkpoint. `Set-ClaudeSettingsSymlink` keeps its historical name for callers,
but now performs the managed render, backs up any existing target, replaces an
existing symlink with a real file, and preserves unmanaged local root keys.

```Powershell
$sharedVSCodeWorktree = 'C:\Dropbox\whertzing\GitHub\SharedVSCode-wt-54-Sprint-0012-work-items'
Set-ClaudeSettingsSymlink `
  -SharedVSCodeWorktreePath $sharedVSCodeWorktree `
  -AllowUserGlobalWrite `
  -CheckpointConfirmed
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
  # ToDo: Fix after packaging is working
  if (!${get-command New-SymbolicLink}) {
    . "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\New-SymbolicLink.ps1"
  }

  # ToDO: ensure we are at the repo root
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.markdownlint.yml"  -symbolicLinkPath ".\.markdownlint.yml" -force
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.prettierrc.yml"  -symbolicLinkPath ".\.prettierrc.yml" -force
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.gitignore"  -symbolicLinkPath ".\.gitignore" -force
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.gitattributes"  -symbolicLinkPath ".\.gitattributes" -force
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.editorconfig"  -symbolicLinkPath ".\.editorconfig" -force
  # Every projects in a repository needs a ReadMe.md
  Set-Content -Path './ReadMe.md' -Value "ReadMe file for $(pwd | split-path -leaf)"

  # this command is only needed for repositories that have projects that use javascript or typescript
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.eslintrc.js"  -symbolicLinkPath ".\.eslintrc.js" -force
  # this command only for repositories that use mocha for testing JavaScript
  New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.mocharc.yaml"  -symbolicLinkPath ".\.mocharc.yaml" -force
```

### additional cSpell dictionaries

ToDo: Cspell dictionaries are in a different place, they are in SharedVSCode, and the setup stuff needs to somehow reference
ToDo: a local dictionary file in this repository's root
cSpell has many language-specific dictionaries with the language's keywords.. Run the following

```Powershell
# from your repo root
npm i -D @cspell/dict-csharp  @cspell/dict-html @cspell/dict-markdown @cspell/dict-powershell @cspell/dict-python @cspell/dict-sql @cspell/dict-typescript
```

ToDo: add the ansible and jenkins specific dictionaries

### Additional project-specific directories and files

Projects are created under the 'src' directory of the repository. Projects are individual code workspaces.
Put the project name into a local setting.

ToDo: CodeWorkspace File needs correcting.

```Powershell
  if (-not (Get-Command -Name 'Get-RepositoryRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
    . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-RepositoryRoot.ps1'
  }

  # ToDo: must get the username for the specific computer from a vault
  $username = 'whertzing'
  # be SURE you are in the new project's directory
 # ToDo: Add Get-RepoRoot and make sure it navigates you to a empty directory
  $AddPowershell = $false
  $AddCSharp = $true
  # set the local project name
  $projectName = split-path $(pwd) -leaf
  # set the local project full path
  $projectDirectory = . pwd

# .code-workspace files per subproject in a multi-project repo is obsolete
#   # the code-workspace file
# @'
# {
#   "folders": [
#     {
#       "path": "."
#     }
#   ],
#   "settings": {
#     "dotnet-test-explorer.testProjectPath": "{workspacefolder}/tests",
#     "pester.pesterModulePath": "{workspacefolder}",
#     "powershell.pester.codeLens": false,
#     "powershell.pester.useLegacyCodeLens": false,
#     "powershell.pester.outputVerbosity": "Diagnostic",
#     "powershell.enableProfileLoading": true,
#     "cSpell.customDictionaries": {
#       "custom": {
#         "name": "${projectName}Dictionary",
#         "path": "${workspaceFolder}/${projectName}CustomDictionary.txt",
#         "addWords": true
#       }
#     },

#   }
# }
# '@ | Out-File -FilePath "./$projectName.code-workspace" # UTF8 encoding via a parameter default

# If the new project exisit inside a repo that already has a custom dictionary, don't createa new one
if ($false) {
  # The custom dictionary file, which contains the $projectName as an approved word
  "$projectName" | Out-File -FilePath "${projectName}CustomDictionary.txt"
}
  # The ReadMe file for the repo as a whole
  "ReadMe file for $projectName" | Out-File -FilePath './ReadMe.md'
  # the subdirectory where all generated files are placed
  $null = New-Item -ItemType Directory -Force $global:settings[$global:configRootKeys['GeneratedRelativePathConfigRootKey']];
  # the subdirectory for documentation of the repo as a whole
  $null = New-Item -ItemType Directory -Force './Documentation';
  # The subdirectory for releases of the repo as a whole
  $null = New-Item -ItemType Directory -Force './Releases';
  # The Release Notes File for releases of the repo as a whole
  "Release Notes file for $projectName" | Out-File -FilePath './ReleaseNotes.md'
  # The source code subdirectory
  $null = New-Item -ItemType Directory -Force './src';
  # The block of code that adds a Powershell Project
  if ($AddPowershell ) {
    $powershellProjectName =  "${projectName}.Powershell"
    $powershellProjectRelPath =  "./src/$powershellProjectName"
    $null = New-Item -ItemType Directory -Force "$powershellProjectRelPath";
    # Move into the "$powershellProjectRelPath
    pushd
    cd "$powershellProjectRelPath"
    # The subdirectory for documentation of the Powershell Module
    $null = New-Item -ItemType Directory -Force "./Documentation"
    # The subdirectory for releases of the Powershell Module
    $null = New-Item -ItemType Directory -Force "./Releases"
    "ReadMe file for $powershellProjectName" | Out-File -FilePath "./ReadMe.md"
    "Release Notes file for $projectpowershellProjectNameName" | Out-File -FilePath "./ReleaseNotes.md"
    # Powershell specific projects public, private, and tests projects
    $null = New-Item -ItemType Directory -Force "./public"
    $null = New-Item -ItemType Directory -Force "./private"
    # Powershell tests are found as peers of powershell private and public subdirectories
    $null = New-Item -ItemType Directory -Force "./tests"
    # ToDo: use an installed package path for the latest (?) BuildTooling.Powershell module
    New-SymbolicLink -Force -symbolicLinkPath "./module.build.ps1" -targetPath $(Join-Path $global:settings[$global:configRootKeys['CloudBasePathConfigRootKey']] 'whertzing' 'GitHub', 'ATAP.Utilities','src','ATAP.Utilities.BuildTooling.PowerShell','module.build.ps1');
    New-SymbolicLink -Force -symbolicLinkPath "./tests/PesterConfiguration.psd1" -targetPath  $(Join-Path $global:settings[$global:configRootKeys['CloudBasePathConfigRootKey']] 'whertzing' 'GitHub', 'SharedVSCode', 'PesterConfiguration.psd1')
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
'@ |Out-File -FilePath "./$powershellProjectName.psm1"

    # module manifest file ().psd1 file)
    # a new guid in the proper format for a .psd1 file
    $newGuid = [Guid]::NewGuid().ToString().ToUpper()
    # ToDo: make this come from a template somewhere
    @"
    #
    # Module manifest for module 'ATAP.Utilities.Powershell'

    @{

    # Script module or binary module file associated with this manifest.
    RootModule = "$powershellProjectName.psm1"

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
    FunctionsToExport = @()

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

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
            # RequireLicenseAcceptance = 0

            # External dependent modules of this module
            # ExternalModuleDependencies = @()

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

    }

"@ |Out-File -FilePath "./$powershellProjectName.psd1"
  # This ends the powershell specific components of a new project in a repo
  popd
  }
  # Add the CSharp project to the repo
  if ($AddCSharp) {
    $csharpProjectName =  "${projectName}.Csharp"
    $csharpProjectRelPath =  "./src/$csharpProjectName"
    $null = New-Item -ItemType Directory -Force "$csharpProjectRelPath";
    pushd
    cd "$csharpProjectRelPath"
    # The subdirectory for documentation of the CSharp Module
    $null = New-Item -ItemType Directory -Force "./Documentation"
    # The subdirectory for releases of the CSharp Module
    $null = New-Item -ItemType Directory -Force "./Releases"
    "ReadMe file for $csharpProjectName" | Out-File -FilePath "./ReadMe.md"
    "Release Notes file for $csharpProjectName" | Out-File -FilePath "./ReleaseNotes.md"
  # ToDo add the .csproj file
  # This ends the csharp specific components of a new project in a repo
  popd
  }
```

### Project-specific symbolic links

#### VSC Extension development symbolic links

Place these symbolic links in the .vscode subdirectory of any project that builds a VSC extension.

```Powershell
# OBSOLETE
  # New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.vscode\launch4Extension.jsonc"  -symbolicLinkPath ".\.vscode\launch.json" -force
  # New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.vscode\tasks4Extension.jsonc"  -symbolicLinkPath ".\.vscode\tasks.json" -force
```

#### Database development symbolic links

Databases are migrated using FLyway from Red Hat. Flyway migrations require a flyway.toml file. There is a common shared flyway.toml file which should be symlinked. This should be placed in the Database/Flyway folder of the project.

```Powershell
  # The New-SymbolicLink cmdlet is found in the ATAP.Utilities.Powershell module
if (!${get-command New-SymbolicLink}) {
  . "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\New-SymbolicLink.ps1"
}
# Ensure current directory ends in Database\Flyway (cross-platform)
$expectedSuffix = Join-Path 'Database' 'Flyway'
$currentPath = (Get-Location).Path
if (-not $currentPath.EndsWith($expectedSuffix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Current directory must end in '$expectedSuffix'. Current path: $currentPath"
}
$targetPath = $flywayToml = Join-Path -Path 'C:' -ChildPath 'Dropbox' 'whertzing' 'GitHub' 'SharedVSCode' 'Databases' 'flyway.toml'
New-SymbolicLink -targetPath $targetPath   -symbolicLinkPath ".\flyway.toml" -force
```

## Symbolic Links and cloud-synchronization

The ATAP organizations use Dropbox to sync development environments across desktops and laptops. Dropbox DOES NOT sync symbolic links. The current workaround is to ensure that symbolic links are created, manually, on every host participating in the development environment.

ToDO: Use Ansible to ensure creation, update, and removal of symbolic links occur on all hosts that participate in the development process

## Docker Desktop

To utilize Docker packages inside of WSL 2, Docker Desktop for windows is recommended.

### Prerequisites and installing Docker in ubuntu

Login to ubuntu on WSL, then run the following commands

````Powershell
# Runs apt update and installs HTTPS, curl, and GPG tooling inside Ubuntu from PowerShell.
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release
# Create the keyring directory
sudo install -m 0755 -d /etc/apt/keyrings
# Add Docker’s GPG key
$gpgTemp = "/tmp/docker.gpg"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg `
  | sudo gpg --dearmor -o $gpgTemp
sudo mv $gpgTemp /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
# Add Docker’s apt source
$osRelease = Get-Content /etc/os-release
$codename  = ($osRelease | Where-Object { $_ -match '^UBUNTU_CODENAME=' -or $_ -match '^VERSION_CODENAME=' }) `
  -replace '^[^=]+=',''
$codename
$dockerSource = @"
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $codename
Components: stable
Signed-By: /etc/apt/keyrings/docker.gpg
"@

$dockerSource | sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null
# Refresh apt to pick up Docker packages
sudo apt update
# verify
apt-cache policy docker-ce
#  Install Docker Engine, CLI, and runtime (latest)
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# verify
sudo systemctl status docker
# Test the CLI
sudo docker version
sudo docker run hello-world
# Allow running docker without sudo
sudo groupadd docker 2>$null
sudo usermod -aG docker $env:USER
newgrp docker
# restart the shell session so the group membership is applied
exit
pwsh
# Verify sudo is not required
docker run hello-world
docker ps
# Troubleshoot if failure
# 1) Check your groups
id
id -nG
# 2) Check the docker group entry
getent group docker
# 3) Check the socket permissions
ls -l /var/run/docker.sock

# ensure systemd is enabled
gc '/etc/wsl.conf '
# insert if not found, and reboot
# [boot]
# systemd=true

# enable Docker with systemd
sudo systemctl enable docker
sudo systemctl start docker

# Create a location for OpenMetadata
cd /srv
sudo mkdir openmetadata-docker && cd openmetadata-docker
sudo chmod 777 .

# download the docker container for OpenMetadata
# Pick a specific OpenMetadata release tag
$version = "1.9.7-release"

# MySQL-based docker-compose file URL from the Releases assets
$composeUrl = "https://github.com/open-metadata/OpenMetadata/releases/download/$version/docker-compose.yml"

# Ensure directory and move into it
$targetDir = "/srv/openmetadata-docker"
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
Set-Location $targetDir

# Download as docker-compose.yml
Invoke-WebRequest -Uri $composeUrl -OutFile "docker-compose.yml"

# Start the OpenMetadata stack
cd /srv/openmetadata-docker

# Optional: see what services are defined
docker compose config

# Start everything in the background
docker compose up -d

# Check status:
docker compose ps

# Install Firefox in Ubuntu
sudo apt install firefox

# Confirm OpenMetadata is accessable from ubuntu browser

firefox &

From a windows browser, navigate to
`http://localhost:8585`

#### Troubleshoot access

In Ubuntu Powershell terminal

```Powershell
cd /srv/openmetadata-docker
docker compose ps
```

### create a Windows Task Scheduler job that starts docker user login

there is already a login script that runs at user login. Add the following to the script"

' wsl -d <distro> -e service docker start'

## Add user to Docker-Desktop windows group

In a powershell prompt, run the following

```powershell
Add-LocalGroupMember -Group "docker-users" -Member $env:USERNAME

```
````

## 5-Tier Module Flow

Use the module-level getting started guide for the lifecycle workflow:

- [Documentation/GettingStarted.md](Documentation/GettingStarted.md)

### Promoted-module test isolation

`Invoke-PromotedModuleTests` restores and imports the immutable package, then
runs the tier-filtered source tests in a child scope with StrictMode disabled.
The BuildMaster stage runner keeps `Set-StrictMode -Version Latest` for its own
orchestration, but that policy no longer leaks into Pester fixture code where
normal missing-property and scalar `.Count` behavior is expected.

For fixtures that must reload the module, the delegated run temporarily sets
the process-scoped `ATAP_PROMOTED_MODULE_MANIFEST` value to the restored package
manifest. Fixtures use that path rather than a source manifest, then the runner
restores the previous value after Pester completes. This keeps the promoted
artifact—not the source tree—as the system under test.

Suites that must import or dot-source the BuildTooling source tree, depend on
developer-workstation globals or paths, or evaluate the full repository carry
the `PromotedModuleHostSensitive` tag. `Invoke-PromotedModuleTests` passes that
tag through `AdditionalExcludeTag`, so promoted-package selection is identical
at every console verbosity. Normal source test runs still execute the tagged
tests unless the quiet BuildMaster source gate applies its established
host-sensitive exclusions.

`Invoke-PSModulePesterTests` retains its module-bound result, plugin-restoration,
and JUnit helper scriptblocks before entering Pester. Tests may therefore remove
or force-reimport BuildTooling without breaking runner teardown or artifact
generation. It also restores the pre-run global `Get-SecretATAP` function so a
test double cannot contaminate the next promoted tier; no secret value is
retained. Tier totals and JUnit cases exclude Pester's tag-filtered `NotRun`
records; explicit skips remain represented as skipped cases.

`Set-TaskComplete` validates its literal helper and task-file paths with
`System.IO.File.Exists`, avoiding unnecessary PowerShell-provider lookup for
paths that are always literal files.

Task 10.30 promoted `ATAP.Utilities.BuildTooling.PowerShell` 0.1.7 through
BuildMaster build 14137. Development passed 476/476 tests, and Integration, QA,
and Production each passed 482/482. ProGet then exposed 0.1.7 in all five
PowerShellGet feeds, including `powershellget-stable`.

Feed vocabulary remains deliberately split: SprintStart's residual
`NuGet.config` uses the D-2 `*-production` names, while the immutable promotion
ladder and `Resolve-ProGetFeedFromSettings` normalize `Production` to the
canonical `*-stable` tier.

- Version bumped to 0.1.13 in Sprint 11

## Functional area

PowerShell Build & Packaging - START HERE: SolutionDocumentation\PowerShell-Modules-Build-Process.md (link-up added 2026-07-07, Sprint 0012 Task 12.46.f)
## BuildTooling family contract

`ModuleFamily.psd1` at the repository root is the checked-in source for approved
BuildTooling module names, GUIDs, dependency minimums, and deterministic build order.
`module.build.ps1 -ModuleName <approved name>` builds a named family member while
preserving the legacy parent-module path. `Build-PSModulePsm1` includes only guarded
`lib/*.types.ps1` files, and `Build-PSModuleManifest` derives explicit function exports
from the target module's public files.

`New-BuildToolingChildModule` renders one empty, importable child module from
`src/_Templates/BuildToolingChildModule` and returns proposed BuildMaster-map and
SolutionDocumentation-index text. It never edits another repository.

During migration, packaging and publishing commands must resolve from the installed,
immutable bootstrap module—not from the in-flight source tree. The parent source path is
used only to build the bootstrap release itself.

The first extraction pilot is
`ATAP.Utilities.BuildTooling.PesterScaffolding.PowerShell`. It owns ten Pester
configuration and test-template commands. The parent requires child version 0.1.0 or
later and generates parameter-preserving compatibility forwarders at import time, so
the committed 200-command parent surface remains unchanged during migration.
