# AceCommander Modernization Plan

> **Parked in ATAP.Utilities SolutionDocumentation on 2026-07-06** (Sprint 0012 Task 12.45.e,
> documentation reorganization per `PlanDocumentationReorganization.md`; moved from
> `_Planning/AceCommander-Modernization-Plan.md`). **Eventual home: AceCommander SolutionDocumentation** — parked here
> because AceCommander has no sprint worktree in Sprint 0012 (user decision 2026-07-06);
> relocation is tracked as a scope-creep item.

## Status

| Field                 | Value                                                                                                                                  |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Last Updated          | 2026-04-03 (PLANNINGSESSION-0004)                                                                                                      |
| Current Sprint        | Sprint 4 (started 2026-04-01)                                                                                                          |
| Project End           | Sprint 23 (unchanged)                                                                                                                  |
| Scope Changes Adopted | 34 total (3 SESSION-0002 + 16 SESSION-0003 + 14 PLANNINGSESSION-0003 + 1 PLANNINGSESSION-0004 — all +0 sprints); 1 cancelled (SC-0089) |

> **Note on plan versions**: This document originated as a 5-phase, 12-sprint plan (v1).
> During the architecture planning conversation, it was expanded to an 8-phase, 23-sprint
> plan (v2) covering native apps, Digital Modeling engine, Philote versioning, and the
> Outdoor Sharing plugin. The v2 scope is the canonical target. The 23-sprint
> implementation plan with milestone diamonds is documented in the Conversation Bookmark
> (`AceCommander_Project_State_Conversation_Bookmark_001.md`). This file will be
> progressively updated to reflect the full v2 scope as phases are reached.

---

## Executive Summary

Rework AceCommander to incorporate the original ACe project's capabilities (rule-based data management, visual workflows, plugin extensibility) using modern .NET 10 standards. The project depends on ATAP.Utilities libraries and must support a plugin module architecture where plugins themselves consume ATAP.Utilities. Two workstreams run in parallel: **Infrastructure** (repository, build, packaging, plugin scaffold) and **UI/Data** (WASM client, SQL table viewing/editing).

Extended scope (v2): Android, iOS, and Windows native apps via .NET MAUI + Blazor Hybrid. Digital Modeling as the composition engine. Philote + TimeBlock versioning. Executable Instantiations. Outdoor Sharing plugin with OpenTopoMap and BLE. Self-modeling recursive closure by Sprint 23.

---

## Guiding Constraints

- Languages: **C#** and **PowerShell**
- IDE: **Visual Studio Code**
- Database: **Microsoft SQL Server Community Edition** (server), **SQLCipher via sqlite3mc** (local/offline)
- Documentation: **Markdown**, **PlantUML**, **DrawIO**
- Package repository: **ProGet Free** (NuGet + PowerShell feeds, four environment tiers)
- CI/CD: **BuildMaster Free** (Experimental → Development → Testing → Production)
- Secrets: **Bitwarden Secrets Manager** (cloud API, single bootstrap token)
- Hosting target: **IONOS Windows VPS** (IIS via bootstrap Windows Service)
- UI components: **Syncfusion Blazor** (existing dependency, web + MAUI Hybrid)
- Local encryption: **sqlite3mc** (Decision D-001, SESSION-0001; revisit if MAUI issues arise)

---

## Workstream Overview

```
SPRINT 1     2     3     4     5     6     7     8     9    10    11    12
      ├─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┤

WS-A  ██████████████████████████████████████████████████████████████████████
      Infrastructure & Build Pipeline

WS-B              ██████████████████████████████████████████████████████████
                  WASM UI & SQL Table Viewer/Editor
                  (+ SC-0005: game card iteration alongside per-sprint UI tasks)

      ├── Phase 1 ──┤── Phase 2 ──┤── Phase 3 ──┤─ Phase 4 ─┤─ Phase 5 ─┤
      Repo & Build   ATAP.Util     Plugin Arch   Integration  Stabilize
                     Integration                  & Deploy

Sprints 13–23: MAUI native apps, Digital Modeling engine, Outdoor Sharing,
             Ingestion engine maturation, self-modeling closure.
             (See Conversation Bookmark for full per-sprint breakdown.)
```

---

## Phase 1 — Repository Online & Build Pipeline (Sprints 1–3)

**Goal**: AceCommander builds from a clean clone, packages flow through ProGet, and CI pushes to the correct environment feed.

### Task 1.1 — Repository Housekeeping — ✅ COMPLETE (Sprint 1)

Audited and fixed `.gitignore`. Removed tracked `bin/` and `obj/` artifacts.

### Task 1.2 — Local Build Validation — ✅ COMPLETE (Sprint 1)

All projects target `net10.0`. `dotnet restore` and `dotnet build` succeed. Test suite passes with `-SkipE2E -SkipCoverage`.

### Task 1.3 — ProGet Feed Setup — ✅ COMPLETE (Sprint 2, Task 2.1)

ProGet installed on localhost:50000. All 8 feeds created (4 NuGet + 4 PowerShell). Inter-tier connectors configured. API keys stored in Bitwarden. Documented in `Explainers/0002-ProGet-Setup.md`.

### Task 1.4 — BuildMaster Pipeline (First Pass) — ✅ COMPLETE (Sprint 2, Task 2.2)

BuildMaster installed. AceCommander application created with 4-stage pipeline. OtterScript Build plan verified — Build #7 succeeded with 6 packages pushed to nuget-experimental. Documented in `Explainers/0004-BuildMaster-Setup.md`.

### Task 1.5 — Bitwarden Secrets Bootstrap — 🔄 IN PROGRESS (Sprint 2→Sprint 4, Task 2.3→3.3→4.1)

DI wiring and string constants added. ATAP.Utilities Secrets packages published to ProGet. Blocked on: LoginScript.ps1 env var entries and Bitwarden vault item creation. Carried forward from Sprint 3 Task 3.3 to Sprint 4 Task 4.1.

### Additional Sprint 1 Deliverables (not in original plan)

These were added to Sprint 1's TASKS.md to front-load scaffolding:

| Task          | What                                                | Status      |
| ------------- | --------------------------------------------------- | ----------- |
| 1.4-README    | Build prerequisites in README.md                    | ✅ Complete |
| 1.5-ArchDocs  | Architecture docs in SolutionDocumentation/         | ✅ Complete |
| 1.6-SQLCipher | SQLCipher licensing decision (sqlite3mc)            | ✅ Complete |
| 1.7-Dashboard | Dashboard layout replacing Home page                | ✅ Complete |
| 1.8-SignalR   | SignalR pulse indicator on dashboard                | ✅ Complete |
| 1.9-DataCore  | AceCommander.Data.Core with executor/Philote stubs  | ✅ Complete |
| 1.10-DM       | AceCommander.DigitalModeling plugin project (empty) | ✅ Complete |

### Deliverable for Phase 1

A developer can clone the repo, run `dotnet build`, run unit/component tests, and `dotnet pack` produces NuGet packages that land in the ProGet experimental feed.

**Status**: Substantially met. Build, tests, ProGet, and BuildMaster all operational. Bitwarden integration in progress (Sprint 3 Task 3.3). Phase 1 complete for build pipeline purposes.

---

## Phase 2 — ATAP.Utilities Integration (Sprints 3–5)

**Goal**: ATAP.Utilities libraries are published to ProGet as NuGet packages and consumed by AceCommander via package references (not local path references).

### Task 2.1 — Publish ATAP.Utilities to ProGet — ✅ COMPLETE (Sprint 2, Task 2.4)

All 20 required ATAP.Utilities packages published to nuget-experimental feed.

### Task 2.2 — Replace Local Path References in AceCommander — ✅ COMPLETE (Sprint 2, Task 2.5)

All csproj files confirmed using PackageReference (no path references). `dotnet restore` succeeds from ProGet + nuget.org.

### Task 2.3 — ATAP.Utilities Versioning Strategy — ✅ COMPLETE (Sprint 2, Task 2.10)

SemVer + environment suffix convention documented (`1.0.0-experimental.42`).

### Deliverable for Phase 2

AceCommander consumes ATAP.Utilities purely as NuGet packages from ProGet. Building AceCommander no longer requires the ATAP.Utilities source code to be present on disk.

---

## Phase 3 — Plugin Architecture (Sprints 5–8)

**Goal**: AceCommander supports dynamically discovered plugin modules.

### Task 3.1 — Define the Plugin Contract

- `AceCommander.Plugin.Abstractions` project — **partially exists** (minimal version created in Sprint 1, Task 1.10 to support `IAceCommanderPlugin` stub).
- Full interface set (`IAceCommanderPluginUI`, `IAceCommanderPluginDataProvider`, `IOfflineCapablePlugin`, `IPlatformAwarePlugin`, `IPeerSharingPlugin`, `IFriendExecutor`) to be defined.

### Task 3.2 — Plugin Discovery and Loading

`PluginLoader` service with `AssemblyLoadContext` isolation. Not yet started.

### Task 3.3 — Plugin Project Template

`dotnet new` template or sample project. Not yet started.

### Task 3.4 — Plugin Build and Packaging

Plugin NuGet packaging convention. Not yet started.

### Deliverable for Phase 3

A sample plugin can be built, packaged, deployed alongside AceCommander, and discovered at startup.

---

## Phase 4 (Parallel) — WASM UI & SQL Table Viewer/Editor (Sprints 3–9)

**Goal**: The Blazor WebAssembly client provides a functional, modern interface for viewing and editing SQL Server tables.

**SC-0005 (Gamification)**: During this phase, each sprint's UI deliverable may include an iteration on the existing game card on the Home screen. This rides alongside the primary UI work at zero schedule cost. The game card was added during Sprint 1 by Claude Code.

Tasks 4.1–4.6 unchanged from original plan. Not yet started.

---

## Phase 5 — Integration, Deployment & Stabilization (Sprints 9–12)

Tasks 5.1–5.5 unchanged from original plan. Not yet started.

---

## Phases 6–8 (v2 Scope — Sprints 13–23)

These phases were defined in the architecture planning conversation and are documented in the Conversation Bookmark. Summary:

- **Phase 6**: .NET MAUI + Blazor Hybrid native apps (Android, iOS, Windows). SQLCipher local storage with platform-native key management.
- **Phase 7**: Digital Modeling engine maturation. Executor implementations (Filesystem, PowerShell, C#, MSBuild, SQL, Document). Ingestion engine scanning real workstation/repo/build.
- **Phase 8**: Outdoor Sharing plugin (OpenTopoMap, BLE sharing, trip lifecycle). Self-modeling recursive closure.

Detailed per-sprint breakdown to be expanded in this file as Phases 1–5 complete.

---

## Dependency Graph (Task Sequencing)

```
1.1 Repo Housekeeping ─────┐    ✅
1.2 Local Build Validation ─┤    ✅
1.3 ProGet Feed Setup ──────┼──► 1.4 BuildMaster Pipeline    ✅ Sprint 2
1.5 Bitwarden Secrets ──────┘         │                       🔄 Sprint 2→3
                                      ▼
                            2.1 Publish ATAP.Utilities        ✅ Sprint 2
                                      │
                            2.2 Replace Path Refs ──────┐     ✅ Sprint 2
                            2.3 Versioning Strategy     │     ✅ Sprint 2
                                      │                 │
                                      ▼                 │
                            3.1 Plugin Contract         │
                            3.2 Plugin Loader           │
                            3.3 Plugin Template         │
                            3.4 Plugin Packaging        │
                                      │                 │
                                      │    ┌────────────┘
                                      │    │  (parallel from Sprint 3)
                                      │    ▼
                                      │  4.1 WASM Shell Modernization
                                      │  4.2 API Layer
                                      │  4.3 Table Metadata Service
                                      │  4.4 Table Viewer
                                      │  4.5 Table Editor
                                      │  4.6 Cross-Schema Views
                                      │  + SC-0005: Game card iteration (per-sprint)
                                      │    │
                                      ▼    ▼
                                 5.1 Plugin + UI Integration
                                 5.2 Bootstrap Service
                                 5.3 IONOS VPS Deployment
                                 5.4 Test Hardening
                                 5.5 Documentation
```

---

## Scope Change Log

| SC ID       | Title                                   | Session              | Impact     | New End   |
| ----------- | --------------------------------------- | -------------------- | ---------- | --------- | ------------------------------------------------------------------------- | ------- | ------------------------------- | ------------ | ---------- | --------- |
| SC-0001     | PowerShell `idea` alias in README       | SESSION-0001         | +0 sprints | Sprint 23 |
| SC-0005     | Gamification (game card iteration)      | SESSION-0002         | +0 sprints | Sprint 23 |
| SC-0008     | Add Tags to Planning                    | SESSION-0002         | +0 sprints | Sprint 23 |                                                                           | SC-0014 | ProGet license key in Bitwarden | SESSION-0003 | +0 sprints | Sprint 23 |
| SC-0019     | ProGet global vars cleanup              | SESSION-0003         | +0 sprints | Sprint 23 |
| SC-0022     | Git commit template cleanup             | SESSION-0003         | +0 sprints | Sprint 23 |
| SC-0023     | Fix Dependabot security finding         | SESSION-0003         | +0 sprints | Sprint 23 |
| SC-0024     | Clipboard paste for idea capture        | SESSION-0003         | +0 sprints | Sprint 23 |
| SC-0026     | LoginScript file-based env vars         | SESSION-0003         | +0 sprints | Sprint 23 |
| SC-0029     | Fix dotnet restore warnings             | SESSION-0003         | +0 sprints | Sprint 23 |
| SC-0032     | Remove stale feed registrations         | SESSION-0003         | +0 sprints | Sprint 23 |
| SC-0033     | `_generated/` output convention         | SESSION-0003         | +0 sprints | Sprint 23 |
| SC-0043     | BuildMaster working directory mgmt      | SESSION-0003         | +0 sprints | Sprint 23 |
| SC-0044     | Rotate compromised API key (SEC-01)     | SESSION-0003         | +0 sprints | Sprint 23 |
| SC-0046     | AssemblyInfo.cs standardization         | SESSION-0003         | +0 sprints | Sprint 23 |
| SC-0047     | /checkpoint skill (already done)        | SESSION-0003         | +0 sprints | Sprint 23 |
| SC-0048     | BuildMaster version update              | SESSION-0003         | +0 sprints | Sprint 23 |
| SC-0049     | Checkpoint padding fix                  | SESSION-0003         | +0 sprints | Sprint 23 |
| SC-0050     | Deduplicate Bitwarden API key entry     | SESSION-0003         | +0 sprints | Sprint 23 |
| SC-0057     | Package promotion documentation         | PLANNINGSESSION-0003 | +0 sprints | Sprint 23 |
| SC-0060     | Package promotion terminology           | PLANNINGSESSION-0003 | +0 sprints | Sprint 23 |
| SC-0062     | Add ATAP.IAC repository                 | PLANNINGSESSION-0003 | +0 sprints | Sprint 23 |
| SC-0065     | Sprint-start automation script          | PLANNINGSESSION-0003 | +0 sprints | Sprint 23 |
| SC-0066     | ProGet/BuildMaster Cobian backups       | PLANNINGSESSION-0003 | +0 sprints | Sprint 23 |
| SC-0067     | SQL Server backup jobs                  | PLANNINGSESSION-0003 | +0 sprints | Sprint 23 |
| SC-0069     | Renumber Explainer 0020 conflict        | PLANNINGSESSION-0003 | +0 sprints | Sprint 23 |
| SC-0087     | SprintEnd subagent junction fix         | PLANNINGSESSION-0003 | +0 sprints | Sprint 23 |
| ~~SC-0089~~ | ~~Sync-WorktreeShared bidirectional~~   | PLANNINGSESSION-0003 | +0 sprints | Sprint 23 | **CANCELLED 2026-04-03** — superseded by SC-0112 (junction-only strategy) |
| SC-0091     | Store claude settings.json              | PLANNINGSESSION-0003 | +0 sprints | Sprint 23 |
| SC-0092     | BuildMaster OtterScript under VCS       | PLANNINGSESSION-0003 | +0 sprints | Sprint 23 |
| SC-0094     | pgutil references removal               | PLANNINGSESSION-0003 | +0 sprints | Sprint 23 |
| SC-0096     | Checkpoint bugfix — wrong branch        | PLANNINGSESSION-0003 | +0 sprints | Sprint 23 |
| SC-0097     | Checkpoint inbox bugfix                 | PLANNINGSESSION-0003 | +0 sprints | Sprint 23 |
| SC-0112     | Junction-only strategy (arch. decision) | PLANNINGSESSION-0004 | +0 sprints | Sprint 23 |

---

## Scope-Creep Amendments

### ◈ SC-0005 — Gamification (scoped to game card iteration)

| Field              | Value                                                |
| ------------------ | ---------------------------------------------------- |
| SuggestedBy        | Self                                                 |
| SuggestedDate      | 2026-03-17                                           |
| AdoptedDate        | 2026-03-17                                           |
| AdoptedIn          | SESSION-0002 (2026-03-17)                            |
| InsertedAt         | Phase 4 (Sprints 3–9), alongside per-sprint UI tasks |
| ImpactSprints      | +0                                                   |
| PreviousProjectEnd | Sprint 23                                            |
| NewProjectEnd      | Sprint 23                                            |

**What Changed in the Plan:**

- Added note to Phase 4 section: each sprint's UI deliverable may include a game card iteration
- No tasks shifted, no milestones affected

**Rationale:** A game card already exists on the AceCommander dashboard (added during Sprint 1). Scoped down from "build a gamification framework" to "iterate on the existing game card." Zero schedule impact because it rides alongside the per-sprint UI cadence already in the plan.

---

### ◈ SC-0008 — Add Tags to Planning

| Field              | Value                     |
| ------------------ | ------------------------- |
| SuggestedBy        | Self                      |
| SuggestedDate      | 2026-03-17                |
| AdoptedDate        | 2026-03-17                |
| AdoptedIn          | SESSION-0002 (2026-03-17) |
| InsertedAt         | Sprint 2, as Task 2.11    |
| ImpactSprints      | +0                        |
| PreviousProjectEnd | Sprint 23                 |
| NewProjectEnd      | Sprint 23                 |

**What Changed in the Plan:**

- Added Task 2.11 to TASKS.md: define tags convention for planning and idea capture
- Updated `ScopeCreep-Process.md` template and `Add-ScopeCreepIdea.ps1` script (pending)

**Rationale:** Small effort that improves the planning system actively being built. Tags enable categorization of scope-creep ideas and planning session topics (e.g., `PersonOfInterest`, `PluginContract`, `UIComponent`).

---

### ◈ SESSION-0003 Batch Adoption (16 items, all +0 sprints)

| SC ID   | Title                                | InsertedAt                          |
| ------- | ------------------------------------ | ----------------------------------- |
| SC-0014 | ProGet license key in Bitwarden      | Sprint 3, Task 3.2                  |
| SC-0019 | ProGet global vars cleanup           | Sprint 3, Task 3.2                  |
| SC-0022 | Git commit template cleanup          | Sprint 3, Task 3.8                  |
| SC-0023 | Fix Dependabot security finding      | Sprint 3, Task 3.9                  |
| SC-0024 | Clipboard paste for idea capture     | Sprint 3, Task 3.5                  |
| SC-0026 | LoginScript file-based env vars      | Sprint 3, Task 3.14                 |
| SC-0029 | Fix dotnet restore warnings          | Sprint 3, Task 3.10                 |
| SC-0032 | Remove stale feed registrations      | Sprint 3, Task 3.2                  |
| SC-0033 | `_generated/` output convention rule | Sprint 3, Task 3.6                  |
| SC-0043 | BuildMaster working directory mgmt   | Sprint 3, Task 3.12                 |
| SC-0044 | Rotate compromised API key (SEC-01)  | Sprint 3, Task 3.1 (FIRST PRIORITY) |
| SC-0046 | AssemblyInfo.cs standardization      | Sprint 3, Task 3.11                 |
| SC-0047 | /checkpoint skill                    | Already implemented — closed        |
| SC-0048 | BuildMaster version update           | Sprint 3, Task 3.13                 |
| SC-0049 | Checkpoint padding fix               | Sprint 3, Task 3.15                 |
| SC-0050 | Deduplicate Bitwarden API key entry  | Sprint 3, Task 3.2                  |

**Adoption rationale:** All 16 items are XS/S effort and fit naturally into Sprint 3 alongside carryover tasks. 4 items bundle into a single "ProGet configuration hygiene" task (3.2). SC-0044 (compromised API key) is the critical security finding from AI Conversation Analysis (SEC-01) and is Sprint 3's first priority. SC-0047 was already implemented as `.claude/skills/checkpoint/SKILL.md` — adopted and immediately closed. Total schedule impact: +0 sprints. Project end unchanged at Sprint 23.

Additionally, 24 items were deferred to future sprints with documented trigger conditions. See `ScopeCreep-Deferred.md` for details.

---

### ~~◈ SC-0089~~ [CANCELLED 2026-04-03] — Sync-WorktreeShared bidirectional

| Field               | Value                                                                                                                                                                                                                                                            |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| OriginallyAdoptedIn | PLANNINGSESSION-0003                                                                                                                                                                                                                                             |
| CancelledDate       | 2026-04-03                                                                                                                                                                                                                                                       |
| CancelledIn         | PLANNINGSESSION-0004                                                                                                                                                                                                                                             |
| CancellationReason  | Superseded by SC-0112 (junction-only architectural decision). The bidirectional copy-based approach via `Sync-WorktreeShared.ps1` introduced race conditions and state divergence. The junction-only strategy eliminates these risks and is simpler to maintain. |

**What Changed:** `Sync-WorktreeShared.ps1` has been renamed to `Sync-WorktreeShared.ps1.archived` and will not be continued. All downstream repo worktrees use NTFS junctions to reference the SharedVSCode `.claude`, `.github`, and `.vscode` folders directly.

---

### ◈ SC-0112 — Junction-only strategy for shared workspace folders (architectural decision)

| Field              | Value                                                                 |
| ------------------ | --------------------------------------------------------------------- |
| SuggestedBy        | User (architectural decision)                                         |
| SuggestedDate      | 2026-04-03                                                            |
| AdoptedDate        | 2026-04-03                                                            |
| AdoptedIn          | PLANNINGSESSION-0004 (2026-04-03)                                     |
| InsertedAt         | Sprint 4, infrastructure — applies retroactively across all worktrees |
| ImpactSprints      | +0                                                                    |
| PreviousProjectEnd | Sprint 23                                                             |
| NewProjectEnd      | Sprint 23                                                             |

**What Changed in the Plan:**

The architectural decision permanently establishes the **junction-only strategy** for the `.claude`, `.github`, and `.vscode` folders in all downstream repo worktrees:

- **Source of truth**: SharedVSCode main or sprint worktree (depending on worktree type)
- **Main worktrees** of ATAP.Utilities, AceCommander, \_Planning → junctions target SharedVSCode **main** worktree
- **Sprint worktrees** → junctions target SharedVSCode **sprint** worktree (using `Set-WorktreeJunctions -DevSourceRepoPath`)
- **Junctions are excluded** from Dropbox (`.dropboxignore`) and git (`.gitignore`) in downstream repos
- **SharedVSCode worktrees are NOT excluded** — they hold the real files

**Critical Safety Rules (permanent guardrails):**

1. Never use `Remove-Item -Recurse` on a junction — use `Remove-Item` (no `-Recurse`) only
2. Never use `Remove-Item -Recurse` on any parent folder while junctions exist inside it — remove all junctions first
3. Sprint end: remove all junctions with `Remove-Item` BEFORE calling `git worktree remove`

**Files Updated (2026-04-03):**

| File                                    | Repository           | Change                                                         |
| --------------------------------------- | -------------------- | -------------------------------------------------------------- |
| `Sync-WorktreeShared.ps1` → `.archived` | ATAP.Utilities-wt-94 | Archived                                                       |
| `New-WorktreeWithJunctions.ps1`         | ATAP.Utilities-wt-94 | Fixed unsafe Recurse removal; added NOTES                      |
| `SprintEndAgent.md` (was `SprintEndSubagent.md`, renamed sprint-0005) | \_Planning-wt-7      | Added Step 5a junction removal before Step 5b worktree removal |
| `VersionControlIssueToWorktreeAgent.md` | SharedVSCode-wt-36   | Rewrote Step 6 for sprint vs. normal junction targeting        |
| `issue-to-worktree/SKILL.md`            | SharedVSCode-wt-36   | Added design decision, target table, safe removal block        |
| `ReadMe.md` (BuildTooling.PowerShell)   | ATAP.Utilities-wt-94 | Added design decision notice and safety rules                  |
| `ScopeCreep-Inbox.md`                   | \_Planning-wt-7      | Cancelled SC-0068, SC-0088, SC-0089; added SC-0112             |
| `ScopeCreep-Adopted.md`                 | \_Planning-wt-7      | Struck SC-0089; added SC-0112                                  |
| `AceCommander-Modernization-Plan.md`    | \_Planning-wt-7      | This file — added SC-0112 amendment                            |

**Rationale:** Junctions provide a single-source-of-truth model with no sync lag, no copy drift, and no race conditions. The copy-based approach (Sync-WorktreeShared) required manual invocation, created stale copies, and couldn't handle conflicts when both source and target diverged. Junctions solve all of this at the filesystem level. The only additional operational requirement is proper junction lifecycle management (creation at worktree start; removal before `git worktree remove`).

---

## Key Risks and Mitigations

| Risk                                               | Impact                 | Mitigation                                                         |
| -------------------------------------------------- | ---------------------- | ------------------------------------------------------------------ |
| ATAP.Utilities API breakage when packaging         | Blocks Phase 2         | Pin versions; publish `-experimental` first and validate           |
| Syncfusion WASM rendering issues                   | Blocks Phase 4         | Validate grid components early; server-side fallback               |
| Plugin isolation via AssemblyLoadContext           | Dependency conflicts   | Use collectible load contexts; test shared ATAP.Utilities versions |
| SQL Server metadata discovery across schemas       | Permissions edge cases | Validate against both schemas; handle views, computed columns      |
| Single developer bandwidth on parallel workstreams | Slippage               | Phase 4 can start with stub data before Phase 2 completes          |
| ProGet/BuildMaster installation issues             | Blocks Sprint 2        | Fallback: local NuGet folder feed as temporary bridge              |

---

## Open Questions for Next Iteration

1. **Authentication migration** — replace `StubAuthenticationStateProvider`? Could be Sprint 10.
2. **Syncfusion MAUI licensing** — needs verification before Sprint 13.
3. **Full v2 per-sprint plan** — expand Phases 6–8 into this document (currently in Bookmark only).
4. **Executor sandboxing** — process isolation for untrusted executors. Future security phase.
5. **macOS target** — not in scope. Future phase beyond Sprint 23.

---
