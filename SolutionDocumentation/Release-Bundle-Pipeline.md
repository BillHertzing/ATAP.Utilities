# Release Bundle Pipeline

**Scope:** The third durable BuildMaster pipeline — the one that produces the
final customer-facing installable package containing application code, Flyway
migrations, CSV seed data, seed loaders, install/upgrade scripts, and the
release manifest. Targets Chocolatey and WinGet for distribution.
**Audience:** Release engineers cutting a release; anyone wiring a new
component to ship via Chocolatey/WinGet; CI authors maintaining the
`ReleaseBundle-*` ProGet feeds.
**Status:** Authoritative for sprint-0007.

**Companion docs:**

- [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) — build-once
  policy and the five-tier promotion shape.
- [Database-Change-Unit-and-Flyway-Promotion.md](Database-Change-Unit-and-Flyway-Promotion.md)
  — what DB content gets bundled.
- [Release-Branch-and-Manifest.md](Release-Branch-and-Manifest.md) — the
  release manifest JSON schema.
- [BuildMaster-Pipeline-Topology.md](BuildMaster-Pipeline-Topology.md) — how
  this pipeline fits alongside the C# and PowerShell pipelines.

---

## 1. Why a third pipeline

The C# pipeline ships **library packages** (consumed by other code).
The PowerShell pipeline ships **module packages** (consumed by PowerShell
scripts and other modules). Neither produces an artifact that an end-user
installs.

The Release Bundle pipeline ships the **deployable system of record**: the
single archive that, when extracted on a customer workstation, contains
everything needed to install or upgrade an application — including the
database. This is the artifact that gets named in a Chocolatey package and
referenced by a WinGet manifest.

Treating this as a separate pipeline (rather than a fourth stage of the C#
pipeline) gives it:

- Its own ProGet feed family (`ReleaseBundle-*`).
- Its own approval gates (Chocolatey publish, WinGet manifest update).
- Its own metadata schema (the release manifest, see §5).
- Its own immutable build identity, decoupled from any one library version.

---

## 2. What goes into a bundle

For each release version (e.g. `AceCommander 1.4.0`):

1. **App runtime artifacts**
   - The application package (NuGet, zip, or self-contained `dotnet publish`
     output, depending on the component).
   - PDBs / symbols.
   - Runtime configuration templates (with secrets redacted).

2. **Database change artifacts**
   - All Flyway migration scripts up to and including the target Flyway
     version for that release.
   - CSV files for seed / static data.
   - SQL or PowerShell loader scripts that bulk-load or upsert from CSV.
   - A DB sub-manifest (target Flyway version, included script filenames,
     checksums, seed dataset names + row counts).

3. **Quality / governance artifacts**
   - Test results that validated this release (TRX, JUnit XML, JaCoCo).
   - Code-quality / security-scan reports.
   - Optional schema snapshot (DDL or hash) per release for drift detection.

4. **Operational artifacts**
   - Versioned configuration examples (connection strings sans secrets,
     feature-flag samples).
   - Rollback / roll-forward guidance Markdown for non-trivial DB changes.
   - The install / upgrade scripts that do first-time DB creation,
     schema migration, seed refresh, or no-op DB action as appropriate.

5. **The release manifest**
   - JSON file at the root of the bundle. Schema in
     [Release-Branch-and-Manifest.md](Release-Branch-and-Manifest.md) §3.

The bundle is built **once** from the release-branch tag and then promoted
unchanged through the five tiers per the immutable-build strategy.

---

## 3. Bundle storage in ProGet

Release Bundles live in **Universal Feeds**, not NuGet feeds. Universal
feeds accept arbitrary file content and arbitrary directory structure,
which is what the bundle needs (it carries SQL, CSV, PowerShell, and
binaries simultaneously).

| Feed name                    | Tier         | Purpose                                                       |
| ---------------------------- | ------------ | ------------------------------------------------------------- |
| `ReleaseBundle-Experimental` | Experimental | First push from any release-bundle pipeline run.              |
| `ReleaseBundle-Development`  | Development  | Promoted after smoke + packaging validation.                  |
| `ReleaseBundle-Integration`  | Integration  | Promoted after Flyway-migration rehearsal on a "prev-prod" snapshot. |
| `ReleaseBundle-QA`           | QA           | Promoted after full E2E suite.                                |
| `ReleaseBundle-Production`   | Production   | Source feed for Chocolatey / WinGet publication.              |

The bundle's Universal Package identifier is
`<ProductName>.<SemVer>+<gitshorthash>` — for example
`AceCommander.1.4.0+8f4b2c1`. The `+` suffix is build metadata (per SemVer
2.0); ProGet treats it as part of the package identity.

---

## 4. Bundle directory layout

```text
<ProductName>.<Version>.upack
├── manifest.json                          # release manifest (§5 of Release-Branch-and-Manifest)
├── app/                                   # runtime payload
│   ├── bin/                               # app DLLs / exe / self-contained publish output
│   ├── config/
│   │   └── appsettings.template.json
│   └── symbols/
│       └── *.pdb
├── db/                                    # DB change unit
│   ├── flyway/
│   │   ├── V1.4.0__baseline_schema.sql
│   │   ├── V1.4.1__add_feature_tables.sql
│   │   └── R__views_and_procs.sql
│   ├── seed/
│   │   ├── S1_4_0_roles.csv
│   │   ├── S1_4_0_roles_load.sql
│   │   ├── S1_4_0_permissions.csv
│   │   └── S1_4_0_permissions_load.sql
│   └── db-manifest.json                   # Flyway target version, file checksums, row-count expectations
├── installer/                             # PowerShell entry-point scripts
│   ├── Install-Application.ps1            # first-time install (creates DB, applies migrations, deploys app)
│   ├── Update-Application.ps1             # upgrade in place
│   └── Test-InstallPrerequisites.ps1
├── tests/                                 # evidence
│   ├── unit-results.trx
│   ├── integration-results.trx
│   ├── coverage.cobertura.xml
│   └── flyway-rehearsal.log
└── docs/
    ├── README.md
    ├── ROLLBACK.md
    └── RELEASE_NOTES.md
```

The `installer/Install-Application.ps1` script is what Chocolatey calls
during `choco install <productname>` and what a WinGet-referenced installer
invokes after extraction. The script reads the release manifest to decide
whether to do first-time DB creation, schema migration, seed refresh, or
nothing at all.

---

## 5. BuildMaster pipeline shape

One BuildMaster Application per shipping product (`AceCommander-ReleaseBundle`,
`ATAP.Utilities-ReleaseBundle`, etc.) — but all use the **same shared
pipeline**, parameterized by application variables.

Stages:

```text
Experimental → Development → Integration → QA → Production → Distribution
```

The first five are the standard immutable-build tiers. **Distribution** is
a final stage specific to the Release Bundle pipeline; it publishes the
production-tier bundle to Chocolatey and updates the WinGet manifest source
to point at the new installer URL.

| Stage         | Action                                                                                                                    |
| ------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Experimental  | Build bundle from release-branch tag. Push to `ReleaseBundle-Experimental`. Smoke install on a clean VM.                  |
| Development   | Promote bundle to `ReleaseBundle-Development`. Run install + uninstall on a clean VM.                                     |
| Integration   | Promote to `ReleaseBundle-Integration`. Apply DB migrations against a snapshot of the previous-prod database.             |
| QA            | Promote to `ReleaseBundle-QA`. Run full E2E suite (Playwright, etc.) against the installed product.                       |
| Production    | Promote to `ReleaseBundle-Production`. Manual approval gate from the release manager.                                     |
| Distribution  | Publish to Chocolatey (`Publish-ChocolateyRelease`); update WinGet manifest source (`Update-WinGetManifestSource`).       |

Promotion calls (Experimental → Development → … → Production) are
ProGet API operations — never rebuilds. See
[Immutable-Build-Strategy.md §5](Immutable-Build-Strategy.md#5-what-promotion-is-and-is-not).

---

## 6. PowerShell automation surface

`ATAP.Utilities.BuildTooling.PowerShell` exposes the cmdlets that the
BuildMaster stages call. The Release Bundle pipeline uses:

| Cmdlet                          | Role                                                                                                |
| ------------------------------- | --------------------------------------------------------------------------------------------------- |
| `Get-BuildContext`              | Resolve branch type, application, release version, included DB assets.                              |
| `New-ReleaseManifest`           | Generate the `manifest.json` (schema in [Release-Branch-and-Manifest.md §3](Release-Branch-and-Manifest.md#3-the-manifest-schema)). |
| `New-ReleaseBundle`             | Assemble the directory tree under `_generated/release-bundle/<Version>/` and pack to `.upack`.      |
| `Publish-UniversalPackageToProGet` | Push the `.upack` to `ReleaseBundle-Experimental`.                                                |
| `Promote-ProGetPackage`         | Promote the same bundle between feeds via ProGet promotion API.                                     |
| `Invoke-FlywayRehearsal`        | Apply the bundled Flyway migrations to a clone of the previous-prod DB; capture log.                |
| `New-BuildMasterRelease`        | Create / update the BuildMaster release record for the bundle.                                      |
| `Approve-BuildMasterStage`      | Mark a tier gate passed (script-driven; manual approval is also supported).                         |
| `Publish-ChocolateyRelease`     | Push the `.nupkg` Chocolatey wrapper that references the bundle's installer URL.                    |
| `Update-WinGetManifestSource`   | Update the WinGet `.installer.yaml` to point at the new installer URL (and submit the PR if WinGet auto-PR is enabled). |

All cmdlets are idempotent where possible and read environment-specific
configuration (feed URLs, API keys) from version-controlled `*.psd1` files
plus User-scope environment variables — never from hard-coded constants.

---

## 7. Triggering the pipeline

Three trigger paths, in order of normal-day frequency:

1. **ProGet webhook on `package-added` to `ReleaseBundle-Experimental`.**
   When a developer pushes a candidate bundle (typically via
   `New-ReleaseBundle` + `Publish-UniversalPackageToProGet`), ProGet fires
   a webhook to a BuildMaster API endpoint. The webhook payload includes
   `$PackageName`, `$PackageVersion`, and `$FeedName`. BuildMaster's first
   stage uses this to attach the package as an artifact and start the
   pipeline. See [BuildMaster-Pipeline-Topology.md §6](BuildMaster-Pipeline-Topology.md#6-proget-webhook-integration).
2. **Manual `Create Build` from the BuildMaster UI.** Used when a release
   engineer cuts a release branch and wants to build the bundle by hand.
3. **Cron / scheduled trigger.** Disabled by default. Enable only for
   nightly builds of long-lived release branches that want continuous
   regression coverage.

The pipeline never creates or deletes itself per sprint or per feature.

---

## 8. Distribution to Chocolatey and WinGet

### 8.1 Chocolatey

`Publish-ChocolateyRelease` builds a thin Chocolatey `.nupkg` whose
`tools/chocolateyInstall.ps1` downloads the bundle's installer URL from
ProGet (or from a CDN proxy) and invokes `Install-Application.ps1`.

The Chocolatey package version exactly matches the bundle's SemVer (no
`+<hash>` build-metadata suffix — Chocolatey does not honor it).

The Chocolatey `.nupkg` itself is small (a few KB of script + metadata);
it is **not** the bundle. The bundle is downloaded from ProGet at install
time. This keeps Chocolatey's central repository light and makes our
release pipeline the only authoritative source of bundle bytes.

### 8.2 WinGet

`Update-WinGetManifestSource` produces / updates the WinGet manifest set
(`<ProductName>.installer.yaml`, `<ProductName>.locale.en-US.yaml`,
`<ProductName>.yaml`) for the new version and either:

- Commits to a forked `microsoft/winget-pkgs` repo and opens a PR (the
  Microsoft-recommended path for community-managed entries), or
- Updates a private WinGet source manifest if the org runs a private
  WinGet REST source.

The manifest references the bundle's installer URL on ProGet (or a CDN
proxy in front of it), with the SHA-256 from the release manifest.

### 8.3 Why the bundle ships, not just a stub

The end-user expectation is that one Chocolatey/WinGet install **gets
everything needed**, including the database. The bundle therefore always
includes the DB content — Flyway migrations, seed data, loaders — even when
no DB schema changes were introduced in this release. This trades package
size for installation predictability and operational simplicity. See the
research note in
[BuildPromotePipelineWithPerplexity.md §5 of the source-of-truth doc](../../_Planning-wt-14-Sprint-0007-work-items/Research/RawResearch/BuildPromotePipelineWithPerplexity.md)
for the rationale.

---

## 9. Code-only releases

A release that introduces no new DB changes still produces a full bundle.
The DB content is the same set of migrations + seed files as the previous
release; the release manifest records `databasePackageIncluded: true` and
the same `flywayTargetVersion` as the prior release. The
`Install-Application.ps1` script detects "current DB Flyway version equals
target" and skips migration steps.

This deliberately rules out the older "skip the DB section for code-only
releases" idea — every shipped bundle carries the complete DB story.
Bundle sizes grow modestly as a result; the operational simplification
is worth it.

---

## 10. Known drift and gaps (sprint-0007)

1. **Universal Package feeds not yet provisioned.** ProGet has the five
   `ReleaseBundle-*` feed names reserved but the feeds themselves need to
   be created via SprintStartAgent at the start of sprint-0007.
2. **`Publish-ChocolateyRelease` is a stub.** Returns `Published=$false`
   with reason "not yet implemented." Tracked in TASKS.md.
3. **`Update-WinGetManifestSource` is a stub.** Same as above.
4. **No automated rollback for Chocolatey publication.** If a production
   bundle is found to be defective after Chocolatey publication, the
   recovery path today is "publish a higher version that is functionally
   equivalent to the prior good version." There is no `unpublish`
   operation.

---

## 11. Quick reference

Build a release bundle from a release-branch tag:

```powershell
$ctx = Get-BuildContext -ReleaseTag 'v1.4.0' -Application AceCommander
$mfst = New-ReleaseManifest -Context $ctx
$bundle = New-ReleaseBundle -Manifest $mfst -OutputPath ./_generated/release-bundle/
Publish-UniversalPackageToProGet -Path $bundle.Path -Feed ReleaseBundle-Experimental
```

Promote across tiers (idempotent — no-op if already in the target feed):

```powershell
Promote-ProGetPackage -Name AceCommander -Version 1.4.0+8f4b2c1 `
                      -FromFeed ReleaseBundle-Experimental `
                      -ToFeed   ReleaseBundle-Development `
                      -Reason   'INT-PASS for build #4271'
```

Final distribution after Production gate:

```powershell
Publish-ChocolateyRelease    -BundleVersion '1.4.0+8f4b2c1'
Update-WinGetManifestSource  -BundleVersion '1.4.0+8f4b2c1'
```

---

## 12. Related documents

- [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) — build-once strategy.
- [Release-Branch-and-Manifest.md](Release-Branch-and-Manifest.md) — release-manifest schema.
- [Database-Change-Unit-and-Flyway-Promotion.md](Database-Change-Unit-and-Flyway-Promotion.md) — what goes in `db/`.
- [BuildMaster-Pipeline-Topology.md](BuildMaster-Pipeline-Topology.md) — pipeline catalog.
- [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md) — sister pipeline for libraries.
- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — index.
