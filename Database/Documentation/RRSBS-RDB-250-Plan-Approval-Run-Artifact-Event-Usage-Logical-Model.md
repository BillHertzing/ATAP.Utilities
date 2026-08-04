# RDB-250 — Plan, Approval, Run, Artifact, Event, and Usage Logical Model

Status: Wave 3 design-only contract. No SQL, migrations, seed data, package,
feed, live-tier, filesystem, executor, or AceCommander changes are authorized
by this document.

## Purpose and boundary

This slice makes the approved execution boundary durable and auditable. It
separates an immutable proposed effect (`ManifestationPlan`) from the approval
of that exact effect, the idempotent requested operation (`Manifestation`), its
append-only attempts, and observed artifacts. It implements the contracts of
[RDB-140](../../SolutionDocumentation/RRSBS-ADR-140-Manifestation-Executor-Safety.md),
[RDB-145](../../SolutionDocumentation/RRSBS-ADR-145-Execution-Reliability.md),
and [RDB-146](../../SolutionDocumentation/RRSBS-ADR-146-Plan-Approval.md).

RDB-240 remains the authority for Instantiation, selected input snapshots, and
the `plan`, `execute`, `approve`, and `read-artifacts` permission verbs. This
slice consumes immutable RDB-240/230/220 identities as external contracts; it
does not alter their keys. RDB-270 closes cross-slice FKs, RDB-280 supplies the
independent adversarial review, and RDB-450 owns physical SQL and fixtures.

## Decisions

1. `ManifestationPlan` is an immutable plan for exactly one published
   `InstantiationVersion`, exact selected input snapshot, immutable execution
   graph selector, target scope/policy, executor boundary, and canonical plan
   fingerprint. It is neither an authorization nor evidence that an effect ran.
2. `PlanArtifact` is an immutable planned output slot. It has a stable
   plan-local ordinal and canonical locator, effect class, expected content
   hash/byte contract, and target-root policy reference. A plan cannot contain
   a duplicate slot, locator, or ordinal.
3. `PlanApproval` is an append-only decision bound by trusted FKs to one exact
   plan and all of its approval-sensitive fingerprint components. It records
   decision, authority/policy, UTC time, optional expiry, and permitted
   executor boundary. Revocation, supersession, and expiry observation are
   separate immutable `PlanApprovalStateEvent` rows; they never rewrite the
   decision.
4. `Manifestation` is the durable idempotent execution operation. Its caller
   idempotency key is unique only within an exact authorization scope, and its
   immutable request fingerprint includes plan, approval, target, selected
   inputs, graph selector, and executor-build identity. The same key with a
   different fingerprint is a conflict, not another run.
5. `ManifestationAttempt` is one append-only attempt within a Manifestation.
   It has a monotonic attempt number, optional retry predecessor, lease and
   heartbeat identity, controlled state, terminal timestamps, and non-secret
   diagnostics. A retry creates a new attempt and revalidates its approval.
6. `RuleExecution` records exact RuleVersion execution within one attempt and
   one deterministic RDB-240 occurrence. It records executor identity/build,
   ordered start/finish facts, controlled outcome, and an immutable execution
   fingerprint; it does not substitute a current/latest RuleVersion alias.
7. `ManifestationArtifact` is an observed output, never a planned intent. It
   is produced by exactly one successful RuleExecution for exactly one
   PlanArtifact slot in exactly one attempt. `(ManifestationAttemptId,
   PlanArtifactId)` is unique: an attempt cannot claim two observed artifacts
   for the same planned slot. Reuse/caching is an explicit observation linked
   to the completed original producer, not a second producer or an approval.
8. `ManifestationEvent` is append-only operational/journal evidence. It is
   ordered per attempt, tied to a closed `ManifestationEventKind`, and may
   reference a typed `ErrorTaxonomy` entry plus a non-secret diagnostic hash.
   State transitions, leases, cancellation, outbox delivery, recovery, and
   observed artifact facts are events; free-form text cannot define state.
9. `RuleUsage` is immutable provenance: one governed subject/version uses one
   exact RuleVersion in one named usage role, with an optional source
   manifestation/attempt/rule-execution fact. It uses typed Entity references
   and never a schema/table/key triple or free-form rule name.

## Shared identity and temporal contract

`ManifestationPlan`, `PlanApproval`, `Manifestation`, and `ManifestationArtifact`
are RDB-200 Entity subtypes with table-specific immutable Philotes. Attempts,
slots, state events, RuleExecutions, and RuleUsage are typed relations. RDB-270
owns final EntityType allow-list closure and composite-FK naming.

Every plan, approval, request fingerprint, attempt, execution, artifact, event,
and usage fact is append-only. A corrected decision, retry, supersession,
recovery, or cache observation creates a new linked row. It never updates or
deletes historic evidence.

## Logical tables

### Plan and approval

| Logical table | Key and responsibility |
| --- | --- |
| `ManifestationPlan` | PK plus immutable Philote; exact `InstantiationVersionId`; canonical graph-selector identity/hash; selected-input snapshot hash; target scope/policy identity/hash; executor/policy identity; hash algorithm, plan fingerprint, and `PlannedAtUtc`. |
| `PlanArtifact` | PK; `ManifestationPlanId`; immutable slot ordinal, canonical locator, locator-policy version, effect class, expected content hash/byte contract, and target-root identity. Unique `(ManifestationPlanId, SlotOrdinal)` and canonical locator. |
| `PlanApproval` | PK plus immutable Philote; exact plan, published InstantiationVersion, target scope/policy, graph selector/hash, input snapshot hash, executor boundary, hash algorithm/fingerprint, authority Entity reference, authority-policy version, decision, `DecidedAtUtc`, and optional expiry. |
| `PlanApprovalStateEvent` | PK; one PlanApproval; closed state event (`revoked`, `superseded`, `expired-observed`), decision authority/policy, UTC time, and optional successor approval. It preserves the original decision. |

An approval must repeat the approval-sensitive fingerprint as FK-backed facts
and hashes. A display environment, path, caller, or Instantiation identity is
not a target or plan identity. `Approved` is necessary but not sufficient: it
must be unexpired and have no effective invalidating state event at attempt
creation or retry.

### Manifestation, attempts, and exact Rule execution

| Logical table | Key and responsibility |
| --- | --- |
| `Manifestation` | PK plus immutable Philote; exact approved plan/approval; authorization scope; caller idempotency key; immutable request fingerprint; request time and controlled operation state. Unique `(AuthorizationScopeId, CallerIdempotencyKey)`. |
| `ManifestationAttempt` | PK; Manifestation; monotonic `AttemptNumber`; optional same-Manifestation retry predecessor; executor build identity; lease holder/token/expiry; heartbeat, start, terminal timestamps; controlled state; non-secret diagnostic hash. Unique `(ManifestationId, AttemptNumber)`. |
| `RuleExecution` | PK; one attempt, exact RDB-240 occurrence and exact RuleVersion; execution ordinal; executor/build identity; controlled outcome; started/finished UTC; execution fingerprint. Unique `(ManifestationAttemptId, OccurrenceKey, ExecutionOrdinal)`. |
| `ManifestationEvent` | PK; one attempt; per-attempt monotonic sequence; closed event kind; UTC time; optional RuleExecution, PlanArtifact, ErrorTaxonomy, outbox-message identity, and non-secret diagnostic hash. Unique `(ManifestationAttemptId, EventSequence)`. |
| `ErrorTaxonomy` | Closed catalog: stable machine-readable code, category, retry disposition, safety class, and retirement/supersession lineage. Diagnostic prose is supplementary only. |

Only a non-expired matching lease holder records effect-producing RuleExecution
facts. Lease expiry leads to `RecoveryRequired`; it does not authorize another
concurrent attempt or establish failure/success. Terminal state is derived from
the durable event/fact contract, not from a path's existence.

### Observed artifact and governed Rule usage

| Logical table | Key and responsibility |
| --- | --- |
| `ManifestationArtifact` | PK plus immutable Philote; one producing attempt, RuleExecution, and PlanArtifact; canonical observed locator; observed content hash/byte facts; observation time; artifact state; optional original producer for an explicit cache reuse observation. Unique `(ManifestationAttemptId, PlanArtifactId)`. |
| `RuleUsage` | PK; typed subject Entity/version reference; exact RuleVersion; closed usage role; optional source plan/attempt/RuleExecution; observed/planned provenance discriminator; recorded UTC and immutable usage fingerprint. Unique natural key covers subject, version, RuleVersion, role, and provenance fact. |

An artifact is an observation only after the executor verifies the plan's exact
locator policy and bytes. A failed, cancelled, or recovery-required attempt
cannot emit a success artifact. Cache reuse must reference a completed original
producer with identical plan fingerprint, selected inputs, target policy,
executor build, locator, and expected content hash.

## Required constraints

- Plan, slot, approval, state event, manifestation, attempt, execution,
  artifact, event, and usage rows are immutable after insert.
- A PlanArtifact belongs to one plan and cannot use a duplicate ordinal,
  canonical locator, target-root identity, or ambiguous output policy.
- PlanApproval FKs and stored fingerprint must match the plan's exact
  InstantiationVersion, inputs, graph selector, target/policy, executor
  boundary, and hash algorithm. Expiry is strictly after decision time.
- A Manifestation references one approved, unexpired, unrevoked exact
  PlanApproval. Its idempotency key maps to exactly one request fingerprint.
- An attempt has the same Manifestation as its retry predecessor, a unique
  monotonic number, and cannot overlap another active lease for that operation.
- RuleExecution uses an exact occurrence and exact RuleVersion compatible with
  the approved InstantiationVersion graph; it cannot execute an editable or
  current/latest alias.
- An observed artifact has one producer and one plan slot, with composite FKs
  proving that its attempt, RuleExecution, and PlanArtifact share the same
  ManifestationPlan. It may not be used as a second approval or producer.
- Events have a known kind, monotonic sequence, valid transition predecessor,
  and taxonomy-controlled error code. Error prose must not contain a secret.
- RuleUsage uses a typed subject/version and exact RuleVersion; observed usage
  references a real source execution, while planned usage references a plan
  and never masquerades as observed execution.

## EntityType registrations

This slice reserves semantic codes only: `manifestation-plan`, `plan-approval`,
`manifestation`, and `manifestation-artifact`. Numeric identifiers, GUID
allocation, physical names, extended properties, and seed rows remain
RDB-320/RDB-450/RDB-500 work.

## Relational counterexamples

RDB-280/RDB-450 must reject each of the following:

1. A plan references an editable Instantiation, latest alias, missing input snapshot, or untyped target/environment label.
2. Two plan slots share an ordinal or canonical locator, or a slot lacks expected bytes/hash and locator-policy identity.
3. An approval has no trusted plan FK, changes plan/target/executor/hash in place, uses an unknown hash algorithm, or expires at/before its decision.
4. An approval for a similar Instantiation, display target, old subgraph, changed inputs, changed target policy, or different executor authorizes execution.
5. Revocation, supersession, or expiry overwrites its original approval decision or is ignored on a retry.
6. The same idempotency key is accepted with two different request fingerprints, or different scopes are collapsed to one key space.
7. Two attempts share a number, a retry points to another Manifestation, a stale lease heartbeats a new attempt, or overlapping effect leases are accepted.
8. A retry starts without revalidating approval, plan/inputs, target policy, executor build, and outstanding recovery facts.
9. A RuleExecution targets a foreign/duplicate occurrence, a current/latest RuleVersion alias, or a version absent from the approved graph.
10. An artifact has no producing RuleExecution, is produced by a failed/cancelled attempt, or two artifacts claim the same attempt/plan slot.
11. An artifact's plan slot belongs to a different plan, its locator/bytes differ from the plan, or a cache observation lacks an identical completed producer.
12. An event has a free-form kind/error code, duplicate/gapped sequence, impossible state transition, secret-bearing diagnostic, or missing recovery/outbox evidence.
13. A path exists or a partial cached output is treated as a successful artifact without hash, producer, and approved-plan provenance.
14. A RuleUsage uses a table-name/key pair, free-form Rule name, foreign version, or calls planned usage an observed execution.
15. A plan, approval, manifestation, attempt, execution, artifact, event, or usage fact is updated/deleted to hide a failure, cancellation, or historical decision.

## Integration obligations and deferred work

RDB-240 provides immutable Instantiation/input/occurrence identities and
authorization verbs. RDB-230/220 provide exact graph and RuleVersion contracts.
RDB-270 reconciles all cross-slice composite FKs and dictionary coverage.
RDB-280/RDB-450 convert these counterexamples to invalid-row fixtures and
physical enforcement. RDB-630 implements safe planning/execution/recovery;
RDB-820 rehearses it under a temporary root. This slice does not claim SQL,
numeric identifiers, Philote GUIDs, seeds, secret resolution, real approvals,
filesystem writes, package actions, or live-tier work.
