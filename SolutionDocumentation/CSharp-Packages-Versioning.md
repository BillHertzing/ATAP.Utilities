# C# Packages — Versioning

**Scope:** How version numbers for `ATAP.Utilities.*` and `AceCommander.*` C# assemblies
and NuGet packages are computed, encoded, promoted through pipeline tiers, and retired.
**Audience:** Developers cutting packages; release engineers running
Experimental → Stable promotions; maintainers modifying the version toolchain.
**Status:** Authoritative. Consolidates and supersedes the versioning portions of
`Building.md`, `_Planning/Explainers/0013-BuildTooling-CSharp-MSBuild-interaction.md`,
and `_Planning/Explainers/0109-nbgv-version-label-promotion.md`.

> **Strategy update (sprint-0007 — Immutable Build).** A package's version
> is computed **once** at the moment of build (Experimental tier) and stays
> the same as the package promotes through the five feeds. Promotion does
> not bump `{height}`, does not re-evaluate `version.json`, and does not
> re-stamp any `Assembly*Version` attribute. The same `.nupkg` (with the
> same SemVer string) lives in all five feeds simultaneously while it is
> being promoted upward. The prerelease label declares the **ceiling**
> tier; the current tier is which feed and BuildMaster stage the artifact
> currently lives in.
> See [Immutable-Build-Strategy.md §6](Immutable-Build-Strategy.md#6-versioning-no-special-case-for-promotion).

**Not in this doc:**

- Build-graph mechanics, MSBuild file hierarchy, the `GetVersion` / `UpdateVersion` /
  `SetVersion` MSBuild task wiring (→ `CSharp-Packages-Build-Process.md`).
- How `.nupkg` files are produced and pushed to ProGet (→ `CSharp-Packages-Pack-and-Push.md`).
- Central Package Management (CPM) / `Directory.Packages.props` / package-pin strategy
  (→ `CSharp-Central-Package-Management.md`).
- BuildMaster pipeline orchestration across the 5 tiers
  (→ `BuildMaster-ProGet-CSharp-Package-Pipeline.md`).

---

## 1. The Two Coexisting Systems

Sprint-0006 is a transition sprint. Two versioning systems are active **simultaneously**
across the `ATAP.Utilities` and `AceCommander` solutions:

| System                                           | Source of truth                                | Status        |
| ------------------------------------------------ | ---------------------------------------------- | ------------- |
| **Legacy** — custom MSBuild tasks                | Per-project `Properties/AssemblyInfo.cs`       | Being retired |
| **NBGV** — [Nerdbank.GitVersioning][nbgv]        | Per-project `version.json` + git height        | Target system |

Both are wired into the build today. NBGV is intended to become the only system.
The retirement plan is in §9.

The Legacy system computes `AssemblyVersion`, `AssemblyFileVersion`, and
`AssemblyInformationalVersion` by regex-editing `AssemblyInfo.cs` at build time.
NBGV computes those same attributes from a git commit-height count scoped by
`pathFilters` and a prerelease label read from `version.json`.

> **One project must win.** If a project has a `version.json` adjacent to its
> `.csproj`, NBGV is authoritative — the MSBuild task-generated `AssemblyInfo.cs`
> values are overwritten by NBGV's generated attributes. If there is no
> `version.json`, the Legacy tasks remain in control.

[nbgv]: https://github.com/dotnet/Nerdbank.GitVersioning

---

## 2. Version Anatomy

Every .NET assembly carries three distinct version attributes. All three are surfaced
both in the compiled DLL and in the generated `.nupkg`:

| Attribute                       | Format                | Consumer               | Purpose                                                          |
| ------------------------------- | --------------------- | ---------------------- | ---------------------------------------------------------------- |
| `AssemblyVersion`               | `Major.Minor.Patch.0` | CLR assembly binder    | Binding / strong-name identity. Breaking-change contract.        |
| `AssemblyFileVersion`           | `Major.Minor.B.R`     | Windows file-properties| Build forensics. B = days since 2000-01-01 UTC; R = seconds/2.   |
| `AssemblyInformationalVersion`  | SemVer-2 string       | Humans, NuGet, tools   | The "real" package version — includes prerelease label and hash. |

`AssemblyInformationalVersion` is also used verbatim as the **NuGet package version**
(`<Version>` / `<PackageVersion>`). This is what appears in the `.nupkg` filename and
in ProGet's UI.

### 2.1 Why three?

- `AssemblyVersion` must be a strict 4-part `uint16` tuple and is used for runtime
  binding. A package update that changes `AssemblyVersion` is a potential binary
  break. For this reason it moves slowly — `Major.Minor.Patch` only, with the 4th
  component always `0`.
- `AssemblyFileVersion` encodes **when** the DLL was built. It is allowed to change
  on every build, carries no semantic meaning, and never participates in binding.
- `AssemblyInformationalVersion` is the SemVer-2 string — the only one that can
  carry prerelease labels (`-Sprint.12`, `-Alpha.3`, `-RC`) and build metadata
  (`+<gitshorthash>`).

### 2.2 Legacy encoding in an `AssemblyInfo.cs`

Current state, as written by the `UpdateVersion` MSBuild task on every build:

```csharp
// ATAP.Utilities.BuildTooling.targets will update the build (date in yMMdd format), and revision fields each time a new build occurs
[assembly:AssemblyFileVersion("0.1.9598.25573")]
// ATAP.Utilities.BuildTooling.targets will update the AssemblyInformationalVersion field each time a new build occurs
[assembly:AssemblyInformationalVersion("0.1.1-Alpha-0000-000")]
[assembly:AssemblyVersion("0.1.1")]
```

- `9598` = days since 2000-01-01 UTC (the build date)
- `25573` = UTC seconds-since-midnight / 2 (the build time)
- `-Alpha-0000-000` = `-{PackageLabel}-{BuildRevision}-{LabelCount}` written by
  `Utilities.MakePackageVersion` (see §7).

### 2.3 NBGV encoding (target state)

NBGV produces the same three attributes but derives the values differently:

```text
AssemblyVersion              → 0.1.0.0                     (from version.json "version" stripped)
AssemblyFileVersion          → 0.1.{height}.{revision}     (height = git-commit depth of filtered paths)
AssemblyInformationalVersion → 0.1.0-Sprint.47+8f4b2c1     (NBGV SemVer-2 + git short hash)
```

The package version on the filename is the `AssemblyInformationalVersion` minus the
`+<hash>` build metadata — e.g. `ATAP.Utilities.ETW.0.1.0-Sprint.47.nupkg`.

---

## 3. The Five-Tier Promotion Model

Packages progress through five tiers. Each tier has its own ProGet feed and
gate discipline. The label NBGV writes into `AssemblyInformationalVersion` is
the promotion ceiling for one immutable pipeline run, not the current stage.

| Ceiling tier | ProGet feed reached at or below ceiling | `version.json` label | Example NuGet version | Git branch               |
| ------------ | ------------------------------ | -------------------- | --------------------- | ------------------------ |
| Experimental | `nuget-Sprint{N}-experimental` | `Sprint`             | `0.1.0-Sprint.3`      | `{issue}-sprint-{N}-*`   |
| Development  | `nuget-Sprint{N}-development`  | `Alpha`              | `0.1.0-Alpha.1`       | `integration`            |
| Integration  | `nuget-integration`            | `Beta`               | `0.1.0-Beta.2`        | `integration` (promoted) |
| QA           | `nuget-qa`                     | `QA`                 | `0.1.0-QA.1`          | `qa`                     |
| Stable       | `nuget-stable`                 | _(none)_             | `0.1.0`               | `main`                   |

- `{N}` is the sprint number (for sprint-0006 it is `6` or `0006` depending on the
  feed naming convention in BuildMaster).
- A package with no prerelease label (`0.1.0` exactly) is a Production / Stable
  release. NuGet treats any `-*` suffix as prerelease.
- The `Sprint` label lives on the developer's sprint worktree branch. Packages
  pushed from there land only in that sprint's experimental feed and are skipped
  by higher stages because their `CeilingTier` is Experimental.

### 3.1 Why `Sprint` before `Alpha`?

`Sprint` is a newer addition specific to this ecosystem's branch topology. A
developer working inside a sprint worktree (`-wt-{issueNumber}-sprint-{N}-*`)
produces `-Sprint.{height}` packages that coexist per-sprint without colliding.
When the work is ready to raise the ceiling, the label flips to `Alpha`,
height resets, and the next package still publishes first to Experimental.
That immutable package may then promote to Development and stops there.

This avoids the older problem where every developer's alpha-labeled prereleases
on their own branches shared a single version-space and clobbered each other in
ProGet.

---

## 4. NBGV — `version.json`

### 4.1 Current schema in use

Two shapes exist in the tree today:

**Repo-root and per-project in ATAP.Utilities:**

```json
{
  "$schema": "https://raw.githubusercontent.com/dotnet/Nerdbank.GitVersioning/main/src/NerdBank.GitVersioning/version.schema.json",
  "version": "0.1-Sprint.{height}",
  "pathFilters": ["./", ":^./_generated", ":^./bin", ":^./obj"],
  "nuGetPackageVersion": { "semVer": 2 }
}
```

**Repo-root and per-project in AceCommander:**

```json
{
  "$schema": "https://raw.githubusercontent.com/dotnet/Nerdbank.GitVersioning/main/src/NerdBank.GitVersioning/version.schema.json",
  "version": "0.1-Sprint.{height}",
  "nuGetPackageVersion": { "semVer": 2 },
  "pathFilters": ["./"]
}
```

The only meaningful difference is that `ATAP.Utilities` excludes generated artifacts
(`_generated`, `bin`, `obj`) from the height calculation. AceCommander currently
does not — this should be brought into alignment (see §10, Known Drift).

### 4.2 Field-by-field

| Field                          | Meaning                                                                 |
| ------------------------------ | ----------------------------------------------------------------------- |
| `$schema`                      | Enables JSON IntelliSense in editors. Never edit.                        |
| `version`                      | Base version + prerelease template. `{height}` is replaced at build time. |
| `pathFilters`                  | Restricts height counting to commits that touched these paths.           |
| `nuGetPackageVersion.semVer`   | `2` enables dot-separated prerelease (`Sprint.47`) per SemVer 2.0.       |

### 4.3 `{height}` — what it actually counts

`{height}` is the number of git commits, walking back from `HEAD`, where at least one
changed file matched `pathFilters`, stopping as soon as it finds a commit that
changed `version.json` itself or reaches the root. In practice:

- A label change (`Sprint` → `Alpha`) resets height to 0 because `version.json`
  itself is included in the filter.
- A commit that only touches docs outside the project tree does not bump height
  for that project.
- Reverting a commit changes height just like any other commit — there is no
  magic.

### 4.4 `pathFilters` gotchas

- `"./"` alone means **all files under this `version.json`'s directory bump
  height**, which for a root-level `version.json` means *every* commit to the repo.
  This is fine for a single-project repo but noisy for a solution with 170 projects
  where a change to project A should not bump project B's version.
- Per-project `version.json` files solve this — each project becomes its own
  height origin.
- Prefixing a pattern with `:^` excludes it (ripgrep-style, which NBGV borrowed).
  `:^./_generated` means "but not files under `_generated`".

### 4.5 Placement rules

- **Repo-root `version.json`**: sets the default for every project without its own.
- **Project-adjacent `version.json`** (next to `.csproj`): overrides the root for
  that project and **resets the height origin** to the directory containing the
  override. This is the preferred pattern — each shipping project owns its version
  line.
- The ATAP.Utilities sprint-0006 tree currently has both a root file **and** ~170
  per-project files. The per-project files take precedence; the root file only
  matters for projects not yet migrated.

---

## 5. Promotion mechanics under immutable build

Under immutable build, the version-label embedded in the `.nupkg` declares
the **ceiling tier** the artifact may reach during this run. The current tier
is which feed and BuildMaster stage the artifact currently lives in. Movement
between feeds is by
`Promote-ProGetPackage` (a ProGet API call), **not** by editing
`version.json` and rebuilding. The latter produces a _new_ artifact with a
new version number; promotion leaves the bytes (and the version number)
unchanged.

### 5.0 Ceiling semantics of the prerelease label

| `version.json` label | `CeilingTier` | Stages allowed for the same artifact |
| --- | --- | --- |
| `Sprint` or feature label | Experimental | Experimental only |
| `Alpha` | Development | Experimental, Development |
| `Beta` | Integration | Experimental, Development, Integration |
| `QA` | QA | Experimental, Development, Integration, QA |
| none | Production | Experimental through Production |

Example: changing a project to `"version": "0.1-Beta.{height}"` and
committing it cuts a fresh Integration-ceiling candidate. The next run builds
the `.nupkg` once in Experimental, promotes the same bytes to Development and
Integration, then skips QA and Production. `Get-BuildContext.CeilingTier`
contains `Integration`; `Get-BuildContext.CurrentTier` changes as each
BuildMaster stage runs.

### 5.0.1 BuildMaster run state for C# package promotion

`CSharpPackage-5Stage.otter` derives the current BuildMaster build id with
`$BuildMasterId(build)` and stores generated inter-stage state here:

```text
_generated/buildmaster/<BuildMasterBuildId>/
```

The Experimental preamble captures the resolved NuGet package version once in
`_resolved_version.tmp` and `build-context.json`. Later tiers promote that
captured version with `Promote-ProGetPackage`; they do not rebuild, repack, or
read flat `_generated/buildmaster/*.tmp` files. Package outputs remain in
`_generated/nuget/<Tier>/`; the buildmaster folder is only per-run state and
diagnostic evidence.

### 5.1 The two operations are different

- **Cutting a new candidate at the next tier** = edit `version.json`,
  commit, build a new artifact. Produces a new version number. (See §5.3.)
- **Promoting an existing candidate** = call `Promote-ProGetPackage`.
  Bytes of the artifact unchanged. Version number unchanged. (See §5.2.)

A common failure mode for new contributors is to assume the two are the
same procedure with different inputs. They are different procedures with
different effects: only one preserves the artifact's `(PackageId, Version,
SHA-256)` identity across feeds.

### 5.2 Promotion procedure (Experimental → Development example)

The artifact `0.1.0-Alpha.7` already exists in `nuget-experimental` (because
the developer who built it used the Alpha label). To make it official at
the Development tier, promote it:

```powershell
# The artifact 0.1.0-Alpha.7 already exists in nuget-experimental
# (because the developer who built it used the Alpha label).
# To make it official at the Development tier, promote it:

Promote-ProGetPackage `
    -Name     'ATAP.Utilities.Philote' `
    -Version  '0.1.0-Alpha.7' `
    -FromFeed 'nuget-experimental' `
    -ToFeed   'nuget-development' `
    -Reason   'DEV-PASS for build #4271'
```

The same shape applies for every higher-tier transition. BuildMaster passes
`-CeilingTier` so the cmdlet aborts before the ProGet API if the destination
feed is above the ceiling.

### 5.3 Cutting a new candidate (formerly the "label promotion procedure")

This procedure is what you run when you want to **change the label on a
fresh build** — for example, you've been building `Sprint` candidates from
a sprint worktree and now want to start building `Alpha` candidates as a
prelude to a Development-tier release. It produces a new artifact with a
new version number; it does **not** move an existing artifact between
feeds.

**Prerequisites.**

- Sprint branch fully committed and pushed.
- All unit tests pass on the sprint branch.
- `nbgv` global tool installed: `dotnet tool install -g nbgv`.
- A clean working tree (`git status` is empty).

**Step 1. Change the label in every `version.json`.**

ATAP.Utilities has ~170 project-level `version.json` files. AceCommander has ~10.
Update all of them in one sweep, per repo:

```powershell
$root = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-{NNNN}-sprint-{M}-work-items'
Get-ChildItem $root -Filter 'version.json' -Recurse | ForEach-Object {
    $c = Get-Content $_.FullName -Raw
    $n = $c -replace '"version"\s*:\s*"([\d.]+)-Sprint\.\{height\}"',
                     '"version": "$1-Alpha.{height}"'
    if ($n -ne $c) { Set-Content $_.FullName -Value $n -NoNewline }
}
```

Run once per affected worktree. `Get-ChildItem ... -Recurse` traverses the
entire tree, so both the repo-root and per-project files are rewritten in one
pass.

**Step 2. Height reset is automatic.**

Because `version.json` files are inside their own `pathFilters`, editing them
forces a new commit that matches the filter — subsequent `{height}` counts
restart from 0. Do **not** manually add an offset.

Verify:

```powershell
nbgv get-version
# Expected on the label-change commit itself:
#   0.1.0-Alpha.0+<shorthash>
# After the first subsequent filtered-path commit:
#   0.1.0-Alpha.1+<shorthash>
```

**Step 3. Commit the label change.**

```powershell
git add '**/version.json'
git commit -m "chore(version): cut new Alpha candidate (was Sprint)"
```

Keep this as a **dedicated commit** — don't bundle code changes into it. A
lone version-bump commit is easy to revert if the candidate cut needs to be
rolled back.

**Step 4. Verify a real `.nupkg`.**

Build any one target project and inspect the output filename:

```powershell
dotnet pack src/ATAP.Utilities.ETW/ATAP.Utilities.ETW.csproj -o /tmp/verify
Get-ChildItem /tmp/verify -Filter '*.nupkg' | Select-Object -ExpandProperty Name
# Expected: ATAP.Utilities.ETW.0.1.0-Alpha.1.nupkg
```

If the filename still shows `-Sprint`, either (a) that project has its own
`version.json` that was not updated, or (b) the project does not have a
`version.json` and Legacy `AssemblyInfo.cs` is authoritative — update the
`AssemblyInfo.cs` file or add a `version.json` (see §7.4).

**Reversing a candidate cut.**

If you want to go back to the previous label (e.g., revert from `Alpha` to
`Sprint`) before further work:

```powershell
Get-ChildItem $root -Filter 'version.json' -Recurse | ForEach-Object {
    $c = Get-Content $_.FullName -Raw
    $n = $c -replace '"version"\s*:\s*"([\d.]+)-Alpha\.\{height\}"',
                     '"version": "$1-Sprint.{height}"'
    if ($n -ne $c) { Set-Content $_.FullName -Value $n -NoNewline }
}
git add '**/version.json'
git commit -m "chore(version): revert candidate label Alpha -> Sprint"
```

The label change is fully symmetric — the height likewise resets.

**Stable cut.** When cutting from `QA` to a Stable (Production) candidate,
the `version.json` **removes** the prerelease segment entirely:

```jsonc
// before (QA candidate)
"version": "0.1-QA.{height}"
// after (Stable candidate)
"version": "0.1"
```

Height is no longer relevant on `main` for publicly released packages; it's
replaced by explicit `Major.Minor.Patch` bumps (see §6).

### 5.4 Two operations, two procedures

| Operation | When | Procedure |
| --- | --- | --- |
| Cut a new candidate at the next tier | when you want a new artifact built under a new label | §5.3 |
| Promote an existing artifact between feeds | when an artifact has passed its tier gate | §5.2 |

---

## 6. SemVer Versus Time-Based Versioning

The ATAP ecosystem uses SemVer 2.0 on `AssemblyInformationalVersion` / NuGet
package version, but uses **time-based** encoding for `AssemblyFileVersion`.
Keeping the two straight avoids a class of confusion:

| Component                       | Who chooses the value              | When does it change |
| ------------------------------- | ---------------------------------- | ------------------- |
| `Major` (SemVer)                | Human. Breaking API change.        | Rarely.             |
| `Minor` (SemVer)                | Human. Additive feature.           | Per feature.        |
| `Patch` (SemVer)                | Human. Bugfix only.                | Per fix.            |
| Prerelease label (`Sprint`/`Alpha`/…) | Pipeline tier promotion.     | At tier transitions. |
| `{height}` counter              | NBGV, derived from git.            | Every filtered commit. |
| `AssemblyFileVersion` B.R       | Build machine clock.               | Every build.        |

**Guideline:** Never hand-edit the 3rd or 4th component of `AssemblyFileVersion`
— it is machine-generated and carries no semantic contract. Edit Major/Minor/Patch
in `version.json` (NBGV) or `AssemblyInfo.cs` (Legacy) when the contract truly
changes.

---

## 7. The Legacy System (being retired)

This section documents the system that predates NBGV. It is still active for
projects without a `version.json`. The Build Process doc covers the MSBuild
wiring; this section covers only the version-number semantics.

### 7.1 Source of truth

`<ProjectDir>/Properties/AssemblyInfo.cs` — a normal C# source file with three
`[assembly:…]` attributes. The `UpdateVersion` MSBuild task regex-edits it
in place on every build.

### 7.2 Property inputs

The task reads these properties from `Directory.Build.props` and the project's
own `.csproj`:

| Property                    | Typical value          | Role                                             |
| --------------------------- | ---------------------- | ------------------------------------------------ |
| `MajorVersion`              | `0`                    | Human-maintained.                                |
| `MinorVersion`              | `1`                    | Human-maintained.                                |
| `PatchVersion`              | `1`                    | Human-maintained.                                |
| `PackageLabel`              | `Alpha` / `Beta` / `QA`| Per-tier label, parallel to NBGV's label.        |
| `PackageLifeCycleStage`     | `Production` / other   | If `Production`, label is dropped (stable build). |
| `ATAPBuildToolingConfiguration` | `Debug`            | Verbosity switch for the task.                   |

### 7.3 The build-revision encoding

`Utilities.MakeBuild` in [ATAP.Utilities.BuildTooling.CSharp.cs:118-122](../src/ATAP.Utilities.BuildTooling.CSharp/ATAP.Utilities.BuildTooling.CSharp.cs#L118-L122)
is the canonical implementation:

```csharp
DateTime now = DateTime.Now.ToUniversalTime();
build    = (now - DateTime.Parse("Jan 1,2000")).Days;
revision = (int)(now.TimeOfDay.TotalSeconds) / 2;
```

This matches the classic .NET Framework "auto-generated version" convention
documented by Eric Lippert. `AssemblyFileVersion` parts 3 and 4 thus uniquely
identify the build moment to within 2 seconds, repo-independent. This is
useful for build forensics and is **deliberately kept** in the target NBGV
system.

### 7.4 `PackageVersion` composition

`Utilities.MakePackageVersion` in [ATAP.Utilities.BuildTooling.CSharp.cs:124-146](../src/ATAP.Utilities.BuildTooling.CSharp/ATAP.Utilities.BuildTooling.CSharp.cs#L124-L146):

```text
PackageVersion = "{Major}.{Minor}.{Patch}"
                 + (if not Production)  "-{Label}-{LabelCount:D3}"
```

`LabelCount` auto-increments on each build while Major/Minor/Patch/Label are
unchanged; it resets to 0 when any of those change. This gives the Legacy
system a monotonically-increasing build counter that is roughly analogous to
NBGV's `{height}` — but it is per-workstation and per-build-sequence, not
per-commit. This difference is a chief reason NBGV is preferred: `{height}`
is reproducible on any clone of the repo with any tooling.

### 7.5 Known quirks in `MakePackageVersion`

The function has a known logic bug in the `if/else` around `labelReleaseCandidate`
— the `if` condition is logically unreachable as written, and the `else` branch
never triggers. This does not affect the happy path (the label is always
appended when non-Production), but a cleanup is recommended as part of the
retirement work. See §10.

---

## 8. Version Flow End-to-End

### 8.1 NBGV build

```text
┌──────────────────────────────────────────────────────────────┐
│ git rev-list --count HEAD -- <pathFilters>  →  {height}       │
│ version.json "version"                       →  base + label   │
│ git short hash                               →  +<hash>        │
└──────────────────────────────────────────────────────────────┘
                         │
                         ▼
         Nerdbank.GitVersioning MSBuild targets
                         │
                         ▼
    AssemblyVersion / AssemblyFileVersion / AssemblyInformationalVersion
    $(PackageVersion) in the generated .nupkg
```

### 8.2 Legacy build

```text
┌──────────────────────────────────────────────────────────────┐
│ <PropertyGroup> in Directory.Build.props / .csproj            │
│   MajorVersion / MinorVersion / PatchVersion                  │
│   PackageLabel / PackageLifeCycleStage                         │
└──────────────────────────────────────────────────────────────┘
                         │
                         ▼
             UpdateVersion MSBuild task (custom)
               reads AssemblyInfo.cs
               recomputes build/revision/labelCount
               rewrites AssemblyInfo.cs in place
                         │
                         ▼
    AssemblyVersion / AssemblyFileVersion / AssemblyInformationalVersion
    are then compiled into the DLL by Csc.exe
    Pack target copies the values into the .nupkg
```

---

## 9. Migration Plan — Retiring the Legacy System

**Current state** (sprint-0006):

- Every `ATAP.Utilities.*` and `AceCommander.*` project that ships a package has
  a project-adjacent `version.json`.
- `Directory.Build.props` line 250 already carries
  `<PackageReference Include="Nerdbank.GitVersioning" PrivateAssets="all" />`.
- ~170 `AssemblyInfo.cs` files still exist, still get rewritten by `UpdateVersion`
  on every build, and their `AssemblyInformationalVersion` strings are
  **overwritten** by NBGV's generated attributes before `Csc.exe` sees them.

The `AssemblyInfo.cs` rewrites are effectively dead data for projects with a
`version.json`. But the MSBuild tasks still run, which is wasted work and a
source of confusion for developers reading a stale `AssemblyInfo.cs`.

**Retirement order** (safest path first):

1. **Verify NBGV coverage** — every shipping project has a `version.json`
   adjacent to its `.csproj`. Currently ~170 out of ~170 in ATAP.Utilities,
   ~10 out of ~10 in AceCommander. No gaps known. (Confirm with a build of
   each `.csproj` and grep the `.nupkg` filename for the expected NBGV label.)
2. **Stop rewriting `AssemblyInfo.cs`** — in `ATAP.Utilities.BuildTooling.targets`,
   gate the `UpdateVersion`/`GetVersion` targets on
   `!Exists('$(MSBuildProjectDirectory)/version.json')`. Projects with NBGV
   become untouched; any remaining legacy project still gets the old treatment.
3. **Delete `AssemblyInfo.cs`** — once no project triggers the rewrites, the
   files can be deleted en masse. Keep `GenerateAssemblyInfo=false` in
   `Directory.Build.props` (or flip it back to the SDK default `true` — NBGV
   writes all attributes itself, so either works).
4. **Delete the custom tasks** — remove the
   `ATAP.Utilities.BuildTooling.CSharp` project, the sentinel-file machinery,
   and `ATAP.Utilities.BuildTooling.targets`. Remove `ATAPBuildToolingVersion`
   and the fallback from `Directory.Build.props`.
5. **Drop the retirement scaffolding** — remove the `Condition="Exists(...)"`
   guards on imports, remove the `ConstrainATAPPackageDependencyVersionRange`
   target if CPM (→ doc e) replaces it, and remove the label-mapping property
   groups keyed off `PackageLabel`.

**What to keep:**

- The 5-tier pipeline model (§3) — independent of which versioning system.
- Time-based `AssemblyFileVersion` — NBGV supports this via
  `versionHeightOffset` and `buildNumberOffset` settings if the forensic value
  is still wanted; decide per-team.
- The promotion procedure (§5) — the Sprint/Alpha/Beta/QA labels live in
  `version.json` and don't need the legacy machinery.

---

## 10. Known Drift and Open Items

- **AceCommander `version.json` missing generated-path excludes.** AceCommander's
  `pathFilters` is `["./"]` while ATAP.Utilities excludes `_generated`, `bin`,
  `obj`. If a code generator writes into `_generated` in AceCommander, that
  commit will bump `{height}` unnecessarily. Recommended fix: align the
  filter list across both repos.
- **Sprint-number interpolation in feed names.** The ProGet feeds
  `nuget-Sprint{N}-experimental` / `-development` require the sprint number
  at BuildMaster time. Sprint-0006 BuildMaster templates use `6`; older
  conventions sometimes use `0006`. This is a BuildMaster concern (→ that
  doc), noted here only because it intersects with version-label choice.
- **Legacy `MakePackageVersion` logic bug.** See §7.5. Safe to ignore while
  retiring the system; do not invest in fixing it.
- **Two `version.json` shapes in tree.** ATAP.Utilities uses
  `"version": "0.1-Sprint.{height}"` (no explicit patch). NBGV treats a
  missing patch as `0`. Both produce `0.1.0-Sprint.N` at build time. Keep
  whichever shape the repo has already committed; don't churn.
- **Repo-root `version.json` coexisting with project-level files.** Not a bug —
  the project-level file wins — but it is redundant. Can be removed as part
  of step 4 in §9.

---

## 11. Quick Reference

### 11.1 Inspect the current version of a project

```powershell
# NBGV view (most trustworthy once NBGV is authoritative)
cd <project-folder-containing-version.json>
nbgv get-version

# Legacy view (inspect the generated attribute in the DLL)
dotnet build -c Debug
Get-Item bin\Debug\net10.0\<Assembly>.dll |
    Select-Object -ExpandProperty VersionInfo
```

### 11.2 Bump Minor across the whole solution

For a pre-Production bump, edit the `version` field in every `version.json` you ship:

```powershell
$root = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-{NNNN}-sprint-{M}-work-items'
Get-ChildItem $root -Filter 'version.json' -Recurse | ForEach-Object {
    $c = Get-Content $_.FullName -Raw
    $n = $c -replace '"version"\s*:\s*"0\.1', '"version": "0.2'
    if ($n -ne $c) { Set-Content $_.FullName -Value $n -NoNewline }
}
```

Then commit as a dedicated `chore(version): bump minor 0.1 -> 0.2` commit.

### 11.3 Force a Patch bump on one project

Edit only that project's `version.json`:

```jsonc
"version": "0.1.1-Sprint.{height}"
```

Height resets on the next commit that touches its filtered paths.

### 11.4 "Why isn't my label change taking effect?"

1. Did you commit the `version.json` change? Uncommitted edits don't affect
   NBGV output.
2. Is the project using NBGV or Legacy? A `version.json` adjacent to the
   `.csproj` confirms NBGV.
3. `nbgv get-version` from the project directory — if it still shows the old
   label, `git log --oneline -- version.json` will show whether the change
   committed.
4. Check if another `version.json` higher in the tree is overriding yours —
   NBGV walks **up** the directory tree from the project, and the
   **nearest** file wins.

---

## 12. Related Documents

- [CSharp-Packages-Build-Process.md](CSharp-Packages-Build-Process.md) — build-graph mechanics.
- [CSharp-Packages-Pack-and-Push.md](CSharp-Packages-Pack-and-Push.md) — `.nupkg` packing, ProGet push.
- [CSharp-Central-Package-Management.md](CSharp-Central-Package-Management.md) — consumer-side version pinning.
- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — the index this doc belongs to.
- `_Planning/Explainers/0109-nbgv-version-label-promotion.md` — the promotion procedure source; this doc now supersedes it.
- [Nerdbank.GitVersioning documentation][nbgv] — upstream reference.
