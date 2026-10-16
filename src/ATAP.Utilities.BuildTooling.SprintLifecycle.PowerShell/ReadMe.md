# ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell

Sprint lifecycle commands for SprintStart, SprintEnd, worktree teardown, checkpoint archival, and sprint-boundary validation.

Version 0.1.49 recovers a narrowly identified native cleanup failure: Git255 with
the exact permission-denied message for a pre-captured, now-empty administrative
slot. The registration and worktree pointer must be absent, the captured owning
repository and slot identity must match, and the recovery ref must preserve HEAD.
Only that empty directory is deleted nonrecursively, with at most six attempts
for Windows access/sharing/lock errors. The failed Git result stays in the receipt;
captured identity and completion evidence are required for subsequent resume.
Unknown failures, new files, unsafe links or recreated worktrees still stop cleanup.

Version 0.1.39 was verified as the release that a name-only
`Import-Module` resolved to from the AllUsers path on UTAT022. Version 0.1.34 was
the first release to export `Write-GatherCallRecord`. Version 0.1.14 remains the accepted **two-host** deploy state for
service-profile discovery — the claims in the rest of this paragraph were verified at 0.1.14 on both
UTAT01 and UTAT022 and have not been re-verified on UTAT022 since. Service-profile fallback discovery is bounded to `SvcBuildMaster`, `SvcProGet`, and `SvcSQLServer`; an authenticated service identity manages only its own profile, while an operator session may deploy the approved set. Focused discovery tests pass 8/8, isolated SprintEnd lifecycle tests pass 25/25, and all six host/account targets are idempotent at the canonical profile hash.

SprintEnd handoffs invoke `Remove-SprintWorktreeSafely`: teardown is blocked for active
Codex/VS Code roots, retries are bounded, and an incomplete teardown leaves a minimal
retry handoff instead of recursively deleting the worktree.

The parent `ATAP.Utilities.BuildTooling.PowerShell` module retains the legacy command surface by requiring this child module.

## Receipt-backed worktree cleanup

Version 0.1.44 introduces the controls below to `Remove-SprintWorktreeSafely`.
Verify the exact installed version, provenance, and release acceptance before
live cleanup.

- Keep the removal receipt for normal cleanup and recovery. `ReceiptPath` defaults
  to `_generated/SprintWorktreeRemoval/<worktree-leaf>.json` under the owning
  repository. The durable receipt records native removal attempts so recovery
  after Git deregistration does not retry Git removal against a missing entry.
- Supply `OwningRepositoryPath` with the complete owner set. Approve junctions
  through `ApprovedJunctionTarget`, a map from relative paths to exact absolute
  targets. Nested paths must be beneath a selected `ResidualDirectoryRoot`.
  Cleanup requires the observed target to match the approved target and never
  traverses it.
- Use `ResidualDirectoryRoot` only for explicitly selected direct-child directory
  names. Residual trees must be ordinary directories or have the exact native
  cloud tag `0x9000e01a`, verified through `fsutil`; file attributes alone do not
  establish eligibility. Trees must contain zero files before removal.
  Filesystem removals are nonrecursive.
- Use `SelectedNestedWorktree` for specifically selected prunable nested slots,
  with `RepositoryPath`, `WorktreePath`, `Head`, `RecoveryReference`, and
  `AdministrativePath` recorded for each. Cleanup does not run a global prune.
- Recovery from a 0.1.43 failure requires both `AcceptLegacy043Recovery` and
  `LegacyRecoveryEvidencePath`. The legacy evidence uses schema version 1 and
  records `RepositoryPath`, `WorktreePath`, `Head`, `RecoveryReference`,
  `BeforeSnapshotPath`, `FailedReceiptPath`, `InstalledModulePath`, and
  `InstalledModuleSha256`; the installed module evidence must be pinned to
  0.1.43.

Cleanup fails closed when required ownership, receipt, recovery, junction, or
zero-file evidence cannot be verified. An approval does not authorize deletion
of files discovered in a residual directory; preserve the failure evidence and
resolve the reported condition before retrying.

Every resume repeats the active-root check. Legacy recovery JSON is
operator-reviewed evidence without a cryptographic authenticity claim; recovery
also verifies the owning common Git directory, the preserved commit reference,
and the independent absence of the current worktree registration.

## Login scheduled-task lifecycle

[`Set-SprintLoginScheduledTaskTarget`](private/Set-SprintLoginScheduledTaskTarget.ps1)
maintains the existing `ATAPLoginScript` and `Unlock BitWarden` scheduled-task
actions. [`New-SprintStage2`](public/New-SprintStage2.ps1) selects the single
successful active ATAP.Utilities sprint worktree and its
`src/ATAP.Utilities.PowerShell/Profiles/LoginScript.ps1` for SprintStart.
[`Invoke-SprintEndLifecycle`](public/Invoke-SprintEndLifecycle.ps1) selects the
stable ATAP.Utilities login script before sprint worktree teardown.

An explicitly supplied `LoginScriptPath` takes precedence for that invocation
only; supply it again for each lifecycle invocation that needs the development
override. Empty or invalid paths fail closed. A SprintEnd override must survive
the planned worktree removals.

The helper conservatively replaces the recognized login script action binding
while preserving other arguments, actions, task properties, and disabled state.
It compensates attempted writes when an update fails and reports rollback
failures. Cleanup and final boundary checks audit task bindings without writing.
`WhatIf` describes planned changes and does not prove deployment.

Task 15.208 source verification recorded 283 passing tests and 26 existing
skipped tests. Version 0.1.39 passed all five promotion gates in BuildMaster build
21506 (execution 22683), including Production tests with 396 passing, zero failing,
and 99 skipped tests. The package is promoted to `powershellget-stable`, installed
in the UTAT022 AllUsers scope, and verified by a fresh name-only import. The
[live scheduled-task acceptance evidence](../../_generated/Sprint0015/Task15.208/release/live/acceptance.json)
records End, repeated End, Start, and repeated Start for both retained tasks.
Both tasks remain disabled, with their final actions targeting the current sprint
`LoginScript.ps1`; full XML comparison preserves every other task property. This
acceptance covers action maintenance without running the tasks or a full sprint
teardown.

## Gather-call recorder — `Write-GatherCallRecord`

`Write-GatherCallRecord` appends exactly one immutable record per invocation of the
canonical `gather-content-summary` agent: every call, without exception, including
stubbed calls, failed calls, and calls that returned nothing. That last clause is the
whole point — a worker that skipped the mandatory gather step and a worker whose call
returned nothing must not leave the same evidence behind.

It implements `gather-call-record.contract.v1.md` (recordVersion `1.0.0`), which lives
with its companions in
`_Planning/InformationForTheFuture/Sprint0015/StreamM/Task15.183/`.

### Discovery and invocation

The function is exported by this module. Import the module (or, when running from
source, dot-source `public/Write-GatherCallRecord.ps1` — its `begin` block dot-sources
the six `private/` helpers it needs) and call it:

```powershell
Write-GatherCallRecord `
  -Tags @('handoff', 'schema') `
  -AgentName 'junior-dev-coder-sh' `
  -WorktreeRoot 'C:/GitHub/ExampleRepo-wt-1-Sprint-0015-work-items' `
  -TaskId '15.183.B01' `
  -Prompt 'Synthetic example prompt' `
  -Response $envelope
```

`-WorktreeRoot` is **required in effect**. Omitting it is a terminating error, not a
walk-up to the nearest `.git` ancestor: an inferred root is indistinguishable downstream
from a stated one, and since the durable destination is derived from that root's parent,
a guessed root would write a sprint's seed data into whatever repository the shell
happened to be sitting in.

`Get-Help Write-GatherCallRecord -Full` is the parameter-level reference; this section is
the operator's overview and does not restate it.

### Input and output

Inputs are the call's own arguments (`-Tags`, `-Depth`, `-Width`, `-Instance`,
`-Prompt`), the response (`-Response`, or `-NoResponse` when the call threw), and caller
identity (`-AgentName`, `-AgentModel`, `-SessionId`, `-TaskId`, `-ConversationId`,
`-ConversationTitle`, `-RequestResponsePairId`, `-Ordinal`). Derived fields — `outcome`,
`responseStatus`, `stubMarker`, `itemCount`, `truncated`, `responseDigest` — are computed
mechanically from the envelope and are deliberately **not** parameters.

The output is a `PSCustomObject` carrying `Ok`, `Written`, `RecordPath`,
`RecordDirectory`, `InvocationId`, `Ordinal`, `OrdinalScope`, `TimestampUtc`, `Outcome`,
`RecordVersion`, `Redacted`, `RedactionCount`, `Record`, and `Error`. `-PassThruLine`
additionally attaches `Line`, the serialized JSON. It is off by default so a caller
cannot accidentally echo a prompt into a transcript.

On disk each record is one JSON Lines file — one line, minified, UTF-8 without BOM,
terminated by `\n` — named `<yyyyMMddTHHmmssfff>Z-<invocationId>.jsonl`. Keys are sorted
ordinally (RFC 8785 JCS), which is what lets the terminal-less agent half author a
byte-format-identical record by hand. The record's full field set and JSON Schema are in
contract §§ 3, 4, and 9; do not re-derive them from this file.

### Durable versus evidence — the distinction that matters most

Two paths, two lifetimes, and confusing them is the failure this feature exists to
prevent:

| Target | Path | Lifetime |
| :--- | :--- | :--- |
| `-StoreTarget Durable` (default) | `<_Planning sprint worktree>/InformationForTheFuture/Sprint<NNNN>/<Stream>/<TaskFolder>/gather-calls/` | Committed; **merges to stable at sprint end and persists indefinitely** (R-38) |
| `-StoreTarget Generated` | `<WorktreeRoot>/_generated/Sprint<NNNN>/<Stream>/gather-calls/` | Git-ignored; **deleted at sprint end** (SC-0033) |

Durable is the default because the 2026-08-26 rescope parked the handoff-correlation
half. The records are no longer point-in-time evidence feeding a downstream durable
artifact — they *are* the durable artifact: seed data for the Tags database and the
initial prompt-to-tag associations. A record written under `_generated/` would not
survive the sprint that produced it.

Manifests, hashes, counts, and run logs *about* the recorder remain correct `_generated/`
material and are deleted at sprint end as intended. Never cite a `_generated/` path from
a durable document as though it will still resolve later.

**The destination is under `_Planning`; the record body still describes the CALLING
worktree.** `worktreePath` and `repositoryName` name the worktree the gather call ran in.
Only the write destination moved.

Durable is the target *for now*. The operator's stated intent is that records move back
under `_generated/` once the shape settles, which is why the target is a documented
parameter rather than a constant — reversing it is one argument, not a code change.

### Lifecycle timing

A record is written at the moment a gather call is issued, by whichever half made the
call, and is never edited afterwards. `timestampUtc` records the issue time, not the
return time. There is no sprint-boundary step: durable records simply merge with the
`_Planning` sprint branch at sprint end.

**No harvester and no SprintEnd integration exist.** Task 15.183.c (harvesting) and Task
15.183.d (SprintEnd integration) were parked in the 2026-08-26 rescope; the carried-forward
design is in `handoff-correlation.deferred.v1.md`. References to "the harvester" in the
contract and in the function help describe the reader the format was designed for, not
something callable today.

### Concurrency

Concurrency-safe **without locking**, by construction rather than by discipline:

1. **Never overwrite.** Each record is staged to `_partial-<guid>.tmp` and published with
   the two-argument `[System.IO.File]::Move` overload, which refuses an existing
   destination. That refusal *is* the mutual exclusion.
2. **Never tear.** The line is serialized in memory, written in one `Write`, and forced
   to stable storage with `Flush($true)` before the name is published, so a `*.jsonl`
   glob can never observe a partial file. The residue of a crash is an inert `.tmp`.
3. **Never double-count.** `invocationId` is minted per call — there is no
   `-InvocationId` parameter — so a repeated write of the same id is a loud name
   collision, not a silent duplicate.

One caveat consumers must know: **`ordinal` is neither dense nor unique under
contention.** A measured run of 30 concurrent records in one session scope produced 11
distinct ordinals, gapped as well as duplicated. Do not read a gap as a missing record.
Total order is still well defined through contract § 8's four sort keys, ending in the
unique `invocationId`. Supplying `-Ordinal` avoids the race outright.

### Compatibility and versioning

Every record carries `recordVersion`, fixed at `1.0.0`. Additive changes bump the minor
version and readers must ignore unknown fields; removing or renaming a field, narrowing a
type, or changing the digest algorithm is a major bump requiring a new contract document.
Records of differing major versions must not be merged into one corpus without an
explicit migration.

Companion contracts `worker-handoff-changed-file.contract.v1.md` and
`correlated-corpus.contract.v1.md` are **parked**, not binding. Only
`gather-call-record.contract.v1.md` governs current behaviour.

### Troubleshooting

| Symptom | Cause and action |
| :--- | :--- |
| Terminating error naming `WorktreeRoot` | `-WorktreeRoot` was omitted, blank, or unresolvable. Supply it explicitly; there is no walk-up and no switch to re-enable one. |
| `Error` reads "No _Planning sprint worktree for Sprint `<NNNN>` was found beneath Git root …" | No `_Planning-wt-<issue>-Sprint-<NNNN>-work-items` folder sits beside the calling worktree. Supply `-PlanningRoot` or `-StoreRoot`, or use `-StoreTarget Generated`. |
| `Error` reads "Ambiguous _Planning sprint worktree for Sprint `<NNNN>` beneath …" and names two folders | Two candidate worktrees exist for one sprint. The resolver refuses to pick, because choosing would scatter seed data across two stores. Supply `-PlanningRoot`. |
| `Ok = $false` with an `Error`, but the worker continued | Working as designed. Store resolution and write faults are **non-terminating**: a recorder must never fail the gather call it is recording. Escalate with `-ErrorAction Stop` if the caller wants it fatal. |
| Nothing on disk after a call | Check `-WhatIf` was not in play (`Ok = $true`, `Written = $false`) and read `RecordPath`. |
| `redactionCount: 0` on a prompt that contained a secret | Redaction is **keyword-anchored, not a secret scanner**. The same high-entropy value redacts after `password=` and passes through standing alone. Contract § 5.5 permits this. Do not rely on the recorder to catch a bare secret. |
| `redactionCount: 0` on a response that contained a secret | Correct: the redactor never sees `items[]` because contract § 4 forbids persisting response content at all. Containment here is non-persistence, not redaction. |
| `prompt: null` with `redactionCount: -1` | The redaction sentinel: redaction was unavailable, so content was withheld rather than written unredacted. |
| `itemCount` always 0 and the digest always identical | Expected. ContentSummary retrieval is stubbed (`CONTENT_SUMMARY_RETRIEVAL_NOT_IMPLEMENTED`, blocked on RDB-190, RDB-260, Stream D), so `items` is `[]` and `responseDigest.value` is the empty-array constant with no discriminating power. Distinguish stubbed-empty from genuinely-empty by `stubMarker`/`responseStatus`, never by the digest. |
| An orphan `_partial-*.tmp` in the store | Residue of an interrupted write. Inert and invisible to a `*.jsonl` glob; safe to delete. |

Exercising the recorder against the durable store without closing the sprint is a recorded
reusable procedure: see section `procedure-exercise-durable-recorder-without-closing-sprint`
in `Tasks.Sprint0015.ProceduralDetails.html`.

## Functional area

PowerShell Build & Packaging - START HERE: `SolutionDocumentation/PowerShell-Modules-Build-Process.md`.

Task 16.12 release replacement 0.1.47 isolates the settings audit in unrelated
SprintEnd unit fixtures and retains the real fail-closed settings regressions.
UTAT022 installed acceptance is recorded in the Planning Task16.12 deployment
handoff; UTAT01 remains separately scoped under Task16.64.

Version 0.1.48 bounds retries of transient atomic receipt-replacement failures
without repeating worktree removal. Persistent denial preserves the prior receipt
and fails closed after six attempts; no permission or attribute changes are made.
