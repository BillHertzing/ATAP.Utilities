# ConfigRootKeys and Host Settings

How `$global:configRootKeys` and `$global:settings` are created, populated, and
consumed across the ATAP PowerShell ecosystem.

> **Audience:** anyone writing or maintaining a PowerShell cmdlet, agent, skill,
> or profile in this workspace. Read this before you reference either global.
>
> **Scope:** the PowerShell two-tier global-settings pattern only. The C# Options
> pattern is a separate mechanism — see _Related Documentation_ below.

---

## 1. The Problem This Solves

Automation in this workspace runs on many hosts (developer workstations, build
servers, CI agents) and under many users. Each host has different drive layouts,
install paths, service-account names, ProGet/BuildMaster endpoints, and secret
locations. Cmdlets must not hard-code any of that.

The naive fix — read each value from an environment variable or a config file at
every call site — spreads brittle literal strings (`'ProGetBaseUrl'`,
`'DropboxBasePath'`) across hundreds of scripts. A typo in any one of them fails
silently at runtime.

The ATAP solution is a **two-tier indirection**:

| Tier | Global                   | What it holds                                       | Varies by                         |
| ---- | ------------------------ | --------------------------------------------------- | --------------------------------- |
| 1    | `$global:configRootKeys` | The **names of settings keys**, as string constants | Nothing — identical on every host |
| 2    | `$global:settings`       | The **actual values** for those keys                | Host **and** user                 |

Tier 1 is a stable, code-defined vocabulary. Tier 2 is the host/user-specific
data. Code names a setting through Tier 1 and never types a raw key string, so a
mistyped key name is a missing-variable error caught immediately rather than a
silent `$null` lookup.

---

## 2. The Three-Level Value Chain

This is the single most important concept in this document. There are **three**
distinct strings involved in every lookup, and conflating them is the most common
source of confusion.

```text
  ConfigRootKey constant name        →  settings key string        →  runtime value
  (ends in "ConfigRootKey")             (a key into $global:settings)   (host/user data)

  'ProGetBaseUrlConfigRootKey'       →  'ProGetBaseUrl'             →  'http://utat022:8624'
  'CloudBasePathConfigRootKey'       →  'CloudBasePath'             →  'C:\Dropbox'
  'ProGetFeedNuGetExperimentalFeedNameConfigRootKey'
                                     →  'ProGetFeedNuGetExperimentalFeedName'
                                                                   →  'nuget-experimental'
```

- **Level 1 — ConfigRootKey constant name.** A key _in_ `$global:configRootKeys`.
  By convention it ends in `ConfigRootKey`. This is what code types literally.
- **Level 2 — settings key string.** The _value_ stored at Level 1, and the key
  _into_ `$global:settings`. Usually the Level 1 name with the `ConfigRootKey`
  suffix removed, but treat that as a convention, not a rule — always go through
  the lookup.
- **Level 3 — runtime value.** The _value_ stored at Level 2 in `$global:settings`
  — the actual path, URL, feed name, or flag the cmdlet uses.

The canonical access expression chains Level 1 → Level 2 → Level 3:

```powershell
$global:settings[ $global:configRootKeys['ProGetBaseUrlConfigRootKey'] ]
#                 └── Level 1 ─────────────────────┘
#                 └────────── returns Level 2 ('ProGetBaseUrl') ───────┘
# $global:settings[ 'ProGetBaseUrl' ]  →  Level 3 ('http://utat022:8624')
```

---

## 3. Tier 1 — How `$global:configRootKeys` Is Created

`$global:configRootKeys` is a plain `[hashtable]`. It is built by the
**`ATAP.Utilities.ConfigRootKeys.PowerShell`** module, whose entire purpose is to
define this key vocabulary.

### 3.1 The Orchestrator: `Set-GlobalConfigRootKeys`

`Set-GlobalConfigRootKeys` is the single entry point. It invokes an **explicit,
ordered list of section functions** — order matters because every step after the
first depends on the hashtable already existing. There is **no directory scan and no
fragment discovery**: every set of ConfigRootKeys is a named `Set-*ConfigRootKeys` /
`Add-*ConfigRootKeys` function, listed both in the module manifest's
`FunctionsToExport` and in the orchestrator's ordered invocation list.

| Order | Section function                                                  | Role                                                                                                                                                        |
| ----- | ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1     | `Set-CoreConfigRootKeys`                                          | **Bootstrap.** Creates `$global:configRootKeys` as a fresh hashtable and assigns the core / non-domain key constants in one literal. Must run first.        |
| 2     | `Add-DatabasesConfigRootKeys`                                    | Adds database connection key constants, then invokes the per-database section functions **by name**: `Set-DatabasesATAPUtilitiesConfigRootKeys`, `Set-DatabasesAceCommanderConfigRootKeys`. |
| 3     | `Set-BuildMasterConfigRootKeys`                                  | Adds BuildMaster automation-path / endpoint keys.                                                                                                            |
| 4     | `Set-RulesManagementConfigRootKeys`                             | Adds Rules-Management framework keys.                                                                                                                        |
| 5     | `Add-PackageRepositoriesConfigRootKeys`                         | **Single source of truth** for all ProGet / NuGet / PowerShellGet / ReleaseBundle feed key constants (the canonical five-tier set). Loads no sub-fragments.  |

Step 1 **creates** the hashtable (`$global:configRootKeys = @{ ... }`); every later
step **appends** to it with `.Add(...)`. Because `.Add` throws on a duplicate key, an
accidental double-registration fails loudly rather than silently overwriting.

`Set-GlobalConfigRootKeys` supports `-WhatIf` (shows which section functions would run)
and accepts an optional `-Path` to resolve the co-located section sources from an
alternate directory; by default it resolves `$PSScriptRoot` (the `public/` folder).

#### Explicit loading replaces fragment discovery

The earlier design dropped `*.ConfigRootKeys.ps1` "fragment" files into `public/` and
let a higher-level function **discover** them with `Get-ChildItem` scans (the old
"Phase 3" discovery, plus the `Databases.*.ConfigRootKeys.ps1` sub-fragment scan inside
`Add-DatabasesConfigRootKeys`). That practice is **no longer allowed**. Each section is
now an eponymous advanced function; adding one means writing a new
`Set-<Domain>ConfigRootKeys.ps1`, adding it to `FunctionsToExport`, and adding one line
to the relevant orchestrator's ordered list.

#### In-module sibling resolution (development-from-source guard)

When `Set-GlobalConfigRootKeys` runs **from source** — its `.ps1` dot-sourced
individually (the profile bootstrap, a Pester test) rather than imported as a built
module — calling a sibling such as `Set-CoreConfigRootKeys` would trigger PowerShell
command **autoloading**. Autoloading resolves the first match on `$env:PSModulePath`,
which may be an **installed, production-grade** copy of this module, silently shadowing
the in-development sprint-worktree code. To guarantee the worktree version wins, each
orchestrator's `begin` block dot-sources every section function it invokes from the
co-located source file (`-Path` directory, default `$PSScriptRoot`) **when that file is
present**. In a built/installed module the `public/*.ps1` files are merged into the
`.psm1`, so the files are absent and the already-loaded module-scoped functions (the
correct production versions) are used instead. This is the canonical pattern for "a
higher-level function calling a lower-level function in the same module under
development"; a scope-creep item tracks propagating it to the other ATAP PowerShell
modules.

### 3.2 What a ConfigRootKey Entry Looks Like

Each entry maps a Level 1 constant name to its Level 2 settings-key string:

```powershell
# from Set-CoreConfigRootKeys.ps1
$global:configRootKeys = @{
  'CloudBasePathConfigRootKey'   = 'CloudBasePath'
  'DropboxBasePathConfigRootKey' = 'DropboxBasePath'
  'ProGetBaseUriConfigRootKey'   = 'ProGetBaseUri'
  # ... ~150 more
}

# from Add-PackageRepositoriesConfigRootKeys.ps1
$global:configRootKeys.Add('ProGetFeedNuGetExperimentalFeedNameConfigRootKey',
                           'ProGetFeedNuGetExperimentalFeedName')
```

### 3.3 Naming Conventions

- A ConfigRootKey constant name **ends in `ConfigRootKey`**.
- Its value is the literal Level 2 string used to index `$global:settings` —
  conventionally the same name minus the `ConfigRootKey` suffix.
- ProGet/NuGet/PowerShellGet **feed name** values stored at Level 3 are lowercase
  (`nuget-experimental`, `powershellget-experimental`) to match the real feed
  names on the ProGet server. ReleaseBundle Universal feed names follow the
  `releasebundle-<tier>` convention.

Tier 1 contains **only key names** — never host data, never secrets. It is
identical on every machine.

---

## 4. Tier 2 — How `$global:settings` Is Created

`$global:settings` is the host/user-specific `[hashtable]` whose **keys are the
Level 2 strings** defined in Tier 1 and whose **values are the Level 3 runtime
data**.

### 4.1 The Builder: `Get-HostSettings`

`Get-HostSettings` lives in the **`ATAP.Utilities.PowerShell`** module. It:

1. **Validates the precondition.** If `$global:configRootKeys` is absent, not a
   hashtable, or empty, it throws immediately:
   _"`$global:configRootKeys` is not populated. Call `Set-GlobalConfigRootKeys`
   before `Get-HostSettings`."_ — Tier 1 must always exist before Tier 2 is built.
2. **Locates the IAC host-settings script.** It probes a candidate list for
   `HostSettings.ps1` (or `Windows\HostSettings.ps1`): the `-IACBasePath`
   parameter, the ATAP.IAC sprint worktree, the `ATAP_IAC_BASE_PATH` environment
   variable (Process then User scope), `~\GitHub\ATAP.IAC`, the stable ATAP.IAC
   worktree, and finally the installed-module `Resources` folder.
3. **Dot-sources `HostSettings.ps1` in a child scope.** That IAC file defines its
   _own inner_ `Get-HostSettings` function. The wrapper invokes the inner
   function with the requested host name and returns the resulting hashtable.
4. **Validates the result** — non-null and an actual `[hashtable]` — then returns
   it.

The IAC `HostSettings.ps1` is the actual source of host-specific data: it is a
per-host dispatch (`switch` on host name) that assigns Level 3 values, keyed by
the Level 2 strings it reads back out of `$global:configRootKeys`. It lives in
the **ATAP.IAC** repository, not here, because that data is infrastructure
configuration.

The caller assigns the return value to the global:

```powershell
$global:settings = Get-HostSettings -hostName $env:COMPUTERNAME
```

### 4.2 Post-Creation Mutation

`$global:settings` is **not frozen after `Get-HostSettings` returns.** The
PowerShell profile (and some cmdlets) write additional runtime-derived values
back into it using the same Tier-1 indirection — for example:

```powershell
# AllUsersAllHostsV7CoreProfile.ps1 — set after the hashtable is built
$global:settings[$global:configRootKeys['IsElevatedConfigRootKey']]  = <is this shell elevated?>
$global:settings[$global:configRootKeys['ENVIRONMENTConfigRootKey']] = $inProcessEnvironmentVariable
$global:settings[$global:configRootKeys['GIT_CONFIG_GLOBALConfigRootKey']] = 'C:\Dropbox\whertzing\Git\.gitconfig'
```

So `$global:settings` = _static host data from IAC_ **+** _runtime facts about
the current process/session_.

---

## 5. The Bootstrap Sequence (PowerShell Profile)

Both globals are established at shell startup by the ATAP PowerShell profile
(`AllUsersAllHostsV7CoreProfile.ps1`). The ordering is mandatory:

```text
1. Ensure Set-GlobalConfigRootKeys is available
     → if not loaded, dot-source it from the active ATAP.Utilities worktree
2. Set-GlobalConfigRootKeys
     → creates and populates $global:configRootKeys   (Tier 1)
3. Ensure Get-HostSettings is available
     → if not loaded, dot-source it from the active ATAP.Utilities worktree
4. $global:settings = Get-HostSettings -hostName $hostName -IACBasePath $repobasepath
     → creates and populates $global:settings          (Tier 2)
5. Profile writes runtime facts (IsElevated, ENVIRONMENT, …) into $global:settings
```

> **Sprint vs. stable worktree.** Until `ATAP.Utilities.PowerShell` and
> `ATAP.Utilities.ConfigRootKeys.PowerShell` ship as installed modules, the
> profile dot-sources these scripts from a worktree by absolute path.
> SprintStartAgent points `$repobasepath` at the sprint worktree;
> SprintEndAgent points it back at the stable worktree. The marked comment lines
> in the profile (`# SprintStartAgent …` / `# SprintEndAgent …`) are the toggle.

The profile also registers a default so cmdlets with a `-Settings` parameter
pick up the global automatically:

```powershell
$PSDefaultParameterValues['*:Settings'] = { $global:settings }
```

---

## 6. How to Consume the Globals

### 6.1 Reading a setting

Always chain both globals — never type a Level 2 string literally:

```powershell
# Correct — indirection through Tier 1
$cloudRoot = $global:settings[$global:configRootKeys['CloudBasePathConfigRootKey']]
$progetUrl = $global:settings[$global:configRootKeys['ProGetBaseUrlConfigRootKey']]

# Wrong — raw key string; a typo here fails silently as $null
$cloudRoot = $global:settings['CloudBasePath']
```

If a key may legitimately be absent, test before reading:

```powershell
$krk = $global:configRootKeys['SecretVaultNameConfigRootKey']
if ($global:settings.ContainsKey($krk)) {
    $vaultName = $global:settings[$krk]
}
```

### 6.2 Defensive loading in cmdlets and agents

Interactive shells get both globals from the profile. **Non-interactive shells
do not** — agent-spawned shells, `pwsh -NoProfile`, and some CI runners start
with neither global defined. A cmdlet that assumes they exist will fail with a
confusing `$null` index error deep in its logic.

A cmdlet that depends on these globals must check for them up front and fail with
an actionable message (this is the pattern adopted for `New-SprintStage2`):

```powershell
if ($null -eq $global:configRootKeys -or $null -eq $global:settings) {
    throw "Global configuration is not loaded. Run this first:`n" +
          "  Set-GlobalConfigRootKeys; " +
          "`$global:settings = Get-HostSettings -hostName `$env:COMPUTERNAME"
}
```

Naming the recovery command in the error message is the point — the operator (or
the next agent) can copy-paste the fix.

---

## 7. Common Pitfalls

| Pitfall                                                           | Symptom                                              | Fix                                                                                                           |
| ----------------------------------------------------------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Indexing `$global:settings` with a raw string                     | Lookup silently returns `$null`                      | Always go through `$global:configRootKeys[...]`                                                               |
| Calling `Get-HostSettings` before `Set-GlobalConfigRootKeys`      | Throws _"`$global:configRootKeys` is not populated"_ | Run the orchestrator first                                                                                    |
| Running a settings-dependent cmdlet in a no-profile / agent shell | `$null` index errors with no obvious cause           | Add the §6.2 defensive guard                                                                                  |
| Adding a new setting but only defining the value                  | Code that names the key by constant can't find it    | Register the **ConfigRootKey constant** in the right fragment **and** add the value in IAC `HostSettings.ps1` |
| Registering a duplicate ConfigRootKey                             | `.Add()` throws on load                              | Pick a unique constant name; check existing fragments                                                         |
| Treating `$global:settings` as immutable                          | Stale `IsElevated` / `ENVIRONMENT`                   | Remember the profile and cmdlets mutate it after creation                                                     |

---

## 8. Adding a New Setting — Checklist

1. **Pick the section function.** Choose the `Set-*ConfigRootKeys` /
   `Add-*ConfigRootKeys` function that owns the domain (core, databases, BuildMaster,
   RulesManagement, or package repositories). Add a new domain section function only if
   none fits — create `public/Set-<Domain>ConfigRootKeys.ps1` as an eponymous advanced
   function that guards on `$global:configRootKeys` existing and `.Add(...)`s its keys in
   the `process` block.
2. **Register the ConfigRootKey constant** (Level 1 → Level 2 mapping). Use a
   name ending in `ConfigRootKey`; in `Set-CoreConfigRootKeys` add a hashtable entry, in
   an `Add-*` / `Set-*` section function use `.Add(...)`.
3. **Provide the value** (Level 2 → Level 3) in the ATAP.IAC `HostSettings.ps1`
   for every host that needs it. Secrets are **not** stored here — store the
   _name of the environment variable / Bitwarden item_, and let code resolve the
   actual secret at use time.
4. **Consume it** with the chained `$global:settings[$global:configRootKeys[...]]`
   expression.
5. If you added a new section function, add it to `FunctionsToExport` in the `.psd1`,
   add its name to the ordered invocation list in the appropriate orchestrator
   (`Set-GlobalConfigRootKeys`, or `Add-DatabasesConfigRootKeys` for a database), and
   update the module `INDEX.md`. Do **not** rely on directory discovery — there is none.

---

## 9. The ATAP.IAC HostSettings Fragment Files (Tier 2 data source)

> Migrated from ATAP.IAC `Documentation\global_ConfigRootKeys and HostSettings.md`
> (2026-07-06, Task 12.45.c) and reconciled against the live `Windows\` tree. The
> fragment **data files remain in the ATAP.IAC repository** (they are host-specific
> infrastructure data); this section documents them because they are the physical
> source of the Tier 2 values described in §4.

`Get-HostSettings` (§4.1) dot-sources ATAP.IAC `Windows\HostSettings.ps1`, whose
inner function builds the `$HostsType1` hashtable by loading fragment files from
`Windows\HostSettings.IAC.Fragments\`. Live inventory as of 2026-07-06:

| Fragment | Role |
| --- | --- |
| `HostSettings.IAC.Fragment.Hosts.ps1` | Entry point. Uses `$PSScriptRoot` to locate peer fragments and a `switch` on `$env:COMPUTERNAME` (currently `utat022`, `utat01`) to decide which fragments to load. |
| `HostSettings.IAC.Fragment.Databases.ps1` | Orchestrator. Auto-discovers and dot-sources all `HostSettings.IAC.Fragment.Databases.*.ps1` files and creates the `DatabasesCollection` entry in `$HostsType1`. |
| `HostSettings.IAC.Fragment.Databases.ATAPUtilities.ps1` | Values for the ATAPUtilities database across environments. |
| `HostSettings.IAC.Fragment.Databases.AceCommander.ps1` | Values for the AceCommander database across environments. |
| `HostSettings.IAC.Fragment.PackageRepositories.ps1` | Creates `PackageRepositoriesCollection` in `$HostsType1`; builds URIs with `[UriBuilder]::new()` from component parts; defines connector configurations for push feeds (NuGet → api.nuget.org, PSResourceGet → powershellgallery.com, ChocolateyGet → chocolatey.org). Each entry carries `LongName`, `ShortName`, `ApiKeyName` (vault reference), `Uri`, and `Connectors`. |
| `HostSettings.IAC.Fragment.PackageRepositories.ProGetFeeds.ps1` | ProGet feed URI value population. |
| `HostSettings.IAC.Fragment.BuildMaster.ps1` | BuildMaster endpoint/automation values. |
| `HostSettings.IAC.Fragment.RulesManagement.ps1` | Rules-Management framework values. |
| `HostSettings.IAC.Fragment.AmbitiousPackageRepositories.ps1` | Deprecated 5-dimension feed structure; superseded by `PackageRepositories.ProGetFeeds.ps1`. |

Each database fragment populates a nested hashtable, environments as keys:

```powershell
$HostsType1['DatabasesCollection']['<DatabaseName>'] = @{
  'Production' = @{
    DatabaseHost     = '<host>'
    ConnectionMethod = '<method>'
    SqlInstance      = '<instance>'
    DatabasePath     = '<path>'
    UseNamedLogin    = '<boolean>'
    LoginKey         = '<credentials-key>'
  }
  '<EnvironmentName>' = @{ ... }
}
```

### 9.1 Adding a new database or host

1. Add the key-name constants as a section function in
   `ATAP.Utilities.ConfigRootKeys.PowerShell` (see the §8 checklist — no directory
   discovery; register in `FunctionsToExport` and the orchestrator's ordered list).
2. Create `HostSettings.IAC.Fragment.Databases.<NewName>.ps1` in ATAP.IAC
   `Windows\HostSettings.IAC.Fragments\` to populate the runtime values; it is
   auto-discovered by `HostSettings.IAC.Fragment.Databases.ps1`.
3. For a new host, extend the `switch` in `HostSettings.IAC.Fragment.Hosts.ps1`
   and, if new key definitions are needed, `Set-GlobalConfigRootKeys`.

### 9.2 Historical: migrated ConfigRootKeys fragments and constants

The Tier 1 side of the old two-sided IAC fragment system is gone. The
`global_ConfigRootKeys.IAC.Fragment.*` files (Hosts, Databases,
Databases.ATAPUtilities, PCMSC_CE, PackageRepositories) were removed from ATAP.IAC
in Sprint 7; their definitions are authoritative in
`ATAP.Utilities.ConfigRootKeys.PowerShell` (`Set-GlobalConfigRootKeys` and the
section functions of §3.1). The `constants\` data files (`FeedConstants.psd1`,
`HostConstants.psd1`, `PowerShellGetFeedMap.psd1`) were likewise migrated to that
module — note that as of 2026-07-06 `FeedConstants.psd1` and `HostConstants.psd1`
are still physically present in ATAP.IAC `constants\` (with
`PowerShellGetFeedMap.psd1` under `constants\Obsolete\`); the module is
authoritative and those on-disk copies are removal candidates. PCMSC fragments
(`HostSettings.IAC.Fragment.Databases.PCMSC.ps1`, `HostSettingsFragment.PCMSC_CE.ps1`)
no longer exist in the live tree.

---

## 10. Related Documentation

- `src/ATAP.Utilities.ConfigRootKeys.Powershell/INDEX.md` — module file map,
  phase order, deprecated fragments, and the canonical five-tier feed mapping.
- `src/ATAP.Utilities.PowerShell/INDEX.md` — `Get-HostSettings` and related
  cmdlets.
- `SecretsPluginArchitecture.md` (this folder) — configuration/secrets shim
  loading (absorbed the former `_Planning` Explainer 0012, deleted 2026-05-28).
- `Immutable-Build-Strategy.md` (this folder) §Dependency Restoration Invariant —
  the five-tier feed set referenced by `Add-PackageRepositoriesConfigRootKeys`
  (absorbed the former `_Planning` Explainer 0111 feed-tier report).
- `ATAP.IAC` repository — `Windows\HostSettings.ps1` and the
  `HostSettings.IAC.Fragments\` data files (§9), the per-host source of Tier 2
  values.
- `IAC-Windows-Scripts-Migration.md` (this folder) — status ledger for migrating
  the executable scripts out of ATAP.IAC `Windows\`.
- **C# equivalent.** C# code does **not** use these globals. It uses the .NET
  Options pattern with DI (`services.AddOptions<T>().Bind(...)`). The two systems
  are independent; see `CLAUDE.md` → _Configuration System_.

---

_This document supersedes the never-created planning placeholder
`Explainers/0027-configrootkeys-and-hostsettings.md` (task H09). The content was
placed in `SolutionDocumentation/` because it teaches how the production tooling
works, which is this folder's purpose._
