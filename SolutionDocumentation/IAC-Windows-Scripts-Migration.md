# IAC Windows/ Scripts Migration (status ledger)

> **Moved here 2026-07-06 (Task 12.45.c)** from ATAP.IAC `Windows\planned-migration.md`,
> per the documentation-reorganization plan (`PlanDocumentationReorganization.md`):
> ATAP.IAC carries no documentation. This is the authoritative status ledger for
> migrating every executable/reusable script out of ATAP.IAC `Windows\` into
> ATAP.Utilities modules.
>
> **Status reconciliation against the live ATAP.IAC `Windows\` tree (2026-07-06):**
>
> - Still present in ATAP.IAC (migration pending): `Add-NetworkShareAsLocalDriveLetter.ps1`,
>   `HostSettings.ps1`, and the `HostSettings.IAC.Fragments\` set — `Hosts`, `Databases`,
>   `Databases.ATAPUtilities`, `Databases.AceCommander`, `PackageRepositories`,
>   `PackageRepositories.ProGetFeeds`, `AmbitiousPackageRepositories` (deprecated),
>   plus `BuildMaster.ps1` and `RulesManagement.ps1` — the latter two are **not in the
>   original scope table below**; treat them as Phase 3 items with the same
>   orchestrator/leaf disposition analysis.
> - Already gone from ATAP.IAC (rows below referencing them are complete or moot):
>   `HostSettingsFragment.PCMSC_CE.ps1`, `HostSettings.IAC.Fragment.Databases.PCMSC.ps1`,
>   and all `global_ConfigRootKeys.IAC.Fragment.*` files.
> - `constants\`: `FeedConstants.psd1` and `HostConstants.psd1` are still physically
>   present (and `PowerShellGetFeedMap.psd1` sits under `constants\Obsolete\`) even
>   though their content is migrated to `ATAP.Utilities.ConfigRootKeys.PowerShell`;
>   the on-disk copies are removal candidates.
> - The fragment system's current documentation lives in
>   `ConfigRootKeys-and-HostSettings.md` §9 (this folder).

This document describes the plan for migrating every executable and reusable script
currently living in `Windows/` out of the ATAP.IAC repository and into the
`ATAP.Utilities` repository, where it can be properly packaged, versioned, tested,
and published via ProGet.

---

## Background

The `Windows/` tree in ATAP.IAC was originally the right home for ad-hoc scripts and
configuration fragments that were closely coupled to Ansible inventory.  Over time,
three categories of code drifted in:

1. **Executable utility functions** — general-purpose PowerShell commands that have no
   intrinsic tie to IAC data (e.g., mapping a network share).
2. **Runtime configuration loaders** — the `HostSettings` and `global_ConfigRootKeys`
   fragment system, which constructs environment-aware configuration hashtables.
   These contain real **logic** (switch statements, dot-sourcing orchestration, URI
   construction) that belongs in a tested module.
3. **Pure IAC data files** — YAML/TXT inventory lists, XML application configs, and
   static text templates that have no equivalent home in ATAP.Utilities and must stay
   here.

Migration applies to categories 1 and 2 only.

---

## Scope

### Files to migrate (categories 1 & 2)

| Source file (relative to `Windows/`) | Destination module in ATAP.Utilities | Notes |
|---------------------------------------|--------------------------------------|-------|
| `Add-NetworkShareAsLocalDriveLetter.ps1` | `ATAP.Utilities.FileIO.PowerShell` | General file-system utility; rename to use approved `Verb-Noun` form. |
| `HostSettings.ps1` | `ATAP.Utilities.PowerShell` (or new `ATAP.Utilities.Configuration.PowerShell`) | Core `Get-HostSettings` function family; currently mixed with transitional dot-source guards that will be removed once the module ships. |
| `HostSettingsFragment.PCMSC_CE.ps1` | `ATAP.Utilities.PowerShell` alongside `HostSettings.ps1` | Fragment merged or dot-sourced from the main module. |
| ✅ `global_ConfigRootKeys.IAC.Fragments/global_ConfigRootKeys.IAC.Fragment.Databases.ps1` **— DONE** | `ATAP.Utilities.ConfigRootKeys.PowerShell` (`Add-DatabasesConfigRootKeys.ps1`) | Migrated. Orchestration and key-name constants now in ATAP.Utilities.ConfigRootKeys.PowerShell. Original planned destination was incorrect. |
| ✅ `global_ConfigRootKeys.IAC.Fragments/global_ConfigRootKeys.IAC.Fragment.Databases.ATAPUtilities.ps1` **— DONE** | `ATAP.Utilities.ConfigRootKeys.PowerShell` (`Databases.ATAPUtilities.ConfigRootKeys.ps1`) | Migrated. Original planned destination was incorrect. |
| `global_ConfigRootKeys.IAC.Fragments/global_ConfigRootKeys.IAC.Fragment.Databases.PCMSC.ps1` | `ATAP.Utilities.DatabaseManagement.PowerShell` | As above. |
| ✅ `global_ConfigRootKeys.IAC.Fragments/global_ConfigRootKeys.IAC.Fragment.Hosts.ps1` **— DONE** | `ATAP.Utilities.ConfigRootKeys.PowerShell` (`Set-GlobalConfigRootKeys.ps1`) | Migrated. Hostname-dispatch logic now in ATAP.Utilities.ConfigRootKeys.PowerShell. Original planned destination was incorrect. |
| ✅ `global_ConfigRootKeys.IAC.Fragments/global_ConfigRootKeys.IAC.Fragment.PCMSC_CE.ps1` **— DONE** | `ATAP.Utilities.ConfigRootKeys.PowerShell` | Migrated. PCMSC integration key names now in ATAP.Utilities.ConfigRootKeys.PowerShell. Original planned destination was incorrect. |

> **Note:** The three former package-repository configRootKey fragments (`...PackageRepositories.ps1`, `...PackageRepositories.ProGet.ps1`, `...PackageRepositories.ProGet.Feeds.ps1`) have been removed from ATAP.IAC. Those keys are now defined authoritatively in `ATAP.Utilities.ConfigRootKeys.PowerShell` and loaded via `Set-GlobalConfigRootKeys`. No migration step is required for them.
>
> **Sprint 7 addition:** The `constants/` folder files (`FeedConstants.psd1`, `HostConstants.psd1`, `PowerShellGetFeedMap.psd1`) have also been removed from ATAP.IAC. Their content has been migrated to `ATAP.Utilities.ConfigRootKeys.PowerShell`. These files were not in the original migration scope table.
| `HostSettings.IAC.Fragments/HostSettings.IAC.Fragment.Databases.ps1` | `ATAP.Utilities.DatabaseManagement.PowerShell` | Orchestration logic. |
| `HostSettings.IAC.Fragments/HostSettings.IAC.Fragment.Databases.ATAPUtilities.ps1` | `ATAP.Utilities.DatabaseManagement.PowerShell` | Value population for ATAPUtilities DB across envs. |
| `HostSettings.IAC.Fragments/HostSettings.IAC.Fragment.Databases.PCMSC.ps1` | `ATAP.Utilities.DatabaseManagement.PowerShell` | Value population for PCMSC DB. |
| `HostSettings.IAC.Fragments/HostSettings.IAC.Fragment.Hosts.ps1` | `ATAP.Utilities.PowerShell` | Hostname-dispatch value loader. |
| `HostSettings.IAC.Fragments/HostSettings.IAC.Fragment.PackageRepositories.ps1` | `ATAP.Utilities.BuildTooling.PowerShell` | Package-repository value orchestration. |
| `HostSettings.IAC.Fragments/HostSettings.IAC.Fragment.PackageRepositories.ProGetFeeds.ps1` | `ATAP.Utilities.BuildTooling.PowerShell` | Phase 1 ProGet feed URI value population. |
| `HostSettings.IAC.Fragments/HostSettings.IAC.Fragment.AmbitiousPackageRepositories.ps1` | `ATAP.Utilities.BuildTooling.PowerShell` | 5-dimension feed structure — keep but mark deprecated; superseded by ProGetFeeds. |

### Files that stay in ATAP.IAC

| File | Reason |
|------|--------|
| `AnsibleHostInventory/**` | Ansible inventory data; no executable logic. |
| `NetworkResources/Hosts IP addresess.txt` | Static host-file template for Ansible deployment. |
| `SSHServer/sshd_config for Windows SSH Server.txt` | SSH daemon config template deployed by Ansible. |
| `AnsibleHostInventory/utat022/ProGet.config` | Application connection string managed by Ansible. |

---

## Migration Phases

### Phase 0 — Prerequisites (before any code moves)

- [ ] Ensure `ATAP.Utilities.Configuration.PowerShell` module folder exists in
  `ATAP.Utilities/src/`; if not, create it following the standard module scaffold
  (module manifest, `public/`, `private/`, `tests/` subdirectories).
- [ ] Confirm `ATAP.Utilities.DatabaseManagement.PowerShell` and
  `ATAP.Utilities.BuildTooling.PowerShell` modules already exist in ATAP.Utilities.
- [ ] Decide whether `Get-HostSettings` lives in `ATAP.Utilities.PowerShell` (the
  general utilities module) or a new dedicated `ATAP.Utilities.Configuration.PowerShell`
  module.  **Recommendation:** new dedicated module to maintain single-responsibility.
- [ ] Create a GitHub issue in ATAP.Utilities for the migration work and open a worktree
  using the `issue-to-worktree` skill.

### Phase 1 — Migrate `Add-NetworkShareAsLocalDriveLetter.ps1`

This is the simplest migration; the function has no dependencies on `HostSettings` or
`global_ConfigRootKeys`.

**Steps:**
1. Copy `Add-NetworkShareAsLocalDriveLetter.ps1` to
   `ATAP.Utilities/src/ATAP.Utilities.FileIO.PowerShell/public/`.
2. Rename to `Add-NetworkDriveMapping.ps1` (or keep original name if preferred) and
   review for conformance with PowerShell.instructions.md (PSFMessage logging, param
   blocks, approved verbs).
3. Add a Pester test in
   `ATAP.Utilities/src/ATAP.Utilities.FileIO.PowerShell/tests/Unit/`.
4. Export the function in the module manifest.
5. Delete the source file from ATAP.IAC and replace with a comment stub pointing to the
   new location.

### Phase 2 — Migrate `global_ConfigRootKeys.IAC.Fragments/` *(Partially Complete — Sprint 7)*

> **Sprint 7 Update:** The following fragments have been migrated to `ATAP.Utilities.ConfigRootKeys.PowerShell`
> and removed from ATAP.IAC: `global_ConfigRootKeys.IAC.Fragment.Databases.ps1`,
> `global_ConfigRootKeys.IAC.Fragment.Databases.ATAPUtilities.ps1`,
> `global_ConfigRootKeys.IAC.Fragment.Hosts.ps1`, `global_ConfigRootKeys.IAC.Fragment.PCMSC_CE.ps1`.
>
> **Remaining:** `global_ConfigRootKeys.IAC.Fragment.Databases.PCMSC.ps1`.

The fragment files define key-name constants.  They belong alongside the module code
that consumes them.

**Steps:**
1. ✅ Keys now live in public functions in `ATAP.Utilities.ConfigRootKeys.PowerShell` (4 of 5 files complete).
2. ✅ Files removed from ATAP.IAC for the 4 completed fragments above.
3. ✅ `global_ConfigRootKeys.IAC.Fragment.Hosts.ps1` deployment superseded — `Set-GlobalConfigRootKeys.ps1`
   in `ATAP.Utilities.ConfigRootKeys.PowerShell` is the new entry point.
4. Write Pester tests that verify each key is added exactly once and has the expected
   string value.
5. Migrate `global_ConfigRootKeys.IAC.Fragment.Databases.PCMSC.ps1` to
   `ATAP.Utilities.ConfigRootKeys.PowerShell` and remove from ATAP.IAC.

### Phase 3 — Migrate `HostSettings.IAC.Fragments/`

The 10 fragment files are more complex because they contain data values and URI-build
logic.  The orchestrator files (`Hosts.ps1`, `Databases.ps1`, `PackageRepositories.ps1`)
contain real logic; the leaf files are mostly data.

**Steps:**
1. Migrate orchestrator scripts first: `Hosts.ps1`, `Databases.ps1`,
   `PackageRepositories.ps1` → target modules (see scope table above).
2. For each leaf fragment, evaluate whether the data values should be:
   - Kept as `.ps1` data files inside the module, OR
   - Moved to `.psd1` data files (preferred for pure data), OR
   - Superseded by Ansible variable files (e.g., host_vars YAML) and removed entirely.
3. Migrate `AmbitiousPackageRepositories.ps1` last; mark it `[Deprecated]` in the header
   comment with a pointer to `ProGetFeeds.ps1`.
4. Update all Ansible deployment tasks to copy from the new published module path.
5. Write Pester tests for the orchestrators verifying the correct fragments are sourced
   per hostname.
6. Remove the files from ATAP.IAC.

### Phase 4 — Migrate `HostSettings.ps1` and `HostSettingsFragment.PCMSC_CE.ps1`

These are the highest-dependency files; migrate last.

**Steps:**
1. Strip the transitional dot-source guards (`if (!(Get-Command ...))` blocks) — these
   exist only because the module was not yet published; they are no longer needed after
   Phases 1–3 complete.
2. Move `Get-HostSettings` / `Get-HostSettings2` into the new
   `ATAP.Utilities.Configuration.PowerShell` module's `public/` folder.
3. Move `HostSettingsFragment.PCMSC_CE.ps1` into the module's `private/` or `data/`
   folder and dot-source it from the main function.
4. Write comprehensive Pester tests covering each named host's returned hashtable
   (mock `$env:COMPUTERNAME`).
5. Update all PowerShell profile scripts that currently dot-source `HostSettings.ps1`
   directly to instead `Import-Module ATAP.Utilities.Configuration.PowerShell`.
6. Remove the source files from ATAP.IAC.

---

## Post-Migration: What Remains in ATAP.IAC

After all phases complete, the `Windows/` tree should contain only:

```
Windows/
├── AnsibleHostInventory/       ← Ansible inventory data (unchanged)
├── NetworkResources/           ← Static host-file template (unchanged)
└── SSHServer/                  ← sshd_config reference template (unchanged)
```

The Ansible playbooks and roles that previously deployed files from `Windows/` directly
will instead:

1. Trigger an `Install-Module` or ProGet-pull step to install the relevant
   ATAP.Utilities module on the target host.
2. Rely on the module's own deployment logic (or a thin Ansible wrapper) to place
   fragment files in the correct system paths.

---

## Acceptance Criteria

- [ ] All migrated functions pass Pester tests in ATAP.Utilities.
- [ ] No PowerShell profile or Ansible task in any repo references a file path inside
  `ATAP.IAC/Windows/` for the migrated scripts.
- [ ] `Windows/` in ATAP.IAC contains only the three folders listed above.
- [ ] The ATAP.Utilities modules affected publish successfully to the internal ProGet
  PowerShell feed.
- [ ] `INDEX.md` in this folder is updated to reflect the reduced file set.

---

*See `ATAP.IAC\Windows\INDEX.md` for the current file inventory and descriptions
(inventory file kept in place alongside the data it indexes).*
