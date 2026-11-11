# Coordination-v1 prose contract

Status: authored for distinct review and coordinator acceptance; no runtime or
schema acceptance is asserted. Task 17.19.b / C17.1.b, Sprint 0017.
Correction 01 addresses distinct-review findings F01-F04.

This document states the semantic obligations of the initial existing-task
PowerShell clerk. Outside S1-S4, MUST, MUST NOT and REQUIRED express obligations
traced below to the adopted plan. Within S1-S4 they express proposed binding
rules conditional on acceptance. Semantic labels describe observable meanings; they are not
an approved JSON schema or numeric enumeration. The sections marked Proposal
S1-S4 supply new deterministic semantic choices for review, grounded in the
adopted obligations. They are author proposals, not operator-adopted decisions.
If accepted by the coordinator after distinct review, they bind downstream
schemas and implementation. Until then no producer may treat them as accepted.
Remaining representation and runtime gates are recorded in the final section.

## Authority and traceability

The governing adoption [G] and subsequent acceptance [A] establish the authority
of the frozen R2 documents despite their historical draft headings. This prose
does not grant implementation, pilot, configuration, package or live authority.
References use original source line numbers and clause IDs. Relative links bind
the current sibling sprint worktrees; future relocation must rebind these links.

| Ref | Original adopted source | Normative clauses used |
| --- | --- | --- |
| P | [Detailed plan](../../../../_Planning-wt-44-Sprint-0017-work-items/InformationForTheFuture/Sprint0017/SprintStartPlanning/Codex-V3-Astra/plan/02-Sprint0017-Detailed-Plan.md) | Lines 104-147, C17.1-C17.14; line 290 C17.1a; lines 309-315 integration matrix |
| D | [Operator decisions](../../../../_Planning-wt-44-Sprint-0017-work-items/InformationForTheFuture/Sprint0017/SprintStartPlanning/Codex-V3-Astra/plan/03-Operator-Decisions.md) | D01-D03, D05-H, Remaining D05, D11; Pilot ownership and coordinator transfer |
| I | [Dependency and integration register](../../../../_Planning-wt-44-Sprint-0017-work-items/InformationForTheFuture/Sprint0017/SprintStartPlanning/Codex-V3-Astra/analysis/Dependency-and-Integration-Register.md) | DEP04/05/08/09; INT01-04 lines 41-44; qualification line 53 |
| G | [Governing plan V1](../../../../_Planning-wt-44-Sprint-0017-work-items/InformationForTheFuture/Sprint0017/GoverningPlan/Sprint0017-Governing-Plan-V1.md) | Adoption lines 3-7; selected outcome and transfer lines 13-15 |
| A | [R2 acceptance record](../../../../_Planning-wt-44-Sprint-0017-work-items/InformationForTheFuture/Sprint0017/SprintStartPlanning/Sprint0017-V3-Astra-R2-Acceptance.json) | Status, AcceptedRevision, ManifestSHA256, FrozenPacketTreatment, ImplementationAndLiveOperations |

Byte pins of P, D and I, respectively, are SHA256
`2385B3BB0741D785179F1485663C036D80C0AF17A6C1A4DA9A70B6299617721A`,
`D8BAB7123B0BFCBEC0B6AD0B443479A2E699C194B7FB3432CC985F2A3FD04098`,
and `C173C25230F58D3761297123E7AFCFAC863AA06206B1E6E6FB0B916CA638AA85`.
The accepted review-set manifest pin is
`05620FCB41907AE3F0A07DEC6AAA255023EB1B6281BB5A4AAE934095592D0B2B`.
The worker report records current hashes; pins do not prove runtime behavior.

## Scope, vocabulary and authority

The clerk MUST serve existing tasks only. Its public operations are
`Submit-CoordRequest`, `Get-CoordTask`, `Get-CoordResult`, `Get-CoordClaims`,
`Invoke-CoordClerk` and `Stop-CoordClerk`. Query operations MUST NOT render or
mutate boards. Bounded drains are coordinator-invoked; permanent loops and Git
services are outside this contract. [P: C17.4, C17.11-12, lines 135-138]

The request vocabulary MUST distinguish coordinator-authorized claim, result
report (`ReportResult`), coordinator acceptance of an existing-task change, and
release. Proposal S1 defines their inputs below; exact serialized kind strings
await schema acceptance. Requests MUST NOT
allocate or append tasks, reorder/delete board items, execute arbitrary commands
or elevate roles. Unknown tasks and unsupported kinds require explicit typed
outcomes, never implicit task creation. Reporting a result MUST NOT check off a
parent. [P: lines 104-116, C17.5-8, line 147]

The coordinator retains planning judgment, claim ownership, contract acceptance,
dispatch, dependency advancement and integration. Workers submit within exact
delegated scopes; they MUST NOT directly edit boards or independently take or
release claims. Distinct review remains required before pilot use. The clerk is
the executor of accepted changes, not an independent planning authority.
[P: lines 112-116; D: Pilot ownership and coordinator transfer]

## Request identity, immutable content and results

### Proposal S1: identity, operation inputs and canonical equality

Basis: P C17.1/5/6/7/8 and I INT01 require stable identities, changed-payload
conflicts and immutable retry results. The following equality and namespace
choices are proposed to make those obligations deterministic.

The identity key is (registered canonical board resource ID, request ID).
Request IDs are nonempty opaque case-sensitive strings assigned by the active
coordinator, unique for the entire resource lifetime across sprints, sessions,
generations, restore and migration. Resource registration identity survives
relocation and restore; a new path/session cannot create a fresh deduplication
namespace. IDs MUST NOT be reused, including after rejection or cleanup. Where
retention removes full content, retained identity/digest/outcome evidence must
still prevent reuse; an inability to answer safely holds admission.

Each request binds all common semantic inputs: protocol version, resource ID,
sprint ID, request ID, category, task ID, exact owned scope, holder/session,
coordinator authorization reference, admitted generation, expected revision,
ordered predecessor request IDs, and category-specific payload. Predecessor
IDs are unique and local to the same resource. Every semantic input is digest
covered; none of holder, authorization, scope, generation or predecessors is
transport-only. Authorization references are verified against admitted authority,
not treated as self-authenticating grants.

| Category | Required payload and specific authorization |
| --- | --- |
| Claim | Existing task, requested exact scope and holder/session; coordinator grant binds those same values. No overlapping active exact/ancestor claim. |
| ReportResult | Existing owned claim identity, outcome classification (source-ready, failed or blocked), evidence references with digests and stated limits. Only that holder/session or explicitly authorized coordinator may report. No completion/acceptance effect. |
| AcceptChange | Existing task, exact Applied reported-result request ID, evidence binding, and explicit coordinator-approved task annotation/status change. Approval applies to that task only; parent status requires its own explicit independently justified request. |
| Release | Existing claim identity and scope, bound holder/session, and release reason. An active holder or coordinator must be authorized; release changes claim custody only. A result report is not required to release blocked work. |

The category words above are semantic constants for this proposal; schemas map
them one-to-one to wire values and cannot merge report, approval and release.
Common inputs remain required for every category; no absent field receives an
inferred default. Query and stop/drain calls are control/read operations, not
additional board-mutation request kinds. Allocation/append/delete/reorder and
arbitrary executable payloads remain rejected.

Claim applies only when that exact requested ownership is free. ReportResult
requires its claim to be active at preparation; otherwise reject ClaimConflict.
AcceptChange requires the report to identify that same task/claim and be an
Applied predecessor, with evidence still matching its digests; otherwise reject
ResultConflict. Failed/blocked reports can support annotations, not a completed
status. Source-ready is not deployed-done; any completion approval must explicitly
bind the applicable task's full acceptance evidence. Release requires the exact
active claim, and closes only it; an already-released claim under a NEW request
is ClaimConflict. Same-ID release retry still returns its original result.

Canonical equality is equality of the canonical bytes of the entire validated
request, excluding only its supplied digest field. The digest is SHA256 of those
bytes, represented as lowercase hexadecimal; a submitted digest must match the
recomputed value exactly. Transport delivery IDs, filenames and receipt times
live outside the request and have no equality or authority effect.

Canonical bytes are compact UTF-8 JSON without BOM, using the later schema's
exact fixed property names. Parse strictly: reject duplicate member names after
escape decoding, unknown properties, malformed Unicode, and missing required
properties. Decode escapes before comparison; perform no Unicode normalization,
case folding or path rewriting. Objects sort member names by unsigned UTF-8 byte
lexicographic order; arrays retain order. Strings use literal valid Unicode
scalars except quote/backslash escaped as backslash-quote/backslash-backslash,
and U+0000-U+001F encoded as lowercase six-character backslash-u00xx escapes.
No optional slash escape or insignificant whitespace is emitted. Boolean/null
tokens are lowercase. Numbers, where allowed by schema, are integer JSON tokens
only: no fraction/exponent; canonical signed decimal has no leading zero and
negative zero becomes zero. Semantic version/revision/identity tokens are
strings, never floating numbers. Exact schema numeric bounds remain downstream.

Consequences: member order, insignificant whitespace and equivalent string
escape spellings do not change equality; string case, Unicode scalar sequence,
array order, explicit null versus absence and any changed semantic input do.
Absence of a required input is invalid, not equal to null. Scope paths that
resolve to the same place but have different strings are changed content for
retry identity; containment is separately checked on resolved paths. Unknown
fields cannot be silently ignored when computing equality. Digest mismatch or
malformed input never overwrites an existing request record.

Each request MUST bind its version, stable request identity, sprint/resource,
operation category, target existing task/scope, coordinator-bound holder/session,
generation, expected revision, causal predecessors and payload digest. These are
required semantic information, not final wire field names. A timestamp, filename
or a fresh ID MUST NOT substitute for any applicable precondition.
[P: C17.1, C17.5-7; I: INT01]

Submission MUST persist an immutable request and its digest. Failed persistence
MUST NOT report acceptance. Same-ID/same-payload retry MUST resolve to the same
retained operation/result, including pending or recovery status, without a second
effect. Same-ID/changed-payload MUST be rejected as a typed identity conflict;
the original immutable request/result survives. Validation must compare the
bound content, not trust a supplied digest alone. S1 supplies the proposed
canonical content function. S3 fixes retry precedence. [P: C17.5-6; I: INT01]

Queue acceptance means durable submission, not claim grant, board publication,
coordinator acceptance or feature completion. Results MUST distinguish pending,
prepared, applied, rejected and recovery meanings and retain enough identity,
digest and outcome information to answer retries. `Stop-CoordClerk` retains
queue/state and MUST NOT imply a completed drain. [P: C17.6, C17.11]

## Revision, generation and causal order

Expected revision identifies the board state against which the operation is
authorized. Generation identifies the admitted state/publication context; it
MUST NOT be silently refreshed to make an old request valid. A fresh request ID
with stale revision, an old holder/session or stale generation MUST NOT mutate.
S2 defines tokens/events and S3 selects the typed rejection outcome.
[P: C17.1, C17.5, C17.7; I: INT01, INT03]

Causal predecessors MUST be evaluated before applying a dependent operation.
A release that arrives before its claim MUST NOT overtake it. Filename ordering,
arrival time and wall-clock sorting MUST NOT replace causality. A dependent
operation with an unmet predecessor remains non-mutating. S3 distinguishes
pending, rejected, missing and incompatible predecessors with definite outcomes.
[I: INT01; P: C17.5, C17.11-12]

### Proposal S2: revision, authority generation and batch commit

Basis: P C17.1/9/10/12 and I INT01-03 require exact preimages, stale-authority
denial and no complete mixed generation. Revision is proposed as an opaque
unique committed-head token for the canonical board resource, covering its
logical claim/reservation/task state and exact quartet output manifest. Equality
is exact token equality within the admitted generation, not timestamp order.
Each committed mutating batch advances the revision once, even if it changes
only durable claims/results and leaves the quartet bytes unchanged. Rejected
requests, queue acceptance, queries, stop and preparation do not advance it.

Generation is a separate opaque authority epoch. It changes only on explicitly
approved first admission or re-admission after custody/owner transfer, compatible
restore, or coordinated manual board addition. It does not change on ordinary
drains, batch preparation, publication or process restart under the same proven
custody. Never reuse a retired epoch. No incrementing starting number or clock
is implied. Claims/import receipts must be explicitly bound to the new epoch;
old queued requests cannot acquire it by rewriting their immutable content.

A publication generation is the pair (authority epoch, committed revision).
Prepared records retain the base pair, immutable batch membership, proposed
next revision, exact before/after state and quartet manifest. Readers obtain the
durable committed head plus any incomplete prepared record; mixed files are
reported NeedsRecovery with the old committed head and proposed pair, never as
the new complete pair. A head is usable as complete only when all manifest
digests and state agree; delayed external replacement immediately holds admission.

Commit occurs when every prepared after-image is verified and a durable commit
receipt binds the new head, batch results, reservations and exact output manifest.
Publication without that receipt is incomplete even if every file is already
after. Recovery then verifies images and completes that same prepared receipt
and proposed revision once; it never generates a second revision for a retry.
Restart after the receipt returns retained results at that head. A third-state
output prevents the receipt and holds recovery. This logical commit rule adds
no filesystem atomicity or power-loss guarantee; implementation must prove its
durable record protocol separately.

For a bounded batch, validate eligible requests against one committed base head
and epoch. Only requests with all predecessors already Applied before the batch
may join; causal chains are never collapsed within the batch. Among those
eligible requests, durable queue acceptance ordinal selects membership order;
it is not a filename/time or authority override. Requests expecting another
revision are rejected, not rebased. Independent valid requests sharing the base
revision can join one batch and produce one next revision. Their effects must
have disjoint task/scope/claim/reservation footprints; touching the same task or
an ancestor scope is a conflict, even if different categories are used. Earliest
eligible ordinal wins; a later overlapping candidate is rejected BatchConflict,
not silently moved into a new batch. Outstanding candidates that missed the
batch face the new head on revalidation and reject RevisionConflict if stale.

Recover all prepared work before selecting a batch. Revalidate authority and
preconditions immediately before preparation; custody uncertainty or any external
board mismatch holds the resource. One renderer call covers each changed batch;
an unchanged quartet requires none. An empty/rejected-only drain creates no new
revision. These batch choices favor explicit resubmission over implicit rebasing.

## Registered resources and path containment

Requests MUST bind registered roots and authorized sprint/board resources.
Validation MUST reject a root/path outside the registered scope, including a
path alias that defeats containment. Exact and ancestor ownership conflicts
MUST be recognized. An unregistered absolute path, traversal through a relative
path, or an alias resolving outside the authorized root cannot gain authority
from string-prefix agreement. Unresolved containment MUST NOT admit mutation.
[P: C17.1, C17.5, C17.7, integration matrix line 311]

Implementation must bind and test actual path normalization, case handling,
separator boundaries and junction/symlink resolution before accepting requests.
These are required containment cases, not a specified resolver implementation.
No registration, filesystem access grant or repository identity is invented by
this document. Deferred history repository mapping is not clerk authorization.
[P: C17.5/7; D: Remaining D05 and retained repository identity consumer gate]

## Claims, reservations and legal transitions

Claims MUST bind the coordinator-authorized holder, session, generation and
exact scope. A duplicate/conflicting exact or ancestor claim MUST NOT grant
ownership. Expiry alone MUST NOT cause takeover. Release of a source claim
MUST NOT complete a feature or reassign custody implicitly. [P: C17.7]

Reservations MUST remain request-bound and persist with prepared operations.
Previously imported reservations survive board gaps and the rejection of new
allocation/append requests. Absence from the visible board MUST NOT free an
unpublished reservation or erase a prior identity. [P: C17.8-9; I: INT04]

| Semantic state | Permitted progression and effect |
| --- | --- |
| Pending | Durably submitted; may wait for validation, authority or causality. No applied board effect is implied. |
| Rejected | Typed non-applied result for an invalid/conflicting request; preserve identity and retry outcome. |
| Prepared | Immutable before/after images, digests, output manifest and reservations persisted before publication. |
| Applied | Exact prepared after-state/publication is recognized; retain result and retry identity. |
| NeedsRecovery | Interrupted or conflicting publication/state requires recovery before new mutation; never advertise a complete generation. |

The table states minimum observable meanings, not an exhaustive serialized enum.
Validation precedes publication; preparation precedes any published change;
recovery precedes new mutation. Rejected input cannot bypass preparation to
become applied, and conflict cannot be resolved by overwriting third-state
bytes. No timeout transition, automatic owner reassignment or automatic
coordinator acceptance is introduced. [P: C17.5, C17.9-12; I: INT01-03]

### Proposal S3: decision precedence and legal state edges

Basis: P C17.5/6/11 and I INT01 require a frozen wait/reject policy and stable
retry results. Outcome labels below are semantic reason codes; schemas preserve
their distinctions. Apply these checks in the listed order. A later condition
cannot override an earlier returned result.

| Order | Condition | Definite outcome and effect |
| --- | --- | --- |
| 1 | Caller lacks permission to submit/query this registered resource, or envelope cannot be safely parsed/canonicalized | Denied or InvalidRequest; no request acceptance, identity reservation, result disclosure or board mutation. This transport response does not consume an unknown request ID. |
| 2 | Existing identity key, different canonical bytes | IdentityConflict; original record/result unchanged, even if revision/session is also stale. |
| 3 | Existing key, same canonical bytes but supplied digest mismatches recomputation | DigestMismatch; no replacement, original result retained. |
| 4 | Existing key, same bytes and valid digest | Return its current retained status/result before checking authority/revision for a NEW operation. Applied/Rejected terminal result is returned even after epoch retirement, subject to current result-read permission. Pending/Prepared/NeedsRecovery returns that state, not a new attempt. |
| 5 | New key with wrong digest, unsupported version/kind, invalid required fields, unknown task, escaped/unregistered scope or duplicate predecessor IDs | Reject with specific invalidity reason; no effect. Persist a terminal rejection only for a safely validated identity namespace and authorized submitter; otherwise use order 1's non-admitted response. |
| 6 | New key with retired/wrong epoch, invalid holder/session or coordinator authorization | Rejected AuthorityConflict. Generation mismatch takes precedence over revision conflict. No authority is inferred from queue position or elapsed time. |
| 7 | Self predecessor, cycle, missing predecessor record, or predecessor from another resource | Rejected CausalCycle, MissingPredecessor or ForeignPredecessor respectively. Never wait for a request that has not durably arrived. |
| 8 | Any predecessor is Rejected or identifies an incompatible target/claim/category relationship | Rejected PredecessorFailed or PredecessorMismatch; it cannot later become pending merely by retry. |
| 9 | All predecessors exist but at least one is Pending, Prepared or NeedsRecovery | Pending WaitingForPredecessor; no mutation. Do not evaluate revision as authority to bypass that wait. NeedsRecovery also holds new mutation resource-wide. |
| 10 | Predecessors are all Applied; expected revision differs from current committed head | Rejected RevisionConflict; no rebase. |
| 11 | Wrong claim holder/state, overlapping active claim, expired holder takeover attempt, stale report approval or batch overlap | Rejected ClaimConflict, ResultConflict or BatchConflict as applicable; no implicit ownership/status change. |
| 12 | All checks satisfied but resource recovery/custody is held | Pending ResourceHeld, with explicit reason; no preparation until proven clear. |
| 13 | All checks satisfied and resource admitted | Pending Eligible, then Prepared only through the persisted immutable preparation record. |

When multiple predecessor errors of the same priority exist, report all of that
priority in ordinal predecessor-ID order. Cycle takes precedence over missing
and foreign references at order 7; missing takes precedence over foreign.
Schema/containment errors at order 5 may report all invalidities without changing
the non-applied outcome. Fresh requests arriving while custody cannot safely
accept queue writes receive non-admitted ResourceHeld; do not report durable
Pending if persistence is unavailable. A failed submission reports
PersistenceFailed and cannot claim a durable rejection or acceptance.

For a persisted Pending operation, each scheduler reconsideration revalidates
orders 5-13 against its immutable content; the existing-key retry shortcut is
only for answering submissions, not for bypassing scheduler checks. A pending
predecessor that later applies may make the dependent request's expected
revision stale: reject RevisionConflict then, and require a new authorized ID
with the observed head. A pending request from a retired epoch becomes Rejected
AuthorityConflict when safely reconciled under the new owner. No timeout,
automatic expiry takeover or synthetic predecessor success exists. Because
new requests must reference existing records, forward-reference cycles cannot
be admitted; S4 rejects cycles in the non-Rejected dependency graph while
preserving terminal rejection evidence without executing its invalid references.

| From | Legal next state / condition |
| --- | --- |
| No durable record | Pending after validated persistence, or Rejected with retained reason when safely recordable. Failed persistence remains non-admitted. |
| Pending | Pending with an updated wait reason; Rejected after a failed recheck; Prepared only after immutable images/reservations persist. |
| Prepared | Applied after S2 commit; NeedsRecovery on interruption, mismatch or custody uncertainty. Never back to Pending or directly Rejected. |
| NeedsRecovery | Remains NeedsRecovery until custody/preimages are reconciled; returns to Prepared to complete the SAME exact prepared plan, then Applied. No new payload, membership, revision or authority is silently substituted. |
| Applied | Terminal. Retries/readback return Applied and original commit/result; never replay effects. |
| Rejected | Terminal. Retries/readback return the retained rejection; corrected work requires a new ID. |

Pre-prepare rejection releases only that request's provisional claim attempt;
it cannot release imported or other requests' reservations. Prepared reservations
are never freed by rejection/cleanup. An unresolvable prepared third-state
conflict stays NeedsRecovery for explicit coordinator/custodian resolution;
automatic rollback/cancellation and force-apply are not legal edges in v1.
`Stop-CoordClerk` stops admitting/draining as requested, retains durable state,
and reports pending/prepared/recovery work. It changes no operation terminality.

## Publication, retry and recovery

The active board MUST be the highest active version. Untouched content must be
preserved; parsing must distinguish task IDs from task-like prose and detect
duplicate IDs. Changed batches use the existing renderer once per changed batch;
queries do not render. [P: C17.3-4, C17.12]

Before publication, persist the immutable prepared operation with exact
before/after images, digests, reservations and output manifest for the board
quartet. Recovery compares every affected output with those images: before can
advance to the prepared after-image; already-after is recognized without a
second effect; an unexpected third version MUST preserve conflict and hold.
Mixed outputs after interruption MUST NOT advertise a complete generation.
Recover before accepting new mutation. [P: C17.9-12; I: INT02]

The contract makes no cross-file atomicity or tested power-loss durability
claim. Retry/reservation outcomes MUST survive for the applicable closed-sprint
and migration retention contract; diagnostic cleanup MUST NOT erase deduplication
obligations. Optional history loss under D05-H does not authorize loss of active
clerk recovery state. [P: lines 140-145; D: D05-H; I: INT02/04]

## Bootstrap, state loss, compatibility and custody

An explicitly admitted first bootstrap is distinct from missing established
state. Missing established state or the configured state root MUST fail closed;
the clerk MUST NOT silently initialize an empty replacement, reconstruct from
the visible board alone, or fall back to Dropbox/ephemeral storage.
S4 specifies the proposed first-use witness and admission predicate below.
[P: C17.1, C17.9, C17.13]

Bill is accountable active-state custodian. Configured protected ProgramData
custody, automated protected backups and verified clean compatible restoration
are required before pilot admission. Export/import MUST retain active claims,
unpublished reservations, pending/prepared operations, immutable requests,
before/after images, receipts and retry results with their identities. Restore
must compare the retained state and retry original requests in a clean configured
location. [P: C17.13; D: D11; I: INT04]

Restoration MUST NOT overwrite a live writer. Drain or hold, preserve current
evidence, and activate only a compatible state/package pair; failed restore
blocks pilot. Unknown/incompatible schema or package compatibility MUST NOT be
treated as an empty or healthy state. Compatibility versions, export envelope,
migration route and actual rollback matrix entries require later evidence;
S4 specifies the minimum compatibility/admission predicate.
[I: INT04; P: C17.13-14]

### S4: external first-use witness and compatibility predicate

Basis: P C17.1/9/13, D11 and I INT04 require distinguishing first use from state
loss, Bill's custody and compatible restoration. The following is a logical
admission protocol; exact protected locations/envelopes are downstream. It adds
no service, automatic provisioning or permission grant.

The coordinator subsequently selected file-based Bill/Windows-account custody:
the custodian maintains a protected record under ProgramData, outside Dropbox and
the replaceable state directory. Runtime verification must check the configured
Bill SID, actual Windows identity, record ownership and ACL, and the bindings
below. Chat identifiers are cooperative correlation and role identifiers, not
OS-authenticated identities. An exclusive FileStream lease serializes resource
access, and manual-to-clerk handoff also observes CoordinatorBoard.lock. First use
requires explicit custodian approval and setup; absence of a directory is not
approval. This decision does not itself establish the record or authorize pilot
admission. The previously accepted contract digest refers to the earlier frozen
text; this paragraph records the subsequent mechanism decision.

Admission requires a trusted custodian-authorized resource custody record
outside the replaceable clerk state root and the synced board/ephemeral worktree.
Its trust comes from explicitly bound custodian approval and protected custody,
not a self-declared field inside a request. It binds immutable resource identity,
registered canonical roots, board quartet baseline digests, state-lineage ID,
authority epoch, selected coordinator/holder, package/schema compatibility
approval reference, and its admission mode. The independent reviewer must verify
these bindings before pilot admission. A copy within the lost state root alone
does not meet this witness rule. Missing, conflicting or unverifiable custody
records always hold admission; directory absence is never first-use evidence.

| Custody evidence and observed state | Admission outcome |
| --- | --- |
| Explicit unconsumed FIRST_USE approval by Bill attests no established lineage for this resource, exact baseline/import claim inventory is approved, roots/owner/exclusion/compatibility predicates pass, no conflicting custody record | Eligible for controlled first bootstrap, not yet active. |
| FIRST_USE approval but established state data exists or resource is recorded as already established | Hold CustodyConflict; never overwrite or initialize. |
| No custody record or only an untrusted first-use assertion; state absent | Hold MissingCustodyEvidence; cannot bootstrap. |
| Established/consumed custody record; state missing or partially initialized | Hold StateLoss/NeedsRecovery; restore/reconcile the same lineage, never issue replacement FIRST_USE. |
| Established record and state present, matching lineage/head/epoch and all predicates | Reconcile outstanding preparation before admitted mutation; ordinary restart does not mint a new epoch. |
| State or custody disagrees about resource, lineage, baseline, epoch or compatibility | Hold CustodyConflict; preserve both and obtain explicit reconciliation. |

Before creating the initial state, durably mark FIRST_USE consumed/establishing
in the external custody record, retaining its unique bootstrap operation ID and
proposed lineage/epoch. This is monotonic: no consumed approval becomes unused.
A crash before or after creating state therefore requires recovery of the same
bootstrap, not a second first-use decision. Persist the initial state and import
receipt, verify baseline/current claims/reservations and empty-or-explicitly-bound
pending set, and record the matching established custody receipt before admitting
mutation. Partial external/state updates hold; they never imply atomicity.
The registered state root must already exist under separately approved setup;
missing configured root fails rather than being automatically created by drain.

Explicit restore/re-admission records bind the same resource/lineage, selected
export or checkpoint digest and head, reconciled complete board baseline,
preserved immutable requests/results/reservations, retired and fresh authority
epochs, permitted active claims rebound to the fresh epoch, and current sole
coordinator. Do not rewrite old requests to the fresh epoch. Compatible recovery
completes Prepared plans in their recorded historical epoch under explicit
recovery authority before new-epoch mutation; their original results remain
deduplicated and the re-admission receipt links both epochs. A pending old-epoch
request follows S3's AuthorityConflict rule after reconciliation. Unresolved
prepared work blocks admission. The replacement coordinator cannot simply
declare the old epoch current.

Compatibility is true only if an explicitly approved compatibility record names
the exact consuming package version AND artifact digest, Coordination-v1
semantic revision/canonicalization profile, exact request/state/result and export
schema versions, supported prepared-journal format, and any source-to-target
restore/rollback pair. All required read/write/recovery capabilities must be
listed; absence means unsupported. Version-label equality or a shared major
version alone is insufficient. Unknown tuples, changed bytes under a version,
implicit migrations and unapproved rollback pairs hold IncompatibleState before
any mutation. Actual version/digest matrix rows await the real release producer.

Import validation must verify the approved export digest and schema, exact
resource/lineage/head, complete quartet/images/manifest consistency, unique
request IDs and canonical digests, immutable terminal outcomes, active claims,
unpublished reservations, all original predecessor fields as evidence, and the
dependency graph of non-Rejected records. Reject duplicate identities, omitted
deduplication obligations and invalid executable dependencies; never infer
missing records from visible board rows. Prepared records require their complete
base/after images and receipt status.

An authentic retained Rejected request is immutable historical evidence, not
executable work. Preserve its complete original request, digest, references and
terminal rejection receipt, including missing, foreign or self/cyclic references
that caused rejection. Verify their identity/digest/result binding and protected
export/custody provenance; do not require that rejected input satisfy current
dependency preconditions or reclassify its original reason. Such references are
not outgoing edges of the executable dependency graph and do not alone invalidate
restore. Missing referenced requests MUST NOT be fabricated, fetched from another
resource, or declared Applied. A mere Rejected label without authentic retained
result/provenance cannot excuse corrupted work; integrity or result-binding
failure holds import. Never rewrite/delete the invalid references or original
rejection to make an import pass, and never change a Rejected record to runnable.

For every non-Rejected record, validate the complete local predecessor edges:
each target must exist in the restored evidence set under the same resource;
self references, cycles among non-Rejected records, missing targets and foreign
edges hold InvalidImport. A reference TO authentic Rejected evidence is resolved,
not missing, but is never successful: a Pending dependent remains non-executable
and follows S3's PredecessorFailed rejection at scheduler reconciliation. Prepared,
NeedsRecovery and Applied records require all predecessors to be Applied as
required at preparation; a Rejected predecessor there holds InvalidImport.
Historical Rejected records never enter a drain or satisfy an Applied predecessor
condition. After restore, exact retry uses S3's retained terminal-result precedence
and returns the original rejection without re-evaluation or mutation, even if a
formerly missing target has since arrived. Changed content under the same ID
still conflicts; corrected work requires a new authorized request ID.

No live writer may exist
at the target; state/package compatibility and sole-writer exclusion must pass
before restore, and clean-restore/retry evidence must pass before pilot. Failed
validation preserves evidence and holds activation. This predicate authorizes
no export/import execution under the present prose-only assignment.

## Exclusive writer, replicas and coordinator transfer

Only one clerk writer per canonical board resource is admitted throughout the
pilot. Before pilot, inventory every writer and active claim, including manual
coordinators, legacy mutation paths, second hosts and delayed replicas. Pause or
relay old mutation paths; import current claims once. Prove duplicate local
owner denial, stale-generation handling and delayed external replacement.
[P: C17.12/14; D: D11; I: INT03]

A local ProgramData lock is not distributed fencing. Uncertain exclusion MUST
stop admission and hold conflicting state; no automatic failover or offline
mutation is permitted. If all writers cannot be controlled, retain FileProtocol
and report partial delivery. A compatible manual writer may resume only after
explicit custody handoff. [P: C17.14, line 147; I: INT03]

At manual Codex/Claude transfer, the outgoing coordinator records roots/state,
claims, pending or uncertain requests, decisions and next actions, then ceases
requests. Bill activates the replacement; it reconciles durable state and resumes
as sole coordinator. Test both directions. Task creation outside the initial
grammar requires stopped admission, reconciled pending operations, coordinated
manual addition and explicit re-admission with compatible state/generation.
[D: Pilot ownership and coordinator transfer; I: DEP08; P: line 147]

## Semantic examples for later verification

These are prose vectors, not executed fixtures. Adopted clauses require the
safety outcomes; S1-S4 propose the precise classifications shown here. Assume
authorized result access, valid envelope/digest and no earlier-priority failure
unless the row says otherwise. Symbols are bound identities/tokens, not defaults.

| Input or interruption | Required observable outcome | Source |
| --- | --- | --- |
| Retry R with the original payload while R is Pending or Applied | Return retained state/result, even after its revision/epoch retires; no duplicate effect. | C17.6; INT01; S3 order 4 |
| Retry R changing only object member order, JSON whitespace or equivalent string escape | Same canonical bytes/digest and retained result. | S1 |
| Retry R changing target, holder/session, authority, predecessor array order or a path's string case while retaining the original claimed digest | IdentityConflict before DigestMismatch; preserve original R. | C17.5; INT01; S1/S3 |
| Retry R with identical content but a forged supplied digest | DigestMismatch; original R unchanged. | S1/S3 order 3 |
| New ID with duplicate decoded keys, unknown member, missing required input or fractional/exponent numeric token | InvalidRequest; no accepted operation or mutation. | S1/S3 |
| New ID N with correct epoch/applied predecessors but stale revision | Rejected RevisionConflict; fresh ID grants no freshness. | INT01; S3 order 10 |
| New ID has both retired epoch and stale revision | Rejected AuthorityConflict. An existing equal Applied retry instead returns retained Applied. | C17.7; INT01/03; S3 |
| Release L references a durably Pending claim C | Pending WaitingForPredecessor. After C applies, recheck L: if L's expected revision is now stale, Rejected RevisionConflict; resubmit new ID/head. | INT01; S2/S3 |
| L references a claim ID that has not arrived, or one terminally Rejected | Rejected MissingPredecessor or PredecessorFailed respectively; no indefinite forward wait. | S3 orders 7/8 |
| Self predecessor on a new request, or a cycle in imported non-Rejected dependencies | Rejected CausalCycle at request admission, or held InvalidImport for executable graph corruption at restore; no effect. Authentic historical Rejected references follow the next two vectors. | S3/S4 |
| R is durably Rejected MissingPredecessor for absent M; export and clean compatible restore preserve R's original request/digest/rejection while M remains absent | Restore passes this graph check with R as non-executable evidence; exact retry R returns original Rejected MissingPredecessor, never waits, fabricates M or executes R. If M later arrives, exact retry still returns that rejection. | INT01/04; S3/S4 |
| R names itself as predecessor and is durably Rejected CausalCycle; export and clean compatible restore preserve R's original self-reference/digest/rejection | Restore passes this graph check with R as non-executable evidence; exact retry R returns original Rejected CausalCycle and no mutation. Relabeling R Pending or Applied cannot use this exception and holds InvalidImport. | INT01/04; S3/S4 |
| Two eligible disjoint requests expect base revision B and join one batch | Both prepared against B, both Applied at one new revision N after commit; epoch unchanged. | INT01/02; S2 |
| Same-revision candidates overlap task/scope | Earliest eligible queue ordinal wins; later Rejected BatchConflict. | S2/S3 |
| Request expecting B misses a batch that commits N | Rejected RevisionConflict at reconsideration once all predecessors are Applied; never automatically rebased. | S2/S3 |
| Root `repo` and candidate sibling `repo-other`, traversal, or escaping junction | No containment admission from lexical prefix alone. | C17.1/5/7; matrix line 311 |
| Exact/ancestor claim overlaps, or holder appears expired | No conflicting grant or expiry takeover. | C17.7 |
| Imported reservation has no current board row | Retain reservation; do not allocate its identity. | C17.8; INT04 |
| Crash after prepare or any quartet boundary before commit receipt | NeedsRecovery at old committed pair; complete the same proposed next pair only after exact image verification. | INT02; S2/S3 |
| All after-images exist but commit receipt is absent | Incomplete; recover by committing the same prepared revision once. | S2 |
| Commit receipt exists and current manifest matches after restart | Return committed head/results; no extra revision or epoch change. | S2 |
| Recovery sees already-after bytes plus a third-state edited output | Keep NeedsRecovery, old head and third-state bytes; no commit receipt until explicitly reconciled. | C17.10; INT02; S2/S3 |
| Established state disappears while board and external custody receipt remain | Hold StateLoss/NeedsRecovery for same lineage; never first bootstrap. | C17.9/13; S4 |
| State absent and no trustworthy external custody evidence | Hold MissingCustodyEvidence; Bill must supply an explicit verified admission decision. | S4 |
| Crash after consuming FIRST_USE but before initial state creation | Hold NeedsRecovery of same bootstrap ID/lineage; consumed approval cannot be reused. | S4 |
| Valid unconsumed FIRST_USE, approved baseline/imports, existing configured root, supported compatibility tuple and all admission predicates | Controlled bootstrap eligible; activate only after matching established/import receipts and pilot gates. | S4 |
| Same schema label but package digest/restore tuple absent from approved compatibility record | Hold IncompatibleState; version equality is insufficient. | INT04; S4 |
| Clean restore loses a retry result or unpublished reservation | Restore acceptance fails; pilot remains blocked. | INT04 |
| Duplicate owner, delayed replica or unknown manual writer appears | Stop admission/hold; local lock proves no distributed exclusion. | INT03 |
| Worker reports source-ready, releases claim, or stops drain | No feature/parent completion inferred from any of those events. | C17.7/8/11; lines 147 |

## Source-ready, acceptance and remaining decisions

This document can become source-ready only after distinct review and coordinator
acceptance. It does not close C17.1 schemas/configuration or 17.19 as a whole.
Feature done means a tested versioned module installed and used in a real,
recoverable task round trip, with exact installed bytes, clean restore,
independent writer admission and board quartet evidence. Component passes and
claim release are insufficient. [P: lines 104-110, 147; I: DEP05/09, line 53]

S1-S4 are concrete proposals awaiting distinct review and coordinator acceptance.
They resolve the four review findings at the prose level if accepted; they are
not assertions of existing operator policy. No new engine, distributed service
or configuration value is proposed. The choice to accept or revise these
semantics belongs to the coordinator; any change beyond adopted authority must
be escalated to Bill. No such broader architecture change is claimed here.

The following downstream bindings remain. They must implement accepted prose
semantics rather than independently choose equality, tokens, wait/reject rules
or state-loss classification.

| Open item | Required resolution / consumer |
| --- | --- |
| Wire grammar | Exact JSON property names, numeric bounds, serialized category/status names, envelope/schema versions; map one-to-one to accepted S1/S3 semantics. Unknown versions have no implicit negotiation fallback. |
| Storage and publication | Durable records, token encoding, output manifest serialization, queue ordinal persistence and containment implementation; preserve accepted S1-S3 equality, commit events and recovery ordering. |
| Custody binding | Actual protected external witness location and approval/verification mechanism, state root, initial inventory and admission/import receipts implementing S4. No actual setup/access grant from prose. |
| Compatibility and retention | Actual approved package/digest/schema/restore matrix rows, export representation and closed-sprint/migration retention periods; implement S4 and retain deduplication obligations, with no expiry-based identity reuse. |
| Configuration | Keys, units/ranges, batch/request/retry/drain/retention limits, Get-PVal/ConfigRootKeys/HostSettings source entries for both hosts and human-reviewed measured values; C17.1a. Missing/invalid configuration must fail; no polling interval, timeout or measured value selected here. |
| Runtime proof | Actual containment resolver, prepared publication fixtures, installed package/restore receipts, writer/replica exclusion and both manual transfers; DEP05/08, INT01-04. |

Remaining D05 engine choices stay deferred to their selected consumers. They
MUST NOT be silently selected by this clerk contract. Distinct review may identify
further grammar decisions; that finding holds the affected producer rather than
inventing an accepted policy. [D: Remaining D05; I: DEP15]


## Local recovery history and clean restore

The logon-task Windows account owns the recovery component. Bind
OrchestrationRecoveryHistoryRootPath to a protected resident nonsynced directory
outside State and Custody, normally C:/ProgramData/ATAP/AICoordinator/RecoveryHistory.
Only that custodian, SYSTEM and Administrators may write it. Provision and review
the directory before initialization. Set the corresponding global config-root
key and host setting through the existing configuration system.

The feature is opt-in for existing installations. Its activation requires the
setting, protected directory and a verified initial binding. Missing configuration
does not establish recovery protection. Restore refuses without a bound retained
history. A changed configuration, replaced history directory or whole-machine
restore requires explicit custodian reconciliation against retained evidence.

Under continuous resource custody, initialize once with the module-private
Write-CoordRecoveryHistory -Action Initialize. The binding retains the current
Windows SID, host, resource, lineage, original state and custody paths and exact
pair digests. Initialization refuses an existing store. Every subsequent protected
state or witness replacement retains a flushed intent before replacement and a
flushed receipt after exact pair readback. File names carry consecutive ordinals
and the records form a digest chain. Missing, malformed or unfinished records
hold normal producer operations. The trusted cooperative operator must keep this
history outside the State/Custody restore scope. This local design detects old
pair restoration against retained newer history. It cannot independently detect
restoration or deletion of the entire history store with the machine.

An interrupted record is retained. A separately reviewed custodian resolution
binds its exact intent digest and observed Before or After pair through
Write-CoordRecoveryHistory -Action Resolve -ExpectedIntentDigest ... -Outcome
Aborted or Committed. This appends a receipt and consumes the ordinal. It never
deletes an intent or resets request, grant, approval or operation history.

Export-CoordState compresses by default. Bind OrchestrationSevenZipPath to the
reviewed installed executable and OrchestrationSevenZipSha256 to its exact hash.
Compression invokes that executable with a fixed ZIP format and a single
bundle.json entry. Export readback verifies the decoded bundle before publication.
Supply -NoCompression for the existing Coordination-export-v1 raw JSON format.
The returned Digest pins the actual backup file and BundleDigest pins its JSON.

Restore-CoordState accepts the actual file digest and exact expected resource,
lineage, generation and revision. It detects ZIP or raw JSON by contents. ZIP
reading admits only one ordinary bundle.json entry and limits both input and
decoded bytes, by default to 64 MiB each. No archive path is extracted. Digests,
schema, identity, journal image closure, custodian SID and installed package
inventory are checked before destination publication.

Restore targets clean files at the original configured absolute paths. Preserve
old physical images separately before an authorized restore. Destination parents
must exist with approved protection. The retained history must match the backup
pair exactly, which prevents automatic restoration of an older backup. A restore
retains one intent, stages each image, flushes and verifies it, and publishes it
without overwrite. A retry of that same intent skips matching published images
and restores missing ones. A differing existing image or changed history holds.
Pending requests, prepared plans, terminal results, reservations, grants and
original request identity are retained in their original bytes. Restore returns
RestoredHeld. It does not drain work, grant a pilot or change custody actors.
Resume pending work through the existing separately authorized recovery flow.

UTAT01 remains deferred. Its parity entry must bind the same promoted package
version and hash, actual logon-task SID, approved nonsynced local history path,
7-Zip executable and hash, protected-root configuration and initial binding.
Repeat raw/compressed clean restore and exact-request retry using its installed
module before considering parity verified.
