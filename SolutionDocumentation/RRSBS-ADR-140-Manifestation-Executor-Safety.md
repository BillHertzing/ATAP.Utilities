# RRSBS ADR-140: Manifestation, Executor Safety, and UnRollIt Traversal

Status: Proposed for Wave 1 review  
Date: 2026-08-02  
Owner: RDB-140 / Task 14.20.b.07

## Decision

UnRollIt executes only an immutable, published InstantiationVersion or a
recorded approved subgraph. It creates an immutable ManifestationPlan before
any effect, records one Execution attempt, and observes ManifestationArtifacts
after effects occur. These are separate concepts and tables: an authored
Instantiation is not a plan, a plan is not an execution, and an expected output
is not an observed artifact.

The executor is default-deny. It may run only a RuleKind executor that is
explicitly classified and authorized for the selected plan. The execution
authorization contract is finalized by RDB-146; this ADR requires an immutable
approved plan hash and approved target scope before any executor side effect.

This ADR is normative for logical design and future tests. It does not
authorize a filesystem write, secret resolution, SQL mutation, package/feed
operation, or a live-system execution.

## Manifestation cardinality and provenance

A ManifestationPlan contains immutable planned-output slots. For each
`(ExecutionAttemptId, PlannedOutputSlotId)`, the executor records zero or one
observed ManifestationArtifact; a unique constraint enforces that cardinality.
Zero means the attempt failed, was cancelled, or deliberately skipped before
production. A retried attempt receives a new ExecutionAttemptId and has its
own observed artifacts; retry/journal semantics belong to RDB-145.

Every observed artifact must reference its producing ExecutionAttempt, planned
output slot, exact InstantiationVersion, selector or approved subgraph, executor
identity/version, and content hash. A cached artifact also records the selected
InputBlockVersions and remains verifiable against the originating published
version. An artifact cannot become evidence of a plan merely because a file is
present at a matching path.

## UnRollIt traversal boundary

UnRollIt accepts one exact published version and either its whole approved graph
or an immutable recorded subgraph selector. It resolves every selected binding
to its exact InputBlockVersion before execution. It rejects a mutable draft,
an arbitrary node identifier, a rule outside the published graph, missing or
duplicate input, an unapproved selector, and a RuleKind whose executor category
does not allow the requested effect.

The executor plans first and performs effects only after plan approval and
target validation. It never upgrades a draft to published, changes the selected
version, broadens a target root, or treats a cached artifact as permission to
repeat an effect.

## Locator and target-root contract

Each planned output declares a locator type. Filesystem locators are relative
paths beneath one immutable, approved target root; non-filesystem locators use
a controlled scheme-specific canonical form and cannot be converted to a local
filesystem path implicitly.

For a filesystem locator, normalization and validation must reject:

1. rooted, drive-qualified, UNC, device, or extended-length paths;
2. `.` or `..` traversal segments, empty ambiguous segments, mixed separator
   aliases, and a path that canonicalizes outside the approved root;
3. alternate data streams (`:` in a relative component), reserved Windows
   device names, trailing dot or space, invalid control characters, and
   platform-length violations;
4. duplicate, ordinal-case-colliding, or normalization-colliding planned
   outputs; and
5. an existing or newly encountered reparse point, junction, symbolic link, or
   other filesystem indirection in any parent or final output component.

Validation is not sufficient by itself. The executor must create temporary
output under the approved root, open/inspect the resulting handle without
following a reparse point, verify its final resolved path and root containment,
then atomically place it in the approved destination. It repeats containment
and reparse checks after opening so a path swap between validation and write
(TOCTOU) cannot escape the root. If the platform cannot provide this proof, the
filesystem output is rejected.

## Exact-byte environment contract

The plan hash covers the exact published version and selected InputBlockVersions
as well as the executor identity and build hash, toolchain/dependency-lock
identities, RuleKind grammar hash, encoding, BOM policy, newline policy,
locale/culture, and output locator policy. The executor compares reconstructed
bytes to the planned content hash before recording success. It records observed
byte count and content hash after write; a mismatch fails the attempt.

Secrets are never placed in plans, hashes, artifacts, or provenance. A planned
secret reference may contain only its approved SecretName under the value
contract; resolving it is outside this ADR and remains subject to the runtime
authorization boundary.

## Non-filesystem outputs

Every non-filesystem scheme has a named executor and canonicalization rule. Its
plan declares the target identity, effect class, and verification strategy; a
filesystem-style relative-path check is not substituted for scheme validation.
Unknown, unclassified, or policy-sensitive schemes are rejected by default.

## Consequences

RDB-250 models ManifestationPlan, plan slots, ExecutionAttempt,
ManifestationArtifact, and error taxonomy with the stated provenance and
cardinality. RDB-630 implements UnRollIt against exact published snapshots.
RDB-145 adds reliable retries and outbox recovery without weakening these
single-attempt artifact rules. RDB-146 defines the approval record consumed by
this executor boundary, and RDB-147 defines SourceArtifact/locator identity.

The current renderer is useful legacy evidence: it rejects rooted/traversal and
case-colliding paths and verifies exact bytes, but it does not by itself prove
the full v2 approval, reparse, TOCTOU, or non-filesystem contract. See
[Task 13.80 execution evidence](Task-13.80-Instantiation-Execution.md) and
[RRSBS ADR-115 publication boundary](RRSBS-ADR-115-RollItUp-Publication-and-Concurrency.md).

## Negative controls

The implementation and adversarial fixtures must reject these scenarios:

1. UnRollIt receives an editable draft, a nonexistent/out-of-graph node, or an
   unapproved subgraph selector.
2. A planned output uses a rooted, UNC, device, extended-length, traversal, or
   noncanonical path; or a non-filesystem locator is silently treated as a file.
3. A path contains an ADS, reserved device name, trailing dot/space, invalid
   character, overlength value, duplicate output, or ordinal-case collision.
4. A parent or final component is a symbolic link, junction, or reparse point.
5. A directory is swapped for a junction/reparse point after validation but
   before or during the write.
6. An executor writes outside the immutable approved target root, changes the
   root after approval, or follows a locator normalization alias.
7. Two observed artifacts are recorded for the same execution attempt and
   planned output slot, or an artifact lacks producing-execution provenance.
8. An artifact is accepted when its bytes, encoding/BOM/newline policy, grammar
   hash, executor build, toolchain/dependency locks, or locale differ from plan.
9. A cached artifact is used as an execution approval or has no exact selected
   version/input/executor/hash provenance.
10. An unknown, policy-sensitive, or unauthorized executor/scheme performs an
    effect, or a secret value appears in plan/artifact/provenance data.
11. A failed attempt records a success artifact or leaves a filesystem effect
    without the required observable failure/recovery evidence.

## Acceptance checks

- RDB-280 supplies invalid-model cases for cardinality, selector, and locator
  constraints.
- RDB-450/RDB-460 fixtures prove one-artifact-per-slot, provenance FKs, plan
  hash binding, and rejected invalid locator states.
- RDB-630 tests use a temporary root and cover every filesystem negative
  control, including reparse and TOCTOU adversarial cases where platform support
  permits them.
- RDB-770 publishes the executor operation guide and RDB-820 rehearses failure,
  retry, and partial-output recovery without using a live target.

## Related authorities

- [RRSBS ADR-100: Glossary and Entity-Philote Authority](RRSBS-ADR-100-Glossary-and-Entity-Philote-Authority.md)
- [RRSBS ADR-115: RollItUp Publication and Concurrency](RRSBS-ADR-115-RollItUp-Publication-and-Concurrency.md)
- [Task 13.80: Instantiation Query, Ingestion, and Execution](Task-13.80-Instantiation-Execution.md)
