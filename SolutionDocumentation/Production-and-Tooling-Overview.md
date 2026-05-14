# Production and Tooling Overview

This document is an **index of the future detailed documentation** that will describe,
end-to-end, the processes and tools used to produce and test the five subject areas
of the ATAP ecosystem. It is narrower in scope than [INDEX.md](INDEX.md) — the master
catalog of all `SolutionDocumentation/` files — and is focused specifically on
**build, version, package, publish, and workstation-provisioning tooling**.

Use this file as a roadmap:

- **Section 2** names the five subject areas and lists the future docs planned per area.
- **Section 3** names the cross-cutting tooling (ProGet, BuildMaster, NBGV, Bitwarden,
  new-computer setup) and points to the authoritative doc for each.
- **Section 4** is a table of **docs that already exist** across all five sprint-0006
  workTrees, so readers can go directly to what is written today.
- **Section 5** enumerates the **documentation gaps** — the docs yet to be written,
  grouped by the subject area they belong to.

---

## 1. Scope and Relationship to Other Indexes

**In scope.** Production, build, version, package, publish, test, and workstation-
provisioning tooling for:

1. ATAP.Utilities C# NuGet packages
2. ATAP.Utilities PowerShell modules
3. ATAP.Utilities documentation (Markdown, diagrams, images, animations)
4. AceCommander application and its documentation
5. SharedVSCode components used across all four downstream repositories

**Out of scope** (covered by other indexes):

- Application-runtime architecture of Ace Commander — see [architecture-overview](../../AceCommander-wt-34-sprint-0006-work-items/SolutionDocumentation/architecture-overview.md)
  and [Module Catalog](Module%20Catalog.md).
- Rule-primitive specifications — see the `Rules Compendium.*.md` family, indexed by [INDEX.md](INDEX.md).
- Sprint lifecycle and role assignments — see [\_Planning/Explainers/0108-sprint-lifecycle-and-roles.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0108-sprint-lifecycle-and-roles.md).

**Sibling indexes** this file cross-references:

| Index                                                                                                         | Role                                                           |
| ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| [INDEX.md](INDEX.md)                                                                                          | Master catalog of all `SolutionDocumentation/` Markdown files. |
| [\_Planning/Explainers/INDEX.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/INDEX.md)            | Catalog of the 0000–0500 numbered Explainer series.            |
| [src/ATAP.Utilities.BuildTooling.PowerShell/INDEX.md](../src/ATAP.Utilities.BuildTooling.PowerShell/INDEX.md) | Build-tooling PowerShell module index.                         |
| [src/ATAP.Utilities.PowerShell/INDEX.md](../src/ATAP.Utilities.PowerShell/INDEX.md)                           | General PowerShell utilities index.                            |
| [src/ATAP.Utilities.IAC.Ansible.Powershell/INDEX.md](../src/ATAP.Utilities.IAC.Ansible.Powershell/INDEX.md)   | Ansible/IAC infrastructure index.                              |
| [ATAP.IAC/Windows/INDEX.md](../../ATAP.IAC-wt-7-sprint-0006-work-items/Windows/INDEX.md)                      | Windows workstation provisioning index.                        |

> **Tier-vocabulary note.** Throughout this index, the authoritative tier names are
> the 5-tier set established in Sprint 6: **Experimental → Development → Integration →
> QA → Production**, with NBGV prerelease labels **Sprint → Alpha → Beta → QA → (none)**.
> Older docs using 4-tier labels (Experimental / Development / Testing / Production)
> are being updated under [\_Planning/Plan-UpdateDocFor5Tier.md](../../_Planning-wt-12-sprint-0006-work-items/Plan-UpdateDocFor5Tier.md).
> The single source of truth for label/feed mapping is
> [BuildMaster-ProGet-CSharp-Package-Pipeline](BuildMaster-ProGet-CSharp-Package-Pipeline.md).

> **Build-strategy note (Sprint 7).** The ecosystem has moved from the older
> "build-per-tier" pattern to an **immutable-build, promote-the-artifact** pattern.
> Each release unit (C# package family, PowerShell module family, or final
> Release Bundle) is built **exactly once** from a release-branch tag and the
> resulting artifact is promoted unchanged through the five ProGet feeds. Tier
> gates run **tests against the existing artifact** rather than rebuilding it.
> Sprint-7 reorganizes the docs around this pattern; cross-cutting concepts are
> established in:
>
> - [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) — the new authoritative
>   overview of "build once, promote the artifact, never rebuild between tiers."
> - [Release-Bundle-Pipeline.md](Release-Bundle-Pipeline.md) — the new third
>   BuildMaster pipeline that produces the customer-facing installer (Chocolatey
>   / WinGet) bundling app code + Flyway migrations + seed data into one package.
> - [Database-Change-Unit-and-Flyway-Promotion.md](Database-Change-Unit-and-Flyway-Promotion.md)
>   — how Flyway migrations and CSV seed data are grouped into versioned DB
>   change units and tied to an application release version.
> - [Release-Branch-and-Manifest.md](Release-Branch-and-Manifest.md) — release
>   branches as the source of truth for what ships, plus the release-manifest
>   schema that travels with every artifact.
> - [BuildMaster-Pipeline-Topology.md](BuildMaster-Pipeline-Topology.md) — the
>   three durable BuildMaster pipelines (C#, PowerShell, Release Bundle) and the
>   PowerShell automation surface that drives them.

---

## 2. The Five Subject Areas

Each subject area below lists the **detailed docs planned** to fully describe its
production and test process. Each planned doc has a one-line scope statement.
A check-mark in the "Status" column indicates the content already exists in some
form (see Section 4 for the specific file); an empty status means the doc is not
yet written.

### 2.0 Cross-cutting: Immutable Build & Release Bundles (Sprint 7)

These docs establish the strategy that the per-area docs in §2.1–§2.5 follow.

> `spec` means the strategy is documented but the cmdlets the doc references do not yet exist. See [`BuildMaster-Pipeline-Topology.md §4`](BuildMaster-Pipeline-Topology.md) for the canonical cmdlet inventory.

| Planned doc                                    | Scope                                                                                                                                                                                      | Status                                                                                                     | Implementation                                                                                                                                                                                               |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Immutable-Build-Strategy.md`                  | "Build once, promote the artifact, never rebuild between tiers." Replaces the older build-per-tier pattern across C#, PowerShell, and Release Bundles.                                     | **written** — [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md)                                   | code complete (no cmdlet dependency)                                                                                                                                                                         |
| `Release-Bundle-Pipeline.md`                   | The third BuildMaster pipeline that produces the final installer bundle (app + Flyway migrations + seed data) for Chocolatey and WinGet distribution.                                      | **written** — [Release-Bundle-Pipeline.md](Release-Bundle-Pipeline.md)                                     | partial implementation: Stream I bundle assembly cmdlets are implemented/tested; Chocolatey and WinGet distribution cmdlets remain spec                                                                      |
| `Database-Change-Unit-and-Flyway-Promotion.md` | Grouping Flyway migrations and CSV seed loaders into versioned DB change units; mapping app version ↔ DB change unit version; promotion through the five tiers.                            | **written** — [Database-Change-Unit-and-Flyway-Promotion.md](Database-Change-Unit-and-Flyway-Promotion.md) | partial implementation: Stream J DB lifecycle cmdlets and `Invoke-FlywayRehearsal` rotation are implemented/tested; destructive-migration linting and install-time checksum verification remain tracked gaps |
| `Release-Branch-and-Manifest.md`               | Release branches as the canonical source of release artifacts; the release-manifest JSON schema that travels with each artifact and records app + DB contents.                             | **written** — [Release-Branch-and-Manifest.md](Release-Branch-and-Manifest.md)                             | implemented for Stream I: `New-ReleaseManifest`, `Get-DeployedReleaseManifest`, and `Compare-ReleaseManifest` are exported/tested                                                                            |
| `BuildMaster-Pipeline-Topology.md`             | The three durable BuildMaster pipelines (C#, PowerShell, Release Bundle); PowerShell automation surface; ProGet-webhook → BuildMaster integration.                                         | **written** — [BuildMaster-Pipeline-Topology.md](BuildMaster-Pipeline-Topology.md)                         | mixed implementation; §4 is the canonical cmdlet inventory and marks Stream I release-bundle cmdlets implemented                                                                                             |
| `Worktree-Source-of-Truth-Inventory.md`        | Files developers must author and commit (vs. files that are generated under `_generated/`). Per-task checklists for new C# packages, PS modules, DB change units, and release-branch cuts. | **written** — [Worktree-Source-of-Truth-Inventory.md](Worktree-Source-of-Truth-Inventory.md)               | code complete (no cmdlet dependency)                                                                                                                                                                         |

### 2.1 ATAP.Utilities C# Packages — Build, Version, Pack, Push

Produces ~170 NuGet packages from a single solution.

| Planned doc                            | Scope                                                                                                                                                                                                                                                                                                                                                                                      | Status                                                                                     |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------ |
| `CSharp-Packages-Build-Process.md`     | Solution layout; `Directory.Build.props` / `Directory.Build.targets` roles; custom MSBuild tasks from `ATAP.Utilities.BuildTooling.CSharp`; multi-TFM strategy; reproducible-build switches.                                                                                                                                                                                               | partially covered by [Building.md](Building.md)                                            |
| `CSharp-Packages-Versioning.md`        | NBGV `version.json` at repo root and per-project overrides; version-height rules; prerelease-label promotion (Sprint→Alpha→Beta→QA→stable); `nbgv` CLI usage; SemVer-2.0 compliance gotchas.                                                                                                                                                                                               | **written** — [CSharp-Packages-Versioning.md](CSharp-Packages-Versioning.md)               |
| `CSharp-Packages-Pack-and-Push.md`     | `dotnet pack` for each project; meta-package aggregation (`ATAP.Utilities.csproj`); `dotnet nuget push` with `--api-key`; ProGet flatcontainer-only limitation; cache clearing after re-push.                                                                                                                                                                                              | **written** — [CSharp-Packages-Pack-and-Push.md](CSharp-Packages-Pack-and-Push.md)         |
| `CSharp-Packages-Test-Process.md`      | xUnit test project conventions (`*.Tests` project names post-sprint-0007); `UsePackageReferenceForSUT` / `SUTVersion` for promotion-tier runs (Development–Production); tier-to-filter mapping (`--filter Category=...`); `dotnet test` invocation; code coverage via coverlet; test-artifact collection for BuildMaster. TestSlice (`.slnf`) solution-filter model is planned; no `.slnf` files exist yet. | **written** — [CSharp-Packages-Test-Process.md](CSharp-Packages-Test-Process.md)           |
| `CSharp-Central-Package-Management.md` | Migration from `<PackageReference Update>` in `Directory.Build.targets` to `Directory.Packages.props`; framework-conditional versions; 85-package inventory.                                                                                                                                                                                                                               | **written** — [CSharp-Central-Package-Management.md](CSharp-Central-Package-Management.md) |

### 2.2 ATAP.Utilities PowerShell Modules — Build, Version, Pack, Publish

Produces PowerShell modules that are published to the PowerShell feeds on ProGet.

| Planned doc                              | Scope                                                                                                                                                                                          | Status                                                                                         |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `PowerShell-Modules-Build-Process.md`    | Role of `module.build.ps1` (InvokeBuild driver); 5-tier task pipeline; manifest (`.psd1`) generation; `.psm1` assembly from `public/` and `private/`; snippet-template reuse.                  | **written** — [PowerShell-Modules-Build-Process.md](PowerShell-Modules-Build-Process.md)       |
| `PowerShell-Modules-Versioning.md`       | NBGV or equivalent for PowerShell modules; manifest-version sync; prerelease labels on PSGallery/ProGet PowerShell feeds.                                                                      | **written** — [PowerShell-Modules-Versioning.md](PowerShell-Modules-Versioning.md)             |
| `PowerShell-Modules-Pack-and-Publish.md` | `.nuspec` generation; `.nupkg` creation; publish via `Publish-PSResource` (PSResourceGet v3+); ProGet PowerShell feed (`powershell-experimental` / `-development` / …); PSModulePath behavior. | **written** — [PowerShell-Modules-Pack-and-Publish.md](PowerShell-Modules-Pack-and-Publish.md) |
| `PowerShell-Modules-Test-Process.md`     | Pester 5 layout (`RegularTests` / `RequiresNewProcess`); PSFramework logging; tag/new-process filtering; `Invoke-Pester` invocation.                                                           | **written** — [PowerShell-Modules-Test-Process.md](PowerShell-Modules-Test-Process.md)         |
| `PowerShell-Script-Consolidation.md`     | Phase-0 consolidation of build/sprint scripts into `ATAP.Utilities.BuildTooling.PowerShell`.                                                                                                   | **written** — [PowerShell-Script-Consolidation.md](PowerShell-Script-Consolidation.md)         |

### 2.3 ATAP.Utilities Documentation Pipeline — Markdown, Diagrams, Images, Animations

Produces the published documentation for the ATAP.Utilities solution.

| Planned doc                             | Scope                                                                                                                                                                   | Status                                                                     |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `Docs-Pipeline-Markdown-Conventions.md` | Markdown dialect; front-matter (if any); cross-reference style; table conventions; callout blockquotes; Philote GUID usage in Rules Compendium files.                   | gap (partial in [INDEX.md](INDEX.md) prose)                                |
| `Docs-Pipeline-Drawio-Diagrams.md`      | `.drawio` source → `.svg` export workflow; diagram naming; draw.io MCP server integration; where diagrams live in the tree.                                             | gap                                                                        |
| `Docs-Pipeline-Manim-Animations.md`     | Manim subsystem (`src/ATAP.Utilities.ManimVideoGenerator/`); code-generation rules via [Rules Compendium.Manim](Rules%20Compendium.Manim.md); video-artifact lifecycle. | partially covered by [Rules Compendium.Manim](Rules%20Compendium.Manim.md) |
| `Docs-Pipeline-Image-Optimization.md`   | imgbot integration; image formats; Authenticode-signed assets vs. content images.                                                                                       | gap (mentioned briefly in [Building.md](Building.md))                      |
| `Docs-Pipeline-DocFX-or-Static-Site.md` | DocFX configuration; `toc.yml` maintenance; static-site output; publish target.                                                                                         | gap ([toc.yml](toc.yml) is a stale 12-line stub)                           |
| `Docs-Pipeline-Index-Maintenance.md`    | How to keep [INDEX.md](INDEX.md), this file, and the subsystem indexes in sync when docs are added, renamed, or deleted.                                                | gap                                                                        |

### 2.4 AceCommander Application and Documentation

Produces the AceCommander server, Blazor WASM client, and its documentation.

| Planned doc                               | Scope                                                                                                                                          | Status                                                                                                                                                                                                                                                                                                                                   |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AceCommander-Build-Process.md`           | Solution layout (Server, Client, Shared, Tests); `dotnet build`; Syncfusion license handling; user-secrets; Directory.Build.props consumption. | partially covered by [AceCommander/ReadMe.md](../../AceCommander-wt-34-sprint-0006-work-items/ReadMe.md)                                                                                                                                                                                                                                 |
| `AceCommander-Versioning.md`              | AceCommander's NBGV `version.json` (currently `0.1-Sprint.{height}`); how it relates to ATAP.Utilities package versions consumed from ProGet.  | covered by [AceCommander/version.json](../../AceCommander-wt-34-sprint-0006-work-items/version.json) (file) but no prose doc                                                                                                                                                                                                             |
| `AceCommander-Release-Runbook.md`         | End-to-end release: build → test → publish → deploy; IIS app pool provisioning; bootstrap Windows Service; client bundle publish.              | partially covered by [AceCommander-Modernization-Plan §5](../../AceCommander-wt-34-sprint-0006-work-items/SolutionDocumentation/AceCommander-Modernization-Plan.md)                                                                                                                                                                      |
| `AceCommander-Test-Orchestration.md`      | `Invoke-AceCommanderTests.ps1`; unit + bUnit + Playwright E2E; `_generated/test-orchestration/` artifact layout; Test Dashboard generation.    | covered by [AceCommander/SolutionDocumentation/Testing in AceCommander.md](../../AceCommander-wt-34-sprint-0006-work-items/SolutionDocumentation/Testing%20in%20AceCommander.md) + [Test Orchestration Skill](../../AceCommander-wt-34-sprint-0006-work-items/SolutionDocumentation/AI%20Agent%20Skills/Test%20Orchestration%20Skill.md) |
| `AceCommander-Documentation-Structure.md` | Index of AceCommander/SolutionDocumentation contents and how they relate back to this ATAP.Utilities index.                                    | partially covered by [AceCommander/SolutionDocumentation/Index.md](../../AceCommander-wt-34-sprint-0006-work-items/SolutionDocumentation/Index.md) (stub)                                                                                                                                                                                |

### 2.5 SharedVSCode Cross-Repo Components

Produces the shared `.claude/` agents/skills/rules, shared VSC user settings, and
shared PowerShell functions that propagate into all four downstream repositories
via NTFS junctions.

| Planned doc                              | Scope                                                                                                                                                                              | Status                                                                                                                                                                                                                                      |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SharedVSCode-Components-Catalog.md`     | What lives in SharedVSCode; how the `.claude/` junction works; what is authoritative vs. copied; propagation model to the 4 downstream repos.                                      | partially covered by [SharedVSCode/ReadMe.md](../../SharedVSCode-wt-40-sprint-0006-work-items/ReadMe.md) + [SharedVSCode/CLAUDE.md](../../SharedVSCode-wt-40-sprint-0006-work-items/CLAUDE.md)                                              |
| `SharedVSCode-Sprint-Agents.md`          | `SprintStartAgent` / `SprintEndAgent` workflows; ProGet feed provisioning; BuildMaster sprint-build scaffolding; SQL instance + Bitwarden-secret creation; infrastructure cleanup. | covered by [.claude/agents/SprintStartAgent.md](../../SharedVSCode-wt-40-sprint-0006-work-items/.claude/agents/SprintStartAgent.md) + [SprintEndAgent.md](../../SharedVSCode-wt-40-sprint-0006-work-items/.claude/agents/SprintEndAgent.md) |
| `SharedVSCode-PowerShell-Functions.md`   | `Import-SharedVSCodeFunctions.ps1`; `New-SprintStage1` / `New-SprintStage2`; `Set-WorktreeJunctions`; `Invoke-WithFileLock`; transition plan to publish as a ProGet-hosted module. | gap                                                                                                                                                                                                                                         |
| `SharedVSCode-Rules-and-Instructions.md` | `.claude/Rules/*.md` (stub rules) vs. `.github/instructions/*.instructions.md` (substantive); how the two layers interact; editing-impact warning.                                 | partially covered by [SharedVSCode/CLAUDE.md](../../SharedVSCode-wt-40-sprint-0006-work-items/CLAUDE.md)                                                                                                                                    |
| `SharedVSCode-Settings-Propagation.md`   | `UserSettings.jsonc` as the single source of truth for VSC settings across repos; absence of `.vscode/settings.json` by design.                                                    | gap                                                                                                                                                                                                                                         |

---

## 3. Cross-Cutting Tooling

These tools appear in multiple subject areas. Each has an **authoritative doc**;
detailed subject-area docs should **link to it** rather than duplicate.

| Concern                                         | Authoritative doc                                                                                                                                                                                                                                                                                                                     | Notes                                                                                                                                                                                 |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **ProGet (private package server)**             | [\_Planning/Explainers/0002-ProGet-Setup.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0002-ProGet-Setup.md) + [0002a-ProGet-Feed-Architecture.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0002a-ProGet-Feed-Architecture.md)                                                                           | Installation, feed topology, connector chains, API keys, NuGet.config. Host `utat022:50000`.                                                                                          |
| **BuildMaster / OtterScript**                   | [\_Planning/Explainers/0004-BuildMaster-Setup.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0004-BuildMaster-Setup.md) + [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md)                                                                                                 | Installation, application/pipeline/stage model, API-key rotation, `$Decrypt()` and `$Obscure()` usage, sprint `WorkingDirectory` variable.                                            |
| **NBGV (Nerdbank.GitVersioning)**               | [\_Planning/Explainers/0109-nbgv-version-label-promotion.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0109-nbgv-version-label-promotion.md)                                                                                                                                                                            | `version.json` schema, label promotion across the 5 tiers, `nbgv` CLI.                                                                                                                |
| **MSBuild build-tooling**                       | [Rules Compendium.MSBuild.md](Rules%20Compendium.MSBuild.md) + [\_Planning/Explainers/0013-BuildTooling-CSharp-MSBuild-interaction.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0013-BuildTooling-CSharp-MSBuild-interaction.md)                                                                                       | Directory.Build.props/targets model, custom tasks (`GetVersion` / `SetVersion` / `UpdateVersion`), multi-TFM publishing.                                                              |
| **Bitwarden secrets**                           | [SharedVSCode/.github/instructions/Bitwarden.instructions.md](../../SharedVSCode-wt-40-sprint-0006-work-items/.github/instructions/Bitwarden.instructions.md) + [AI on WSL2 Ansible Docker and Bitwarden.md](AI%20on%20WSL2%20Ansible%20Docker%20and%20Bitwarden.md)                                                                  | `Get-BitWardenSecret`, `BW_SESSION`, User-scope env vars, LoginScript.ps1 pattern.                                                                                                    |
| **New computer setup**                          | [NewComputerSetup.md](NewComputerSetup.md) + [\_Planning/Explainers/0500-New Computer Setup.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0500-New%20Computer%20Setup.md)                                                                                                                                               | OS bootstrap → service accounts → Inedo Hub → ProGet → BuildMaster → SQL Server → dev tooling.                                                                                        |
| **Backup / disaster preparedness**              | [\_Planning/Explainers/0021-sql-server-backup-proget-buildmaster.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0021-sql-server-backup-proget-buildmaster.md) + [0021a-proget-buildmaster-application-backup.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0021a-proget-buildmaster-application-backup.md) | `Invoke-SqlServerBackup.ps1`, Cobian Reflector integration, `C:\Dropbox\Backups\utat022\` layout. [Disaster Preparedness.md](Disaster%20Preparedness.md) is still largely a skeleton. |
| **5-Tier software production model (umbrella)** | [\_Planning/Explainers/0100-sw-production-process-overview.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0100-sw-production-process-overview.md) + siblings 0101–0108                                                                                                                                                   | Roles (Developer, Integrator, Tester, Release Engineer, Debug Engineer), tiers, branch/worktree/role mapping, sprint lifecycle.                                                       |

---

## 4. Authoritative Docs That Exist Today

This table consolidates what has already been written, across all five sprint-0006
workTrees. Use it to locate source material when expanding any of the planned docs
in Section 2.

### 4.1 ATAP.Utilities (this repo)

| Doc                                                                                                                                                                                                                                                                                                               | Topic(s)                                               | Depth                                      |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ | ------------------------------------------ |
| [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md)                                                                                                                                                                                                                    | ProGet, BuildMaster, NBGV, pack/push, 5-stage pipeline | Substantive (747 lines) — authoritative    |
| [Building.md](Building.md)                                                                                                                                                                                                                                                                                        | MSBuild, solution build, NuGet & PowerShell packaging  | Substantive (231 lines)                    |
| [Rules Compendium.MSBuild.md](Rules%20Compendium.MSBuild.md)                                                                                                                                                                                                                                                      | MSBuild primitives & rules                             | Substantive (858 lines) — authoritative    |
| [Rules Compendium.Powershell.md](Rules%20Compendium.Powershell.md)                                                                                                                                                                                                                                                | PowerShell primitives & rules                          | Substantive (~1,545 lines) — authoritative |
| [NewComputerSetup.md](NewComputerSetup.md)                                                                                                                                                                                                                                                                        | Workstation + build-server provisioning runbook        | Substantive (700+ lines)                   |
| [plan-fixDotnetBuild.prompt.md](plan-fixDotnetBuild.prompt.md)                                                                                                                                                                                                                                                    | Central Package Management migration (85 packages)     | Substantive plan                           |
| [MSBuild Binary Logging.md](MSBuild%20Binary%20Logging.md)                                                                                                                                                                                                                                                        | `-bl` switch, log viewer                               | Stub (8 lines)                             |
| [src/ATAP.Utilities.BuildTooling.PowerShell/Documentation/5Tier tasks for module.build.ps1.md](../src/ATAP.Utilities.BuildTooling.PowerShell/Documentation/5Tier%20tasks%20for%20module.build.ps1.md)                                                                                                             | 5-tier task design for `module.build.ps1`              | Substantive                                |
| [src/ATAP.Utilities.BuildTooling.PowerShell/Documentation/5tier Implementation plan.md](../src/ATAP.Utilities.BuildTooling.PowerShell/Documentation/5tier%20Implementation%20plan.md)                                                                                                                             | 5-tier implementation roadmap                          | Substantive                                |
| [src/ATAP.Utilities.BuildTooling.PowerShell/Documentation/Deep Dive on Building Modules and Publishing to Powershell Package Repositories.md](../src/ATAP.Utilities.BuildTooling.PowerShell/Documentation/Deep%20Dive%20on%20Building%20Modules%20and%20Publishing%20to%20Powershell%20Package%20Repositories.md) | PSResourceGet v3+, module lifecycle, nuspec/nupkg      | Substantive                                |
| [src/ATAP.Utilities.IAC.Ansible.Powershell/Documentation/Starting an organization infrastructure.md](../src/ATAP.Utilities.IAC.Ansible.Powershell/Documentation/Starting%20an%20organization%20infrastructure.md)                                                                                                 | Ansible org-infrastructure setup                       | Substantive                                |
| [TestingMethodology.md](TestingMethodology.md)                                                                                                                                                                                                                                                                    | Pester layout (RegularTests / RequiresNewProcess)      | Partial — C# xUnit conventions missing     |
| [Disaster Preparedness.md](Disaster%20Preparedness.md)                                                                                                                                                                                                                                                            | Backup topology skeleton                               | Skeleton only                              |
| [ReadMe.md](ReadMe.md)                                                                                                                                                                                                                                                                                            | Repo overview                                          | Several TBD sections                       |
| [ContributingGuidelines.md](ContributingGuidelines.md)                                                                                                                                                                                                                                                            | —                                                      | 1-line stub                                |
| [GettingStarted.md](GettingStarted.md)                                                                                                                                                                                                                                                                            | —                                                      | 1-line stub                                |

### 4.2 \_Planning worktree

| Doc                                                                                                                                                        | Topic(s)                                                                                 | Depth                               |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- | ----------------------------------- |
| [0100-sw-production-process-overview.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0100-sw-production-process-overview.md)                   | 5-tier model entry point, 5 roles, 4→5-tier transition                                   | Substantive — authoritative         |
| [0101-code-lifecycle-terminology.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0101-code-lifecycle-terminology.md)                           | Artifact types, 7 lifecycle stages                                                       | Substantive                         |
| [0102-branches-and-workTrees.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0102-branches-and-workTrees.md)                                   | Git branching model, worktree naming, junctions                                          | Substantive                         |
| [0103-package-types-and-contents.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0103-package-types-and-contents.md)                           | SemVer labels, 5 package variants                                                        | Substantive                         |
| [0104-sql-databases-lifecycle.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0104-sql-databases-lifecycle.md)                                 | SQL instances, schemas, tiered lifecycle, Flyway                                         | Substantive                         |
| [0106-testing-process-and-artifacts.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0106-testing-process-and-artifacts.md)                     | 9 test types, per-tier testing, coverage targets                                         | Substantive                         |
| [0107-build-artifacts-trace-etw.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0107-build-artifacts-trace-etw.md)                             | 13-field build metadata, TRACE config, ETW providers                                     | Substantive                         |
| [0108-sprint-lifecycle-and-roles.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0108-sprint-lifecycle-and-roles.md)                           | Sprint lifecycle, PR merge order, hotfix flow                                            | Substantive                         |
| [0109-nbgv-version-label-promotion.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0109-nbgv-version-label-promotion.md)                       | NBGV tier label mapping, `version.json` edits, `nbgv` CLI                                | Substantive — authoritative         |
| [0002-ProGet-Setup.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0002-ProGet-Setup.md)                                                       | ProGet install, feeds, connectors, API keys, NuGet.config                                | Substantive — authoritative         |
| [0002a-ProGet-Feed-Architecture.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0002a-ProGet-Feed-Architecture.md)                             | Phase-1/Phase-2 feed topology (combined vs. split push/pull)                             | Substantive — authoritative         |
| [0004-BuildMaster-Setup.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0004-BuildMaster-Setup.md)                                             | BuildMaster install, 4-stage pipeline, OtterScript Build plan, INC-001 rotation incident | Substantive — authoritative         |
| [0013-BuildTooling-CSharp-MSBuild-interaction.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0013-BuildTooling-CSharp-MSBuild-interaction.md) | Directory.Build.\* ↔ custom MSBuild tasks ↔ ProGet push                                  | Substantive — authoritative         |
| [0021-sql-server-backup-proget-buildmaster.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0021-sql-server-backup-proget-buildmaster.md)       | SQL backup via dbatools + Cobian, storage layout                                         | Substantive                         |
| [0021a-proget-buildmaster-application-backup.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0021a-proget-buildmaster-application-backup.md)   | ProGet / BuildMaster application-data backup                                             | Substantive                         |
| [0022-backup-ci-evolution-gaps-instructions.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0022-backup-ci-evolution-gaps-instructions.md)     | 4-era backup/CI/DB diagnostic; 15-item gap catalogue                                     | Substantive                         |
| [0500-New Computer Setup.md](../../_Planning-wt-12-sprint-0006-work-items/Explainers/0500-New%20Computer%20Setup.md)                                       | OEM-to-workstation bootstrap, 14 phases                                                  | First-draft, several phases pending |
| [TASKS.md](../../_Planning-wt-12-sprint-0006-work-items/TASKS.md)                                                                                          | Sprint 6 work items (6.1 swarm for 5-tier, 6.2–6.8 fixes)                                | Live tracking                       |
| [5TierTasks.md](../../_Planning-wt-12-sprint-0006-work-items/5TierTasks.md)                                                                                | Phase-0 → Phase-5 implementation checklist                                               | Substantive                         |
| [plan-ATAP5TierSoftwareProduction.md](../../_Planning-wt-12-sprint-0006-work-items/plan-ATAP5TierSoftwareProduction.md)                                    | 5-tier high-level model, 4→5 rename mapping                                              | Substantive                         |
| [Plan-PowershellScriptUpdate.md](../../_Planning-wt-12-sprint-0006-work-items/Plan-PowershellScriptUpdate.md)                                              | Phase-0 PowerShell script consolidation                                                  | Substantive plan                    |
| [Plan-UpdateDocFor5Tier.md](../../_Planning-wt-12-sprint-0006-work-items/Plan-UpdateDocFor5Tier.md)                                                        | Phase-4 doc-revision plan                                                                | Substantive plan                    |

### 4.3 AceCommander worktree

| Doc                                                                                                                                                                      | Topic(s)                                                                             | Depth               |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------ | ------------------- |
| [AceCommander-Modernization-Plan.md](../../AceCommander-wt-34-sprint-0006-work-items/SolutionDocumentation/AceCommander-Modernization-Plan.md)                           | 12-week roadmap: ProGet feeds, BuildMaster OtterScript, versioning, IIS provisioning | Substantive roadmap |
| [Testing in AceCommander.md](../../AceCommander-wt-34-sprint-0006-work-items/SolutionDocumentation/Testing%20in%20AceCommander.md)                                       | xUnit + bUnit + orchestration script                                                 | Substantive         |
| [AI Agent Skills/Test Orchestration Skill.md](../../AceCommander-wt-34-sprint-0006-work-items/SolutionDocumentation/AI%20Agent%20Skills/Test%20Orchestration%20Skill.md) | `run-tests-and-coverage.ps1`, dashboard output                                       | Substantive         |
| [ReadMe.md](../../AceCommander-wt-34-sprint-0006-work-items/ReadMe.md)                                                                                                   | Prerequisites, quick-start, Playwright E2E                                           | Substantive         |
| [SolutionDocumentation/Index.md](../../AceCommander-wt-34-sprint-0006-work-items/SolutionDocumentation/Index.md)                                                         | Local navigation hub                                                                 | Stub/placeholder    |

### 4.4 SharedVSCode worktree

| Doc                                                                                                                                                  | Topic(s)                                                                         | Depth                                   |
| ---------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | --------------------------------------- |
| [CLAUDE.md](../../SharedVSCode-wt-40-sprint-0006-work-items/CLAUDE.md)                                                                               | Ecosystem conventions, shell rules, config/logging/secrets/naming/testing, RRSBS | Substantive (378 lines) — authoritative |
| [.claude/agents/SprintStartAgent.md](../../SharedVSCode-wt-40-sprint-0006-work-items/.claude/agents/SprintStartAgent.md)                             | Sprint bootstrap: branches, feeds, BuildMaster builds, SQL, Bitwarden            | Substantive (493 lines)                 |
| [.claude/agents/SprintEndAgent.md](../../SharedVSCode-wt-40-sprint-0006-work-items/.claude/agents/SprintEndAgent.md)                                 | Sprint closure: retrospective, PR merge order, infrastructure cleanup            | Substantive (351 lines)                 |
| [.github/instructions/ProGet.instructions.md](../../SharedVSCode-wt-40-sprint-0006-work-items/.github/instructions/ProGet.instructions.md)           | Token access, flatcontainer-only caveat, cache clearing, feed names              | Substantive (97 lines)                  |
| [.github/instructions/BuildMaster.instructions.md](../../SharedVSCode-wt-40-sprint-0006-work-items/.github/instructions/BuildMaster.instructions.md) | API key security, sprint `WorkingDirectory`, rotation procedures                 | Substantive (52 lines)                  |
| [.github/instructions/Bitwarden.instructions.md](../../SharedVSCode-wt-40-sprint-0006-work-items/.github/instructions/Bitwarden.instructions.md)     | `Get-BitWardenSecret`, BW_SESSION, User-scope env vars                           | Substantive                             |
| [.github/instructions/Powershell.instructions.md](../../SharedVSCode-wt-40-sprint-0006-work-items/.github/instructions/Powershell.instructions.md)   | Windows + PS 7.x mandate, Pester invocation, snippet reuse                       | Substantive                             |
| [.github/instructions/CSharp.instructions.md](../../SharedVSCode-wt-40-sprint-0006-work-items/.github/instructions/CSharp.instructions.md)           | C# 14+, DI-first, nullable, xUnit                                                | Substantive                             |
| [ReadMe.md](../../SharedVSCode-wt-40-sprint-0006-work-items/ReadMe.md)                                                                               | VSC symlink strategy, extension recommendations                                  | Substantive                             |
| [SolutionDocumentation/Agent Descriptions.md](../../SharedVSCode-wt-40-sprint-0006-work-items/SolutionDocumentation/Agent%20Descriptions.md)         | Three agent-orchestration clusters                                               | Substantive                             |

### 4.5 ATAP.IAC worktree

| Doc                                                                                                                                                               | Topic(s)                                                              | Depth            |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- | ---------------- |
| [ReadMe.md](../../ATAP.IAC-wt-7-sprint-0006-work-items/ReadMe.md)                                                                                                 | ProGet setup, SQL Server Express, repository initialization           | Substantive      |
| [CLAUDE.md](../../ATAP.IAC-wt-7-sprint-0006-work-items/CLAUDE.md)                                                                                                 | IaC conventions + R-24 OtterScript env-var rule                       | Substantive      |
| [CLAUDE-local.md](../../ATAP.IAC-wt-7-sprint-0006-work-items/CLAUDE-local.md)                                                                                     | Repo-specific IaC pointers, bootstrap scripts                         | Substantive      |
| [Windows/INDEX.md](../../ATAP.IAC-wt-7-sprint-0006-work-items/Windows/INDEX.md)                                                                                   | Windows config subsystem, ProGet feed URIs, bootstrap helpers         | Substantive      |
| [Windows/planned-migration.md](../../ATAP.IAC-wt-7-sprint-0006-work-items/Windows/planned-migration.md)                                                           | Migration plan: ATAP.IAC PowerShell → ATAP.Utilities + ProGet publish | Substantive plan |
| [Documentation/global_ConfigRootKeys and HostSettings.md](../../ATAP.IAC-wt-7-sprint-0006-work-items/Documentation/global_ConfigRootKeys%20and%20HostSettings.md) | Two-tier config system, package-repository dimensions                 | Substantive      |

---

## 5. Documentation Gaps

Docs named below do **not yet exist** (or exist only as stubs/skeletons). Each is
grouped under its Section-2 subject area.

### 5.1 ATAP.Utilities C# Packages

_All planned docs in this subject area have been written. See §2.1._

### 5.2 ATAP.Utilities PowerShell Modules

_All planned docs in this subject area have been written. See §2.2._

### 5.3 Documentation Pipeline

- `Docs-Pipeline-Markdown-Conventions.md`
- `Docs-Pipeline-Drawio-Diagrams.md`
- `Docs-Pipeline-Image-Optimization.md`
- `Docs-Pipeline-DocFX-or-Static-Site.md` — [toc.yml](toc.yml) is stale.
- `Docs-Pipeline-Index-Maintenance.md` — rules for keeping indexes (this one, [INDEX.md](INDEX.md), and subsystem INDEXes) in sync.

### 5.4 AceCommander

- `AceCommander-Build-Process.md` — currently only summarized in [AceCommander/ReadMe.md](../../AceCommander-wt-34-sprint-0006-work-items/ReadMe.md) prerequisites.
- `AceCommander-Versioning.md` — `version.json` exists, but no accompanying prose.
- `AceCommander-Release-Runbook.md` — exists as a Phase-5 section of the Modernization Plan, not as a standalone runbook.
- `AceCommander-Documentation-Structure.md` — [AceCommander/SolutionDocumentation/Index.md](../../AceCommander-wt-34-sprint-0006-work-items/SolutionDocumentation/Index.md) is a stub.

### 5.5 SharedVSCode

- `SharedVSCode-Components-Catalog.md` — content scattered across CLAUDE.md, ReadMe.md, and the two sprint agents.
- `SharedVSCode-PowerShell-Functions.md` — no catalog of `New-SprintStage*`, `Set-WorktreeJunctions`, `Invoke-WithFileLock`, etc.
- `SharedVSCode-Settings-Propagation.md` — the "no `.vscode/settings.json`" convention is enforced by CLAUDE.md but not formally documented.

### 5.6 Cross-cutting

- **C# xUnit testing methodology** — now covered by [CSharp-Packages-Test-Process.md](CSharp-Packages-Test-Process.md); [TestingMethodology.md](TestingMethodology.md) still focuses on Pester only and should link out to the new doc.
- **Disaster Preparedness** — [Disaster Preparedness.md](Disaster%20Preparedness.md) is a skeleton.
- **GettingStarted** and **ContributingGuidelines** — both are 1-line stubs.
- **Sprint 6 task 6.1** ([TASKS.md](../../_Planning-wt-12-sprint-0006-work-items/TASKS.md)) explicitly calls for updating all docs to 5-tier vocabulary; [\_Planning/Plan-UpdateDocFor5Tier.md](../../_Planning-wt-12-sprint-0006-work-items/Plan-UpdateDocFor5Tier.md) is the live plan.

---

## 6. Maintenance Notes

Keep this file in sync when docs are added, renamed, or deleted:

1. When a **planned doc in Section 2** is written, move its row's "Status" from empty (or "gap") to a link to the new file, and remove the corresponding bullet from Section 5.
2. When a **cross-cutting authoritative doc in Section 3** is renamed or superseded, update the link _here first_, then propagate the rename via [\_Planning/Plan-UpdateDocFor5Tier.md](../../_Planning-wt-12-sprint-0006-work-items/Plan-UpdateDocFor5Tier.md) or its successor plan.
3. When a new **existing doc** is discovered across the five workTrees, add it to the Section 4 subtable for its repo and, if appropriate, reference it from the matching planned-doc row in Section 2.
4. **Do not duplicate** content from the authoritative docs in Section 3. This file is strictly an index — inline summaries here should be one-line scopes.
5. The sibling [INDEX.md](INDEX.md) remains the master catalog for _all_ `SolutionDocumentation/` files (not just production/tooling). When adding a new file under this folder, update **both** [INDEX.md](INDEX.md) and this file.
