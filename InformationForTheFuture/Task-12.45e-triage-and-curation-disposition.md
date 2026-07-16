# Task 12.45.e — _Planning Stray-Doc Triage + SolutionDocumentation Curation

Date: 2026-07-06. Plan: `PlanDocumentationReorganization.md` Tasks 3 (3.a–3.c) + 4 (4.a–4.e).
Worktrees edited: `_Planning-wt-26`, `ATAP.Utilities-wt-120`.

## Task 3 — _Planning stray documents

| File | Disposition |
| --- | --- |
| `Repositories\AceCommander\AceCommander architecture-overview.md` | PARKED → ATAP.Utilities `SolutionDocumentation\AceCommander-architecture-overview.md` (eventual-home-AceCommander banner); `git rm` in _Planning |
| `AceCommander-Modernization-Plan.md` | PARKED → `SolutionDocumentation\AceCommander-Modernization-Plan.md` (same banner); `git rm` |
| `Repositories\Ace\old Ace architecture-overview.md` | ARCHIVED → `SolutionDocumentation\ReviewedAndArchived\old-Ace-architecture-overview.md` (historical pre-modernization overview); `git rm` |
| (3.a tracking) | **SC-0245** recorded via `Add-ScopeCreepIdea` — relocate the three parked AceCommander docs when an AceCommander sprint worktree exists. Note: the cmdlet threw a non-fatal `Read-Host`/`$rawTags` error in the non-interactive shell because `-Tags` was omitted; the inbox entry was still written (verify Tags field when triaging). |
| `Repositories\ATAP.Utilities\ATAP.Utilities architecture-overview.md` | DELETED (`git rm`) — byte-identical (`diff -q`) to `SolutionDocumentation\architecture-overview.md`; no merge needed (3.b) |
| `AllDBDocuments-052526_v2.md` | ARCHIVED → `_Planning\Archived\` (point-in-time 2026-05-25 DB-doc catalog) (3.c) |
| `SharedVSCode-Reconciliation-Worksheet.md` | ARCHIVED → `_Planning\Archived\` (completed Sprint 0010 reconciliation); link in `SprintEnd-SprintStart-ManualReview-Checklist.md` retargeted (3.c) |
| `Roadmap-File-Rules-Bidirectional-Pattern.md` | KEPT in `_Planning` root — live multi-sprint roadmap (3.c) |

## Task 4 — SolutionDocumentation curation

### 4.b/4.c Archived to `ReviewedAndArchived\` (git mv + superseded banner naming replacement)

| File (new name) | Superseded by |
| --- | --- |
| `Tasks-ToDo-For-Plugin.md` | GenericPluginArchitecture.md |
| `Plugin-Creation-Prompt.md` (typo `PLugin` fixed) | GenericPluginArchitecture.md |
| `Refactoring-Phase1-Discovery-Report.md` | architecture-overview.md |
| `DeveloperMusings.md` | Database-Change-Unit-and-Flyway-Promotion.md |
| `Sprint-0006-5Tier-Retrospective.md` | Immutable-Build-Strategy.md |
| `CriticalAnalysisOfImmutableBuildStrategy.md` | Immutable-Build-Strategy.md |
| `AnalysisOfVersionJsonAsCeiling.md` | VersionJsonAsCeiling.md + Runbook |
| `SWProductionProcessCriticalReview.md` (was repo root) | Production-and-Tooling-Overview.md |
| `PowershellFilesNeedingFix.md` (was repo root) | PowerShell-Script-Consolidation.md + current standards |

Referrer fixes (all live links retargeted to `ReviewedAndArchived\`): `architecture-overview.md`,
`GenericPluginArchitecture.md`, `SecretsPluginArchitecture.md`,
`Database-Change-Unit-and-Flyway-Promotion.md`, `Immutable-Build-Strategy.md`,
`Worktree-Source-of-Truth-Inventory.md`, `INDEX.md` (7 rows),
BuildTooling `Documentation\5Tier gaps.md`.

### 4.d Deduplication / filename fixes

- `ServiceAccountsAndBitwarden.-AlternativesConsidered.md` → renamed
  `ServiceAccountsAndBitwarden-AlternativesConsidered.md` (git mv); 10 inbound links fixed
  (`ServiceAccountsAndBitwarden.md` ×9, `INDEX.md` ×1).
- `NewComputerSetup.md` ↔ `NewComputerSetupUsingAnsible.md`: Ansible doc already declared
  precedence (2026-05-19); reciprocal canonical-wins banner added to `NewComputerSetup.md`.
- `VersionJsonAsCeiling.md`: header banner added linking the Runbook + archived analysis.
- `Immutable-Build-Strategy.md` ↔ archived critical analysis: covered by link retarget.

### 4.a Functional Area Map

`INDEX.md` gained a "Functional Area Map (START HERE per area)" section: 13 rows —
the 11 approved areas + the user-added "AI Agents & Adapters" pointer area
(→ SharedVSCode SolutionDocumentation) + an "AceCommander (parked)" row (SC-0245).
Orphan check: 15 files previously absent from INDEX (7 added by Tasks 12.45.c/d/e,
8 pre-existing: BranchModel-Future-Work, BuildTooling-MSBuild-Internals,
NewOrganizationSetup, Package-Pinning-Ownership-Decision, ProGet-Install-Runbook,
Runbook-BuildMasterConfiguration, TraceETW-Configuration, VersionJsonAsCeiling-Runbook)
— all now indexed; re-run orphan check = **0 orphans**.

### 4.e Module-doc link-up audit

`_generated\Task-12.45e-module-doc-linkup-audit.{json,md}` — 243 module docs scanned
(`src\*\ReadMe.md` + `src\*\Documentation\*.md`): 17 link up to SolutionDocumentation,
**226 missing link-up** (flagged as follow-on editorial work, not edited this pass),
7 boilerplate stubs (flagged, not moved, per plan). The three BuildTooling 5-tier
working docs cited the DELETED `602 - 5Tier ... Revision 2` explainer as their
authoritative reference — retargeted to `SolutionDocumentation\Immutable-Build-Strategy.md`
(2 files carried the link). Archive decision on the 5-tier trio deferred: their
gap/task content is not yet proven fully absorbed by the immutable-build docs
(asserted-unverified; candidate for a future supersession review).

## Acceptance

- `_Planning` root: no subject-matter strays remain (Roadmap kept as live plan).
- SolutionDocumentation INDEX: 0 orphans; one START-HERE doc per area.
- All archive moves via `git mv` (history preserved); every archived file carries a
  superseded banner naming its replacement; no deletions (user policy 2026-07-06).
