# Critical Analysis — Immutable Build Strategy Documentation Set

> **Archived 2026-07-06** (Sprint 0012 Task 12.45.e, documentation reorganization per
> `PlanDocumentationReorganization.md`). Superseded by `Immutable-Build-Strategy.md`.
> Retained as decision/analysis history; do not update.

**Reviewer persona:** Sharp-eyed principal developer. Slightly antagonistic.
Goal: make the SW production process better. Not interested in being polite
about defects that will burn junior devs.
**Reviewed on:** 2026-05-07
**Scope of review:** All files added or modified during the
Immutable-Build-Strategy sprint-7 documentation pass, plus the diagram set:

- New: `Immutable-Build-Strategy.md`, `Release-Bundle-Pipeline.md`,
  `Database-Change-Unit-and-Flyway-Promotion.md`,
  `Release-Branch-and-Manifest.md`, `BuildMaster-Pipeline-Topology.md`
- Updated: `Production-and-Tooling-Overview.md`,
  `BuildMaster-ProGet-CSharp-Package-Pipeline.md`,
  `CSharp-Packages-Build-Process.md`, `CSharp-Packages-Pack-and-Push.md`,
  `CSharp-Packages-Test-Process.md`, `CSharp-Packages-Versioning.md`,
  `CSharp-Central-Package-Management.md`,
  `PowerShell-Modules-Build-Process.md`,
  `PowerShell-Modules-Pack-and-Publish.md`,
  `PowerShell-Modules-Test-Process.md`,
  `PowerShell-Modules-Versioning.md`, `PowerShell-Script-Consolidation.md`
- Diagrams: `SWProductionDiagrams.drawio`
- Source of truth: `_Planning/Research/RawResearch/BuildPromotePipelineWithPerplexity.md`

**Status of this report:** Findings only. No edits applied. Intended to feed
a follow-on grooming pass that creates junior-level tickets.

---

## 0. Executive summary — the things you'll read this report twice for

1. **Ten of twelve "updated" docs ship a `> Strategy update (sprint-0007 — Immutable Build)` callout at the top, then leave the body of the document describing the **build-per-tier** pattern.** A junior dev will read the callout, scroll past it, and copy the body. The OtterScript sample in `BuildMaster-ProGet-CSharp-Package-Pipeline.md §5` is the highest-impact instance — it actually shows `dotnet pack` + `dotnet nuget push` inside Development, Integration, QA, and Production stages. **This is a defect, not a stylistic choice. It needs to be cleaned up before the docs ship.**
2. **NBGV vs immutable build is mathematically inconsistent and the docs hand-wave it.** NBGV's `{height}` is recomputed every time `nbgv get-version` runs. The docs say "version is computed once" without specifying the **mechanism** that captures the version at the Experimental tier and feeds it forward. Without that mechanism written down, two pipeline runs in close succession can produce two different `Sprint.{height}` versions for the same source SHA.
3. **The database-instance model is too coarse for a real dev team.** The doc set treats "Experimental DB" and "Development DB" as singletons. Reality with long-running features and multiple developers requires at minimum: per-developer scratch instance, per-feature-sprint instance, per-feature shared instance. The docs do not name these. The source-of-truth Perplexity file does not name these either — this is a **gap in the source of truth**, not just in the docs.
4. **Long-running feature branches are barely a footnote.** The branch model in `Release-Branch-and-Manifest.md §1` shows them in the diagram, but the lifecycle docs (Immutable-Build-Strategy, BuildMaster-Pipeline-Topology) talk almost exclusively about sprint cadence. A feature branch that spans 3–6 sprints with its own DB-change cadence is the messy real-world case and it is unaddressed.
5. **There is no single inventory of "manifest files that must live in your worktree."** Each doc names one or two; nobody has the checklist. Junior devs onboarding will not know which files to commit, where, when authoring a new module / app / DB change unit.
6. **The PowerShell module pipeline does not visibly produce a single immutable `.nupkg` artifact.** `Publish-PSResource` packs and publishes in one call, which obscures the artifact identity. The docs need to make the `.nupkg` an explicit, hash-able first-class object before promotion makes sense.
7. **The diagram set inherits the same defects.** Specifically: per-tier DB singleton, no feature-branch lane, OtterScript plan list does not flag legacy plans for rewrite.

---

## 1. NBGV ↔ immutable build inconsistency

### 1.1 The problem

The new docs assert (paraphrasing) "the version is computed once at
Experimental and stays the same through promotion." Mechanically this is
correct as a goal, but **none of the documents specify how that version is
captured and held**.

NBGV is a build-time tool. Calling `nbgv get-version` again on the same
commit returns the same string, but **only if the working-tree state is
clean and identical**. In a BuildMaster pipeline:

- The Experimental stage runs `nbgv get-version` to get
  `0.1.0-Sprint.42+8f4b2c1`.
- Subsequent stages, under the legacy buildpertier pattern, also run
  `nbgv get-version` against a fresh checkout. Same SHA → same answer →
  things appear to work.
- Under the immutable pattern, **higher stages don't checkout source at
  all**. They restore the existing `.nupkg` from the lower feed. So the
  question of "what version are we operating on" is answered entirely by
  the package's filename / metadata. The pipeline must read the version
  from the package, not from a re-invocation of NBGV. **The docs do not say this.**

### 1.2 Specific defects

| Doc | Problem |
| --- | --- |
| `Immutable-Build-Strategy.md` §6 | Says "Versioning is unchanged from sprint-0006." False. The mechanism for capturing and propagating the version through stages is new and unspecified. |
| `CSharp-Packages-Versioning.md` strategy callout | Says version "is computed once at the moment of build (Experimental tier)" but does not describe the build variable / artifact metadata that propagates it. |
| `CSharp-Packages-Versioning.md` §5 (Label Promotion Procedure) | Still describes a workflow where editing `version.json` and committing is "the promotion." Under immutable build that produces a NEW artifact, not a re-stamp. The strategy callout marks this as legacy but **the §5 procedure remains the primary explanation**. Junior devs will follow §5. |
| `PowerShell-Modules-Versioning.md` §7 | Same defect. "Promotion procedure (T1 → T2 example)" still says "edit version.json, commit, next nbgv get-version returns Alpha." This is now a contradiction with the strategy callout. |
| `BuildMaster-ProGet-CSharp-Package-Pipeline.md` OtterScript §5 | Each stage has its own `set $NbgvVersion = $Exec(nbgv get-version)`. Under immutable build, only Experimental should call NBGV. Higher stages should `set $NbgvVersion = $PromotedPackageVersion` (read from the artifact's filename or release-record metadata). |
| All docs | None of them name a build variable, application variable, or release-record field that holds the captured version for the lifetime of the release. |

### 1.3 Fix direction (do not implement; this is for the dev tasks)

- Add a section to `Immutable-Build-Strategy.md` (probably §6) titled
  **"Version capture and propagation"** that names the selected Option A
  per-build state folder (`_generated/buildmaster/<BuildMasterBuildId>/`) and
  states that the Experimental stage captures the resolved version there for
  later stages.
- Rewrite `CSharp-Packages-Versioning.md §5` and
  `PowerShell-Modules-Versioning.md §7` so the "promotion procedure" is
  **promote-the-artifact** (call `Promote-ProGetPackage`), not edit-and-rebuild.
  Move the edit-and-rebuild flow to a separate "Cutting a new candidate at
  the next tier" section that is explicit about being a *new release unit*.
- Change the OtterScript plan in `BuildMaster-ProGet-CSharp-Package-Pipeline.md §5`
  so only the Experimental stage calls NBGV; the others read from a build
  variable.

### 1.4 Source-of-truth gap

The Perplexity research file (`BuildPromotePipelineWithPerplexity.md`)
**does not address** how versioning interacts with promotion under
immutable build. It treats "promote the artifact" as the model but never
specifies that the version must be captured once and propagated. **This is a
real incompleteness in the source of truth.** A follow-on Perplexity
session should ask: "Under immutable build, where does the version live
between the build step and the promotion steps? In the package metadata?
In a separate release record? Both?"

---

## 2. Build-once immutability — the gap between callouts and bodies

### 2.1 The pattern

Every "updated" doc got a top-of-file `> Strategy update (sprint-0007 —
Immutable Build).` callout pointing at `Immutable-Build-Strategy.md`. The
callout asserts the new model. Then the body of the doc — sometimes
hundreds of lines — keeps describing the old build-per-tier model with
"legacy" notes scattered through.

This pattern is documentation debt, not documentation. **A doc whose body
contradicts its top-of-file rule is a doc that misleads on every page
view.** Junior devs (and most senior ones) read for the answer to a
specific question, not the framing callouts.

### 2.2 Specific defects

| Doc | Body content that contradicts the callout |
| --- | --- |
| `BuildMaster-ProGet-CSharp-Package-Pipeline.md` §5 | Full OtterScript plan with `dotnet build` / `dotnet pack` / `dotnet nuget push` in **every** stage. The §5 preamble says "this is legacy" but the OtterScript reads as a recipe. |
| `BuildMaster-ProGet-CSharp-Package-Pipeline.md` §8 | Repository monitor table maps each tier to a branch. Under immutable build, only the Experimental build is triggered by branch monitors — promotion is event-driven (gate pass, manual approval). The new caveat at the top of §8 acknowledges this but the table remains misleading. |
| `CSharp-Packages-Pack-and-Push.md` §7 | Feed table now says "Experimental only — others reached by promotion" in the header — good. But the body sections about pushing (§5, §6, §9) still describe `dotnet nuget push` as if it can target any feed. Need to make explicit: only `nuget-experimental` is a normal push target; pushing to higher feeds is an emergency override. |
| `PowerShell-Modules-Pack-and-Publish.md` §4 (tier-to-feed mapping) | Lists "Tier name → feed name" mapping that implies a publish call per tier. The strategy callout deprecates this but the table is still labeled as the canonical mapping. |
| `PowerShell-Modules-Pack-and-Publish.md` §10 (end-to-end developer publish) | Walks a developer through pack + push, but does not show the `Publish-PSModuleToProGet` (singular, no `-FeedTier` suffix) cmdlet that the strategy callout names. Names a non-existent / not-yet-implemented cmdlet implicitly. |
| `CSharp-Packages-Test-Process.md` §6.3 | The legacy "embed-into-nupkg" pattern is now documented as legacy, but the historical text is still presented as if it might be valid. Should be deleted or pushed into an appendix. |

### 2.3 Fix direction

- For each doc: do a body-pass, not just a callout-pass. Anywhere the body
  describes per-tier rebuild semantics, replace with promotion semantics.
  Mark as deprecated only if there is a forward-compat reason to keep the
  legacy text (rare).
- Rewrite the OtterScript sample in
  `BuildMaster-ProGet-CSharp-Package-Pipeline.md §5` end-to-end. The
  rewrite is small: ~60 lines of OtterScript. Worth doing properly.
- Delete the historical "embed test results in `.nupkg`" passage from
  `CSharp-Packages-Test-Process.md §6.3` rather than leaving it as
  pseudo-legacy.

---

## 3. PowerShell module immutability — pack vs publish ambiguity

### 3.1 The problem

PSResourceGet v3+'s `Publish-PSResource` packs **and** publishes in one
call. From the cmdlet's perspective there is no intermediate `.nupkg`
file artifact — it gets created in a temp dir and POSTed to the feed in
one operation.

Under immutable build, **the `.nupkg` is the artifact**. It must exist as
a file with a stable SHA-256 before it gets pushed, so that:

1. The same bytes can be promoted between feeds.
2. Test evidence can be attached to a specific `(Id, Version, SHA-256)`.
3. Identity verification (placeholder section) has something to sign.

### 3.2 Specific defects

| Doc | Defect |
| --- | --- |
| `PowerShell-Modules-Pack-and-Publish.md` §1 | Says "In modern PowerShellGet (PSResource v3+), pack and push are bundled in one `Publish-PSResource` invocation. We do not run a separate `nuget pack` step." This is the wrong model for immutable build. Pack must produce a file; push uploads that file. |
| `PowerShell-Modules-Pack-and-Publish.md` §10 | The walk-through uses `Publish-PSResource -Path $pkgFolder -Repository ...` which packs-and-publishes. Should use `-NupkgPath` only, after a separate explicit pack step. |
| `PowerShell-Modules-Build-Process.md` §7 | The end-to-end flow does not include an explicit "pack to .nupkg" step. Goes from "build .psm1 + .psd1" straight to "publish to ProGet." The .nupkg file is produced as a side effect of `Publish-PSResource` and never named. |
| `BuildMaster-Pipeline-Topology.md` §4 | Names `Publish-PSModuleToProGet` (drops `-FeedTier`) but does not specify that this cmdlet must produce a `.nupkg` file first and then upload it. The cmdlet does not yet exist; its specification should make the file-first pattern mandatory. |

### 3.3 Fix direction

- Add a `New-PSModuleNupkg` cmdlet to the spec'd cmdlet inventory in
  `BuildMaster-Pipeline-Topology.md §4`. Its only job is: take the built
  module folder, produce a `.nupkg` file at a specified path. No upload.
- `Publish-PSModuleToProGet` should accept only `-NupkgPath` (no
  `-Path` for a folder). It uploads the named file. The file's SHA-256 is
  the artifact identity.
- Rewrite `PowerShell-Modules-Pack-and-Publish.md §10` (end-to-end
  developer publish) to show the two-step pattern explicitly.
- Add to the immutability strategy doc: "PowerShell modules are packed to a
  `.nupkg` on disk before any push. The module's identity is the
  `(ModuleId, Version, SHA-256)` of that file."

### 3.4 Source-of-truth gap

The Perplexity research file is silent on PSResourceGet's pack-and-publish
behavior. It treats PowerShell modules and NuGet packages as
operationally symmetric. They are not. **This is a gap in the source of
truth** — the research conversation never went deep on the mechanics of
`Publish-PSResource` vs `dotnet nuget push`.

---

## 4. Manifest / source-of-truth files that must live in worktrees

### 4.1 The problem

The new docs introduced several new file-shaped concepts:

- The release manifest (`manifest.json` inside the bundle).
- The DB sub-manifest (`db-manifest.json` inside the bundle).
- The DB change unit YAML (`db/<App>/releases/<x.y.z>.yml`).
- The Release Bundle directory layout (`app/`, `db/`, `installer/`, `tests/`).

…on top of the existing source-of-truth files:

- `version.json` per project, per module, and at repo root (NBGV).
- `Directory.Packages.props` (CPM).
- `Directory.Build.props` / `Directory.Build.targets`.
- `NuGet.config`.
- `<ModuleName>.psd1` (template manifest) per module.
- `version.schema.json` reference (linked from version.json).
- BuildMaster OtterScript plans (under `src/.../Plans/`).

**There is no single doc that lists which files are source-of-truth (live in
git), which are generated (live in `_generated/`), and where each one must
be authored.** Each new doc names two or three. The PSModule source-of-truth
files are explained in Build-Process; CPM's are in CPM doc; DB ones are in
Database-Change-Unit; Release Bundle's are partly in Release-Bundle-Pipeline
and partly in Release-Branch-and-Manifest.

A junior dev onboarding to author their first new feature-bundle will hunt
across 5+ docs to figure out what to commit and where.

### 4.2 Specific gaps

- No checklist for "I'm starting a new C# package — what files must I author and where?"
- No checklist for "I'm starting a new PowerShell module — what files must I author and where?"
- No checklist for "I'm starting a new Release Bundle — what files must I author and where?"
- No checklist for "I'm cutting a release branch — what files must I edit and where?"
- The release-branch flow in `Release-Branch-and-Manifest.md §2` skips the question of which files in source change as part of cutting / hardening / tagging.

### 4.3 Fix direction

Create a new doc: `Worktree-Source-of-Truth-Inventory.md`. Single page,
table form:

| File / pattern | Lives in (path) | Authored by | When created | When edited | Generated counterpart |
| -------------- | --------------- | ----------- | ------------ | ----------- | --------------------- |
| `version.json` (repo root) | repo root | dev | new repo | when bumping major/minor | (none — pure source) |
| `version.json` (per project) | adjacent to .csproj | dev | new project | when bumping label between releases | (none) |
| `version.json` (per PS module) | adjacent to .psd1 | dev | new module | label change between releases | (none) |
| `<ModuleName>.psd1` (authored template) | `src/<Module>/` | dev | new module | when adding RequiredModules / FormatsToProcess | `_generated/.../packages/<Module>/<Module>.psd1` (stamped) |
| `Directory.Packages.props` | repo root | dev | new repo | every package add / version bump | (none) |
| `Directory.Build.props` / `.targets` | repo root | dev | new repo | rare | (none) |
| `NuGet.config` | repo root | dev / sprint start | new repo | feed topology change | (none) |
| `db/<App>/<flyway,seed>/*` | `db/<App>/` | dev | new schema/seed change | per migration | (copied into bundle's `db/`) |
| `db/<App>/releases/<x.y.z>.yml` | `db/<App>/releases/` | release engineer | release-branch cut | rare (corrections) | drives `db-manifest.json` generation |
| OtterScript plan files | `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/` | build-tooling owner | new pipeline | rare | (loaded into BuildMaster) |
| BuildMaster per-run state | `_generated/buildmaster/<BuildMasterBuildId>/` | BuildMaster preamble scripts | generated per BuildMaster build | generated / cleaned by retention policy | temp files plus `build-context.json`; never source-controlled |
| `manifest.json` | (none in source — bundle root) | `New-ReleaseManifest` | (generated) | (generated) | THIS IS the generated artifact |
| `db-manifest.json` | (none in source — bundle's `db/`) | `New-ReleaseManifest` | (generated) | (generated) | generated artifact |

Then the per-area docs link to this inventory rather than each repeating
their slice.

Risk note for the BuildMaster per-run state row: Option A assumes every stage
in the same BuildMaster build sees the same `_generated/buildmaster/<BuildMasterBuildId>/`
folder. If stages use clean workspaces or different agents, the pipeline must
transfer that folder as an artifact or move the state channel to shared storage.

### 4.4 Source-of-truth gap

The research file does not enumerate source files at all. It is a strategy
document, not an implementation one. The inventory above is **net-new** —
the docs need to invent it. Note in the inventory that it is derived
analysis, not lifted from research.

---

## 5. Long-developing features — barely addressed

### 5.1 The problem

The branch model assumes a sprint as the basic unit of work. Real
software has long-running features that span many sprints, often with
dedicated dev teams, feature flags, and their own DB-change cadence
that diverges from the trunk.

The new docs mention `feature/<long-running>` in the branch diagram but do
not discuss:

- How the version string is shaped on a feature branch that spans 3+ sprints.
- Whether the feature branch gets its own ProGet feed (the answer is "no — it gets a prerelease suffix on the experimental feed") and what the prerelease suffix shape is.
- How sprint slices off a feature branch (`sprint/<feature>-<NNNN>`) interact with the feature branch's own version space.
- How a feature branch's DB changes are kept compatible with stable's DB while the feature is unmerged.
- How the feature branch is merged to stable when the feature is large and DB-touching.
- How testing is gated on a long-running feature branch (does it use the same five tiers? Or does it skip Production until merged?).

### 5.2 Specific defects

| Doc | Defect |
| --- | --- |
| `Immutable-Build-Strategy.md` §8 | "Branch behavior at sprint / feature boundaries" table only lists "Feature start" and "Feature end" with one-line entries. Says nothing about feature *life*. |
| `BuildMaster-Pipeline-Topology.md` §8 | Identical table. Same gap. |
| `Release-Branch-and-Manifest.md` §1 | Branch-model diagram shows the feature branch but the body of the doc is entirely about release branches. No discussion of feature → stable merge mechanics for a DB-touching feature. |
| `Database-Change-Unit-and-Flyway-Promotion.md` §6 | "Backward / forward compatibility rules" implies but does not say: feature branches with DB changes should keep their migrations in additive-only form so they don't break the trunk's existing prod DB if reordered at merge. This is a real risk and needs to be explicit. |
| All docs | No mention of how a feature branch's BuildMaster Releases (the `Release` records) are scoped. Does each feature branch get its own Release, with its own promotion history? Does it share the trunk's Release? |

### 5.3 Fix direction

Write a new top-level doc: `Long-Developing-Features.md`. Cover:

1. Version shape on the feature branch (prerelease suffix per
   feature, e.g. `0.1.0-FeatA.NNN` where NNN is the feature's own height).
2. Whether sprint slices on the feature get their own suffix
   (`0.1.0-FeatA-S07.NNN`) or inherit the feature's.
3. ProGet feed targets for feature builds (Experimental only, full stop).
4. DB-change compatibility rules on the feature branch (additive-only
   until merged; rebase plan when prod schema moves underneath).
5. Merge mechanics: feature → stable, what happens to the version label,
   how DB migrations get re-numbered or kept-in-order.
6. Whether feature builds participate in promotion (no; promotion is for
   trunk and release branches only; feature builds stay in Experimental
   under their suffix).
7. How feature integration testing is run (likely a separate "feature-QA"
   set of validations that does not consume a tier slot).

### 5.4 Source-of-truth gap

The Perplexity research file does discuss feature branches but it stays
abstract. The implementation specifics (suffix shape, migration
re-numbering at merge, feature's relationship to the five-tier promotion
ladder) are not in the research and need to be designed. **This is a
non-trivial design gap.** A follow-on design conversation is required
before the doc above can be written.

---

## 6. Database instances — the per-developer / per-feature gap

### 6.1 The problem (largest gap in the set)

The current `Database-Change-Unit-and-Flyway-Promotion.md §5` tier table
implies one DB instance per tier:

| Tier | DB |
| ---- | --- |
| Experimental | empty database assigned to the logical Experimental role (`localhost\EXPWHERTZING` in this worktree) |
| Development | small dev fixture DB |
| Integration | snapshot of previous-prod DB |
| QA | QA Gold DB |
| Production | customer DB |

> **Historical terminology correction (2026-08-08):** `Experimental` is a
> logical role, not a physical SQL Server instance name. Developer-scoped
> instances follow `Exp<DeveloperName>`; `EXPWHERTZING` is the instance for
> developer `whertzing`. The original wording above must not be used to justify
> provisioning an instance named `Experimental`.

This is suitable for a 1-developer, 1-feature, 1-sprint world. It breaks
in any of these scenarios:

- Two developers running Experimental builds simultaneously (their
  Flyway runs collide).
- A long-running feature branch that needs its own DB to evolve schema
  separately from trunk for weeks.
- A sprint slice off a feature, where the developer wants their own scratch
  DB to iterate without disturbing the feature's shared DB.
- A pipeline run for trunk's Experimental tier in parallel with a pipeline
  run for the feature branch's Experimental tier.

Per the user's prompt for this review: the team likely needs at least
**a feature instance and a feature-sprint instance for each developer at
the Experimental and Development tiers.** That is significantly more
infrastructure than the current docs imply.

### 6.2 Inventory of DB instance types — proposed

Below is a proposal to be discussed and confirmed, not adopted as-is.

| Instance type | Lifetime | Cardinality | Tier(s) it supports | Notes |
| ------------- | -------- | ----------- | ------------------- | ----- |
| **Per-developer scratch** | Ephemeral; created on demand, destroyed on sprint end | 1 per (developer × repo × sprint) | Experimental | Owned by the developer. Used for sprint-line iteration. |
| **Per-feature-sprint** | Ephemeral; one feature × one sprint slice | 1 per (feature × sprint × developer) | Experimental | When a feature has multiple devs working in parallel sprint slices, each gets one. |
| **Per-feature shared** | Persistent for life of feature branch | 1 per feature | Development | Shared by the feature team. Used for cross-developer integration on the feature. |
| **Trunk Development** | Persistent | 1 per repo | Development | Reflects the latest stable + currently-in-flight Alpha. |
| **Trunk Integration** | Persistent (rotating snapshot) | 1 per repo | Integration | Restored from latest Production backup before each Integration run; should be rotated per pipeline run, not shared. |
| **Trunk QA Gold** | Persistent | 1 per repo | QA | Anonymized prod-shaped data. |
| **Customer Production** | Permanent | N (one per customer install) | Production | Lives in customer environments. |

The current docs name only the four singletons in the right-hand column.
The five-row left-hand column is **missing**, and represents the bulk of
the day-to-day database surface area.

### 6.3 Specific defects

| Doc | Defect |
| --- | --- |
| `Database-Change-Unit-and-Flyway-Promotion.md` §5 | Treats Experimental and Development as having one DB each. Breaks in real teams. |
| `Database-Change-Unit-and-Flyway-Promotion.md` §11 | Resolved 2026-05-12: `Invoke-FlywayRehearsal` now creates a uniquely named per-run rehearsal DB and drops it in `finally`. |
| `Release-Bundle-Pipeline.md` §5 | Tier-stage table implies single DB per tier ("Apply DB migrations against a snapshot of the previous-prod database"). Singular. Should be plural. |
| `SWProductionDiagrams.drawio` page 02 | Five DB cylinders, one per tier. Same defect, visually. |
| Docs in general | No mention of provisioning, naming convention, or lifecycle for the per-developer / per-feature DB instances. |

### 6.4 Fix direction

This is a multi-step deliverable, not a one-doc fix:

1. Design conversation: confirm or adjust the proposed DB instance type
   inventory in §6.2 above.
2. Naming convention spec: e.g.
   `<App>_<branch-or-feature>_<sprint-or-tag>_<developer>` — needs to be
   short enough for SQL Server's 128-char DB name limit.
3. Provisioning script: `New-DeveloperScratchDb`, `New-FeatureSharedDb`,
   `Remove-DeveloperScratchDb`, and `Remove-FeatureSharedDb`. Implemented
   2026-05-12 in
   `ATAP.Utilities.DatabaseManagement.Powershell` (already exists per
   PowerShell-Modules-Build-Process.md).
4. Lifecycle hooks: SprintStartAgent / SprintEndAgent / FeatureStart /
   FeatureEnd should provision/de-provision the right instances.
5. Update `Database-Change-Unit-and-Flyway-Promotion.md §5` table.
6. Update `SWProductionDiagrams.drawio` page 02 to show per-developer and
   per-feature instances at the Experimental / Development tiers.
7. Update `Release-Bundle-Pipeline.md §5` to reflect that pipeline runs
   target ephemeral DB instances, not shared ones.
8. Add an entry to the "manifest files in worktree" inventory (§4 of this
   report) for `db/<App>/instance-shapes.yml` if such a config is needed.

### 6.5 Source-of-truth gap

The research file says nothing about per-developer or per-feature DB
instances. This is **the largest gap in the source of truth**. The
research treats DB content (migrations + seed) as a release-shaped concern
and never addresses the operational question of where the migrations
actually run during dev. A follow-on design conversation is required.

---

## 7. Diagram set inconsistencies

### 7.1 Specific defects in `SWProductionDiagrams.drawio`

| Page | Defect |
| ---- | ------ |
| 01 (ProGet channels) | Uses both T1–T5 and Experimental-Production labels in different cells; no defect, but mark T1–T5 as the secondary label or drop it. |
| 02 (Databases) | Per-tier DB singleton (per §6 above). Major defect. |
| 02 | Source documentation footer points to `_Planning/Explainers/0021-sql-server-backup-proget-buildmaster.md` but the doc title is slightly different in the live tree — verify path. |
| 03 (PSModule production) | Last cell says "Pack via Publish-PSResource" with a single arrow into `nupkg`. Per §3 of this report, this conflates pack and publish. Should show an explicit "Pack" cmdlet step producing the `.nupkg`, then a separate "Push" arrow. |
| 04 (Test attach) | Says "test results attach to the same release record" — correct, but does not show the `(Id, Version, SHA-256)` binding. Should add that triple as a label on the artifact box. |
| 04 | The legacy "embed in nupkg" pattern is not shown as legacy at all. There is no contrast between attached vs embedded. Could be improved. |
| 05 (BuildMaster catalog) | Lists `CSharpPackage-5Stage.otter` and friends as if they exist in their final form. Does not flag that the current OtterScript is the legacy build-per-tier shape that needs rewriting. Should add an asterisk + footer note. |
| 05 | The "Releases" card at the bottom right says "per Application" — true, but does not show how a release on a feature branch interacts with a release on stable. |
| 06 (QA testing) | `Invoke-PerformanceSuite` is listed as a cmdlet but does not exist yet. Same for `Invoke-BUnitTests`, `Invoke-PlaywrightE2E`, `Invoke-BundleInstallSmoke`, `Attach-TestResultsToBuildMasterRelease`. **Diagram lists multiple cmdlets that need to be implemented.** Footer note should call them out or the diagram should mark them with "(spec)". |
| 07 (Consumers) | C# consumer lane shows `dotnet restore` against ProGet directly. Doesn't show the package-source-mapping decision (which feed for which package pattern). Minor. |
| 07 | End-user lane: `Install-Application.ps1` has 5 numbered steps. Step 1 says "verify checksums in manifest.json" but the placeholder section (page 9) says checksum verification is not yet implemented. Internal contradiction. |
| 08 (Updates) | C# update lane says "or restore picks up floating 0.*-* automatically." This is the consumer side and it's fine, but doesn't cross-link to the pinning-rule constraint at T3+. Minor. |
| 08 | Does not show what happens during update if the consumer is currently running with a feature-branch prerelease and the update target is a stable version. Edge case but real. |
| 09 (Identity verification placeholder) | Lists candidate mechanisms — good. But does not list the *current* state ("today: nothing; SHA-256 in manifest is calculated but not verified by the installer"). Should make the today-state explicit. |
| All pages | Footer style is fine but the cell IDs (`srcdocs-01`, `srcdocs-02` etc.) are inconsistent with the rest of the diagram's ID scheme — minor. |

### 7.2 Fix direction

- Add an "AS-OF" date to each diagram so a reader knows whether it's
  current.
- Mark all not-yet-implemented cmdlets and tools in diagram 06 with
  "(spec)" or similar.
- Page 02 needs the per-developer / per-feature DB layer.
- Page 03 needs the explicit Pack → Push split.
- Page 09's "today" state needs to be explicit so readers don't assume
  identity verification is partially in place.

---

## 8. Cross-cutting issues

### 8.1 Tier name inconsistency

Some docs use `T1, T2, T3, T4, T5`; others use `Experimental, Development,
Integration, QA, Production`; others use `Sprint, Alpha, Beta, QA, (none)`
for NBGV labels. Three vocabularies for the same five things. The
Production-and-Tooling-Overview note says the 5-tier names + the NBGV
labels are the canonical pair, and T1-T5 should be retired. The retirement
hasn't happened in:

- `CSharp-Packages-Versioning.md` (T1–T5 in §3)
- `PowerShell-Modules-Versioning.md` (T1–T5 in §5)
- Other docs

Pick one (the 5-tier names) and replace.

### 8.2 The "Sprint-7 strategy callout" pattern is itself a code smell

Adding a `> Strategy update` block to 12 docs and not rewriting the
bodies is a pattern that scales badly. By Sprint 9 there will be a
`> Strategy update (sprint-0009)` block on top of the
`> Strategy update (sprint-0007)` block. Rewrite the bodies, then drop
the callout into a one-line "see Immutable-Build-Strategy.md" pointer.

### 8.3 `Production-and-Tooling-Overview.md` claims the new docs are "written"

> 2026-05-11 update: this finding is partially resolved. Stream I implemented
> `New-ReleaseManifest`, `New-ReleaseBundle`, `Get-DeployedReleaseManifest`,
> and `Compare-ReleaseManifest`; `Production-and-Tooling-Overview.md` now calls
> out the mixed implementation state instead of treating those Stream I cmdlets
> as stubs. The Chocolatey and WinGet distribution cmdlets remain spec work.

The §2.0 row I added says all 5 new strategic docs are "written" with a
checkmark. They are written, but several areas described behavior that the code
did not yet implement at the time of the analysis. As of the 2026-05-11
Stream I pass, release manifest and bundle assembly tooling is implemented;
the remaining clear examples are distribution hooks such as
`Publish-ChocolateyRelease` and `Update-WinGetManifestSource`.
**A junior dev reading the index will assume the system works as
described.** The status column needs a third value: "spec — not
implemented."

### 8.4 The PowerShell automation surface in `BuildMaster-Pipeline-Topology.md §4` lists ~12 cmdlets

> 2026-05-11 update: this finding is partially resolved. The topology doc now
> has a current cmdlet inventory, and the four Stream I release-bundle cmdlets
> are exported from `ATAP.Utilities.BuildTooling.PowerShell`.

Of those, by my count, **at least 8 are not yet implemented**. Diagram 06
shows them being called. There is no master tracking doc that says which
exist and which are spec. Should be added (or it's a TASKS.md update).

---

## 9. Source-of-truth incompleteness — consolidated note

Areas where the Perplexity research file (`BuildPromotePipelineWithPerplexity.md`)
**does not provide guidance** and the new docs had to invent or infer:

1. **Version capture and propagation under immutable build (§1.4 above).**
   The research talks about promotion; doesn't address how the version
   captured at build time flows through promotion stages.
2. **PSResourceGet pack-and-publish ambiguity (§3.4 above).** The research
   treats PowerShell modules and NuGet packages as symmetric and never
   gets into the cmdlet mechanics.
3. **Long-developing features (§5.4 above).** Research mentions feature
   branches but doesn't address the implementation specifics.
4. **Per-developer / per-feature DB instances (§6.5 above).** The largest
   gap. Research treats DB content as a release concern only, never as an
   operational dev-environment concern.
5. **Identity verification of distributed packages (placeholder).**
   Research doesn't address. Acknowledged as a placeholder section.
6. **Rollback for code-only releases.** Research discusses DB rollback
   ("backup-restore"); doesn't address what happens when an end user does
   `choco upgrade` to a bad code-only release. Is `choco install --version
   <prev>` the official downgrade path? Does the installer support
   downgrade? The docs don't say.
7. **How sprint-specific BuildMaster releases interact with the "no
   per-sprint pipeline" rule.** Research says no per-sprint pipelines;
   doesn't say how the sprint context is recorded in BuildMaster
   metadata.
8. **WinGet community vs private REST source** — research mentions both
   but doesn't pick one. The new docs hedge with "either."

A recommended action is a **second Perplexity research session** focused
on items 1, 2, 3, 4, and 6. Items 5, 7, and 8 are smaller and can be
designed in-house.

---

## 10. Suggested junior-level tickets

Cut from the findings above. Each is sized for a single dev × 1–3 days.

### Documentation-only tickets

| ID | Title | Source finding | Effort |
| -- | ----- | -------------- | ------ |
| DOC-7-01 | Rewrite OtterScript sample in `BuildMaster-ProGet-CSharp-Package-Pipeline.md §5` to immutable-build shape (only Experimental builds; others promote + test). | §2.2 | M |
| DOC-7-02 | Replace `CSharp-Packages-Versioning.md §5` with an immutable-build-correct promotion procedure. | §1.2 | M |
| DOC-7-03 | Replace `PowerShell-Modules-Versioning.md §7` similarly. | §1.2 | S |
| DOC-7-04 | Delete or appendix-ize the legacy "embed-in-nupkg" passage in `CSharp-Packages-Test-Process.md §6.3`. | §2.2 | XS |
| DOC-7-05 | Write `Worktree-Source-of-Truth-Inventory.md` (single table doc). | §4.3 | M |
| DOC-7-06 | Write `Long-Developing-Features.md` (after a design conversation per §5.4). | §5.3 | L |
| DOC-7-07 | Update `Database-Change-Unit-and-Flyway-Promotion.md §5` with the per-developer / per-feature DB instance table (after design conversation per §6.5). | §6.4 | L |
| DOC-7-08 | Add "Version capture and propagation" section to `Immutable-Build-Strategy.md §6`. | §1.3 | M |
| DOC-7-09 | Standardize tier vocabulary across all docs (delete T1–T5 in versioning docs). | §8.1 | S |
| DOC-7-10 | Add "spec — not implemented" status to `Production-and-Tooling-Overview.md §2.0` for stub cmdlets. | §8.3 | S |
| DOC-7-11 | Add a master cmdlet inventory doc (or TASKS.md section) showing implemented vs spec for the 12+ cmdlets in `BuildMaster-Pipeline-Topology.md §4`. | §8.4 | M |

### Diagram tickets

| ID | Title | Source finding | Effort |
| -- | ----- | -------------- | ------ |
| DIAG-7-01 | Add per-developer / per-feature DB instance lane to `SWProductionDiagrams.drawio` page 02. | §7.1 | M |
| DIAG-7-02 | Split Pack and Push into two explicit steps in `SWProductionDiagrams.drawio` page 03. | §7.1 | S |
| DIAG-7-03 | Add `(Id, Version, SHA-256)` binding label to the artifact box in `SWProductionDiagrams.drawio` page 04. | §7.1 | XS |
| DIAG-7-04 | Mark unimplemented cmdlets in `SWProductionDiagrams.drawio` page 06 with "(spec)" or similar. | §7.1 | S |
| DIAG-7-05 | Add "today: nothing implemented" annotation to `SWProductionDiagrams.drawio` page 09 placeholder. | §7.1 | XS |
| DIAG-7-06 | Add long-developing-feature lane to one of the diagrams (likely a new page 10 or a column in page 05). | §5.3 | M |

### Implementation tickets (driven by doc gaps)

| ID | Title | Source finding | Effort |
| -- | ----- | -------------- | ------ |
| IMPL-7-01 | Implement `New-PSModuleNupkg` cmdlet (split out from `Publish-PSResource`). | §3.3 | M |
| IMPL-7-02 | Refactor `Publish-PSModuleToProGet` to take only `-NupkgPath`. | §3.3 | S |
| IMPL-7-03 | Implement `Promote-ProGetPackage` cmdlet (idempotent ProGet promotion API call). | §1.3, §2.3 | M |
| IMPL-7-04 | Implement `New-ReleaseManifest` cmdlet. Completed 2026-05-11; it now emits `manifest.json` plus the DB sub-manifest sidecar. | §8.3 | done |
| IMPL-7-05 | Implement `New-ReleaseBundle` cmdlet. Completed 2026-05-11; it now stages `db/db-manifest.json`, requires manifest-referenced assets, and packs `.upack`. | §8.3 | done |
| IMPL-7-06 | Implement `Invoke-FlywayRehearsal` rotation so each pipeline run uses a uniquely-named rehearsal DB. Completed 2026-05-12. | §6.3 | done |
| IMPL-7-07 | Implement `New-DeveloperScratchDb` / `New-FeatureSharedDb` / removal counterparts in `ATAP.Utilities.DatabaseManagement.Powershell` (after design per §6.5). Completed 2026-05-12. | §6.4 | done |
| IMPL-7-08 | Capture-and-propagate version through Option A per-build state folder (`_generated/buildmaster/<BuildMasterBuildId>/`). | §1.3 | M |

### Source-of-truth tickets

| ID | Title | Source finding | Effort |
| -- | ----- | -------------- | ------ |
| SOT-7-01 | Run a follow-on Perplexity (or equivalent) session covering: NBGV under immutable build; PSResourceGet split; long-running features; per-developer DB instances; rollback for code-only releases. Capture the output to a new research file under `_Planning/Research/RawResearch/`. | §9 | M |
| SOT-7-02 | After SOT-7-01, update `Immutable-Build-Strategy.md` and the affected per-area docs with the resolved guidance. | §9 | varies |

---

## 11. What I would do first if I were the dev lead

In order:

1. **DOC-7-04** (delete legacy embed-in-nupkg passage). 30 minutes. Removes
   a junior-dev foot-gun.
2. **DOC-7-05** (worktree source-of-truth inventory). Half a day. Unblocks
   onboarding.
3. **DOC-7-08** (version capture and propagation section). Half a day.
   Closes the largest doc-vs-reality gap.
4. **DOC-7-01** (rewrite OtterScript sample). One day. Stops junior devs
   copying the wrong pattern.
5. **SOT-7-01** (research session for the gaps). One pairing session.
   Required before the long-developing-features and DB-instance docs can
   be written.
6. **IMPL-7-08** + **IMPL-7-03** in parallel. Mid-priority but they make
   the strategy doc actually executable.
7. Then the design conversation for §6 (DB instances), then DOC-7-07 and
   DIAG-7-01.

Items I would defer past sprint-7:

- The identity verification work (placeholder is fine for now; design it
  separately).
- WinGet community vs private REST decision (depends on org-wide
  packaging strategy that doesn't need to be settled this sprint).
- Diagram-only polish (DIAG-7-03, DIAG-7-05).

---

## 12. One question I would push back on

The strategy doc says "Build a release unit exactly once. Promote that exact
artifact, byte for byte, through the five tiers." Then the `.nupkg`
metadata embeds an NBGV-generated `+<gitshorthash>` build-metadata segment.
That string is produced from `git rev-parse --short HEAD` at build time. If
the developer's local git state is in any way different from what BuildMaster
sees (uncommitted files, different short-hash truncation rules, dirty-flag
suffix), the `+<hash>` will differ between developer-local builds and
BuildMaster builds even on the same commit. **Two artifacts with the same
SemVer base but different `+<hash>` are different artifacts under SemVer 2.0.**

Implication: a developer's `dotnet pack` output is **not** the same artifact
as what BuildMaster eventually publishes. Anybody who tested locally and
then pushed expecting the same bytes will be wrong.

The docs do not call this out. Should at least be mentioned in
`CSharp-Packages-Versioning.md §2.3` and the equivalent PowerShell doc.

---

*End of report. No file changes applied.*
