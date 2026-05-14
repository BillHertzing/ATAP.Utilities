# PowerShell Modules — Versioning

**Scope:** Sprint-0006/0007. How a PowerShell module's version (the
`ModuleVersion` and `Prerelease` fields in `.psd1`) is computed from NBGV
and how the prerelease label maps onto the 5-tier promotion model.

**Audience:** Anyone who wonders why `Update-ModuleManifest` rejected their
prerelease string, anyone running `nbgv get-version`, anyone promoting a
module from one feed tier to the next.

**Status:** Authoritative for sprint-0006/0007. Mirrors the structure of
[CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md) but documents
the PowerShell-specific translation step.

> **Strategy update (sprint-0007 — Immutable Build).** A module's version
> (`ModuleVersion` + `Prerelease`) is computed **once** at the moment of
> the Experimental build and stays the same as the module promotes through
> the five PowerShellGet feeds. Promotion does not bump `{height}`, does
> not re-evaluate `version.json`, and does not re-stamp the `.psd1`. The
> prerelease label declares the **intended** tier; the actual tier is which
> feed the module currently lives in. The "promotion procedure" in §7
> remains the right tool for cutting a *new* candidate at the next tier
> (Sprint→Alpha) — but moving an existing `.nupkg` between feeds is now a
> `Promote-ProGetPackage` call, not a label edit + rebuild. See
> [Immutable-Build-Strategy.md §6](Immutable-Build-Strategy.md#6-versioning-no-special-case-for-promotion).

**Not in this doc:**
- How NBGV itself works (`version.json` schema, `{height}`, prerelease label
  promotion) → see [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md)
  §§3–6. The mechanics are identical for both ecosystems.
- How the assembled module is built → see [PowerShell-Modules-Build-Process.md](PowerShell-Modules-Build-Process.md).
- How the version is used to choose the publish feed → see
  [PowerShell-Modules-Pack-and-Publish.md](PowerShell-Modules-Pack-and-Publish.md).

---

## 1. The two-format gap

NBGV emits NuGet-style version strings. PowerShell Gallery / `PSResource`
require a stricter format. The translation is the entire job of
`Get-PSModuleVersionFromNBGV`.

| Layer                          | Example                  | Allowed shape                                              |
| ------------------------------ | ------------------------ | ---------------------------------------------------------- |
| NBGV `NuGetPackageVersion`     | `0.1.0-Sprint.42`        | SemVer 2.0 with `.` separators in the prerelease segment   |
| `Update-ModuleManifest -Prerelease` | `Sprint042`         | **Alphanumeric only** — no `.`, no `-`, no underscores     |
| `Update-ModuleManifest -ModuleVersion` | `[Version]'0.1.0'` | 2-, 3-, or 4-part `System.Version`; **no prerelease here** |

The two `.psd1` fields together reconstruct the SemVer string when published:
the gallery joins them as `<ModuleVersion>-<Prerelease>` (e.g.
`0.1.0-Sprint042`).

---

## 2. The translation cmdlet

**File:** `src/ATAP.Utilities.BuildTooling.PowerShell/public/Get-PSModuleVersionFromNBGV.ps1`

**Inputs**: `-ModuleRoot` (absolute path to the module folder).

**Outputs**: `[PSCustomObject]` with three fields
- `ModuleVersion`     — `[System.Version]` (3-part, e.g. `0.1.0`).
- `Prerelease`        — alphanumeric string (e.g. `Sprint042`) or empty.
- `FullNuGetVersion`  — raw NBGV output (e.g. `0.1.0-Sprint.42`).

**Algorithm**:

1. Validate `ModuleRoot` exists.
2. Confirm `nbgv` CLI is on PATH (else throw with install hint).
3. `Push-Location $ModuleRoot` and run
   `nbgv get-version --variable NuGetPackageVersion`. Capture stdout/stderr.
4. Throw if the exit code is non-zero or stdout is empty.
5. Parse with the regex
   `^(?<Major>\d+)\.(?<Minor>\d+)\.(?<Patch>\d+)(?:-(?<Label>[A-Za-z][A-Za-z0-9]*)(?:\.(?<Height>\d+))?(?:\.g[0-9a-f]+)?)?$`.
6. Build the `[Version]` from `Major.Minor.Patch`.
7. If `Label` is empty → stable / Production tier → `Prerelease = ''`.
8. Otherwise concatenate `'{0}{1:D3}' -f $Label, $Height` —
   e.g. `Sprint042`, `Alpha009`, `Beta015`.
9. Validate the result matches `^[A-Za-z0-9]+$` and throw otherwise.

The zero-padding to **3 digits** is critical (see §4).

---

## 3. Why the prerelease must be alphanumeric

`Update-ModuleManifest -Prerelease` enforces the rule
`^[A-Za-z0-9]+$`. It rejects:

- `Sprint.42`  — dot is illegal.
- `Sprint-42`  — hyphen is illegal.
- `42Sprint`   — must start with a letter (the regex above catches this in
  the parse step, not the prerelease check).
- `''` *between* manifests at different tiers — empty is allowed and means
  "stable release."

The PSGallery + ProGet PowerShellGet endpoint both honor SemVer 2.0 *if* the
prerelease is well-formed, but they will not accept a `.psd1` that
`Test-ModuleManifest` itself rejects locally.

---

## 4. Why height is zero-padded to 3 digits

PowerShell Gallery sorts prereleases **lexicographically**, not numerically.
Without padding, `Sprint10` would sort before `Sprint9`, hiding the newer
build under "older" listings. With 3-digit zero-pad:

```text
Sprint001 < Sprint002 < ... < Sprint009 < Sprint010 < ... < Sprint099 < Sprint100
```

This works for heights 0–999. A sprint that produces 1000+ commits to a
given path is unprecedented but would silently re-introduce the sort bug —
tracked as a future improvement (4-digit pad, or switch to a SemVer 2.0
compliant gallery).

---

## 5. Tier-to-label mapping

The same five labels used for C# packages apply unchanged to PowerShell
modules. See
[CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md) §3 for the
authoritative table; reproduced here for convenience:

| Tier         | Label name | NBGV `version.json` `prerelease` | Generated `Prerelease` |
| ------------ | ---------- | -------------------------------- | ---------------------- |
| Experimental | Sprint     | `Sprint`                         | `SprintNNN`            |
| Development  | Alpha      | `Alpha`                          | `AlphaNNN`             |
| Integration  | Beta       | `Beta`                           | `BetaNNN`              |
| QA           | QA         | `QA`                             | `QANNN`                |
| Production   | Production | *(empty — no prerelease)*        | *(empty)*              |

The tier label is **not** stored anywhere PowerShell-specific. It is read
from the module's `version.json` (the same NBGV file used by the C# build).
Editing `<ModuleRoot>/version.json` and committing the change cuts a **new
candidate** at the next tier (it produces a new artifact with a new version
number). Moving an **existing** `.nupkg` between PowerShellGet feeds is a
separate operation — `Promote-ProGetPackage` — and is documented in §7.

---

## 6. The `version.json` per module

Each module folder owns its own `version.json`:

```json
{
  "$schema": "https://raw.githubusercontent.com/dotnet/Nerdbank.GitVersioning/main/src/NerdBank.GitVersioning/version.schema.json",
  "version": "0.1-Sprint.{height}",
  "pathFilters": ["./", ":^./tests", ":^./_generated"],
  "nuGetPackageVersion": { "semVer": 2 }
}
```

Notes:
- **`pathFilters`** scopes the height to commits affecting *this module's
  files only*. Without this, every commit anywhere in ATAP.Utilities would
  bump every module's height.
- **`semVer: 2`** is required for `-Label.height` syntax; SemVer 1
  prereleases use a different separator and are not supported by the
  translation regex.
- **No per-module override of the prerelease label is allowed**. The label
  must match exactly one of the five tiers in §5.

---

## 7. Promotion mechanics for PowerShell modules

Under immutable build, the version-label embedded in a published module
`.nupkg` declares the **intended tier** the module is heading toward. The
**actual** tier is which PowerShellGet feed the `.nupkg` currently lives in.
Movement between feeds is a `Promote-ProGetPackage` call — a ProGet API
operation that copies the existing bytes (or moves a feed-membership pointer)
from one feed to another. The `.psd1` is not re-stamped, NBGV is not
re-invoked, and `version.json` is not re-edited during a promotion.

This section is structured around the two distinct operations that earlier
versions of this doc conflated.

### 7.1 The two operations are different

- **Cutting a new candidate at the next tier** = edit `<ModuleRoot>/version.json`,
  commit, and let the next pipeline run produce a fresh `.nupkg`. This
  produces a **new artifact** with a **new version number** (e.g. moving
  from `Sprint` to `Alpha` makes the next build land at
  `0.1.0-Alpha.{newheight}`). Use this when you want a fresh build under
  a different label. Procedure: §7.3.
- **Promoting an existing candidate** = call `Promote-ProGetPackage`. The
  `.nupkg`'s bytes are unchanged. The version number is unchanged. Only
  the feed membership changes. Use this when an artifact has passed its
  tier gate and is ready for the next feed. Procedure: §7.2.

### 7.2 Promotion procedure (Experimental → Development example)

The artifact `0.1.0-Alpha042` already exists in
`PowershellGet-experimental` (because the developer who built it cut their
candidate under the `Alpha` label — see §7.3). To make it official at the
Development tier, promote it:

```powershell
Promote-ProGetPackage `
    -Name     'ATAP.Utilities.FileIO.PowerShell' `
    -Version  '0.1.0-Alpha042' `
    -FromFeed 'PowershellGet-experimental' `
    -ToFeed   'PowershellGet-development' `
    -Reason   'DEV-PASS for build #4272'
```

`Promote-ProGetPackage` is the **only** mechanism for moving a
PowerShell-module `.nupkg` between PowerShellGet feeds under the immutable
build strategy. Promotion is not a re-pack, not a re-publish, and not a
re-evaluation of `version.json`. See
[Immutable-Build-Strategy.md §5](Immutable-Build-Strategy.md#5-what-promotion-is-and-is-not).

`Promote-ProGetPackage` is currently spec — see
[BuildMaster-Pipeline-Topology.md §4](BuildMaster-Pipeline-Topology.md#4-powershell-automation-surface)
for status.

### 7.3 Cutting a new candidate (formerly the "label promotion procedure")

Run this procedure when you want to **change the label on a fresh build** —
e.g. you've been building `Sprint` candidates and now want to start
producing `Alpha` candidates. It produces a new artifact with a new
version number. It does **not** move an existing artifact between feeds.

To cut a new candidate for a single module under the next label:

```powershell
$file = "src/ATAP.Utilities.FileIO.PowerShell/version.json"
(Get-Content $file -Raw) -replace '"version":\s*"0\.1-Sprint\.\{height\}"', '"version": "0.1-Alpha.{height}"' |
    Set-Content $file -Encoding utf8
git add $file
git commit -m "version(ps): ATAP.Utilities.FileIO.PowerShell cut new Alpha candidate"
```

To cut *every* PowerShell module under the next label at once:

```powershell
Get-ChildItem ./src -Directory -Filter '*Powershell*','*PowerShell*','FinancialAPI' |
    ForEach-Object {
        $vj = Join-Path $_.FullName 'version.json'
        if (Test-Path $vj) {
            (Get-Content $vj -Raw) -replace 'Sprint', 'Alpha' | Set-Content $vj -Encoding utf8
        }
    }
git add src/*/version.json
git commit -m "version(ps): bulk cut new Alpha candidates for PowerShell modules"
```

After commit, the next `nbgv get-version` invocation in any of those module
roots returns `0.1.0-Alpha.{newheight}`. The build/pack/publish pipeline
then publishes the resulting `.nupkg` to `PowershellGet-experimental` (the
**only** publish target — see Pack-and-Publish doc §4). Movement of that
new `.nupkg` to higher feeds happens by `Promote-ProGetPackage` per §7.2.

### 7.4 Two operations, two procedures

| Operation                                  | When                                                      | Procedure |
| ------------------------------------------ | --------------------------------------------------------- | --------- |
| Cut a new candidate at the next tier       | when you want a new artifact built under a new label      | §7.3      |
| Promote an existing artifact between feeds | when an artifact has passed its tier gate                 | §7.2      |

---

## 8. Stable (Production tier) special case

When `version.json` has no `prerelease` segment in `version`:

```json
{ "version": "0.1" }
```

`nbgv get-version --variable NuGetPackageVersion` returns `0.1.0` (no
hyphen, no label). The translation cmdlet:

- Parses `Major=0, Minor=1, Patch=0, Label=$null, Height=$null`.
- Sets `ModuleVersion = [Version]'0.1.0'`.
- Sets `Prerelease = ''`.

`Build-PSModuleManifest` always passes `-Prerelease` to
`Update-ModuleManifest` regardless of value — passing the empty string
**clears** any pre-existing prerelease in the source manifest. This is
intentional: it keeps the same code path for tier promotion to the
Production tier.

---

## 9. Interaction with the manifest's authored `ModuleVersion`

Authored `.psd1` templates carry a placeholder `ModuleVersion` (typically
`'0.0.4'` or `'0.1.0'`). This value is **always** overwritten by
`Build-PSModuleManifest` using the NBGV-computed version. Developers should
not maintain the authored value — it exists only because PowerShell rejects
manifests that omit `ModuleVersion`.

---

## 10. The `git rev` suffix at height 0

NBGV appends `.g{shorthash}` to the version string at height 0 (the very
first commit on a label). Example: `0.1.0-Sprint.0.g1a2b3c4`.

The translation regex matches this and discards the `.g{hash}` segment —
the resulting `Prerelease` is `Sprint000`. This is by design: PSGallery
rejects the git-hash suffix, and we never publish height-0 builds anyway
(the first commit on a label is typically the label-change commit itself).

---

## 11. Common failures and remedies

| Error                                                                              | Cause                                                | Fix                                                             |
| ---------------------------------------------------------------------------------- | ---------------------------------------------------- | --------------------------------------------------------------- |
| `The 'nbgv' CLI was not found on PATH`                                              | NBGV global tool not installed                       | `dotnet tool install -g nbgv`                                  |
| `nbgv output '...' does not match the expected pattern`                             | `version.json` uses an unsupported syntax (e.g. SemVer 1) | Set `nuGetPackageVersion.semVer` to `2` and use `-Label.height` |
| `Computed Prerelease '...' does not match the required alphanumeric pattern`        | Label contains `_` or `-`                            | Edit `version.json`; labels must be `^[A-Za-z][A-Za-z0-9]*$`     |
| `Update-ModuleManifest: Cannot bind parameter Prerelease ... legal characters are alphanumeric` | Hand-passed prerelease bypassed the translation cmdlet | Always use `Get-PSModuleVersionFromNBGV` — never construct the prerelease manually |
| Two consecutive builds resolve different versions                                  | Files outside `pathFilters` were modified            | Verify `pathFilters` includes only this module's source         |

---

## 12. Known drift and gaps (sprint-0006)

1. **Some modules' `version.json` is missing `pathFilters`.** Their height
   includes every commit to the entire repo, so the version bumps on
   every push. Tracked for cleanup.

2. **`ATAP.Utilities.PowerShell.psd1` carries `ModuleVersion = '0.0.4'`** in
   the authored template. This is harmless because `Build-PSModuleManifest`
   overwrites it, but it's misleading to readers.

3. **Height padding is 3 digits.** A module that exceeds 999 path-scoped
   commits in a single label would silently re-sort (e.g. `Alpha1000` <
   `Alpha999`). Switch to 4-digit pad before this becomes a problem.

4. **No PowerShell-specific `version.json` schema validator.** A typo in the
   prerelease label (e.g. `"Sprnit"`) is not caught until publish, where
   it lands in the wrong feed (`PowershellGet-experimental` accepts any
   prerelease shape).

5. **The translation cmdlet does not honor `nuGetPackageVersion.precision`.**
   If a module's `version.json` overrides precision (e.g. to `Major.Minor`
   only), the parser still requires three integer segments. No module
   currently does this, but it's a latent foot-gun.

---

## 13. Quick reference

Get the version for one module:

```powershell
Get-PSModuleVersionFromNBGV -ModuleRoot ./src/ATAP.Utilities.FileIO.PowerShell

# ModuleVersion Prerelease  FullNuGetVersion
# ------------- ----------  ----------------
# 0.1.0         Sprint042   0.1.0-Sprint.42
```

Inspect what NBGV would emit (without translation):

```powershell
Push-Location ./src/ATAP.Utilities.FileIO.PowerShell
nbgv get-version --variable NuGetPackageVersion
nbgv get-version            # full table
Pop-Location
```

Promote one module to the next tier:

```powershell
$file = './src/ATAP.Utilities.FileIO.PowerShell/version.json'
(Get-Content $file -Raw) -replace 'Sprint', 'Alpha' | Set-Content $file -Encoding utf8
```

---

## Related Documents

- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — index.
- [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md) — NBGV
  mechanics shared by both ecosystems; tier table source of truth.
- [PowerShell-Modules-Build-Process.md](PowerShell-Modules-Build-Process.md) — where
  `Get-PSModuleVersionFromNBGV` is invoked.
- [PowerShell-Modules-Pack-and-Publish.md](PowerShell-Modules-Pack-and-Publish.md) —
  how `Tier` (derived from the prerelease label) selects the publish feed.
- [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md) — feed-tier topology.
