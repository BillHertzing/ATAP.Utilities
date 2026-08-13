# RRSBS ADR-105: Entity-Reference Contract

Status: Proposed for Wave 1 review  
Date: 2026-08-02  
Owner: RDB-105 / Task 14.20.b.02

## Decision

RRSBS implements ENTITY-01 with one shared, FK-enforceable `Entity`
supertype. Every cross-concept relationship references an Entity through a
typed composite foreign key. It never uses `TableName`, `SchemaName`, a CLR
type name, or an unpaired `PhiloteId` as a polymorphic reference.

The logical supertype is:

| Column | Contract |
| --- | --- |
| `EntityId` | Numeric primary key used by all generic relationships. |
| `EntityTypeId` | Foreign key to a finite `EntityType` catalog; no free-text discriminator. |
| `EntityPhiloteId` | Immutable, table-specific Philote GUID, unique in `Entity`. |
| `CreatedAtUtc` | Auditable creation timestamp. |

`Entity` has a unique candidate key `(EntityId, EntityTypeId)`. Each
entity-bearing durable or versioned root has exactly one Entity registration,
its own immutable Philote, and a composite foreign key to that candidate key.
The entity-bearing root's type is therefore provable in the database, not
inferred by application code. This complements—not replaces—the root's
table-specific Philote and surrogate primary key.

This ADR is the physical-reference authority required by RDB-105. It does not
authorize DDL, migration, seed, reset, package, feed, live-system, or
cross-repository work.

## Reference pattern

Every generic relationship role stores both `EntityId` and `EntityTypeId` and
has a composite foreign key to `Entity(EntityId, EntityTypeId)`. A finite
relationship-role policy catalog specifies the permitted EntityType values;
the relationship row references that policy with a foreign key. The model
therefore rejects both a nonexistent Entity and an existing Entity of a type
not allowed in that role.

Relationship-specific tables may use direct subtype foreign keys when only one
type is valid. They must not be generalized merely for convenience. A generic
relationship uses the Entity pattern only when it genuinely supports more than
one permitted entity type.

## Required relationship treatments

| Concern | Required reference contract |
| --- | --- |
| Tags | `TagAssignment` references the Tag Entity and subject Entity with typed composite FKs. Tagging is classification only; neither a tag nor an ExpertiseDomain grants permission. |
| Attribution | `Attribution` references both the attributed Entity and the subject Entity with typed composite FKs, plus a controlled attribution-role catalog. It is not an authorization grant. |
| Provenance and usage | A plan, execution, artifact, or usage record references the exact consumed or produced version Entity with typed composite FKs. It records the relationship role and, where applicable, content hash and producing execution. |
| Permissions | `PermissionGrant` references a principal Entity and securable Entity with typed composite FKs, together with controlled action/policy identities. No permission is implied by EntityType, Philote, attribution, tag, or ExpertiseDomain. Default deny remains mandatory. |
| Source links | `SourceLink` references its internal source-artifact/version Entity and internal target Entity with typed composite FKs. A source link records a controlled link role and exact version when the target is versioned. |

## Narrow non-FK exception

Only an external source that is outside the RRSBS baseline and cannot be
represented as a controlled local Entity may use an `ExternalReference` record
instead of a target Entity. That record must contain a controlled locator
scheme, normalized locator, retrieval or observation timestamp, and available
content hash/version evidence. `SourceLink` must enforce exactly one target:
either its typed internal Entity reference or an `ExternalReference` foreign
key, never both and never neither.

`ExternalReference` is not a backdoor generic relationship. It cannot be used
for tags, attribution, permissions, provenance of a local artifact, or an
internal RRSBS object. A deferred or legacy object has no automatic exception:
it must be converted to an Entity, represented as a properly documented
external reference, or excluded from the new baseline by its approved
disposition.

## Legacy boundary

The current migration corpus contains soft-reference patterns, including
`SourceTableName` and `ManifestationArtifact.SourceObjectPhiloteId`. Those are
conversion-audit inputs only. They are not evidence that a non-FK pattern is
allowed in the new baseline. RDB-160 must disposition every retained use, and
RDB-655/RDB-670 must prove no consumer still relies on a legacy generic
reference before retirement.

## Consequences and implementation proof

Wave 3 must define `Entity`, `EntityType`, the relationship-role policy
catalog, and each subtype registration with named primary, unique, foreign-key,
and check constraints. The data dictionary must show both sides of every
generic relationship and the type-policy foreign key. Wave 5 SQL fixtures must
prove that invalid references fail by constraint, rather than by a service-only
validation branch.

This contract is compatible with the glossary and identity rules in
[RRSBS ADR-100](RRSBS-ADR-100-Glossary-and-Entity-Philote-Authority.md). It
does not decide temporal/versioning mechanics, publication semantics, external
consumer APIs, or security policy beyond the referenced default-deny boundary.

## Repeated membership occurrence identity

A membership occurrence is a distinct domain identity from the child version it
contains. The same `RuleVersion` may occur more than once in a `RuleSetVersion`, and
the same `RuleSetVersion` may occur more than once in a `BuildSetVersion`. Those
occurrences must not collapse merely because their child version identifiers match.

Each versioned membership must therefore expose a stable member-occurrence key within
its immutable parent version. Conceptually, a `BuildSetVersion` member occurrence is
identified by its parent `BuildSetVersion` and its member-occurrence key; a
`RuleSetVersion` member occurrence is identified by its parent `RuleSetVersion` and
its member-occurrence key. A complete rule-occurrence key follows the selected
BuildSet-member occurrence to the selected RuleSet-member occurrence and then its
child `RuleVersion`. Future physical names, columns, and table shapes are owned by
RDB-230 and RDB-240.

Member ordering is explicit and deterministic within a parent version. An ordinal is
unique only in that parent-version membership collection and supplies evaluation or
display order; it is not a global identity and must not be used as the sole durable
reference. Reordering, adding, removing, or duplicating a member creates the
appropriate successor version and retains the predecessor's immutable occurrence
meaning.

Any logical reference to a repeated rule occurrence—such as an Instantiation binding
scope, an InputBlock selection, a plan input, or an approval target—must carry the
complete compatible occurrence anchor, not only `RuleId` or `RuleVersionId`. The
logical foreign-key contract must also prove that the referenced binding or selected
value belongs to the same Instantiation and compatible occurrence. When a successor
graph changes occurrences, carry-forward is permitted only through an explicit
compatibility mapping; position, label, or a matching child version alone is not a
mapping.

## Negative controls

The eventual model and tests must reject these counterexamples:

1. A tag, attribution, provenance, permission, or source link stores
   `TableName = 'Rule'` plus a numeric key or a lone Philote GUID.
2. A generic relationship has a valid `EntityId` but supplies a mismatched or
   free-text EntityType.
3. A relationship role targets an EntityType not present in its allowed
   relationship-role policy.
4. A Tag or ExpertiseDomain is accepted as evidence of a permission grant.
5. A permission grant identifies a principal or securable by name, tag, or
   Philote rather than typed Entity foreign keys.
6. Provenance says an artifact was produced from a mutable durable identity
   without an exact version Entity, producing execution, and required hash.
7. A `SourceLink` stores both an internal Entity target and an
   `ExternalReference`, or stores neither.
8. An internal RRSBS object is hidden behind `ExternalReference` to evade an
   FK, or an external source is represented with an invented local Entity.
9. A converted legacy `SourceTableName` or soft `SourceObjectPhiloteId` becomes
   a new runtime relationship without the required Entity conversion.
10. A repeated `RuleVersion` occurrence shares a binding, input value, or approval
    target solely because another occurrence has the same child version.
11. A reference to `RuleId` or `RuleVersionId` alone is accepted where an operation
    addresses a member occurrence in a versioned BuildSet or RuleSet.
12. A member ordinal is treated as a global or immutable occurrence key, or duplicate
    ordinals within one parent version are accepted.
13. An InputBlock, plan, or approval references an occurrence anchor belonging to
    another Instantiation or an incompatible occurrence path.
14. A successor graph silently carries a binding forward by display label, ordinal, or
    matching child version when repeated occurrences make that match ambiguous.

## Acceptance checks

- RDB-200 through RDB-260 cite this contract and enumerate each generic
  relationship's permitted EntityTypes.
- RDB-280 invalid-row scenarios include every negative control above.
- RDB-400 through RDB-470 implement named composite FK and type-policy proof.
- RDB-655 records an owner, disposition, test, and cutover gate for every
  legacy generic-reference consumer.
- RDB-230 and RDB-240 prove that two occurrences of the same child RuleVersion can
  retain separate bindings and selections, and reject an incompatible Instantiation or
  occurrence path.

## Related authorities

- [RRSBS ADR-100: Glossary and Entity-Philote Authority](RRSBS-ADR-100-Glossary-and-Entity-Philote-Authority.md)
- [Current RRSBS database documentation](../Database/Documentation/README.RRSBS.md)
- [Instantiation tables and legacy manifestation context](ATAPUtilities-Instantiation-Tables.md)
