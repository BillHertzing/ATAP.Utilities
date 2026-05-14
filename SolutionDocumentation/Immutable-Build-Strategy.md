# Immutable Build Strategy

**Scope:** The single, authoritative description of the **build-once /
promote-the-artifact** strategy used across the ATAP ecosystem (C# packages,
PowerShell modules, and the customer-facing Release Bundle that ships to
Chocolatey and WinGet).
**Audience:** Anyone reading the per-area Build/Pack/Push docs; anyone
designing a new pipeline; release engineers reasoning about promotion gates.
**Status:** Authoritative for sprint-0007. **Supersedes** the older
build-per-tier ("buildpertier") pattern referenced in earlier sprint-0006 docs.

**Companion docs:**

- [BuildMaster-Pipeline-Topology.md](BuildMaster-Pipeline-Topology.md) — the
  three durable BuildMaster pipelines and the PowerShell automation surface.
- [Release-Bundle-Pipeline.md](Release-Bundle-Pipeline.md) — the third pipeline
  that bundles app + DB + installer into one Chocolatey/WinGet package.
- [Release-Branch-and-Manifest.md](Release-Branch-and-Manifest.md) — release
  branches and the release-manifest JSON.
- [Database-Change-Unit-and-Flyway-Promotion.md](Database-Change-Unit-and-Flyway-Promotion.md)
  — DB artifacts and Flyway promotion.

---

## 1. The principle

> **Build a release unit exactly once. Promote that exact artifact, byte for
> byte, through the five tiers. Never rebuild between tiers.**

A "release unit" is one of three things:

1. A C# NuGet package (or family of packages built from the same solution).
2. A PowerShell module `.nupkg`.
3. A **Release Bundle** — the final installer that contains app code, Flyway
   migrations, CSV seed files, seed loaders, install/upgrade scripts, and a
   release manifest. This is the unit that ships to Chocolatey and WinGet.

Each release unit is built once on the lowest tier (Experimental) and then
promoted through the ProGet feed chain as quality gates pass. The bytes that
land in the Production feed are the bytes that were originally built.

---

## 2. Why "build once"

The older build-per-tier pattern rebuilt the package at every tier transition,
re-running `dotnet pack` against the source. That model has three structural
problems:

1. **Provenance gap.** A package in the QA feed was not the package tested in
   Integration — they were two distinct compilations from possibly-different
   commit states. Test evidence did not carry forward.
2. **Reproducibility cost.** Each tier had to re-resolve dependencies and
   re-execute the entire toolchain, multiplying CI time and exposing the
   build to flakes (NuGet outages, transient build-tool quirks, clock skew).
3. **Hash divergence.** Two `dotnet pack` runs of the same source produce
   `.nupkg` files with different inner timestamps and therefore different
   SHA-256 hashes. Downstream signing, archival, and audit chains break.

Immutable build solves all three: the artifact's hash is fixed at the moment
of creation; tier promotion is a metadata change in ProGet; tests at higher
tiers run **against the existing artifact** and their results are attached to
that artifact's BuildMaster release record.

---

## 3. The pipeline shape (verbal flowchart)

For any release unit, the BuildMaster pipeline does this:

1. **Resolve build context.** Branch type (`stable`, `feature/*`, `sprint/*`,
   `release/*`), application, package family (C# / PowerShell / ReleaseBundle),
   whether DB assets are included for this release candidate.
2. **Load build metadata.** Semantic version (NBGV), prerelease label,
   target package IDs, included Flyway migration set, seed data set,
   compatibility metadata.
3. **Restore dependencies** from the appropriate ProGet development feeds
   (NuGet and PowerShellGet), pinned to specific versions for reproducibility.
4. **Build code.**
   - C#: restore, compile, run unit tests, collect symbols and TRX results.
   - PowerShell: run Pester, lint with PSScriptAnalyzer, validate manifest,
     consolidate sources into the generated `.psm1`.
5. **Assemble the release artifact.** Binaries / module payload + Flyway
   scripts + seed CSV + loaders + install/update scripts + release manifest
   (with checksums).
6. **Publish to the Experimental ProGet feed** for that artifact family.
   The artifact never overwrites an existing version (push uses
   `--skip-duplicate` so partial runs are idempotent).
7. **Create / update a BuildMaster release record** for that exact version.
   Attach all build artifacts, test results, and the manifest as evidence.
8. **Tier gates run as test stages**, not rebuilds:
   - Experimental: smoke tests, packaging validation, installer validation.
   - Development → Integration → QA → Production: progressively broader
     automated and manual checks. For Release Bundles, includes Flyway
     migration rehearsal against a snapshot of the previous tier's DB.
9. **On gate pass, promote the same immutable package** to the next ProGet
   feed via ProGet's package-promotion API. BuildMaster never re-runs
   `dotnet pack`.
10. **At Release-Branch builds**, verify that the full test suite has been
    run against the tagged release artifact set, or that prior test evidence
    matches the release tag and manifest checksums, before allowing
    production publication.
11. **Final step (Release Bundle only):** publish the production-tier bundle
    to Chocolatey and to the hosted installer location referenced by WinGet,
    only after the Production gate passes.
12. **Record promotion, deployment, and provenance** back into BuildMaster
    release metadata for auditability.

---

## 4. ProGet feed-per-tier per package family

Each release unit family has its own five ProGet feeds. Promotion is the
authoritative tier-state mechanism — branch names do not imply feed names.

| Feed family       | Tier         | Purpose                                                    |
| ----------------- | ------------ | ---------------------------------------------------------- |
| `nuget-experimental`     | Experimental | First push from any pipeline run.                          |
| `nuget-development`      | Development  | Promoted after unit-test gate.                             |
| `nuget-integration`      | Integration  | Promoted after integration-test gate (hermetic feed).      |
| `nuget-qa`               | QA           | Promoted after full regression (hermetic feed).            |
| `nuget-stable`           | Production   | Promoted after manual release-engineer approval.           |
| `PowershellGet-experimental` | Experimental | Mirrors NuGet feed semantics for PowerShell modules.   |
| `PowershellGet-development`  | Development  |                                                       |
| `PowershellGet-integration`  | Integration  |                                                       |
| `PowershellGet-qa`           | QA           |                                                       |
| `PowershellGet-stable`       | Production   |                                                       |
| `releasebundle-experimental` | Experimental | Final installer bundles (app + DB + installer scripts).|
| `releasebundle-development`  | Development  |                                                       |
| `releasebundle-integration`  | Integration  |                                                       |
| `releasebundle-qa`           | QA           |                                                       |
| `releasebundle-production`   | Production   | Source feed for Chocolatey / WinGet publication.      |

Release Bundles are stored as ProGet **Universal Packages** rather than NuGet
packages, because they carry mixed content (DLLs + SQL + CSV + PowerShell)
that does not fit the NuGet conventions cleanly. See
[Release-Bundle-Pipeline.md](Release-Bundle-Pipeline.md) §3.

---

## 5. What promotion is (and is not)

**Promotion is** a metadata operation in ProGet:

```text
POST /api/promotions/promote
{
  "packageName":  "ATAP.Utilities.Philote",
  "version":     "0.1.0-Alpha.7",
  "fromFeed":    "nuget-development",
  "toFeed":      "nuget-integration",
  "reason":      "BuildMaster pipeline gate INT-PASS for build #4271"
}
```

ProGet copies the package bytes (or moves a feed-membership pointer,
depending on storage configuration) from the source feed to the target.
The package's SHA-256 is unchanged.

**Promotion is not** any of these:

- A new `dotnet pack` invocation.
- A new `Publish-PSResource` invocation.
- An MSBuild rerun.
- An NBGV `{height}` recomputation.
- A change to the `.nuspec`, `.psd1`, or release manifest.

If a higher-tier feed needs a "different" build, that is a **new release
unit** with a new version number — built from a new (or amended) release
branch tag, taking the same shape as any other build.

---

## 6. Versioning (no special-case for promotion)

NBGV computes the prerelease label and `{height}` from `version.json` **at
the Experimental stage only**. The resulting version string is captured
into a BuildMaster build variable (named `$ResolvedPackageVersion` in the
canonical OtterScript) and **read, not recomputed**, by every later
stage. NBGV is not invoked above Experimental. The label declares the
**intended** tier:

| Label         | Tier         | Where the artifact starts            |
| ------------- | ------------ | ------------------------------------ |
| `Sprint`      | Experimental | First push lands in `*-experimental` |
| `Alpha`       | Development  | Promoted from Experimental           |
| `Beta`        | Integration  | Promoted from Development            |
| `QA`          | QA           | Promoted from Integration            |
| _(none)_      | Production   | Promoted from QA                     |

The label is metadata on the artifact; the actual tier is the feed it
currently lives in. Both must agree before a deployment runs (the deployment
script asserts label↔feed consistency).

A consequence: the **same artifact** lives in the Experimental, Development,
Integration, QA, and Production feeds simultaneously while it is being
promoted. Each feed's listing is independent; the package's identity is
defined by `(PackageId, Version)`.

### 6.1 Where the captured version lives

| Surface | What it holds | Set by | Read by |
| --- | --- | --- | --- |
| BuildMaster build variable `$ResolvedPackageVersion` | full SemVer, e.g. `0.1.0-Sprint.42` | Experimental stage, after `nbgv get-version` | every later stage of the same release |
| The artifact's filename | same SemVer minus the `+<hash>` build metadata | `dotnet pack` / `New-PSModuleNupkg` at Experimental | promotion calls; tier gates |
| BuildMaster release record metadata | full SemVer + SHA-256 | Experimental stage's "attach package" step | audit / forensics |

### 6.2 Why this matters

Two pipeline runs in close succession against the same SHA can produce
the **same** `Sprint.{height}` but with different `+<gitshorthash>` build
metadata if the underlying tools see different working-tree states.
Because `+<hash>` is part of the SemVer 2.0 identity, two such packages
are different artifacts. Capturing the version once at Experimental and
reading it everywhere downstream is what makes "promote the artifact"
mean a single, identifiable thing. This is the rationale documented in
§12 of `CriticalAnalysisOfImmutableBuildStrategy.md` (the
`+<gitshorthash>` problem).

### 6.3 Resolving "latest in feed X"

Because the same artifact is promoted into multiple feeds (§5), a
floating reference resolved against any one feed sees promoted versions
alongside versions originally pushed there. The resolution rule:

> Under immutable build, "latest in feed X" means "highest version
> visible through feed X's resolution chain." A floating `0.*-*`
> reference will always pick up the highest version, regardless of
> whether that version was originally pushed to feed X or promoted into
> it. This is intentional — once promoted, the artifact has feed-X
> identity. Consumers who want "the latest version that has not yet been
> promoted out of feed X" must filter by prerelease label (e.g.
> `0.*-Sprint*`).

---

## 7. What changes in the Build/Pack/Push docs

The per-area docs (C# Build Process, C# Pack-and-Push, PowerShell Build
Process, etc.) describe the **once-per-release-unit** mechanics. They no
longer describe re-running pack/push at every tier; that section has been
removed or reframed as "tier gates: tests against the existing artifact."

When you read those docs, mentally locate any section that talks about a
"build at tier T" — that means "test the artifact at tier T," not "rebuild
the artifact." This doc is the authoritative explanation.

---

## 8. Branch behavior at sprint / feature boundaries

Pipelines are durable. They are **not** created or deleted per sprint or per
feature. What changes per sprint is metadata: prerelease suffixes, release
records in BuildMaster, and the worktree the build agent runs in.

| Boundary                          | Action on pipelines | Action on releases / metadata                                                  |
| --------------------------------- | ------------------- | ------------------------------------------------------------------------------ |
| Feature start                     | None                | BuildMaster creates a **new Release scoped to `$FeatureSlug`** (distinct from the trunk Release). `$FeatureSlug` is computed from the branch name per E-DEC-01 (PascalCase, ≤16 chars, derived from the `feature/` suffix). The first Experimental build produces `0.1.0-<FeatureSlug>.1`. Feature artifacts share the trunk feeds; the prerelease suffix provides isolation. |
| Feature in progress (each sprint) | None                | Feature artifacts are promoted through **all five tiers** under the feature suffix (`0.1.0-<FeatureSlug>.NNN`) using `Promote-ProGetPackage`. The **QA gate is required before merge to stable** — feature artifacts may be promoted to QA, but **no Production promotion** of feature artifacts is permitted until merge. DB migrations on the feature branch must be **additive-only** (no `ALTER COLUMN`, no `DROP`). |
| Sprint start                      | None                | Create a sprint release-train naming context; package versions inherit it.    |
| During sprint                     | None                | Each push triggers an Experimental build via the durable pipeline.            |
| Feature end / merge to stable     | None                | Before merge: **DB migrations are squashed and re-sequenced** to follow trunk's highest existing migration number (no gaps). `version.json` on trunk is updated so the prerelease label is **`Sprint`** (manual step, must precede the pipeline run). After merge, a **trunk Experimental build is triggered**; the first trunk artifact is `Sprint.NNN` where `NNN` resets to trunk's HEAD height. The **feature BuildMaster Release is archived**. The feature's `<FeatureSlug>.NNN` artifacts remain in feeds under their suffix but receive no further promotion. |
| Sprint end                        | None                | Cut a `release/*` branch from stable; build artifacts from the tag.           |
| Release cut                       | None                | Build the Release Bundle once from the release-branch tag; promote the same artifact through the five tiers. |
| _Full lifecycle details_          | _—_                 | _See [`Long-Developing-Features.md`](Long-Developing-Features.md) for the complete feature-branch lifecycle, version-string rules (E-DEC-01), sprint-slice interaction (E-DEC-02), feed targets (E-DEC-03), merge mechanics (E-DEC-04), and DB-compatibility rule (E-DEC-05)._ |

The single exception is the **first time** a new BuildMaster Application is
introduced (e.g., a brand-new component getting its own release-bundle
identity). That is a one-off configuration change, not a sprint-cadence
operation.

---

## 9. Where the old "buildpertier" pattern still appears (and what to do)

If you see any of these in the codebase, it is **legacy** and should be
treated as a documentation bug to fix:

- An OtterScript stage that calls `dotnet pack` after the Experimental stage.
- A "rebuild from source" step in a Development / Integration / QA / Production
  stage.
- A doc that describes "the version that lands in QA may differ from the
  version that landed in Integration."
- A `version.json` mutation in a non-Experimental stage.

The fix is always the same: replace the rebuild with a ProGet promotion
call (or a no-op, if the artifact is already in the target feed).

---

## 10. Related documents

- [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md)
  — the canonical C# pipeline (now expressed as immutable build + promotion).
- [Release-Bundle-Pipeline.md](Release-Bundle-Pipeline.md) — the new third pipeline.
- [Release-Branch-and-Manifest.md](Release-Branch-and-Manifest.md) — release-branch
  flow and manifest schema.
- [Database-Change-Unit-and-Flyway-Promotion.md](Database-Change-Unit-and-Flyway-Promotion.md)
  — DB change units and Flyway promotion.
- [BuildMaster-Pipeline-Topology.md](BuildMaster-Pipeline-Topology.md) — three
  pipelines, automation surface, ProGet-webhook integration.
- [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md) — version-label
  semantics that drive tier targeting.
- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — index.
