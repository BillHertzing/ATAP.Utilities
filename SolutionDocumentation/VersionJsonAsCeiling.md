# version.json as Promotion Ceiling

> Design document. Operational procedures live in the companion
> [VersionJsonAsCeiling-Runbook.md](VersionJsonAsCeiling-Runbook.md); the superseded analysis is
> archived at [ReviewedAndArchived/AnalysisOfVersionJsonAsCeiling.md](ReviewedAndArchived/AnalysisOfVersionJsonAsCeiling.md)
> (cross-links added 2026-07-06, Task 12.45.e).

**Status:** Sprint 0007 production-process requirement.

`version.json` no longer answers "which tier is this stage?" During a
BuildMaster run, the prerelease label answers "how high may this immutable
artifact be promoted?" The current stage comes from BuildMaster.

## Placement Policy — Per-Project `version.json`

**Decision (V4-D07, 2026-05-29):** every shippable unit owns a
project-adjacent `version.json` that resets the NBGV height origin to that
unit's directory. There is **no reliance on a repo-root `version.json`** for
ceiling resolution. `Get-BuildContext` invokes `nbgv` from the per-unit
directory and **throws** if that directory has no `version.json`, so the
ceiling for each artifact is always read from its own file rather than a
parent or root file (see [`Get-BuildContext.ps1`](../src/ATAP.Utilities.BuildTooling.PowerShell/public/Get-BuildContext.ps1)
and the "Throws when -ProjectPath lacks a project-adjacent version.json"
case in [`Get-BuildContext.Tests.ps1`](../src/ATAP.Utilities.BuildTooling.PowerShell/tests/Unit/Get-BuildContext.Tests.ps1)).

This table is the single source of truth for **where each kind of ceiling
lives**. All other versioning docs defer to it.

| Artifact kind          | `version.json` location                                              | Cmdlet that reads it            | Reference doc                                                  |
| ---------------------- | -------------------------------------------------------------------- | ------------------------------- | ------------------------------------------------------------- |
| C# package             | `src/<Project>/version.json` (adjacent to the `.csproj`)             | `Get-BuildContext`              | [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md) §4.5 |
| PowerShell module      | `<ModuleRoot>/version.json` (adjacent to the `.psd1`)               | `Get-BuildContext`              | [PowerShell-Modules-Versioning.md](PowerShell-Modules-Versioning.md) §6 |
| Database change package | `Database/<App>/version.json` (or `Database/<App>.<Stream>/version.json`) | `Get-DatabasePackageBuildContext` | `DatabaseVersioning.md` §1                                    |
| AceCommander packages  | `src/<Project>/version.json` per shipping project (same rule as ATAP.Utilities C#) | `Get-BuildContext`              | [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md) §9–§10 |

Notes:

- **ATAP.Utilities** carries only per-project files; it has no repo-root
  `version.json`. This is the target state for every repo.
- **AceCommander** still carries a redundant repo-root `version.json`
  alongside its per-project files. The per-project file wins, so the ceiling
  is correct today, but the root file is slated for removal (tracked under
  CSharp-Packages-Versioning.md §10 "Known Drift"). Do not add new reliance
  on it.
- A repo-root `version.json` is permitted only as a transitional NBGV default
  for not-yet-migrated projects; it is never the authority for any artifact a
  pipeline actually builds.

## Two Tier Concepts

| Concept       | Source                                                                       | Changes during one run? | Used for                                                          |
| ------------- | ---------------------------------------------------------------------------- | ----------------------- | ----------------------------------------------------------------- |
| `CurrentTier` | BuildMaster stage context (`$Tier`, `-Stage`, or stage environment variable) | Yes                     | Stage gating, test selection, source and destination feed choices |
| `CeilingTier` | NBGV prerelease label in `version.json`                                      | No                      | Skipping stages above the allowed promotion ceiling               |

`Get-BuildContext` now returns both values. Its legacy `.Tier` property is a
deprecated alias for `.CeilingTier` for the release that introduces this change;
callers should move to `.CeilingTier` or `.CurrentTier` explicitly.

## Ceiling Table

| `version.json` prerelease label                          | `CeilingTier`  |
| -------------------------------------------------------- | -------------- |
| `Sprint.N` or feature labels such as `PaymentRefactor.N` | `Experimental` |
| `Alpha`                                                  | `Development`  |
| `Beta`                                                   | `Integration`  |
| `QA`                                                     | `QA`           |
| none                                                     | `Production`   |

The documentation may still call the final public feed "stable" when referring
to ProGet feed names such as `nuget-stable`. The canonical BuildMaster tier name
in code is `Production`; `Stable` is accepted as an alias by promotion guards.

## Stage × Ceiling Matrix

Each row is a `version.json` prerelease label (which sets the ceiling tier).
Each column is a BuildMaster execution stage.
`✓` = stage executes; `–` = stage is skipped because it exceeds the ceiling.

| `version.json` label     | `CeilingTier` | Experimental | Development | Integration | QA  | Production |
| ------------------------ | ------------- | :----------: | :---------: | :---------: | :-: | :--------: |
| `Sprint` / feature label | Experimental  |      ✓       |      –      |      –      |  –  |     –      |
| `Alpha`                  | Development   |      ✓       |      ✓      |      –      |  –  |     –      |
| `Beta`                   | Integration   |      ✓       |      ✓      |      ✓      |  –  |     –      |
| `QA`                     | QA            |      ✓       |      ✓      |      ✓      |  ✓  |     –      |
| _(empty)_                | Production    |      ✓       |      ✓      |      ✓      |  ✓  |     ✓      |

The Experimental stage always executes; no ceiling ever skips it.
`IsAtCeiling` is `$true` in the rightmost ✓ column for each row.

## Edge Cases

| Scenario                                 | Behavior                                                                                                                                                                               |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Unknown label (e.g. `Canary`, `Sprnit`)  | `Get-CeilingFromPrereleaseLabel` returns `Experimental` — only the Experimental stage runs; the pipeline does not error.                                                               |
| Feature label (e.g. `PaymentRefactor.7`) | Treated as unknown → ceiling is `Experimental`. The numeric suffix is stripped before the switch.                                                                                      |
| `Stable` stage alias                     | `Get-CurrentTierFromStage` normalizes `Stable` → `Production`. `Test-PromotionWithinCeiling` accepts `Stable` as a synonym for `Production` in both `‑CurrentTier` and `‑CeilingTier`. |
| Empty / null prerelease label            | Ceiling is `Production`. All five stages execute. This is the requirement for a production-grade release candidate.                                                                    |
| Height-0 label-change commit             | NBGV emits `.g{shorthash}` (e.g. `Alpha.0.g1a2b3c4`). `Get-CeilingFromPrereleaseLabel` strips trailing `.g*` and height digits; ceiling resolves correctly.                            |
| Label case mismatch (`alpha` vs `Alpha`) | `Get-CeilingFromPrereleaseLabel` lower-cases before the `switch` — both are accepted identically.                                                                                      |
| Concurrent BuildMaster runs              | Each run uses a unique `$BuildMasterId(build)` subdirectory under `_generated/buildmaster/`; no cross-run clobbering.                                                                  |

## Vocabulary Map

| Term                        | Where it appears                                                | Meaning                                                                                                                                          |
| --------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| **CeilingTier**             | `version.json` prerelease label; `Get-BuildContext` output      | The highest tier this artifact may reach in one pipeline run. Set by the developer; resolved by `Get-CeilingFromPrereleaseLabel`.                |
| **CurrentTier**             | BuildMaster stage context; `Get-BuildContext` output            | The tier executing now. Comes from the stage's `-Stage` parameter or OtterScript `$Tier`. Resolved by `Get-CurrentTierFromStage`.                |
| **IsAtCeiling**             | `Get-BuildContext` output property                              | `$true` when `CurrentTier == CeilingTier`. Stages at the ceiling run their full logic; stages above the ceiling are skipped.                     |
| **ceiling label**           | `version.json` `"version"` field prerelease segment             | The prerelease portion of the NBGV version string (e.g. `Alpha`, `Beta`, `QA`, or empty). Does not change during a run.                          |
| **skip marker**             | `_generated/buildmaster/<id>/ceiling_skip_markers/<Stage>.skip` | A file written when a stage is skipped due to the ceiling. Aggregated into the `CeilingSkipMarkers` BuildMaster artifact for post-run diagnosis. |
| **immutable artifact**      | The `.nupkg` or universal package produced once in Experimental | Bytes never change across promotions. The same file (same SHA-256) is copied from feed to feed.                                                  |
| **promotion**               | `Promote-ProGetPackage` call                                    | Moving the immutable artifact from one feed to the next tier. Does not rebuild, re-stamp, or re-invoke NBGV.                                     |
| **cutting a new candidate** | Editing `version.json` + committing + triggering a new run      | Produces a new artifact with a new version number. Use this when you need to raise or change the ceiling.                                        |

## Developer Workflow

1. Edit the relevant project or module `version.json` to set the desired
   promotion ceiling for the next immutable artifact.
2. Commit the `version.json` change with the source changes that should produce
   that candidate.
3. Trigger the BuildMaster run.
4. The Experimental stage builds and publishes exactly one artifact.
5. Later stages promote the same package bytes through feeds until
   `Test-PromotionWithinCeiling` says the next stage would exceed the ceiling.

Example: a package built from `0.1-Beta.{height}` starts in Experimental,
promotes to Development, promotes to Integration, runs the Integration gate,
and skips QA and Production. No later stage rebuilds or re-evaluates NBGV.

During BuildMaster execution, the computed ceiling and resolved version are
persisted under the selected Option A run-state channel:

```text
_generated/buildmaster/<BuildMasterBuildId>/
```

`<BuildMasterBuildId>` comes from `$BuildMasterId(build)`. The plan-specific
preamble scripts write `build-context.json` plus temp files for current tier,
ceiling tier, resolved version, prerelease label, and allow/skip decisions.
Later stages read this build-id scoped state instead of flat
`_generated/buildmaster/*.tmp` files or BuildMaster runtime variables.

## Cmdlet Contract

`Get-BuildContext` returns:

- `CurrentTier`: the BuildMaster stage tier.
- `CeilingTier`: the promotion ceiling derived from `version.json`.
- `IsAtCeiling`: true when the current stage equals the ceiling.
- `Tier`: deprecated alias for `CeilingTier`.

`Test-PromotionWithinCeiling -CurrentTier <tier> -CeilingTier <tier>` is the
guard used by the Otter plans and by `Promote-ProGetPackage -CeilingTier`. It
returns `$true` for allowed promotions, and by default throws
`PromotionCeilingExceededException` before any ProGet API call when the
destination tier is above the ceiling.

See also:

- [Immutable Build Strategy](Immutable-Build-Strategy.md)
- [BuildMaster Pipeline Topology](BuildMaster-Pipeline-Topology.md)
- [C# Packages - Versioning](CSharp-Packages-Versioning.md)
- [PowerShell Modules - Versioning](PowerShell-Modules-Versioning.md)
