# RRSBS ADR-146: Plan Approval Contract

Status: Proposed for Wave 1 review

Date: 2026-08-02

Owner: RDB-146 / Task 14.20.b.09

## Decision

Execution requires one immutable, FK-backed PlanApproval record for the exact
immutable ManifestationPlan it will execute. An approval is authorization for
one plan fingerprint and one target scope, not a reusable assertion that an
Instantiation, caller, path, environment name, or “similar plan” is generally
approved.

Each approval records immutable foreign-key references to the exact plan and
published InstantiationVersion, plus the plan version identity, hash algorithm,
plan hash, whole-graph marker or approved-subgraph identity and hash,
target-scope identity and policy/version hash, authority identity, authorization
policy identity/version, decision time in UTC, optional expiry time in UTC, and
allowed executor identity or executor-policy identity/version. The approval
also records an immutable decision state. Only an approved, unexpired,
unrevoked record authorizes execution.

Plan content, selected inputs, source versions, subgraph, target scope, target
policy, executor identity/policy, or hash-algorithm change requires a new plan
and a new approval. Execution compares its resolved fingerprint to the approval
record immediately before it creates an ExecutionOperation or dispatches an
effect. A mismatch rejects execution before any external side effect.

Approvals are append-only. An approval record is never edited to change plan,
target, authority, executor, decision time, or expiry. A later revocation,
supersession, or policy invalidation is represented by a separate immutable
authorization-state event referencing the original approval. It does not alter
the historical decision.

This ADR is an authored normative authority. It authorizes no DDL, migration,
seed, package/feed, secret, live-system, backup, restore, deletion, or
execution action.

## Scope and authority

This ADR implements the RDB-146 PlanApproval requirement. It relies on the
identity and immutable-version terminology in
[ADR-100](RRSBS-ADR-100-Glossary-and-Entity-Philote-Authority.md), the
Entity-reference contract in
[ADR-105](RRSBS-ADR-105-Entity-Reference-Contract.md), the publication
boundary in
[ADR-115](RRSBS-ADR-115-RollItUp-Publication-and-Concurrency.md), and the
execution fingerprint and retry boundary in
[ADR-145](RRSBS-ADR-145-Execution-Reliability.md).

It is not an authorization policy language and does not decide who may approve
which kind of work. RDB-240/RDB-250 define the physical permission,
PlanApproval, target-scope, and execution records; security policy work defines
the authority rules. This ADR defines the minimum immutable facts an approved
decision must bind.

## Normative approval record

1. `PlanApproval` has its own durable identity and immutable row identity. It
   has foreign keys to exactly one immutable ManifestationPlan, its published
   InstantiationVersion, its selected PlanVersion/fingerprint record, and the
   target-scope identity. The stored hash is a checksum of the referenced plan,
   not a substitute for those foreign keys.
2. The fingerprint records hash algorithm and exact bytes or canonical form;
   no verifier may assume an algorithm from hash length or accept an omitted
   algorithm. The approved subgraph is either an explicit whole-graph marker or
   an immutable recorded subgraph identity plus hash.
3. Target scope includes the authoritative target-root or non-filesystem target
   identity and the exact target policy/version used for planning. A display
   name, host alias, environment label, or path string alone is not target
   identity.
4. Authority identity is a typed Entity reference, with the authority-policy
   identity/version that evaluated the request. Decision time is UTC. An expiry,
   when present, is UTC and must be strictly later than decision time.
5. Executor authorization is bound either to one executor identity or to an
   explicit immutable executor-policy identity/version. An executor build hash
   required by the execution/reliability contract is part of the execution
   fingerprint and is validated against the approved policy.
6. Before starting an ExecutionOperation, the executor resolves the requested
   plan, selected inputs, subgraph, target scope/policy, and executor identity
   and compares them to the approval. It rejects a missing, denied, revoked,
   expired, or mismatched approval before journaling an effect or touching a
   target.
7. Retries revalidate the approval and exact fingerprint. A retry never borrows
   an approval for a changed plan, target, selected version, or executor.
8. Approval, denial, revocation, expiry observation, and supersession are
   auditable immutable events. A denial or expired approval is not silently
   converted to approval by a later executor or queue worker.

## Consequences

RDB-250 must model immutable PlanApproval, target scope, plan fingerprint, and
authorization-state records with trusted foreign keys. RDB-400 through RDB-470
must test rejection before effects. RDB-630 execution must pass the exact
PlanApproval identity into its durable operation/attempt fingerprint. RDB-820
recovery must revalidate authorization before any resumed external action.

The existing separately approved deployment and manifestation practice is
historical evidence that exact-target approval is useful. It is not a physical
template for the new baseline and does not authorize reuse of historic approval
records.

## Negative controls

The eventual model, executor, and tests must reject each of the following:

1. Execution with no PlanApproval, a denied approval, or an approval whose
   plan, plan version, hash algorithm, or plan hash differs from the request.
2. Execution of a changed whole graph or subgraph using an approval for the
   earlier graph/subgraph.
3. Execution against a different target root, non-filesystem target, target
   policy/version, environment alias, or path that merely resembles the
   approved target.
4. An approval whose authority is stored as free text, a user name, or a
   table-name/key pair instead of a typed FK-backed authority identity.
5. A decision with an expiry at or before decision time, or execution after
   expiry without a newly valid approval.
6. A queue worker or retry uses a different executor identity/build/policy than
   the approved executor boundary allows.
7. Editing an approval to replace the plan, target, authority, decision,
   expiry, executor, or hash rather than creating a new approval/event.
8. Treating a later policy change, revocation, or supersession as a reason to
   erase the original approval decision or to bypass revalidation.
9. Beginning an external side effect, target probe, or output write before all
   approval-fingerprint comparisons pass.
10. Reusing a prior approval merely because the Instantiation identity, caller,
    display name, or target environment label matches.

## Acceptance checks

- RDB-250 specifies all PlanApproval foreign keys, immutable identities, hash
  algorithm/version fields, target scope/policy fields, authority fields,
  expiry checks, executor policy binding, and authorization-state events.
- RDB-400 through RDB-470 provide positive and negative fixtures for every
  control above, including plan/subgraph/target/executor mismatch and expiry.
- RDB-630 records the exact approval identity and fingerprint in every
  execution operation and rejects changed inputs before effects.
- RDB-820 demonstrates that recovery and retry revalidate an unrevoked,
  unexpired approval before resuming any effect.

## Related authorities

- [ADR-100 glossary and Entity-Philote authority](RRSBS-ADR-100-Glossary-and-Entity-Philote-Authority.md)
- [ADR-105 Entity-reference contract](RRSBS-ADR-105-Entity-Reference-Contract.md)
- [ADR-115 publication and concurrency contract](RRSBS-ADR-115-RollItUp-Publication-and-Concurrency.md)
- [ADR-145 execution reliability contract](RRSBS-ADR-145-Execution-Reliability.md)
- [Historical deployment and manifestation evidence](Task-13.83-Instantiation-Deployment-and-Manifestation.md)
