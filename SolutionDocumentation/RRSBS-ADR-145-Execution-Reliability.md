# RRSBS ADR-145: Execution Reliability, Retry, and Cached Manifestation Validation

Status: Proposed for Wave 1 review
Date: 2026-08-02
Owner: RDB-145 / Task 14.20.b.08

## Decision

Execution is a durable operation containing immutable execution attempts. It
consumes only an exact published InstantiationVersion (or approved recorded
subgraph), approved plan, and frozen selected inputs; it never executes an
editable draft. The operation has a caller idempotency key and immutable request
fingerprint. Each retry has a new attempt identity linked to that operation.

Database recording and filesystem effects are not one transaction. The database
transaction records operation, attempt, artifact intent, journal event, and
outbox message. A dispatcher performs external work from the outbox. Recovery
reconciles durable intent, staging/target observation, and hashes; it does not
infer success from a lost process or path existence alone.

This ADR is normative for execution reliability. It authorizes no DDL,
migration, seed, package/feed, live-system, filesystem, or secret action.

## Durable operation and attempt contract

An `ExecutionOperation` has a unique caller idempotency key in its authorized
scope and an immutable fingerprint: published InstantiationVersion, selected
subgraph or whole-graph marker, plan hash, plan-approval identity, target-root
identity/policy version, selected InputBlockVersion identities, and executor
build hash. An `ExecutionAttempt` is append-only, links to one operation, and
records attempt number, retry-of identity, lease, heartbeat, cancellation,
completion/failure timestamps, executor build hash, and non-secret diagnostics.

The attempt state machine is:

```text
Queued -> Leased -> Running -> Succeeded
                         |        -> FailedRetryable -> Queued (new attempt)
                         |        -> FailedTerminal
                         |        -> Cancelled
                         -> RecoveryRequired
```

Only a holder of a non-expired lease may produce effects. A heartbeat extends a
lease only when holder identity and attempt version match. Lease expiry requires
reconciliation; it is not automatic failure or authorization to run concurrently.

## Idempotency, retry, cancellation, and terminal outcomes

1. Same key and same fingerprint return the existing operation and safe state;
   they never create a second operation or rerun a successful artifact.
2. Same key and different fingerprint is a conflict. Changed plan, target,
   selected version, input selection, or executor build needs a new operation.
3. A retry creates a new immutable attempt linked to its predecessor and
   revalidates approval, target policy, plan hash, versions, and artifact intent.
4. Cancellation is durable and cooperative. The executor records observed state
   and reaches `Cancelled` or `RecoveryRequired`; it cannot claim success after
   cancellation without an explicit later resume operation.
5. `Succeeded`, `FailedTerminal`, and `Cancelled` are terminal attempt states.
   `RecoveryRequired` is not a retry authorization.

## Journal, outbox, and non-atomic effects

The queue transaction writes an immutable journal event and stable outbox message
identity. The outbox is at-least-once; every handler deduplicates by operation,
attempt, and message identity before effects. Its payload is only a reference to
the expected durable state, never a secret or mutable execution graph.

Each artifact intent records normalized locator, target-root identity, expected
hash, and producing plan/version identities. The executor uses the RDB-140
safety contract, stages under an execution-specific temporary root, verifies
bytes, then performs the approved publication step. Recovery marks an artifact
observed only when locator and hash match; otherwise it preserves evidence and
marks recovery-required or failure. It never deletes or overwrites an unowned
output merely to make retry easier.

## Cached manifestation validation

A cache is reusable only when published InstantiationVersion, selected
InputBlockVersions, approved plan hash, selected subgraph, executor build hash,
target-root policy, normalized locator, and expected content hash match. Its
provenance must identify a completed producing attempt and all required artifact
states. A cache hit is an observation, not proof a changed plan/target is safe.

The legacy in-place `RenderFromModel` promotion is historical evidence only.
The new baseline records attempt and artifact provenance without using path-wide
uniqueness as lifecycle history.

## Negative controls

The eventual model, executor, and recovery tests must reject:

1. Execution of an editable Instantiation, unapproved plan, or changed plan hash.
2. Acceptance of one idempotency key with different request fingerprints.
3. A retry that overwrites its predecessor, omits retry linkage, or skips validation.
4. Concurrent lease holders, or a stale heartbeat extending a changed attempt.
5. Immediate rerun after lease expiry without journal/staging/target reconciliation.
6. Cancellation ignored as success, or cancellation erasing partial-effect evidence.
7. An effect without durable journal/outbox evidence or durable deduplication.
8. Treating path existence, stale cache, or partial file as success without hash.
9. Deleting, overwriting, or adopting unowned output during recovery.
10. Reusing a cache after changed plan, executor, versions, target policy, or hash.
11. Recording a connection string, credential, token, or secret value in evidence.
12. Declaring success without producing attempt, exact provenance, and reconciled artifacts.

## Consequences and acceptance checks

- RDB-230 through RDB-260 define immutable operation, attempt, artifact-intent,
  journal, and outbox records with named constraints.
- RDB-400 through RDB-470 fixture idempotency collisions, stale leases,
  cancellation, duplicate delivery, crash boundaries, partial output, cache
  mismatch, and recovery-required outcomes.
- RDB-630 implements the executor; RDB-140 owns locator/target safety and
  RDB-146 owns approval/target identity.
- RDB-820 proves crash/retry/partial-output recovery; RDB-870 proves persisted
  provenance and cache validation after deployment.

## Related authorities

- [RRSBS ADR-110: Temporal and Versioning Contract](RRSBS-ADR-110-Temporal-Versioning.md)
- [RRSBS ADR-115: RollItUp Publication and Concurrency](RRSBS-ADR-115-RollItUp-Publication-and-Concurrency.md)
- [Task 13.80: Instantiation Query, Ingestion, and Execution](Task-13.80-Instantiation-Execution.md)
- [Task 13.83: Instantiation Deployment and Manifestation](Task-13.83-Instantiation-Deployment-and-Manifestation.md)
- [RRSBS ADR-100: Glossary and Entity-Philote Authority](RRSBS-ADR-100-Glossary-and-Entity-Philote-Authority.md)
