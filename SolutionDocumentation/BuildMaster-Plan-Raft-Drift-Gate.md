# BuildMaster Plan Raft Drift Gate

**Rule of record enforced:** the rule stated in
[BuildMaster-Plan-Raft-Sync-Requirement.md](BuildMaster-Plan-Raft-Sync-Requirement.md) — a
committed change to an OtterScript plan or its stage-runner script is not live until
`Sync-BuildMasterPlans` has written it to the raft. That document says what the rule is and
how a human diagnoses a breach after the fact. **This document defines the recurring
automated gate that detects a breach before it costs a release cycle.**

This is the operational definition: what the gate checks, who owns it, when it runs, what
each result does, and what it may write. It is not a scheduler implementation. Nothing here
creates a scheduled task, a cron entry, or a BuildMaster job; those are the operator's to
create from this definition.

The gate's detection capability already exists and is read-only:
`src/ATAP.Utilities.BuildTooling.BuildMaster.PowerShell/public/Compare-BuildMasterPlanRaft.ps1`.

## Why a gate rather than a one-time reconciliation

Sprint 0015 decision **D31 / Q9 / B-06 option (c)** ratified doing both: reconcile the
deployed raft now, and convert the reconciliation into a recurring check. Units 15.171.a
(build the capability) and 15.171.b (run it live, read-only) did the reconciliation. The
reconciliation found breaches in two of five plans that had gone unnoticed for months —
one for 10 days, one since 2026-05-14. Neither produced an error anywhere. A check that
runs once finds the backlog; only a check that recurs keeps it at zero.

The gate must also be designed around what the reconciliation actually found, not around
what the sync-requirement document assumed. Those two differ in ways that would make a
naive gate report false results. See § Plans in scope and § Known limitations.

## What the gate checks

For each of the five plans, two independent checks:

1. **Content check** — SHA-256 and byte length of the raft item's stored content against
   the `.otter` file on disk. This answers "is BuildMaster executing the committed plan?"
2. **Argument-name check** — the argument names on the deployed raft plan's `Exec`
   `Arguments:` line against the paired runner script's parameter names on disk. This is
   the check that catches the 2026-08-03 silent-hang signature, and it is the reason the
   gate cannot be a hash comparison alone.

The argument check is deliberately asymmetric in its inputs, and a maintainer changing it
must preserve this: **argument names come from the raft, parameter names come from disk.**
That pair is what runs in production — BuildMaster executes the raft's plan, and that plan
invokes a runner that is read from the worktree at run time. Comparing the disk `.otter`
against the disk runner would compare two halves that are already consistent and would
never have detected the incident.

### Plans in scope, and their raft scoping

Scoping is not incidental detail. An unscoped, extension-assuming query returns three of
the five plans and reports the other two as absent. The gate must invoke the cmdlet with
these exact parameters:

| Plan file (`Plans/`) | Raft item name | Scope | Raft item id | Required cmdlet arguments |
| --- | --- | --- | --- | --- |
| `CSharpPackage-5Stage.otter` | `CSharpPackage-5Stage.otter` | global (unscoped) | 2009 | none beyond `-Path` |
| `PowerShellModule-5Stage.otter` | `PowerShellModule-5Stage.otter` | global (unscoped) | 2010 | none beyond `-Path` |
| `DatabaseChangePackage-5Stage.otter` | `DatabaseChangePackage-5Stage.otter` | global (unscoped) | 3014 | none beyond `-Path` |
| `ReleaseBundle-6Stage.otter` | **`ReleaseBundle-6Stage`** — no extension | **application 1003** | 2008 | `-ApplicationId 1003 -RaftItemName 'ReleaseBundle-6Stage'` |
| `AceCommander-ApplicationRelease.otter` | `AceCommander-ApplicationRelease.otter` | **application 1003** | 3012 | `-ApplicationId 1003` |

All items are in Raft 1, raft item type code 6. Raft 2 is Git-backed against a branch that
no longer exists on the remote, returns no items, and is out of scope.

> **Two corrections the gate must carry.** `BuildMaster-Plan-Raft-Sync-Requirement.md`
> names only `AceCommander-ApplicationRelease` as application-scoped and lists
> `ReleaseBundle-6Stage` among the global items. Unit 15.171.b established against the live
> server that **`ReleaseBundle-6Stage` is scoped to Application_Id 1003**, and that **its
> raft item name omits the `.otter` extension** while every other plan's item includes it.
> A gate that inherits the sync-requirement document's assumption queries the wrong scope
> under the wrong name and reports the highest-risk plan in the set as merely missing —
> which is exactly how its empty raft item went unnoticed since 2026-05-14. Correcting the
> sync-requirement document is a separate unit's work and is deliberately not done here;
> until it lands, **this table is the authority for scoping** and the two documents
> disagree on purpose. See § Known limitations, item 5.

Because the gate is driven from an explicit roster rather than a directory sweep, a **new
plan added to `Plans/` is invisible to the gate until the roster is updated**. The gate
therefore also asserts that the set of `.otter` files on disk equals the roster, and raises
a gate failure — not a pass — when it does not.

## Owner

| | |
| --- | --- |
| **Accountable role** | Owner of `src/ATAP.Utilities.BuildTooling.BuildMaster` — the BuildTooling / release-engineering role that owns the BuildMaster pipelines and is authorized to run `Sync-BuildMasterPlans` |
| **Responsible for** | The gate running at its stated cadence; triaging every non-pass result; performing or escalating the resulting sync; keeping the roster table above current |
| **Named person** | **Operator's ruling required — not assigned here** |

The named person is deliberately left unassigned. This repository carries no ownership
register, `CODEOWNERS` file, or role roster from which an accountable individual could be
verified, and an owner invented by an agent is worse than an absent one: it looks assigned,
so nobody asks. The only related observation available is that the account `whertzing`
appears as the last modifier of four of the five raft items — that is evidence of who has
been doing the syncing, not an assignment of accountability. **The operator must record the
name here before the gate is scheduled.** An unowned gate produces output nobody is
accountable for acting on, which is indistinguishable from no gate.

## Cadence

The cadence is derived from when raft drift can actually be introduced, which is three
distinct moments, not one interval:

| # | Trigger | Why this trigger | Scope of the run |
| --- | --- | --- | --- |
| 1 | **A commit whose changed paths intersect `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/`** — any `.otter` or any runner `.ps1` | This is the moment drift is created. A commit that changes both halves leaves the raft holding the old argument list; that is the whole failure mode. | The affected plan and every plan whose runner changed |
| 2 | **Immediately before queuing any BuildMaster pipeline run** | This is the moment drift bites. Trigger 1 catches drift at creation, but only if the committer's tooling ran; trigger 2 catches it regardless of how it arrived. | The plan being queued |
| 3 | **Weekly, plus once at sprint start and once at sprint end** | This is the trigger that cannot be replaced by the other two. **A raft item can change without any commit** — it is a database row editable through the BuildMaster UI and API, so a plan can be edited on the server, or restored from a backup, with nothing in Git to trigger on. `PowerShellModule-5Stage` sat stale for 10 days and `ReleaseBundle-6Stage` empty since 2026-05-14 precisely because no commit-shaped event ever fired. Weekly bounds that blind window to seven days. | All five plans |

Triggers 1 and 2 are narrow and fast; trigger 3 is the backstop and is the only one that
must cover the full roster. If only one trigger can be implemented first, implement
**trigger 3** — it is the one with no substitute.

**What runs it.** A single non-interactive PowerShell entry point that loads
`$global:settings` from the profile, imports the BuildMaster tooling module, iterates the
roster in § Plans in scope, applies the severity model in § Severity model, writes evidence
per § Evidence retention, and sets a process exit code from the highest severity observed.
Run it **without `-NoProfile`**: base-URL and secret resolution both read `$global:settings`,
which the profile populates, so a no-profile run changes configuration resolution and can
fail for reasons unrelated to drift.

## Severity model

**This is the most important design decision in the gate.** Today
`Compare-BuildMasterPlanRaft` returns `Status = Drift` for four of the five plans, and
three of those four are healthy. A gate wired to the raw `Status` field is a permanent red
light, and a permanent red light is ignored within about two runs — leaving the pipeline
less protected than before the gate existed.

The cause is that `ArgumentNameDrift` is raised whenever the plan and the runner disagree
in either direction, which conflates two situations with opposite meanings:

- The runner declares a parameter the plan does not pass. If that parameter is
  **optional**, this is normal and permanent — a plan is not obliged to pass an optional
  parameter, and every healthy plan in the set does this. If it is **mandatory**, this is
  the 2026-08-03 hang, exactly.
- The plan passes an argument the runner does not declare. The runner fails loudly on the
  next run; broken, but not silent.

The cmdlet emits the raw material to tell these apart — `RunnerParametersNotInPlan` and
`ArgumentsNotInRunner` per runner — but **not the mandatory-versus-optional split**, because
it collects parameter names without their attributes. The gate must therefore compute
mandatory-ness itself, by parsing the runner script's parameter block on disk and testing
each name in `RunnerParametersNotInPlan` for a `[Parameter(...)]` attribute with
`Mandatory = $true`. Unit 15.171.b computed this externally for the same reason. Pushing
the split down into the cmdlet is the correct long-term fix and is recorded as a limitation,
not done here.

The gate classifies each plan's result into exactly one severity, highest applicable wins:

| Severity | Condition | Meaning | Gate outcome |
| --- | --- | --- | --- |
| **Sev-1 — Block** | A runner parameter in `RunnerParametersNotInPlan` is `[Parameter(Mandatory)]` | The silent-forever-hang signature. The next run of this pipeline blocks on an invisible console prompt. | Fail. Block the pipeline. |
| **Sev-1 — Block** | Raft item present and active but **zero-length content** (`EmptyRaftContent`) | No executable plan body is deployed. `ReleaseBundle-6Stage` is in this state today. | Fail. Block the pipeline. |
| **Sev-1 — Block** | `MissingFromRaft` **after** the correct scope and item name from the roster were applied | The plan genuinely is not deployed. | Fail. Block the pipeline. |
| **Sev-2 — Sync required** | `ContentDrift` — hashes differ — with no mandatory parameter missing | BuildMaster is executing a plan that is not the committed one. Not hanging, but not correct either. `PowerShellModule-5Stage` is in this state today. | Fail. Block release of that pipeline; do not block unrelated pipelines. |
| **Sev-2 — Sync required** | `ArgumentsNotInRunner` non-empty — the plan passes an argument the runner does not declare | The runner will error on the next run. Loud, not silent, but still broken. | Fail. Block release of that pipeline. |
| **Sev-2 — Sync required** | `WhitespaceOnlyContentDrift` | The raft was not written from these exact bytes. Behaviourally likely inert, but the provenance claim is false. | Fail, at the owner's discretion to downgrade with a recorded reason. |
| **Sev-3 — Informational** | `RunnerParametersNotInPlan` contains **only optional** parameters | Benign and permanent. This is the case that must never be reported as drift. | **Pass.** Recorded, no action, no notification. |
| **Sev-3 — Informational** | `MissingOnDisk` | The raft holds a plan with no file. Reportable hygiene; it cannot cause the hang. | Pass with a recorded note. |
| **Sev-I — Indeterminate** | `RunnerScriptMissing`, or the runner's parameter block could not be parsed | **The check did not happen.** `AceCommander-ApplicationRelease` is here today. | **Not a pass.** Treated as a gate failure — see § Failure behavior. |
| **Sev-X — Gate failure** | `Unreachable`, secret unresolvable, application lookup failed, roster/disk mismatch | The gate could not form an opinion. | **Not a pass.** See § Availability handling. |

The single sentence a maintainer must not lose: **`Status = Drift` alone is not a gate
result.** The gate's verdict comes from this table, computed from `DriftReasons`,
`ContentMatches`, `ArgumentsNotInRunner`, and the mandatory-ness of each entry in
`RunnerParametersNotInPlan`. Wiring an alert to `Status` reproduces the cry-wolf failure
this section exists to prevent.

## Failure behavior

The gate is **fail-closed**: no result other than an explicit, complete, in-sync comparison
is a pass. Absence of a finding is never treated as absence of drift.

The distinction that drives everything below is **"drift found" versus "gate failed."**
They need different responses and must never be collapsed into one red state:

- **Drift found** — the gate worked. The pipeline is untrustworthy. Response: sync the
  plan, then re-run the gate to confirm.
- **Gate failed** — the gate did not work. The pipeline's state is *unknown*, which is
  strictly worse than known-bad because nobody knows which plans are affected. Response:
  repair the gate, then re-run. **Never** infer a pass from a failed run.

| Result | What is blocked | What is only reported | Notification |
| --- | --- | --- | --- |
| **Sev-1** (mandatory parameter missing, empty raft item, genuinely missing) | The affected pipeline must not be queued. If found by trigger 2, the queue attempt is refused. | — | Owner, immediately, on every run while it persists |
| **Sev-2** (content drift, undeclared argument, whitespace-only) | Release of the affected pipeline. Unrelated pipelines are unaffected. | — | Owner, on first detection and on any change of state |
| **Sev-3** (optional-parameter asymmetry, missing-on-disk) | Nothing | Recorded in the run evidence | None. Silence here is the point. |
| **Sev-I** (indeterminate) | Nothing automatically — but the run **does not pass**, and a pipeline whose check is indeterminate is released on the owner's explicit, recorded judgement, not by default | The specific check that could not be made, and why | Owner, on first occurrence and whenever a new plan becomes indeterminate |
| **Sev-X** (gate failure) | Nothing automatically | The failure reason verbatim | Owner, immediately. Repeated Sev-X on consecutive runs escalates — a gate that has been failing quietly for a week is the same blind window the gate exists to close. |

**An `Unreachable` server must never read as a pass.** `Compare-BuildMasterPlanRaft` already
fails closed at the cmdlet level — any exception in the per-plan path yields
`Status = Unreachable` with the reason and never `Match`. The gate must preserve that
property and not "helpfully" skip a plan it could not reach: a skipped plan and a clean plan
must be distinguishable in both the exit code and the evidence.

**Exit codes** (so a scheduler can act without parsing the report):

| Exit code | Meaning |
| --- | --- |
| `0` | All plans pass. Sev-3 findings may be present. |
| `1` | At least one Sev-2, no Sev-1. |
| `2` | At least one Sev-1. |
| `3` | At least one Sev-I and no Sev-1/Sev-2 — indeterminate, not pass. |
| `4` | Sev-X — the gate itself failed. Distinct from `1`–`3` on purpose. |

## Availability handling

Each of these has a defined outcome, and none of them is "pass":

| Condition | Detection | Outcome |
| --- | --- | --- |
| **BuildMaster server down or unreachable** | The raft query throws; the cmdlet returns `Status = Unreachable` with the exception message | Sev-X. Exit `4`. Every plan in the run is recorded as not-assessed, never as in-sync. Retry on the next trigger; consecutive failures escalate to the owner. |
| **Admin API key secret unresolvable** — vault unavailable, `bws` failure, or the host-suffixed `SecretName` does not resolve | `Get-SecretATAP` throws during setup | Sev-X. Exit `4`. The run aborts before any plan is compared. **The secret name may be recorded; the secret value must never be recorded, logged, or echoed — not even in a failure message.** |
| **Application-scope lookup fails** — `Applications_GetApplications` errors, or the application name does not resolve to an id | `ApplicationId` cannot be resolved for a roster entry requiring it | Sev-X **for the affected plans only** (`ReleaseBundle-6Stage`, `AceCommander-ApplicationRelease`). The global plans still produce real verdicts. The unresolved plans are recorded as not-assessed. Critically, they must **not** fall back to an unscoped query — an unscoped query returns no item and would report a deployed plan as missing, converting a lookup failure into a false Sev-1. |
| **A roster plan's `.otter` file is absent from disk** | `Test-Path` fails for a roster entry | Sev-3 `MissingOnDisk` if the raft item exists; Sev-X if neither side is present, since the roster is then wrong. |
| **A `.otter` file on disk is not in the roster** | Set comparison between `Plans/*.otter` and the roster | Sev-X. A plan the gate does not know about is an unmonitored pipeline, and silently ignoring it is the failure mode that let `ReleaseBundle-6Stage` hide. |
| **Runner script directory not resolvable** | `RunnerScriptDirectory` does not exist | Sev-I for every plan in that directory — content checks still valid, argument checks indeterminate. |

## Evidence retention

Per **SC-0033**, every generated artifact goes under `_generated/` at the repository root.
Gate runs write to:

```text
_generated/BuildMasterDriftGate/<UTC-run-timestamp>/
    DriftGate-Summary.md      # human-readable, one row per plan, severity and verdict
    DriftGate-Result.json     # machine-readable, the cmdlet records plus computed severity
```

**Run the recurring gate from the stable worktree, not a sprint worktree.** Per **R-38**,
`_generated/` under an ephemeral sprint worktree is deleted at sprint end, which would erase
the gate's history exactly when a sprint-boundary comparison is most useful. A run from a
sprint worktree is legitimate for point-in-time verification of a change, but its evidence
is ephemeral by design; only an escalation record placed under `InformationForTheFuture/`
in `_Planning` survives.

| What | Retained |
| --- | --- |
| Every run's summary and JSON | Last 30 runs |
| Any run containing a Sev-1 or Sev-2 | Until the finding is remediated and a subsequent clean run is recorded, then subject to the 30-run rule |
| Any run containing a Sev-X | Until the cause is resolved |

### Metadata-only constraint

**The gate must never write a plan body, a runner script body, a content diff, or any
secret into evidence.** This is not a preference; it is what makes the output safe to
commit, attach to an issue, or paste into a ticket without review.

Permitted in evidence: plan name, raft item name and id, application scope, raft item
version and active flag, SHA-256 hashes, byte lengths, timestamps, modified-by account,
status, drift reasons, computed severity, argument **names**, parameter **names**, and
mandatory-ness. Forbidden: any bytes of an `.otter` or `.ps1`, any diff or excerpt of them,
the API key value, and any resolved secret. A secret **name** may be recorded; a secret
value may not.

`Compare-BuildMasterPlanRaft` already emits metadata only and has a unit test asserting it
(`emits metadata only - no plan body text and no secret value in any record`). Any wrapper
the gate adds must be held to the same standard, and the gate's own evidence should be
scanned for the API key field name and for a distinctive literal from a plan body as a
standing check.

## Known limitations

Carried forward from units 15.171.a and 15.171.b. Each is a real gap in the gate as
currently constituted, with what a maintainer should do about it.

1. **`Status` conflates benign and dangerous asymmetry.** `ArgumentNameDrift` fires for an
   unpassed optional parameter and for a genuinely missing mandatory one alike, so four of
   five plans report `Drift` today and three of those are healthy.
   *Maintainer action:* never wire the gate to `Status`; use the § Severity model. The
   durable fix is to move the mandatory/optional split into the cmdlet so every consumer
   gets it — currently every caller must recompute it.

2. **The `AceCommander-ApplicationRelease` argument check is indeterminate, not passing.**
   The plan invokes `-File "$ApplicationReleaseRunner"`, a BuildMaster *application
   variable*. The cmdlet resolves runner leaf names only from in-plan assignments to local
   OtterScript variables, so it cannot bind the name and reports `RunnerScriptMissing` —
   even though `Invoke-ApplicationReleaseStage.ps1` exists on disk. The content check for
   this plan is valid and passing; only the argument check is missing.
   *Maintainer action:* treat it as Sev-I, never Sev-3. Because the skipped check is
   precisely the check that catches the hang, this gap is more serious than its status
   suggests. Partial mitigation, not a substitute: this is the only plan in the set invoking
   its runner with `-NonInteractive`, so PowerShell throws rather than prompting — it can
   fail, but it cannot hang silently. The durable fix is to resolve runner names supplied by
   BuildMaster application variables.

3. **An empty raft item is reported as `MissingFromRaft`.** Item 2008 exists, is active, and
   stores zero bytes. "Absent" and "present but empty" have different remediations.
   *Maintainer action:* the gate distinguishes them itself via raft byte length (see
   `EmptyRaftContent` in the § Severity model) rather than waiting for the cmdlet to.

4. **The default raft item name assumes the `.otter` extension.** `ReleaseBundle-6Stage`'s
   item is named without it, so the derived lookup misses a plan that is in fact deployed.
   *Maintainer action:* always pass `-RaftItemName` from the roster table for that plan. Do
   not rely on the derived name.

5. **The sync-requirement document is inaccurate about raft scoping.**
   `BuildMaster-Plan-Raft-Sync-Requirement.md` implies four global plan items and places
   `ReleaseBundle-6Stage` among them; the live raft holds three global type-6 plan items,
   and `ReleaseBundle-6Stage` is scoped to application 1003 under an extension-less name.
   *Maintainer action:* use the roster table in this document. Correcting the
   sync-requirement document is owned by a separate unit and was deliberately not done as
   part of defining this gate; when it lands, this note should be reduced to a cross-
   reference.

6. **`Compare-BuildMasterPlanRaft` is not exported by the module manifest.**
   `FunctionsToExport` in
   `ATAP.Utilities.BuildTooling.BuildMaster.PowerShell.psd1` lists 19 names and does not
   include it, so `Get-Command` does not resolve it after `Import-Module`.
   *Maintainer action:* this must be fixed before the gate can be scheduled — a scheduled
   task cannot dot-source a `.ps1` from a module's `public/` folder as a supported entry
   point. Add `'Compare-BuildMasterPlanRaft'` to `FunctionsToExport`. **This is a
   prerequisite for the gate, not an optional cleanup.**

7. **Two live findings are outstanding and require a write.** `PowerShellModule-5Stage` is
   stale and `ReleaseBundle-6Stage` is empty. Both are remediated by `Sync-BuildMasterPlans`,
   which is a write to a live system and was outside the authorization of the units that
   found them.
   *Maintainer action:* remediate both before the gate's first scheduled run, or the first
   run reports two Sev-1/Sev-2 findings that are already known — which trains the owner to
   dismiss the gate's output on day one.

## Related documentation

- [BuildMaster-Plan-Raft-Sync-Requirement.md](BuildMaster-Plan-Raft-Sync-Requirement.md) — the rule this gate enforces, the 2026-08-03 incident, and the manual triage checklist
- [Runbook-BuildMasterConfiguration.md](Runbook-BuildMasterConfiguration.md)
- [BuildMaster-Pipeline-Topology.md](BuildMaster-Pipeline-Topology.md)
- [BuildMaster-Run-State-Runbook.md](BuildMaster-Run-State-Runbook.md)
- [BuildMaster-Install-Runbook.md](BuildMaster-Install-Runbook.md)
- [Runbook-ProGetBuildMasterApiKeyRotation.md](Runbook-ProGetBuildMasterApiKeyRotation.md) — the admin API key whose unresolvability is a Sev-X condition
