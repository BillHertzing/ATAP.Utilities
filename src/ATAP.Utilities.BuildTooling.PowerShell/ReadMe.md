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

Sprint lifecycle plumbing in this module now resolves downstream Git context from
the workspace file paths being retargeted instead of the caller's current
directory. Generated `.gitattributes` and `.gitconfig.shared` content also
replaces any existing generated header before writing a fresh one, so repeated
retargeting refreshes metadata without stacking header blocks.

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

Sprint planning also now has an explicit markdown-to-board path: use
`Convert-TasksMdToSprintBoard` to regenerate a sprint `TASKS.html` board from the
authoritative `TASKS.md` file after task edits or status updates.

Stage 2 database startup is now safe for non-interactive agent shells (Tasks
10.4 and 10.5). `Test-SprintPrerequisites` and `New-SprintStage2` call the
source-first `Initialize-ATAPConfigurationGlobals` helper when
`$global:configRootKeys` or `$global:settings` is absent or incomplete. The
normal reset path passes the newly created ATAP.Utilities worktree root and its
current `SharedSQL` provisioning folder to `Reset-SprintDatabases`, with
`-Confirm:$false`, so an installed BuildTooling module cannot fall back to stale
module-relative Flyway or `DropAndCreateDatabase.sql` content. Use
`-SkipDatabaseReset` to bypass both the Dev/Exp instance guard and reset during
granular recovery, and `-IncludeRepos` to provision repositories that have no
task-board marker.

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
no on-disk transcript). Antigravity and Codex auto-detect the newest
conversation/rollout when the id argument is omitted. The roster entry records the
`Agent`, `AgentSessionKey`, and `ConversationDbPath` for each save.

**BuildMaster PowerShell Module Release Naming (Task 9.37).** To support building multiple arbitrary PowerShell modules within the single consolidated BuildMaster application (`ATAP.Utilities-PowerShell`) without collisions, the BuildMaster `ReleaseNumber` is generated uniquely per module. The release number appends the module name as a suffix (e.g., `0.1.0-ATAP.Utilities.PowerShell` for stable versions, and `0.1.0-Alpha.6.ATAP.Utilities.PowerShell` for prerelease versions), which is fully SemVer 2.0.0 compliant. This naming is strictly internal to BuildMaster and does not bleed into the built package's name, version, or manifest (`.psd1`) file.

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
with the `bws` CLI and a machine access token (`$env:BWS_ACCESS_TOKEN` or the
DPAPI token file via `Get-BWSAccessToken`). `BW_SESSION` is personal-vault-only
and is never required by sprint automation (SC-0175). Reads of per-sprint
machine secrets go through
`Get-SecretATAP -SecretStoreType 'BitwardenSecretsManager'`.

**Deterministic connection-string fallback (Task 9.22).** The `bws` _write_ path
is currently broken, but the 12 per-sprint Dev/Exp connection strings carry no
credential (`Integrated Security=True`) and are reproducible from
host/tier/db/user. `Get-DbConnectionStringSecretDescriptor` is the single source
of truth for the connection-string **format** and the
**derivable-vs-credentialed** classification, shared by the writer
(`New-SprintBitwardenSecrets`) and the reader (`Resolve-DatabaseSqlConnection`).
By default `New-SprintBitwardenSecrets` derives the strings and writes nothing to
the vault (so sprint Stage 2 needs no `bws` write at all); `-WriteDerivableToVault`
persists them once the write path is fixed. `Resolve-DatabaseSqlConnection`
resolves in order: (a) real vault secret if present, (b) deterministic build when
derivable, (c) hard fail if a credential is required but absent (a credentialed
string is never derived). When SQL logins replace Integrated Security, marking the
affected names credentialed is a one-place config change, not a rewrite, and a
working programmatic write+rotate path becomes mandatory before those credentialed
secrets ship.

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

There are multiple folders and files that need to be present at the root of each repository, and need to be source-controlled and versioned. Having multiple independent copies is prone to errors and misconfigurations. Therefore, we have created a repository named `SharedVSCode`, and placed the source-of-truth copies of these shared folders and files in this git-versioned repository.

**Design decision (2026-04-03):** The `.claude`, `.github`, and `.vscode` folders at the root of
every downstream repo worktree (ATAP.Utilities, AceCommander, \_Planning) are **always NTFS
junctions** — never real folders and never file-sync copies. The `Sync-WorktreeShared.ps1`
copy-based approach has been retired (archived) in favour of the junction-only design.

Junctions are listed in `.dropboxignore` so Dropbox does not try to sync them, and in
`.gitignore` so git does not track them. This is the canonical design.

**Junction targets by worktree type:**

| Worktree                  | Junction target                |
| ------------------------- | ------------------------------ |
| Main worktree (permanent) | `SharedVSCode` main worktree   |
| Sprint worktree           | `SharedVSCode` sprint worktree |
| Normal issue worktree     | `SharedVSCode` main worktree   |

**CRITICAL junction safety rules:**

1. **Never use `Remove-Item -Recurse` on a junction.** Always use just `Remove-Item` (no
   `-Recurse`). This removes the reparse point and does not touch the junction target.
2. **Never use `Remove-Item -Recurse` on any parent folder above a junction.** Always ensure
   the junction has been removed with `Remove-Item` (no `-Recurse`) BEFORE calling any
   `Remove-Item -Recurse` on a parent folder.
3. **Sprint end cleanup:** Before calling `git worktree remove`, always explicitly remove
   the `.claude`, `.github`, and `.vscode` junctions from the worktree first.

```powershell
# Safe junction removal
foreach ($name in @('.claude', '.github', '.vscode')) {
    $jp = Join-Path $worktreePath $name
    if (Test-Path -LiteralPath $jp) {
        $item = Get-Item -LiteralPath $jp -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Remove-Item -LiteralPath $jp  # NO -Recurse on junctions
        }
    }
}
# Only AFTER all junctions are confirmed removed:
git worktree remove $worktreePath --force
```

### Filesystem junction for .claude folder

Claude and Claude Code will look up the filesystem to the repository root for folders named `.claude`. Prompt instructions for Claude AI are stored in the file(s) found in this directory. To make the same prompt instructions available to every repository, the .claude folder is linked, using a junction to the base of the repository.

of particular note are the AI Agent instruction files, for both Copilot and for Claude Code
there is a frontmatter format mismatch between Copilot and Claude Code. For proper path-scoping in Claude Code, we need separate .claude/rules/ files with paths frontmatter and then @import the shared content body from .github/instructions/ to avoid duplication.

### Filesystem junction for .github folder

Every repository needs instruction files for GitHub Copilot. These are kept in the .github directory, and a directory junction is created in the root of the repository. Run the following Powershell commands at the repository root to create a directory junction back to the shared VS Code directory.

ToDo: must look at the other stuff in .github to see if they can be made to work for multiple repositories, or, if Issue Templates and workflows need to be specific to individual repositories

### Filesystem junction for .vscode folder

The organization has multiple GIT repositories. Every repository that uses Visual Studio Code as the IDE, needs a subdirectory `.vscode`, which contains these files and folders

```text
repo-root/
├── .vscode/
    ├── dictionaries/ # Used by the 'CSpell' VSC extension
    ├── solution-explorer/ # Used by the 'Solution Explorer' VSC extension
    ├── cspell.json
    ├── extensions.json
    ├── iisexpress.json
    ├── launch.json
    ├── mcp.json
    ├── PSScriptAnalyzerSettings.psd1
    ├── tasks.json
```

```text
repo-root/
└── .claude/
|   └── rules/
|       ├── python.md ← paths: ["**/*.py"], body: @../../.github/instructions/python.instructions.md
|       └── typescript.md ← paths: ["**/*.ts","**/*.tsx"], body: @../../.github/instructions/typescript.instructions.md
|       └── etc...
├── .github/
│   ├── copilot-instructions.md ← Single source of truth for global instructions
│   └── instructions/
│       ├── Powershell.instructions.md
│       ├── CSharp.instructions.md
│       └── etc...
├── .vscode/
    ├── dictionaries/ # Used by the 'CSpell' VSC extension
    ├── solution-explorer/ # Used by the 'Solution Explorer' VSC extension
    ├── cspell.json
    ├── extensions.json
    ├── iisexpress.json
    ├── launch.json
    ├── mcp.json
    ├── PSScriptAnalyzerSettings.psd1
    ├── tasks.json
```

### Create Filesystem junctions

​
In every new repository, after running `git init`, run these commands (as an administrator) in the root folder of the repository:
We create a junction in each repository that links to the `.github` folder in `SharedVSCode`.

ToDo: replace with a BuildTooling.Powershell script for New-Junction

In every new repository, after running `git init`, run these commands (as an administrator) in the root folder of the repository:
We create a junction in each repository that links to the `.vscode` folder in `SharedVSCode`.

ToDo: replace with a BuildTooling.Powershell script for New-Junction

```powershell
# Ensure that .claude is a folder, junction linked from the repo root to the target.
# The target is GitHub/SharedVSCode/.claude
# The junction name is .claude
# if .claude is present in the repo root, and is a junction to the .claude subfolder under SharedVSCode folder, do nothing.
# if .claude is present in the repo root, and is a junction to anything other than the .claude subfolder under SharedVSCode folder, delete and create it as a junction to the .claude subfolder under SharedVSCode folder.
# if .claude is not present in the repo root create it as a junction to the .claude subfolder under SharedVSCode folder
if (-not (Get-Command -Name 'Get-RepositoryRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
  . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-RepositoryRoot.ps1'
}

$userName = 'whertzing'
$junctionFolderNames = ('.claude', '.github', '.vscode')
$junctionFolderNames | % {
 $junctionFolderName = $_
$targetFolder = Join-Path $global:settings[$global:configRootKeys['CloudBasePathConfigRootKey']] $username 'GitHub', 'SharedVSCode', $junctionFolderName
# Check if junction exists
if (Test-Path $junctionFolderName) {
    $item = Get-Item $junctionFolderName
    # Check if it's a junction/reparse point
    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        # Get the target of the junction
        $currentTarget = $item.Target
        # Compare with expected target
        if ($currentTarget -ne $targetFolder) {
            # Wrong target, delete and recreate
            Write-PSFMessage -Level Verbose -Message "Removing existing junction with wrong target: $currentTarget"
            Remove-Item -Path $junctionFolderName -Force
            $null = New-Item -Path $junctionFolderName -ItemType Junction -Target $targetFolder
            Write-PSFMessage -Level Important -Message "Created $junctionFolderName junction to: $targetFolder"
        }
        else {
            # Correct junction already exists, do nothing
            Write-PSFMessage -Level Verbose -Message "$junctionFolderName junction already points to correct target: $targetFolder"
        }
    } else {
        # It exists but is not a junction - remove and create junction
        Write-PSFMessage -Level Warning -Message "$junctionFolderName exists but is not a junction. Removing and recreating as junction"
        Remove-Item -Path $junctionFolderName -Recurse -Force
        $null = New-Item -Path $junctionFolderName -ItemType Junction -Target $targetFolder
        Write-PSFMessage -Level Important -Message "Created $junctionFolderName junction to: $targetFolder"
    }
} else {
    # Doesn't exist, create it
    $null = New-Item -Path $junctionFolderName -ItemType Junction -Target $targetFolder
    Write-PSFMessage -Level Important -Message "Created $junctionFolderName junction to: $targetFolder"
}
}

```

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

## Symbolic link for ~/.claude/settings.json

The `settings.json` file at (e.g) `C:\Users\<username>\.claude\settings.json` holds the settings that Claude Code will use. It applies to all repositories and workspaces. Every developer on a host needs to link to the organization's common settings, which are stored in the main branch's worktree of the `SharedVSCode` repository. To do this,replace the value of $username with the actual user name in the following command and run the following block of code.

```Powershell
  $username = 'whertzing'
  # The New-SymbolicLink cmdlet is found in the ATAP.Utilities.Powershell module
  # ToDo: Fix after packaging is working
  if (!${get-command New-SymbolicLink}) {
    . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\New-SymbolicLink.ps1'
  }
  # main branch's worktree for SharedVSCode
  $mainBranchWorktree = Join-Path  $global:settings[$global:configRootKeys['CloudBasePathConfigRootKey']] $username 'GitHub', 'SharedVSCode'
  # Figure out the best way to get the users home direcotry on this computer
  $userHome = Join-Path $env:SystemDrive 'Users' $username
  $claudeFolder =  Join-Path  $userHome '.claude'
  #ToDo - ensure the folder exists
  # link the SharedVSCode claude-settings.json to settings.json
  New-SymbolicLink -targetPath $(Join-Path $mainBranchWorktree 'claude-settings.json') -symbolicLinkPath $(Join-Path $claudeFolder 'settings.json') -force
  # Note the following may be used during development of the Claude settings.json
  # Sprint branch's worktree root C:\Dropbox\$usernamewhertzing\GitHub\SharedVSCode-wt-36-sprint-0004-work-items
  $sprintWorktree = "C:\Dropbox\$username\GitHub\SharedVSCode-wt-36-sprint-0004-work-items"
  New-SymbolicLink -targetPath $(Join-Path $sprintWorktree 'claude-settings.json') -symbolicLinkPath $(Join-Path $claudeFolder 'settings.json') -force
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
