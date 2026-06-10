# Release Branch and Release Manifest

**Scope:** Release branches as the canonical source of artifacts that ship to
customers, plus the JSON release-manifest schema that travels inside every
Release Bundle.
**Audience:** Release engineers; anyone debugging "what exactly is in this
release"; anyone modifying the release-pipeline metadata.
**Status:** Authoritative for sprint-0007.

**Companion docs:**

- [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) — establishes
  build-once / promote-the-artifact, of which the release branch is the
  source of truth.
- [Release-Bundle-Pipeline.md](Release-Bundle-Pipeline.md) — the pipeline
  that consumes the release-branch tag and produces the bundle.
- [Database-Change-Unit-and-Flyway-Promotion.md](Database-Change-Unit-and-Flyway-Promotion.md)
  — the DB content the manifest enumerates.

---

## 1. Branch model in one diagram

```text
main / stable
   │
   ├── feature/<long-running>            (may carry DB changes; multi-sprint)
   │      └── sprint/<feature>-<NNNN>    (sliced from feature for one sprint)
   │
   ├── sprint/<NNNN>-<topic>             (sliced directly from stable)
   │
   └── release/<x.y.z>                   (cut from stable when ready to ship)
          │
          └── tag v<x.y.z>               (the immutable build input)
```

**Where work happens:** feature and sprint branches.
**Where stable lives:** the `main` (or `stable`) branch — always
potentially-releasable, but not the canonical source of any specific shipped
release.
**Where releases come from:** `release/<x.y.z>` branches, cut from stable
when the team commits to a release. Tags on the release branch are what the
pipeline builds from.

The release branch can carry late-stage hardening fixes without
destabilizing stable. The rule is that artifacts for `<x.y.z>` are built
from the `v<x.y.z>` tag and **then promoted across environments without
rebuilds**. Promotion never re-resolves source.

---

## 2. Release-branch lifecycle

### 2.1 Cutting

```powershell
git checkout stable
git pull
git switch -c release/1.4.0
git push -u origin release/1.4.0
```

Once cut:

- The release branch is the only branch authorized to feed the Production
  ProGet feeds.
- Stable can keep moving forward (other sprints can merge); the release
  branch stays focused on `1.4.0`.

### 2.2 Hardening

Bug fixes for `1.4.0` are merged from sprint branches **into the release
branch** (not into stable). They are then back-merged to stable so the next
release inherits the fix.

```text
release/1.4.0  ←──── sprint/0008-fix-A          (cherry-picked or merged)
       ↓
       └── back-merge ───→  stable
```

This avoids the "we shipped a fix from stable that wasn't in the release
branch" trap.

### 2.3 Tagging

When a release-branch commit is the candidate to ship:

```powershell
git switch release/1.4.0
git tag -a v1.4.0 -m "AceCommander 1.4.0"
git push origin v1.4.0
```

The tag is the immutable build input. Every artifact in the release
(bundle, included libraries, included PowerShell modules) carries the tag's
SHA in its release manifest.

### 2.4 Building

The Release Bundle pipeline (see
[Release-Bundle-Pipeline.md](Release-Bundle-Pipeline.md)) is triggered
either by ProGet webhook (a developer's local
`Publish-UniversalPackageToProGet` push) or manually from the BuildMaster
UI. Either way the build's first step is `Get-BuildContext -ReleaseTag
v1.4.0 -ProjectPath <repo-root>`, which establishes that everything from here
on is for that tag and captures `CeilingTier` from the repo-root
`version.json`.

### 2.5 Promotion

The bundle moves through the five tiers via ProGet promotion API calls.
The bytes never change. Test evidence at each tier is attached to the
BuildMaster release record and (for the headline tests) embedded in the
bundle's `tests/` folder.

### 2.6 Distribution

After Production-tier approval, `Publish-ChocolateyRelease` and
`Update-WinGetManifestSource` finalize external publication. See
[Release-Bundle-Pipeline.md §8](Release-Bundle-Pipeline.md#8-distribution-to-chocolatey-and-winget).

### 2.7 Archival

After distribution, the release branch is **kept** (not deleted). Bug
reports against `1.4.0` get fix branches cut from `release/1.4.0` and
merged back, producing `1.4.1`. The release branch stays alive as long as
the version is supported.

---

## 3. The manifest schema

Every Release Bundle contains a top-level `manifest.json`. The machine-readable schema lives at
[SolutionDocumentation/schemas/manifest.schema.json](schemas/manifest.schema.json):

```json
{
  "schemaVersion": 1,
  "releaseVersion": "1.4.0",
  "sourceTag": "v1.4.0",
  "sourceCommit": "8f4b2c1d3e5fa9c4b1f2e3d4a5b6c7d8e9f0a1b2",
  "sourceBranch": "release/1.4.0",
  "buildUtc": "2026-05-06T14:32:11Z",
  "buildAgent": "utat022",

  "appPackageId": "AceCommander",
  "appPackageVersion": "1.4.0",
  "includedLibraryPackages": [
    { "id": "ATAP.Utilities.Philote",   "version": "0.1.0-Beta.42" },
    { "id": "ATAP.Utilities.ETW",       "version": "0.1.0-Beta.42" }
  ],
  "includedPowerShellModules": [
    { "id": "ATAP.Utilities.FileIO.PowerShell", "version": "0.1.0-Beta.17" }
  ],

  "databasePackageIncluded": true,
  "dbChangeUnit": "AceCommander-db-1.4.0",
  "flywayTargetVersion": "1.4.2",
  "migrationFiles": [
    "db/flyway/V1.4.0__baseline_schema.sql",
    "db/flyway/V1.4.1__add_new_feature_tables.sql",
    "db/flyway/V1.4.2__add_audit_columns.sql",
    "db/flyway/R__views_and_procs.sql"
  ],
  "seedFiles": [
    "db/seed/S1_4_0_roles.csv",
    "db/seed/S1_4_0_permissions.csv"
  ],
  "seedLoaderScripts": [
    "db/seed/S1_4_0_roles_load.sql",
    "db/seed/S1_4_0_permissions_load.sql",
    "db/seed/R__seed_lookup_tables.sql"
  ],
  "installerScripts": [
    "installer/Install-Application.ps1",
    "installer/Update-Application.ps1",
    "installer/Test-InstallPrerequisites.ps1"
  ],

  "testEvidence": [
    { "kind": "unit",        "path": "tests/unit-results.trx",        "checksumSha256": "..." },
    { "kind": "integration", "path": "tests/integration-results.trx", "checksumSha256": "..." },
    { "kind": "coverage",    "path": "tests/coverage.cobertura.xml",  "checksumSha256": "..." },
    { "kind": "flyway-rehearsal", "path": "tests/flyway-rehearsal.log", "checksumSha256": "..." }
  ],

  "checksums": {
    "app/bin/AceCommander.dll":              "sha256:...",
    "db/flyway/V1.4.0__baseline_schema.sql": "sha256:...",
    "db/seed/S1_4_0_roles.csv":              "sha256:...",
    "installer/Install-Application.ps1":     "sha256:..."
  },

  "compatibility": {
    "minDbVersion": "1.4.0",
    "maxDbVersion": "1.4.2",
    "supportedOs":  [ "Windows 10 1809+", "Windows 11", "Windows Server 2019+" ],
    "requiredDotnet": "10.0"
  },

  "rollback": {
    "supported": false,
    "notes": "1.4.0 introduces NOT NULL columns. Downgrade requires backup restore."
  }
}
```

### 3.1 Field-by-field

| Field                       | Type                | Purpose                                                                         |
| --------------------------- | ------------------- | ------------------------------------------------------------------------------- |
| `schemaVersion`             | integer             | Format version of this manifest schema. Bump when adding required fields.       |
| `releaseVersion`            | SemVer string       | The shipped version. Always equals `appPackageVersion` for single-app bundles.  |
| `sourceTag`                 | git tag name        | The release-branch tag that was built. Immutable input to the build.            |
| `sourceCommit`              | full git SHA        | Belt-and-suspenders for `sourceTag`; survives tag movement.                     |
| `sourceBranch`              | git branch name     | Always a `release/*` branch for production releases.                            |
| `buildUtc`                  | ISO 8601            | When the bundle was built.                                                      |
| `buildAgent`                | hostname            | Which BuildMaster agent ran the build.                                          |
| `appPackageId`              | string              | Component identity.                                                             |
| `appPackageVersion`         | SemVer string       | Component version. For Release Bundles equals `releaseVersion`.                 |
| `includedLibraryPackages`   | array of {id,ver}   | C# packages the bundle depends on, pinned to exact versions.                    |
| `includedPowerShellModules` | array of {id,ver}   | PowerShell modules the bundle depends on, pinned.                               |
| `databasePackageIncluded`   | boolean             | Always `true` for shipped bundles.                                              |
| `dbChangeUnit`              | string              | Identity of the DB change unit. See [Database-Change-Unit-and-Flyway-Promotion.md](Database-Change-Unit-and-Flyway-Promotion.md). |
| `flywayTargetVersion`       | string              | Flyway version the DB will reach after install/upgrade.                         |
| `migrationFiles`            | array of paths      | Versioned and repeatable Flyway scripts in this bundle.                         |
| `seedFiles`                 | array of paths      | CSVs.                                                                           |
| `seedLoaderScripts`         | array of paths      | SQL/PowerShell scripts that load the CSVs.                                      |
| `installerScripts`          | array of paths      | Entry-point scripts called by Chocolatey / WinGet installers.                   |
| `testEvidence`              | array of {kind,path,checksum} | Test results that validated this bundle.                              |
| `checksums`                 | map of path→sha256  | Every file in the bundle that the installer or auditor cares about.             |
| `compatibility.minDbVersion`| Flyway version      | Smallest Flyway-version DB this app can run against.                            |
| `compatibility.maxDbVersion`| Flyway version      | Largest Flyway-version DB this app can run against.                             |
| `compatibility.supportedOs` | array of strings    | Human-readable OS list. WinGet manifest mirrors this.                           |
| `compatibility.requiredDotnet` | string           | Minimum .NET runtime version.                                                   |
| `rollback.supported`        | boolean             | Whether downgrade from this version is supported by the install scripts.        |
| `rollback.notes`            | string              | Operational guidance for rollback (e.g. "restore from backup").                 |

### 3.2 What's not in the manifest

- Secrets or connection strings (never).
- Personally-identifying customer information (never).
- Build-machine paths (only the agent hostname is recorded).
- Any value that would make two byte-identical bundles compare unequal —
  the manifest is part of the bundle's hash chain.

---

## 4. Manifest authoring

The manifest is generated by `New-ReleaseManifest`, never hand-edited.
Inputs:

- The release-branch tag (`-ReleaseTag`).
- The application name (`-Application`).
- A `db/<App>/releases/<version>.yml` file (see
  [Database-Change-Unit-and-Flyway-Promotion.md §2](Database-Change-Unit-and-Flyway-Promotion.md#2-repository-layout)).
- The set of library packages and PowerShell modules the app depends on,
  pinned to exact versions in the release-branch's `Directory.Packages.props`
  / module pin files.

`New-ReleaseManifest` writes the top-level JSON to
`_generated/release-manifest/<Version>/manifest.json` and writes the DB
sub-manifest sidecar to
`_generated/release-manifest/<Version>/db-manifest.json`. `New-ReleaseBundle`
then copies `manifest.json` into the bundle root and places the sidecar at
`db/db-manifest.json` inside the `.upack`.

---

## 5. Verification at install time

`installer/Install-Application.ps1` performs these checks before doing any
work:

1. Parse `manifest.json` from the extracted bundle.
2. For each entry in `checksums`, recompute SHA-256 of the file on disk
   and compare. Abort if any mismatch.
3. Check `compatibility.requiredDotnet` against the installed runtime.
4. Check `compatibility.supportedOs` against `Get-CimInstance
   Win32_OperatingSystem`.
5. Check current DB Flyway version (if any) against
   `compatibility.minDbVersion` / `maxDbVersion`. Either install fresh,
   migrate, or abort.

A bundle whose checksums fail verification is **never** installed. This
gives a hard guarantee that the bytes that were tested in QA are the bytes
running in Production.

---

## 6. Auditing a deployed environment

Given a customer-deployed installation, support staff can run:

```powershell
Get-DeployedReleaseManifest -Path 'C:\ProgramData\AceCommander\manifest.json' |
    Format-List
```

…to get the exact release version, source tag, included library pins, DB
change unit, and Flyway version. The manifest is the **single answer to
"what is running here?"** — there is no other authority.

---

## 7. The relationship between release branches and ProGet feeds

| Branch                    | Where its artifacts initially land                  | Promotion target           |
| ------------------------- | ---------------------------------------------------- | -------------------------- |
| `feature/*` (long-lived)  | `*-experimental` (with `-featureA.NNN` prerelease)   | Stays in Experimental.     |
| `sprint/*`                | `*-experimental`                                     | Stays in Experimental until merged. |
| `stable` (`main`)         | `*-experimental` (with `Sprint` label)               | Promoted to Development by tier gate. |
| `release/<x.y.z>`         | Build from tag → `*-experimental`                    | Promoted through all five tiers; final stop is `*-Production`. |

Note that even `release/*` builds **start in Experimental**. The tier of an
artifact is determined by which feed it lives in, not by which branch
produced it. A release-branch build typically rockets through the lower
tiers quickly (no significant new test surface) and pauses at QA → Production
for the manual approval.

---

## 8. Patch releases (`x.y.z+1`)

A patch release follows the same shape:

1. Cherry-pick the fix into `release/<x.y.z>`.
2. Bump the version to `<x.y.(z+1)>` in the release branch.
3. Tag `v<x.y.(z+1)>`.
4. Build the bundle from the new tag (same pipeline, new release record).
5. Promote through the five tiers.
6. Publish to Chocolatey / WinGet.

The cherry-pick creates a new commit on the release branch; the
`sourceCommit` field in the manifest captures that commit's SHA. The
manifest's `includedLibraryPackages` and `includedPowerShellModules`
sections may pin to the same versions as `<x.y.z>` if the patch is
purely an app-level fix; they may pin to bumped library versions if the
patch propagates a fix from a library.

---

## 9. Known drift and gaps (sprint-0007)

1. **Stream I manifest tooling is implemented.** `New-ReleaseManifest`,
   `New-ReleaseBundle`, `Get-DeployedReleaseManifest`, and
   `Compare-ReleaseManifest` are exported from
   `ATAP.Utilities.BuildTooling.PowerShell` and covered by focused Pester
   tests.
2. **CI schema validation is not yet wired globally.** The
   `manifest.schema.json` and `db-manifest.schema.json` contracts are
   published under `SolutionDocumentation/schemas/`; CI still needs to run
   the schema test corpus automatically.
3. **Release-branch retention policy is informal.** Need an explicit
   "release branches are kept indefinitely" rule documented and enforced
   in the GitHub branch-protection settings.

---

## 10. Quick reference

Cut a release branch:

```powershell
git checkout stable
git pull
git switch -c release/1.4.0
git push -u origin release/1.4.0
```

Tag the build candidate:

```powershell
git switch release/1.4.0
git tag -a v1.4.0 -m "AceCommander 1.4.0"
git push origin v1.4.0
```

Generate the manifest and build the bundle:

```powershell
$ctx  = Get-BuildContext     -ReleaseTag v1.4.0 -Application AceCommander -ProjectPath .
$mfst = New-ReleaseManifest  -Context $ctx
$pkg  = New-ReleaseBundle    -Manifest $mfst -OutputPath ./_generated/release-bundle/
Publish-UniversalPackageToProGet -Path $pkg.Path -Feed releasebundle-experimental
```

Audit a deployed bundle's manifest:

```powershell
Get-Content 'C:\ProgramData\AceCommander\manifest.json' -Raw |
    ConvertFrom-Json |
    Select-Object releaseVersion, sourceTag, dbChangeUnit, flywayTargetVersion
```

---

## 11. Related documents

- [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) — release branch is the build-once input.
- [Release-Bundle-Pipeline.md](Release-Bundle-Pipeline.md) — pipeline that consumes the release branch.
- [Database-Change-Unit-and-Flyway-Promotion.md](Database-Change-Unit-and-Flyway-Promotion.md) — DB content the manifest enumerates.
- [BuildMaster-Pipeline-Topology.md](BuildMaster-Pipeline-Topology.md) — pipeline catalog.
- [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md) — version semantics for `appPackageVersion`.
- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — index.
