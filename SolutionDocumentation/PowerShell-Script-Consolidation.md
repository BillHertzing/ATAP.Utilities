# PowerShell Script Consolidation

**Scope:** Sprint-0006/0007. Inventory of standalone `.ps1` scripts that
live outside any PowerShell module, the rationale for consolidating them
into modules, and the rules that govern when a new standalone script is
acceptable vs. when it should become a module function.

> **Strategy update (sprint-0007 — Immutable Build).** The build / pack /
> publish / promote / Chocolatey / WinGet automation surface is centralized
> in `ATAP.Utilities.BuildTooling.PowerShell` as a set of cmdlets that are
> called by BuildMaster stages and developer workflows alike. The cmdlets
> deliberately replace the older "one orchestrator script per repo" pattern
> (`Publish-ATAPUtilities.ps1`) — the new functions are listed in
> [BuildMaster-Pipeline-Topology.md §4](BuildMaster-Pipeline-Topology.md#4-powershell-automation-surface).
> The classification rules in §2 still apply, but the new cmdlets all fall
> into bucket A (module function) and any standalone script that duplicates
> their behavior is now a candidate for deletion. See §10.4.

**Audience:** Developers who reach for "I'll just write a quick `.ps1`",
maintainers planning the sprint-0007 cleanup, anyone trying to discover
"where does the script that does X live?"

**Status:** Authoritative for sprint-0006. Includes a curated inventory
that will go stale; treat the categorization as load-bearing, the file
list as a snapshot.

**Not in this doc:**

- How modules themselves are built / tested / packed → see the four
  PowerShell module docs.
- C# console apps that wrap PowerShell entry points → out of scope.
- Skills, agents, and the `.claude/` folder → governed separately by
  SharedVSCode.

---

## 1. Why scripts proliferate

Loose `.ps1` files accumulate in a multi-repo PowerShell-heavy ecosystem
because:

1. **No bootstrap cost.** `Foo.ps1` is one file; a module is a folder
   with a manifest, public/private split, tests, and a `version.json`.
2. **Per-repo entry points.** Each repo has a few "developer affordances"
   that are not really cmdlets — `Publish-ATAPUtilities.ps1` at repo root,
   plus workstation setup tools such as
   `src/ATAP.Utilities.BuildTooling.PowerShell/tools/Setup-GitHubMCP.ps1`
   and `src/ATAP.Utilities.BuildTooling.PowerShell/tools/Test-GitHubMCP.ps1`.
3. **CI hook scripts.** `_generated/Check-ProGetFeeds.ps1`,
   `_generated/Fix-PowershellGetFeedNames.ps1` get dropped during sprint
   investigations and never relocated.
4. **Module-internal scripts authored as standalones first.** A function
   typically exists as `Verb-Noun.ps1` in `public/` because the build
   concatenates them — but a script that pre-dates the module conversion
   gets stranded outside.
5. **Database helper scripts.** `Database/Powershell/public/*.ps1` is a
   PowerShell _folder_ but not a published module — Flyway invocation
   wrappers, schema parity checks.

The consolidation problem is real but bounded — the inventory in §3
counts ~25 truly-standalone scripts across the four repos.

---

## 2. The classification rule

Every `.ps1` falls into exactly one of these five buckets:

| Bucket                 | Definition                                                           | Lives where                                                 | Versioned?                         |
| ---------------------- | -------------------------------------------------------------------- | ----------------------------------------------------------- | ---------------------------------- |
| **A. Module function** | Becomes part of `<Module>.psm1` via `Build-PSModulePsm1`             | `src/<Module>/public/`, `private/`, or `lib/`               | Yes (NBGV)                         |
| **B. Module test**     | Pester test for a module function                                    | `src/<Module>/tests/`                                       | n/a                                |
| **C. Loose tool**      | Developer affordance scoped to one repo/workstation (publish, setup, smoke-test) | repo root or `src/ATAP.Utilities.BuildTooling.PowerShell/tools/` for shared build/tooling setup | No (git-tracked, but not packaged) |
| **D. Generated**       | Output of a build/diagnostic step                                    | `_generated/` (per SC-0033)                                 | No                                 |
| **E. Vendor**          | Imported from a third-party package's distribution                   | wherever the package put it (e.g. `bin/Debug/.playwright/`) | n/a                                |

Bucket E is **never** consolidated — those files are restored by `dotnet
restore` or `npm install` and editing them is futile.

Bucket D is **never** consolidated _into source_ — the scripts under
`_generated/` may be deleted at any time. If a `_generated/` script proves
useful, it gets promoted to bucket A or C.

Buckets A and B are governed entirely by the Build-Process,
Versioning, Pack-and-Publish, and Test-Process docs.

The interesting bucket — and the focus of this doc — is **C**.

---

## 3. Inventory of standalone scripts (sprint-0006)

### 3.1 ATAP.Utilities

| Path                                                   | Bucket | Purpose                                        | Disposition                                |
| ------------------------------------------------------ | ------ | ---------------------------------------------- | ------------------------------------------ |
| `Publish-ATAPUtilities.ps1`                            | C      | Iterate projects and publish to ProGet feeds   | **Delete** — replace with `Invoke-DotnetBuildWithRetry` / `Invoke-ModuleBuildWithRetry` |
| `src/ATAP.Utilities.BuildTooling.PowerShell/tools/Setup-GitHubMCP.ps1` | C | One-time GitHub MCP server setup               | Keep as BuildTooling setup tool            |
| `src/ATAP.Utilities.BuildTooling.PowerShell/tools/Test-GitHubMCP.ps1`  | C | Smoke-test GitHub MCP after setup              | Keep as BuildTooling setup tool            |
| `Database/Powershell/public/Export-RuleToTextFile.ps1` | C/A    | Schema rule export                             | **Promote to module** (Database utilities) |
| `Database/Powershell/public/Rebuild-All.ps1`           | C      | Flyway rebuild orchestrator                    | Keep — not a function                      |
| `Database/Powershell/public/Example-RuleExport.ps1`    | C      | Demo / docs example                            | Move to `Documentation/`                   |
| `Database/Powershell/tests/*.Tests.ps1`                | B      | Pester tests for the un-modularized DB scripts | Move with the promotion                    |
| `OlderDBsForReference/**/*.ps1`                        | n/a    | Archive — pre-Flyway era                       | **Delete in sprint-0007**                  |
| `src/.../public/Obsolete/*.ps1`                        | n/a    | Marked obsolete years ago                      | **Delete in sprint-0007**                  |

### 3.2 AceCommander

| Path                                                                 | Bucket | Purpose                                   | Disposition                        |
| -------------------------------------------------------------------- | ------ | ----------------------------------------- | ---------------------------------- |
| `powershell/public/Invoke-AceCommanderTests.ps1`                     | A      | Sole function in an unbuilt module folder | **Wire into the module build**     |
| `AceCommander.Server.Tests/E2E/UserInformationAndSettings.Tests.ps1` | B      | Pester E2E test                           | Keep — already in correct location |
| `AceCommander.Server.Tests/bin/.../*.ps1`                            | E      | Playwright vendor scripts                 | Ignore                             |
| `_generated/*.ps1`                                                   | D      | Sprint-0006 ProGet diagnostics            | Delete after sprint closes         |

### 3.3 \_Planning

| Path                                             | Bucket | Purpose                                         | Disposition                                          |
| ------------------------------------------------ | ------ | ----------------------------------------------- | ---------------------------------------------------- |
| `Powershell/Public/Save-SprintWorkSession.ps1`   | A      | Sprint checkpoint helper (R-15 names this path) | Promote to a `_Planning.PowerShell` module — pending |
| `Powershell/Public/Start-PlanningSession.ps1`    | A      | Begin a planning session (now a cmdlet)         | Same                                                 |
| `Powershell/Public/Complete-PlanningSession.ps1` | A      | End a planning session (now a cmdlet)           | Same                                                 |
| `Powershell/Public/New-BundleProjectFiles.ps1`   | A      | Bundle related project docs                     | Same                                                 |
| `Powershell/Public/Add-ScopeCreepIdea.ps1`       | A      | Park an idea outside the current sprint         | Same                                                 |

The `_Planning/Powershell/Public/` folder follows the _layout_ of a
PowerShell module's public directory but lacks a `.psd1`. It is a
half-modularized state — the cleanup is to add the manifest and
`version.json`, then run the standard build flow.

### 3.4 SharedVSCode

No standalone `.ps1` files. SharedVSCode hosts shell snippets and skills
in `.claude/`, not executable PowerShell.

### 3.5 ATAP.IAC

Most scripts here are infrastructure-as-code (Ansible playbooks
themselves are YAML, but wrapper scripts are PowerShell). Many were
already consolidated into `ATAP.Utilities.IAC.Ansible.Powershell`.
Remaining stragglers are bucket C (one-off provisioning scripts).

---

## 4. The "is this a function or a script" decision tree

When unsure whether a new `.ps1` should be a module function or a
standalone, walk this tree:

```text
Is it a verb-noun cmdlet that takes parameters?
├── Yes → does it fit an existing module's purpose?
│   ├── Yes → write Verb-Noun.ps1 in that module's public/
│   └── No  → does the new module have ≥ 3 functions today + planned?
│       ├── Yes → create the new module (folder, .psd1, version.json)
│       └── No  → write it as a standalone in the appropriate bucket
└── No (it's a procedural orchestrator: "do these N steps in order")
    ├── Is it the entry point for a developer workflow? → bucket C, repo root or tooling folder
    ├── Is it a CI/CD step? → bucket C, repo root, tooling folder, or under `build/`
    └── Is it a one-time fix? → bucket D, `_generated/`, then delete
```

---

## 5. Promotion procedure: standalone → module function

Steps to promote `Foo.ps1` (standalone) into `ATAP.Utilities.X.Powershell`:

1. **Rename to `Verb-Noun.ps1`** if not already cmdlet-named.
2. **Wrap in `function Verb-Noun { ... }`** with a proper
   `[CmdletBinding()]` block, parameter validation, and PSFramework
   logging (per `.claude/rules/PowerShell.md`).
3. **Move to `src/<Module>/public/`** (or `private/` if not exported).
4. **Add a Pester test** at `src/<Module>/tests/Unit/Verb-Noun.Tests.ps1`.
5. **Update `FunctionsToExport`** in the source `.psd1` template — or
   leave it to be auto-populated by the build (preferred).
6. **Delete the original standalone**.
7. **Search the codebase** for callers (`Grep`-able) and update them to
   `Import-Module <Module>; Verb-Noun ...` instead of dot-sourcing the
   old path.

The cleanup commit message convention is
`refactor(<module>): promote Foo.ps1 to Verb-Noun in <Module>`.

---

## 6. Why loose scripts (bucket C) stay loose

It is tempting to consolidate every script into a module. Resist this
for bucket C because:

1. **No version semantics.** `Publish-ATAPUtilities.ps1` is a developer
   convenience, not an API. Versioning it makes the next ProGet pipeline
   weirder, not safer.
2. **Repository context must be explicit.** Many bucket-C scripts depend on
   `git rev-parse --show-toplevel`; if relocated into a tooling folder, they
   must resolve the repository root from their own path or from Git.
3. **Developer discoverability.** Repo-specific entry points can stay at the
   repo root. Shared workstation/build setup helpers should live in the
   BuildTooling `tools/` folder and be linked from the setup runbooks.
4. **Breakage radius is local.** A bug in `Setup-GitHubMCP.ps1` affects
   one developer's workstation; a bug in a cmdlet that gets imported
   everywhere causes wider damage.

The rule is: a bucket-C script may grow up to ~150 lines. Beyond that,
extract the core logic into a module function and keep the script as a
thin wrapper.

---

## 7. The `_generated/` discipline (bucket D)

Scripts under `_generated/` are throw-away. They:

- Are produced by an investigation, prototype, or sprint-scoped fix.
- Are not git-ignored _by default_ (so the user can review and decide).
- Should be deleted at sprint close as part of housekeeping.
- Must never be referenced by import paths from anywhere outside
  `_generated/`.

If a `_generated/` script proves load-bearing for more than one sprint,
that is the trigger to either promote it (§5) or move it to bucket C.

Per SC-0033, **no agent or script should ever write outputs anywhere
other than `_generated/`**. The corollary: every `.ps1` you find under
`_generated/` is a candidate for deletion the moment it is no longer
useful.

---

## 8. Boundary between modules and the build-tooling module

`ATAP.Utilities.BuildTooling.PowerShell` is a special case: it consolidates
~70 build/test/publish helpers under one module. The temptation is to
treat it as a junk drawer for any script related to "the build."

Resist by applying these rules:

- **`Build-*`, `Pack-*`, `Publish-*`** verbs → belong here.
- **`Confirm-*`, `Test-*` (workstation health)** → belong here.
- **`Invoke-Git*Hook`** → belong here (used by all repos via the
  `.claude/` junction).
- **One-shot `Fix-*` from a single sprint** → bucket D, then delete.
- **Repo-specific publish wrappers** → bucket C in that repo, not here.

The 5-tier publish cmdlets (`Publish-PSModuleToProGetFeed`,
`Get-PSModuleVersionFromNBGV`, `Compress-PSModuleArtifacts`,
`Test-CodeCoverageGate`) all correctly live in this module — they are
ecosystem-wide and tier-aware.

---

## 9. Cross-repo invocation (the `.claude/` junction)

The `.claude/` folder at each repo root is an NTFS junction to
`SharedVSCode/.claude/`. Scripts there (skills, agent prompts, hooks)
appear in every repo simultaneously.

Rules:

- A script under `.claude/` may invoke any module function from any
  repo, but it should not assume the module is _imported_ — it must
  `Import-Module <Module> -ErrorAction Stop` first.
- A script under `.claude/` must not write outside `_generated/` of the
  invoking repo.
- Editing a file under `.claude/` from any of the four repos changes
  behavior in **all four** — confirm with the user before doing so.

---

## 10. Known drift and gaps (sprint-0006)

1. **`Database/Powershell/` lacks a manifest.** It looks like a module,
   it has `public/`, `tests/`, but no `.psd1`. Either promote to a real
   module or rename to `Database/scripts/`.

2. **`_Planning/Powershell/Public/` is similarly half-modularized.**
   Tracked for sprint-0007.

3. **`OlderDBsForReference/` and `*/Obsolete/` are dead weight.**
   Multiple `.ps1` files marked obsolete years ago. Slated for deletion.

4. **Both copies of `Publish-ATAPUtilities.ps1` are slated for deletion.**
   The repo-root script (`Publish-ATAPUtilities.ps1`) and the module function
   (`BuildTooling/public/Publish-ATAPUtilities.ps1`) will both be removed.
   Callers that publish **C# libraries** should call `Invoke-DotnetBuildWithRetry`
   instead. Callers that publish **PowerShell modules** should call
   `Invoke-ModuleBuildWithRetry`, which was added in sprint-0006 and orchestrates
   `module.build.ps1` via `Invoke-Build` with NBGV-derived tier resolution and
   automatic retry.

5. **No automated lint for "this `.ps1` should be a function".** A
   PSScriptAnalyzer custom rule could flag standalone scripts that
   define `function Verb-Noun` and recommend module promotion.

6. **`_generated/` cleanup is automated.** `Clear-SprintGeneratedArtifacts`
   in `ATAP.Utilities.BuildTooling.PowerShell` is called by SprintEndAgent
   Step 10.7 with `-SprintNumber $closedSprintNumber`. It removes all
   contents of every sprint worktree's `_generated/` directory. Pass
   `-WhatIf` to preview and `-Force` to suppress the confirmation prompt.
   (Implemented in sprint-0006; SC-0033 task 7.4-2.)

---

## 11. Quick reference

Find all standalone `.ps1` files in this repo (excludes module sources,
tests, vendor, generated):

```powershell
Get-ChildItem -Path . -Filter '*.ps1' -Recurse -File |
    Where-Object {
        $p = $_.FullName
        $p -notmatch '\\(public|private|lib|tests)\\' -and
        $p -notmatch '\\bin\\' -and
        $p -notmatch '\\obj\\' -and
        $p -notmatch '\\_generated\\' -and
        $p -notmatch '\\node_modules\\'
    } |
    Select-Object -ExpandProperty FullName
```

Promote one script (mechanical scaffold):

```powershell
$src = './Publish-Foo.ps1'
$module = './src/ATAP.Utilities.X.Powershell'
$verbNoun = 'Publish-Foo'

Copy-Item $src "$module/public/$verbNoun.ps1"
# manually wrap in function Verb-Noun { ... } and add CmdletBinding
New-Item -ItemType Directory "$module/tests/Unit" -Force | Out-Null
# author $module/tests/Unit/$verbNoun.Tests.ps1
git rm $src
```

Delete sprint-end `_generated/` cruft (review before running):

```powershell
Get-ChildItem ./_generated -Filter '*.ps1' | Remove-Item -WhatIf
```

---

## Related Documents

- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — index.
- [PowerShell-Modules-Build-Process.md](PowerShell-Modules-Build-Process.md) — how a promoted script becomes part of a module.
- [PowerShell-Modules-Test-Process.md](PowerShell-Modules-Test-Process.md) — Pester test that the promotion must add.
- [PowerShell-Modules-Pack-and-Publish.md](PowerShell-Modules-Pack-and-Publish.md) — how the consolidated module ships.
- [PowerShell-Modules-Versioning.md](PowerShell-Modules-Versioning.md) — version semantics that bucket-C scripts deliberately avoid.
