# RRSBS ADR-115: RollItUp Publication and Concurrency

Status: Proposed for Wave 1 review  
Date: 2026-08-02  
Owner: RDB-115 / Task 14.20.b.04

## Decision

**RollItUp** is the sole atomic publication operation for an editable
Instantiation. It validates a complete draft graph, inserts one immutable
InstantiationVersion with its exact selected InputBlockVersions, records a
publication event, and advances the current-publication projection in one SQL
Server transaction. A draft is never an executable or published version.

The operation is exposed through one application/service contract, but its
transactional invariants are enforced at the database boundary (implemented by
a stored procedure or an equivalent single transaction-owned database entry
point). Future callers must not compose direct inserts and updates to recreate
publication semantics.

UnRollIt is a separate future execution operation. It accepts only a
successfully published InstantiationVersion, either for the whole graph or a
recorded approved subgraph. It does not publish drafts or make a graph current.

## Publication transaction

`RollItUp(InstantiationId, ExpectedRevision, RequestedPublicationId, ...)`
must run at `SERIALIZABLE` isolation, or use locking that proves the equivalent
key-range protection. It obtains an update/range lock on the durable
Instantiation's publication state before reading its draft, current projection,
or next version number.

Within one transaction it:

1. verifies the caller's expected editable revision and rejects a stale draft;
2. validates all nine graph-validation families below;
3. allocates the next VersionNumber under the same lock, with a unique
   `(InstantiationId, VersionNumber)` constraint as a backstop;
4. inserts immutable version, membership, binding-selection, and publication
   event rows;
5. changes only the mutable current-publication projection/pointer, preserving
   the prior event and version; and
6. commits all writes together or rolls back all writes together.

The projection has a unique key on `InstantiationId`, so exactly one current
published version is addressable for each durable Instantiation. The historical
publication-event relation remains append-only. RDB-110 owns the compatible
temporal/as-of representation; it must preserve this one-current and immutable
content contract.

`RequestedPublicationId` is a caller-generated idempotency identity. A retry
with the same identity returns the originally committed publication result only
when its InstantiationId and expected revision match. A different request that
loses the lock race fails with a conflict/retryable result; it must not silently
publish a second version, allocate a skipped success result, or overwrite the
current pointer.

## Nine graph-validation families

The analysis lists ten individual assertions; the root and parent assertions
form one topology family. All ten assertions remain mandatory.

| Family | Required validation before any publication write |
| --- | --- |
| 1. Topology | Exactly one root exists, and every non-root node has exactly one parent in the same RuleVersion. |
| 2. Acyclicity | The graph has no cycle. |
| 3. Reachability | Every node is reachable from the sole root. |
| 4. Ordering | Sibling ordinals are unique and gap-free for each parent. |
| 5. Cardinality | `MinOccurs >= 0` and `MaxOccurs IS NULL OR MaxOccurs >= MinOccurs`. |
| 6. Choice semantics | Discriminator/choice values are legal and mutually consistent. |
| 7. Kind compatibility | Every PrimitiveVersion belongs to the RuleKindVersion accepted by its RuleVersion. |
| 8. Input resolution | Every exposed input mapping resolves exactly once. |
| 9. Output compatibility | Output declarations are compatible with the selected kind's executor contract. |

The validation query set runs against a stable transaction snapshot. It may not
accept a graph because a later statement happens to make it valid. Set-based
draft construction remains possible because these checks run at publication,
not after every draft edit.

## Collision and failure behavior

The database returns a typed publication conflict when the expected editable
revision no longer matches, another publication holds or has advanced the
Instantiation state, or a uniqueness backstop detects a collision. Deadlock or
serialization failures are retryable only by re-invoking the same
`RequestedPublicationId` after observing the resulting state. Validation
failure is not retryable until the draft changes.

No failed or conflicted call may leave an InstantiationVersion, selected
InputBlockVersion, publication event, current projection, or manifestation
record. No publication transaction runs UnRollIt, creates an artifact, or
performs external side effects.

## Consequences

RDB-610 implements the publication service through this contract. RDB-220,
RDB-230, and RDB-240 supply the relational keys used by the nine validation
families. RDB-400 through RDB-450 supply the database constraints and
positive/negative fixtures. RDB-630/RDB-145 own execution, retry, journal, and
outbox behavior after publication; they must consume the exact published
snapshot selected here.

This ADR adopts the terminology and Entity-reference contract of
[RRSBS ADR-100](RRSBS-ADR-100-Glossary-and-Entity-Philote-Authority.md) and
[RRSBS ADR-105](RRSBS-ADR-105-Entity-Reference-Contract.md). The current
effective-dating documentation is legacy implementation evidence, not the
authority for the new publication mechanism; see
[current RRSBS documentation](../Database/Documentation/README.RRSBS.md).

## Negative controls

The eventual implementation and tests must reject these scenarios:

1. A graph with zero or multiple roots, a cross-RuleVersion parent, a cycle, or
   an unreachable node is published.
2. A sibling set has duplicate or gapful ordinals, or invalid cardinality and
   choice/discriminator values are accepted.
3. A PrimitiveVersion from an incompatible RuleKindVersion, unresolved/duplicate
   exposed input, or incompatible output declaration is published.
4. A caller publishes an editable draft directly, executes it with UnRollIt,
   or replaces the content of an existing published version.
5. Two concurrent callers both publish VersionNumber `n + 1`, or both become
   the current publication for one Instantiation.
6. A stale expected revision advances the current-publication projection.
7. A retry with a new idempotency identity is treated as the same publication,
   or a reused identity with different request data is accepted.
8. Any failed validation/conflict/deadlock leaves partial version, event,
   membership, binding, projection, manifestation, or external-side-effect
   state.
9. A service bypasses the publication entry point by directly inserting a
   current version or changing the current-publication projection.

## Acceptance checks

- RDB-280 invalid-row cases cover all nine validation families.
- RDB-400 through RDB-450 prove atomic rollback, VersionNumber uniqueness,
  singleton-current behavior, and collision outcomes under concurrent callers.
- RDB-610 proves a draft cannot publish after a stale-revision conflict and
  maps validation versus retryable conflict outcomes.
- RDB-630 proves UnRollIt accepts only the exact published version or recorded
  approved subgraph, never an editable draft.

## Related authorities

- [RRSBS ADR-100: Glossary and Entity-Philote Authority](RRSBS-ADR-100-Glossary-and-Entity-Philote-Authority.md)
- [RRSBS ADR-105: Entity-Reference Contract](RRSBS-ADR-105-Entity-Reference-Contract.md)
- [Current RRSBS database documentation](../Database/Documentation/README.RRSBS.md)
