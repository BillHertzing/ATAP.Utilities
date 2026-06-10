# Branch Model — Future Work Tracker

> **Status: Not on the current sprint backlog (Sprint 0007).**
> This document is the **single active tracker** for the multi-sprint branch-
> model design that was originally drafted in the `_Planning/MidSprint*_V3`
> document set. Those drafts were archived on 2026-05-17 to
> `_Planning/Archived/MidSprint-V3/` because the design is too large for
> Sprint 0007 and competes with the immutable-promotion work that is the
> sprint's primary focus.
>
> Until a future sprint adopts this work, **no implementation should begin**.
> Cite this document when scoping the sprint that takes it on; do not let
> branch-model changes leak into other sprints as side scope.

**Created:** 2026-05-17 (Sprint 0007)
**Source artifacts (archived, do not edit):**

- [`_Planning/Archived/MidSprint-V3/MidSprintIndex_V3.md`](../../../_Planning-wt-14-Sprint-0007-work-items/Archived/MidSprint-V3/MidSprintIndex_V3.md)
- [`_Planning/Archived/MidSprint-V3/MidSprintBuildApproach_V3.md`](../../../_Planning-wt-14-Sprint-0007-work-items/Archived/MidSprint-V3/MidSprintBuildApproach_V3.md)
- [`_Planning/Archived/MidSprint-V3/MidSprintTasksForBoth_V3.md`](../../../_Planning-wt-14-Sprint-0007-work-items/Archived/MidSprint-V3/MidSprintTasksForBoth_V3.md)
- [`_Planning/Archived/MidSprint-V3/MidSprintTasksForImmutable_V3.md`](../../../_Planning-wt-14-Sprint-0007-work-items/Archived/MidSprint-V3/MidSprintTasksForImmutable_V3.md)
- [`_Planning/Archived/MidSprint-V3/MidSprintDatabaseAndCodeCoordination_V3.md`](../../../_Planning-wt-14-Sprint-0007-work-items/Archived/MidSprint-V3/MidSprintDatabaseAndCodeCoordination_V3.md)

**Authoring decision recorded in:**
[`_Planning/ExplainerEliminationPlan_V2.md`](../../../_Planning-wt-14-Sprint-0007-work-items/ExplainerEliminationPlan_V2.md) §C and §D Stream W5.

---

## Section A — Branch Model Summary

The V3 design introduces a first-class branch vocabulary and a per-kind
gate set on top of the existing immutable-promotion model.

### A.1 Branch kinds

| Kind                  | Naming pattern                       | Publishes? | Primary use                                                  |
| --------------------- | ------------------------------------ | ---------- | ------------------------------------------------------------ |
| `stable`              | `main`, `release/*`                  | Yes        | Trunk; full 5-tier gate set                                  |
| `feature`             | `feature/<id>-<slug>`                | Yes (T1)   | Long-lived feature work; parallel counter `feat.<id>.<n>`    |
| `sprint-direct`       | `sprint/<NNNN>-work-items`           | Yes        | Sprint branch cut directly from `main`                       |
| `sprint-on-feature`   | `sprint/<NNNN>-on-feature/<id>`      | Yes (T1)   | Sprint branch cut from an active feature branch              |
| `hotfix`              | `hotfix/<incidentId>-<slug>`         | Yes        | Reduced-gate hotfix lane; mandatory back-merge to features   |
| `experimental`        | `experimental/<author>/<slug>`       | **No**     | Local exploration; cannot publish; promoted by rename only   |

### A.2 Per-kind gate behavior (essence)

- **Stable / sprint-direct:** Full 5-tier gate set (Experimental →
  Development → Integration → QA → Stable), governed by the immutable-
  promotion + `version.json`-as-ceiling model.
- **Feature / sprint-on-feature:** May only publish at Experimental
  (T1). Promotion past T1 requires a feature-integration manifest and
  the sprint-close-on-feature checklist.
- **Hotfix:** Reduced gate set, faster path through tiers; mandatory
  AceCommander smoke (T1→T2) plus a mandatory auto back-merge to every
  active feature branch.
- **Experimental:** Build-only; publish guard rejects the push. The
  branch is promoted by *renaming* it to one of the other kinds, not by
  pushing artifacts.

### A.3 First-class concepts introduced

- **Feature registry** (`_Planning/Features/INDEX.md` + per-feature pages).
- **Branch-naming lint** (pre-push hook).
- **Release-manifest schema extensions:** `manifestKind` ∈ {`release`,
  `feature-integration`, `hotfix`}; new `branch`, `hotfix`, and `feature`
  blocks.
- **New permanent feed:** `release-manifests-feature-integration`.
- **Hotfix lane pipeline:** `Hotfix-5Stage.otter` (parallels existing
  `*-5Stage.otter` plans but with reduced gates).
- **Auto back-merge automation:** CI script that fans hotfix landings
  out to all active feature branches.
- **Branch-aware DB migrations:** `Vfeat__<featureId>__NN__<desc>.sql`
  placeholder convention on feature branches, renumbered into the main
  sequence at feature-integration time.
- **Per-feature shadow databases:** Isolated SCRD review surface per
  active feature.

---

## Section B — V2 → V3 Concept Map (Carried From `MidSprintIndex_V3.md`)

The V2 immutable-promotion decisions are **unchanged** by V3. V3 layers
branch awareness on top.

| V2 concept                                          | V3 evolution                                                                                            |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Sprint branch (implicit, off `main`)                | Two flavors: `sprint-direct` and `sprint-on-feature`; both lint-enforced and gate-distinguished         |
| Feature work (not modeled)                          | First-class `feature/<id>-<slug>` branches; feature registry under `_Planning/Features/`                |
| Hotfix (not modeled)                                | `hotfix/<incidentId>-<slug>` branches with reduced gate set and mandatory back-merge to features        |
| Experimental work (implicit)                        | `experimental/<author>/<slug>` branches; cannot publish; promoted by rename                             |
| Release manifest (`manifestKind: release`)          | Adds `feature-integration` and `hotfix` kinds; adds `branch`, `hotfix`, `feature` blocks                |
| Solution-bump policy (no silent exemptions)         | **Unchanged.** Carried forward.                                                                         |
| CI versioning engine                                | **Unchanged** for `main`/hotfix; feature/sprint-on-feature use a parallel counter `feat.<id>.<n>`       |
| Migration-set component                             | Numbered only on `main`; feature branches use `Vfeat__<featureId>__NN__<desc>.sql` placeholders         |
| SCRD discipline                                     | **Unchanged** baseline; V3 adds branch-kind rules (S-1, S-2, S-3)                                       |
| AceCommander smoke gate                             | **Unchanged** placement (T1→T2); also required in hotfix lane                                           |
| Publish guard                                       | Extended to reject `experimental/*` and to refuse promoting feature/sprint-on-feature manifests past T1 |

---

## Section C — Un-Implemented Tasks (Sourced From `ExplainerEliminationPlan_V2.md` §C.3)

Each row below has **no source-of-truth analog** as of 2026-05-17 and
must be implemented (or explicitly rejected) before the V3 branch model
can be considered live. Task IDs preserve the original V3 naming so the
archived design docs remain readable.

### C.1 Documentation surfaces

| Task   | Target artifact                                                  | State              |
| ------ | ---------------------------------------------------------------- | ------------------ |
| TB3-17 | `SolutionDocumentation/BranchVocabulary.md`                      | Does not exist     |
| TB3-21 | `SolutionDocumentation/SprintCloseOnFeatureChecklist.md`         | Does not exist     |
| TB3-22 | `SolutionDocumentation/HotfixRunbook.md`                         | Does not exist     |
| TI3-16 | `SolutionDocumentation/BuildMaster-Pipeline-GateMap.md`          | Does not exist     |
| TI3-14 | Doc reconciliation across topology / gate-map / branch-vocab     | Not started        |

### C.2 Registry & lint infrastructure

| Task   | Target artifact                                                  | State              |
| ------ | ---------------------------------------------------------------- | ------------------ |
| TB3-18 | `_Planning/Features/INDEX.md` + per-feature pages                | Does not exist     |
| TB3-19 | Branch-naming lint (pre-push hook)                               | Not implemented    |

### C.3 Manifest & publish-guard extensions

| Task                | Target artifact                                                  | State              |
| ------------------- | ---------------------------------------------------------------- | ------------------ |
| TB3-20              | `release-manifest.schema.json` extensions (`manifestKind`, `branch`, `hotfix`, `feature` blocks) | Not implemented    |
| TB3-23 / TI3-17     | Branch-aware publish guard (extend the existing TI2-04 guard)    | Not implemented    |
| TI3-20              | Feature-integration manifest producer (`New-ReleaseManifest.ps1` extension) + new feed `release-manifests-feature-integration` | Not implemented    |

### C.4 CI gate selection & lane pipelines

| Task   | Target artifact                                                       | State              |
| ------ | --------------------------------------------------------------------- | ------------------ |
| TI3-16 | Branch-aware CI gate selection (`.otter` plan changes)                | Not implemented    |
| TI3-18 | Hotfix lane pipeline: `src/.../Plans/Hotfix-5Stage.otter`             | Does not exist     |
| TI3-19 | Auto back-merge automation (CI script)                                | Not implemented    |
| TI3-21 | `src/.../PowerShell/public/Promote-ExperimentalBranch.ps1`            | Does not exist     |
| TI3-22 | `src/.../PowerShell/public/Test-FeatureBranchMergeable.ps1`           | Does not exist     |

### C.5 Database / SCRD branch-awareness

| Task     | Target artifact                                                       | State              |
| -------- | --------------------------------------------------------------------- | ------------------ |
| TI3-09g  | `Vfeat__<featureId>__NN__<desc>.sql` placeholder convention           | Not implemented    |
| TI3-09h  | Per-feature shadow database                                           | Not implemented    |
| TI3-09i  | `Database/SCRDReview/<featureId>.md` scaffolding per active feature   | Not implemented    |
| TI3-09j  | Hotfix S-3 check (SCRD reduced-rule set)                              | Not implemented    |

### C.6 Agent / orchestration updates

| Task            | Target artifact                                                  | State              |
| --------------- | ---------------------------------------------------------------- | ------------------ |
| (orchestration) | SprintStartAgent / SprintEndAgent — read feature registry, run sprint-close checklist, emit feature-integration manifest | Not implemented    |
| (orchestration) | Root `CLAUDE.md` — cite V3 branch vocabulary                     | Not implemented    |

**Total open items:** 20 V3-new tasks (matches the `MidSprint-V3/README.md` total).

---

## Section D — Suggested Sequencing (When This Work Is Adopted)

This is a hint for the sprint that takes on the work — not a commitment.

```text
Phase 1  Foundation (docs + registry)
         TB3-17 (BranchVocabulary.md)
         TB3-18 (Feature registry)
         TB3-19 (Branch-naming lint)
         TI3-16 (BuildMaster-Pipeline-GateMap.md)

Phase 2  Manifest + guard
         TB3-20 (manifest schema extensions)
         TB3-23 / TI3-17 (publish-guard extension)
         TI3-20 (feature-integration manifest producer + new feed)

Phase 3  CI lanes
         TI3-16 (branch-aware gate selection in .otter)
         TI3-18 (Hotfix-5Stage.otter)
         TI3-19 (auto back-merge automation)
         TI3-21 / TI3-22 (Promote-ExperimentalBranch, Test-FeatureBranchMergeable)

Phase 4  Database
         TI3-09g / h / i / j

Phase 5  Process + orchestration
         TB3-21 (SprintCloseOnFeatureChecklist.md)
         TB3-22 (HotfixRunbook.md)
         SprintStartAgent / SprintEndAgent updates
         CLAUDE.md updates
```

Phases 1–2 are largely parallelizable and unblock Phase 3. Phase 4 can
run in parallel with Phase 3 if database staff are distinct. Phase 5 is
the rollout gate.

---

## Section E — Relationship to Other Active Plans

- [`_Planning/Plan-VersionJsonAsCeiling.md`](../../../_Planning-wt-14-Sprint-0007-work-items/Plan-VersionJsonAsCeiling.md)
  is **independent** of this work and proceeds first. It tightens the
  immutable-promotion model for the current 5-tier pipeline; the branch
  model in this document layers on top of whatever ceiling semantics
  ship from that plan.
- [`SolutionDocumentation/Immutable-Build-Strategy.md`](Immutable-Build-Strategy.md)
  is the source of truth for the promotion model. Any branch-model gate
  change must cite it; nothing in this document should contradict it.

---

## Section F — Activation Checklist

Before opening a sprint to execute this work:

- [ ] Confirm `Plan-VersionJsonAsCeiling.md` has shipped (or is explicitly
      sequenced ahead of branch-model work).
- [ ] Confirm no other in-flight work edits the same `.otter` plan files
      or the publish-guard cmdlet at the same time.
- [ ] Cite this document in the sprint's `TASKS.md` and copy the §C task
      table into the sprint backlog (do not re-derive it).
- [ ] Re-read the archived V3 design docs in
      `_Planning/Archived/MidSprint-V3/` for full design rationale before
      starting Phase 1.

---

## Section G — Maintenance

This document is the **active tracker**. The archived V3 design docs
are **frozen** — if a task is added, removed, or re-scoped, change it
here, not in the archive. When the work eventually ships, replace this
file's status banner with a "completed; superseded by [shipped docs]"
note and link to the live `BranchVocabulary.md` / `HotfixRunbook.md` /
etc.
