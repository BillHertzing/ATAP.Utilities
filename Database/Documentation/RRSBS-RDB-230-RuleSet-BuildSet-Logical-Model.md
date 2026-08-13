# RDB-230 RuleSet and BuildSet Logical Model

Status: Proposed Wave 3 logical-model slice

Date: 2026-08-03

Owner: RDB-230 / Task 14.20.d.04

## Authority and boundary

This design-only slice defines durable `RuleSet` and `BuildSet` identities,
their immutable published versions, and their ordered member-occurrence rows.
It implements the approved repeated-membership identity rule without creating
SQL, migrations, seed data, package/feed changes, or live-system action.

The authoritative inputs are [ADR-105: Entity-reference contract](../../SolutionDocumentation/RRSBS-ADR-105-Entity-Reference-Contract.md),
[ADR-110: temporal and versioning contract](../../SolutionDocumentation/RRSBS-ADR-110-Temporal-Versioning.md),
[ADR-115: RollItUp publication and concurrency](../../SolutionDocumentation/RRSBS-ADR-115-RollItUp-Publication-and-Concurrency.md),
and the RDB-220 [Rule composition model](RRSBS-RDB-220-Rule-Composition-Logical-Model.md).

RDB-220 owns Rules and RuleVersions. RDB-240 owns Instantiation, editable
bindings, and the complete selected rule-occurrence snapshot. RDB-250 owns
execution. RDB-270 integrates the EntityType catalog and cross-slice FKs;
RDB-280/RDB-430 own executable invalid-row proof and physical enforcement.

## Decisions

1. `RuleSet` and `BuildSet` are distinct durable aggregate identities. A
   `RuleSetVersion` contains `RuleVersion` members; a `BuildSetVersion`
   contains `RuleSetVersion` members. Neither has unversioned membership.
2. Every published aggregate version is immutable and uses the approved
   durable/version lineage: immutable Philote, unique monotonic revision under
   the durable parent, same-parent predecessor, one direct successor at most,
   and immutable `PublishedAtUtc`.
3. A membership occurrence is a domain identity distinct from its child
   version. `RuleSetVersionMember` and `BuildSetVersionMember` each have an
   immutable Philote and a `MemberOccurrenceKey` unique only within their exact
   immutable parent version.
4. The same child `RuleVersion` may occur repeatedly in one RuleSetVersion;
   the same child `RuleSetVersion` may occur repeatedly in one BuildSetVersion.
   Duplicate child identifiers therefore are not a uniqueness violation.
5. `MemberOccurrenceKey` supplies stable semantic identity for an occurrence;
   `Ordinal` supplies ordered position. Reordering an occurrence changes its
   ordinal in a successor version but does not turn its key into a position.
   Reusing an ordinal or key within a parent is invalid.
6. Member ordinals are non-negative, unique, and gap-free in a parent. A
   controlled membership role may describe a repeated child's purpose but is
   not an authorization grant or a substitute for occurrence identity.
7. RuleSet and BuildSet membership can name only exact published child
   versions. A durable child, `IsCurrent`, version label, display name, or
   current/latest alias is never a member target.
8. A complete Rule occurrence for RDB-240 consists of the selected
   BuildSetVersion member occurrence, selected child RuleSetVersion member
   occurrence, and exact child RuleVersion. RDB-230 does not invent an
   Instantiation-owned key or carry forward binding decisions.
9. Aggregate publication is validated as part of the trusted RollItUp graph
   validation boundary. This slice names the immutable keys; RDB-430 owns the
   SQL transaction and RDB-280 owns invalid-row execution.

## Shared Entity and version contract

`RuleSet`, `RuleSetVersion`, `RuleSetVersionMember`, `BuildSet`,
`BuildSetVersion`, and `BuildSetVersionMember` are RDB-200 Entity subtypes.
Each has a table-specific Philote equal to its Entity Philote and is registered
through `(EntityId, EntityTypeId, EntityPhiloteId)`. The finite role catalogs
are not generic Entity endpoints. RDB-270 must close the EntityType catalog and
typed endpoint policies.

The member row, not a child RuleVersion/RuleSetVersion reference, is the
occurrence identity. Its natural key is `(ParentVersionId, MemberOccurrenceKey)`;
the complete child/version target remains a separate exact FK. This avoids the
legacy uniqueness defect that collapsed two legitimate occurrences of one child.

## Logical tables

### RuleSet and RuleSetVersion

| Logical column | `RuleSet` contract | `RuleSetVersion` contract |
| --- | --- | --- |
| Identity | `RuleSetId` PK; immutable `RuleSetPhiloteId`; RDB-200 Entity registration | `RuleSetVersionId` PK; immutable `RuleSetVersionPhiloteId`; Entity registration |
| Durable identity | `RuleSetCode` unique; `CreatedAtUtc` | `(RuleSetId)` immutable parent FK |
| Version lineage | No mutable composition | `RevisionSequence`, nullable same-RuleSet predecessor, `PublishedAtUtc`; unique `(RuleSetId, RevisionSequence)` |
| Definition proof | No membership or mutable state | `MembershipHashAlgorithmCode`, `MembershipContentHash`, and exact published-member FKs |

`RuleSetCode` is an immutable durable semantic code. It is not a permission,
current-version selector, or substitute for a member occurrence key.

### RuleSetVersionMember

| Logical column | Null | Contract |
| --- | --- | --- |
| `RuleSetVersionMemberId`, `RuleSetVersionMemberPhiloteId` | No | PK and immutable Entity Philote. |
| `RuleSetVersionId` | No | Exact immutable parent FK. |
| `MemberOccurrenceKey` | No | Parent-scoped stable semantic occurrence key; unique with parent. |
| `Ordinal` | No | Non-negative, unique, and gap-free within parent. |
| `RuleVersionId` | No | Exact published child RuleVersion FK. Repetition is permitted. |
| `MembershipRoleCode` | No | FK to controlled descriptive role catalog. |
| `MembershipRationaleEntityId`, `MembershipRationaleEntityTypeId` | Yes | Typed exact evidence/authority Entity when a rationale is required. |

Candidate keys: `(RuleSetVersionMemberId, RuleSetVersionId)` and
`(RuleSetVersionId, MemberOccurrenceKey)`. The latter is the RDB-240
continuation point; no unique key includes `RuleVersionId`.

### BuildSet and BuildSetVersion

| Logical column | `BuildSet` contract | `BuildSetVersion` contract |
| --- | --- | --- |
| Identity | `BuildSetId` PK; immutable `BuildSetPhiloteId`; RDB-200 Entity registration | `BuildSetVersionId` PK; immutable `BuildSetVersionPhiloteId`; Entity registration |
| Durable identity | `BuildSetCode` unique; `CreatedAtUtc` | `(BuildSetId)` immutable parent FK |
| Version lineage | No mutable membership | `RevisionSequence`, nullable same-BuildSet predecessor, `PublishedAtUtc`; unique `(BuildSetId, RevisionSequence)` |
| Definition proof | No current/member state | `MembershipHashAlgorithmCode`, `MembershipContentHash`, and exact published-member FKs |

A BuildSet is an ordered aggregate of RuleSet versions, not a recursive
BuildSet graph. It cannot contain itself, another BuildSetVersion, a durable
RuleSet, or a direct RuleVersion.

### BuildSetVersionMember

| Logical column | Null | Contract |
| --- | --- | --- |
| `BuildSetVersionMemberId`, `BuildSetVersionMemberPhiloteId` | No | PK and immutable Entity Philote. |
| `BuildSetVersionId` | No | Exact immutable parent FK. |
| `MemberOccurrenceKey` | No | Parent-scoped stable semantic occurrence key; unique with parent. |
| `Ordinal` | No | Non-negative, unique, and gap-free within parent. |
| `RuleSetVersionId` | No | Exact published child RuleSetVersion FK. Repetition is permitted. |
| `MembershipRoleCode` | No | FK to controlled descriptive role catalog. |
| `MembershipRationaleEntityId`, `MembershipRationaleEntityTypeId` | Yes | Typed exact evidence/authority Entity when a rationale is required. |

Candidate keys: `(BuildSetVersionMemberId, BuildSetVersionId)` and
`(BuildSetVersionId, MemberOccurrenceKey)`. The child RuleSetVersion is not
part of either uniqueness rule, so two roles/paths can contain the same child.

### Membership role catalogs

`RuleSetMembershipRole` and `BuildSetMembershipRole` are finite catalogs with
immutable controlled codes and `AllowsRepeatedChild` policy metadata. Initial
semantic codes may include `primary`, `supporting`, `validation`, `preflight`,
and `postprocess`; no role implicitly grants view, edit, publish, execute, or
approve authority. RDB-240 owns user/Instantiation authorization and binding
scope; RDB-250 owns execution authorization.

## Complete occurrence path

For one selected BuildSetVersion, the complete Rule occurrence is addressed by:

```text
(BuildSetVersionId, BuildSetMemberOccurrenceKey,
 RuleSetVersionId, RuleSetMemberOccurrenceKey, RuleVersionId)
```

The first pair selects one BuildSetVersionMember and proves its exact child
RuleSetVersion. The second pair selects one RuleSetVersionMember and proves
its exact child RuleVersion. RDB-240 will use member IDs/composite FKs as the
physical occurrence path and may add Instantiation-owned durable binding scope;
it must not reduce the path to `(InstantiationId, RuleId)` or a RuleVersion
alone.

## Required constraints

- Ruleset and BuildSet durable codes are unique and immutable; each published
  version has one durable parent and a same-parent predecessor lineage.
- Published versions and member rows are insert-only. No `IsCurrent`, mutable
  membership list, or business-effective membership state appears in this slice.
- Membership parent, occurrence key, ordinal, child version, role, and
  rationale references are all exact FKs/controlled values; no free-form
  TableName, schema, display label, or latest-version selection is permitted.
- Member keys are non-empty, normalized according to the catalog convention,
  and unique only per parent. Child repeats are valid; child-type mismatches are
  not.
- Ordinals are gap-free per parent; a member key cannot be reused for a second
  occurrence in the same immutable version even if its child differs.
- BuildSetVersionMember references exactly a RuleSetVersion; RuleSetVersionMember
  references exactly a RuleVersion. Cross-parent membership and durable-child
  FKs are rejected.
- The stored membership hash covers the ordered member occurrence keys, exact
  child version identities, roles, and controlled rationale references.

## EntityType registrations

This slice reserves semantic codes only: `rule-set`, `rule-set-version`,
`rule-set-version-member`, `build-set`, `build-set-version`, and
`build-set-version-member`. Numeric identifiers, Philote GUID allocation, and
reference rows remain RDB-320/RDB-500 work.

## Relational counterexamples

RDB-280/RDB-430 must reject all of the following:

1. A RuleSet or BuildSet code duplicates or changes after durable creation.
2. A version omits its durable parent, uses another aggregate's predecessor,
   branches direct successors, cycles, or regresses revision sequence.
3. A published version or member row is updated/deleted in place.
4. A RuleSetVersionMember points to a durable Rule, current/latest alias, or
   a RuleSet/BuildSet version instead of one exact RuleVersion.
5. A BuildSetVersionMember points to a durable RuleSet, current/latest alias,
   direct RuleVersion, or another BuildSetVersion.
6. The same child version occurs twice and is incorrectly rejected solely for
   duplicate child identity.
7. Two members of one parent reuse a MemberOccurrenceKey, even with different children.
8. A MemberOccurrenceKey is empty, unnormalized, or treated as a global key.
9. Two members of one parent reuse an ordinal, use a negative ordinal, or leave a gap.
10. A member parent belongs to a different aggregate version than its composite key states.
11. A RuleSetVersionMember's occurrence key is used as a BuildSetVersionMember key.
12. A role code is unknown, used as authorization, or replaces the occurrence key.
13. Rationale uses an untyped GUID, table/key string, wildcard EntityType, or invalid typed Entity reference.
14. A membership hash omits ordering, occurrence keys, child versions, role, or rationale identity.
15. A version's membership is inferred from a mutable view, display label, or durable code.
16. An RDB-240 binding addresses only `(InstantiationId, RuleId)` and collapses repeated paths.
17. An RDB-240 binding path selects a RuleSetVersion or RuleVersion inconsistent with its parent member occurrence.
18. A member from another parent version is substituted by matching key or ordinal.
19. A RuleSet/BuildSet member is inserted outside the trusted publication boundary.
20. A non-FK polymorphic address substitutes for the declared child/version relationship.

## Integration obligations and deferred work

RDB-240 must carry the complete parent-scoped occurrence identity into
Instantiation bindings and snapshots. RDB-270 must reconcile EntityType and
typed rationale endpoint policies with the other Wave 3 slices. RDB-280/RDB-430
own the physical uniqueness/composite FK checks, trusted publication procedure,
and invalid-row execution.

This slice does not implement SQL, migrations, seeds, numeric IDs, Philote
GUIDs, user permissions, editable bindings, execution, package actions, or
live-system work.
