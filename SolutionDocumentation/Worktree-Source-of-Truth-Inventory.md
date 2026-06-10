# Worktree Source-of-Truth Inventory

**Scope:** Files that must live in a developer's git-tracked worktree
to support the Immutable Build pipeline. Distinguishes source-of-truth
files (committed) from generated artifacts (under `_generated/`).
**Audience:** Junior devs starting a new project, module, DB change
unit, or release branch.
**Status:** Authoritative for sprint-0007.

---

## 1. The two categories

- **Source-of-truth.** Lives in git. Authored by humans (or by tooling
  that writes into the source tree). Examples: `version.json`,
  `Directory.Packages.props`, `db/<App>/releases/<x.y.z>.yml`.
- **Generated.** Lives under `_generated/` per rule SC-0033. Never
  committed. Re-creatable from source-of-truth + tooling. Examples:
  `manifest.json`, `db-manifest.json`, `<Module>.psm1` (consolidated),
  `.nupkg`, `.upack`.

---

## 2. The full inventory

| File / pattern | Lives at (path) | Authored by | When created | When edited | Generated counterpart |
| -------------- | --------------- | ----------- | ------------ | ----------- | --------------------- |
| `version.json` (repo root) | repo root | dev | new repo | when bumping major/minor | (none — pure source) |
| `version.json` (per project) | adjacent to `.csproj` | dev | new project | when bumping label between releases | (none) |
| `version.json` (per PS module) | adjacent to `.psd1` | dev | new module | label change between releases | (none) |
| `<ModuleName>.psd1` (authored template) | `src/<Module>/` | dev | new module | when adding RequiredModules / FormatsToProcess | `_generated/.../packages/<Module>/<Module>.psd1` (stamped) |
| `Directory.Packages.props` | repo root | dev | new repo | every package add / version bump | (none) |
| `Directory.Build.props` / `Directory.Build.targets` | repo root | dev | new repo | rare | (none) |
| `NuGet.config` | repo root | dev / sprint start | new repo | feed topology change | (none) |
| `db/<App>/<flyway,seed>/*` | `db/<App>/` | dev | new schema/seed change | per migration | (copied into bundle's `db/`) |
| `db/<App>/releases/<x.y.z>.yml` | `db/<App>/releases/` | release engineer | release-branch cut | rare (corrections) | drives `db-manifest.json` generation |
| OtterScript plan files | `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/` | build-tooling owner | new pipeline | rare | (loaded into BuildMaster) |
| `manifest.json` | (none in source — bundle root) | `New-ReleaseManifest` | (generated) | (generated) | THIS IS the generated artifact |
| `db-manifest.json` | (none in source — bundle's `db/`) | `New-ReleaseManifest` | (generated) | (generated) | generated artifact |

---

## 3. Per-task checklists

### 3.1 I'm starting a new C# package

1. Create the project folder under `src/ATAP.Utilities.<Name>/` and add
   the `.csproj`.
2. Author a per-project `version.json` next to the `.csproj` if the
   project needs a label different from the repo-root default.
3. Add the package to `Directory.Packages.props` (CPM) at the repo
   root — never add `<PackageReference Version="…">` directly.
4. Confirm `Directory.Build.props` / `Directory.Build.targets` at the
   repo root cover the new project (multi-TFM, reproducible-build
   switches, signing).
5. Verify `NuGet.config` at the repo root points at the right ProGet
   feeds for restore.
6. Add a sibling `tests/ATAP.Utilities.<Name>.UnitTests/` xUnit project
   following the conventions in `CSharp-Packages-Test-Process.md`.

### 3.2 I'm starting a new PowerShell module

1. Create the module folder under `src/<ModuleName>/` with the
   conventional sub-folders (`public/`, `private/`, `tests/`).
2. Author the template `<ModuleName>.psd1` next to the module folder.
   Fill in `RequiredModules` and `FormatsToProcess`. The build will
   stamp the version into a generated copy under `_generated/.../packages/`.
3. Author a per-module `version.json` next to the `.psd1`.
4. Confirm the module is referenced by the InvokeBuild driver
   (`module.build.ps1`) for the 5-tier task pipeline.
5. Add Pester tests in `src/<ModuleName>/tests/` per
   `PowerShell-Modules-Test-Process.md`.

### 3.3 I'm authoring a new DB change unit for an existing app

1. Add the Flyway migration script(s) under `db/<App>/flyway/` using
   the project's migration-naming convention.
2. Add any CSV seed data and seed loaders under `db/<App>/seed/`.
3. Do **not** edit `db/<App>/releases/<x.y.z>.yml` here — that file is
   authored at release-branch cut time. The change unit is just the
   migration + seed files.
4. Run the migration locally against a developer SQL instance to
   validate; do not commit `_generated/` artifacts.

### 3.4 I'm cutting a release branch

1. Cut `release/<x.y.z>` from the stable branch tip.
2. Author `db/<App>/releases/<x.y.z>.yml` enumerating the Flyway
   migrations and seed loaders that ship in this release.
3. Tag the release-branch tip; the BuildMaster Release-Bundle pipeline
   builds the bundle exactly once from this tag.
4. The bundle's `manifest.json` and `db-manifest.json` are generated —
   do not author or commit them. They live under `_generated/` until
   the pipeline pushes the bundle to the Experimental ProGet feed.
5. Tier promotion of the bundle happens via `Promote-ProGetPackage`;
   no rebuild between tiers.

---

## 4. Provenance note

This inventory is derived analysis from
`CriticalAnalysisOfImmutableBuildStrategy.md §4` (the source-of-truth
gap section) and is **net-new** to the doc set — it does not appear in
the Perplexity research file that seeded the Sprint-7 strategy docs.
The per-area docs (C# Build Process, PowerShell Build Process,
Database-Change-Unit-and-Flyway-Promotion, Release-Branch-and-Manifest)
should link here rather than repeat their slice of the table.
