# RDB-200 Identity, Authority, Domain, Tag, and Attribution Logical Model

Status: Proposed Wave 3 logical-model slice

Date: 2026-08-03

Owner: RDB-200 / Task 14.20.d.01

## Authority and boundary

This document defines the design-only logical model for the RRSBS identity
foundation, local authorities, experts, expertise domains, tags, attribution,
and attribution disputes. It applies the approved Entity/Philote,
typed-reference, temporal-versioning, external-consumer, and attribution
retention contracts.

The authoritative inputs are:

- [RRSBS ADR-100: Glossary and Entity-Philote Authority](../../SolutionDocumentation/RRSBS-ADR-100-Glossary-and-Entity-Philote-Authority.md)
- [RRSBS ADR-105: Entity-Reference Contract](../../SolutionDocumentation/RRSBS-ADR-105-Entity-Reference-Contract.md)
- [RRSBS ADR-110: Temporal and Versioning Contract](../../SolutionDocumentation/RRSBS-ADR-110-Temporal-Versioning.md)
- [RRSBS ADR-125: ATAPUtilities External-Consumer Boundary](../../SolutionDocumentation/RRSBS-ADR-125-External-Consumer-Boundary.md)
- [RRSBS ADR-149: Retention, Privacy, and Backup Contract](../../SolutionDocumentation/RRSBS-ADR-149-Retention-Privacy-and-Backup.md)
- Final RRSBS plan at
  `_Planning/InformationForTheFuture/RRSBS-Rationalization/Plan-RRSBS-Final.md`

The final plan remains authoritative in the `_Planning` sprint worktree.

This slice creates no SQL, migration, seed data, package/feed change, or live
system action. Physical names, numeric identifiers, stable GUID allocation,
indexes, triggers, publication procedures, and seed rows remain owned by
RDB-300 through RDB-500P. RDB-270 integrates this slice with RDB-210 through
RDB-260, and RDB-280 owns integrated invalid-row review.

## Decisions

1. `Entity` is the only generic internal relationship target. Every generic
   endpoint carries `(EntityId, EntityTypeId)` and a composite foreign key.
2. Each entity-bearing root and version also carries its table-specific
   Philote. A composite subtype-registration foreign key proves that the root,
   Entity type, and Philote agree.
3. Relationship roles use a finite policy catalog. Each endpoint also has a
   policy foreign key proving that the selected EntityType is permitted for
   that role and endpoint.
4. `Authority`, `Expert`, `ExpertiseDomain`, and `Tag` separate stable durable
   identity from immutable published versions. Publish-time insertion creates
   version rows; published versions are never updated or deleted.
5. Authority relationships, domain assignments, tag assignments, and
   attributions are immutable assertions. A correction or retraction inserts a
   successor assertion and preserves its predecessor.
6. Expertise domains and tags are classification only. Authority assignment is
   stewardship or provenance only. None is a permission grant.
7. Runtime permission grants remain consumer-owned under ADR-125. This model
   intentionally contains no ATAPUtilities `PermissionGrant` table. Default
   deny applies unless a separately approved authorization contract permits an
   action.
8. Attribution source evidence is a typed Entity reference to the exact
   evidence version, normally a future `SourceArtifactVersion` from RDB-260.
   RDB-200 does not recreate the proposed free-standing `AttributionSource`
   URI/path table.
9. No table in this slice has `ValidFromDTS` or `ValidToDTS`. These records do
   not have an approved business-effective consumer. Publication and assertion
   times are audit/system times, not business-validity intervals.
10. No table has a mutable `IsCurrent` flag. Current interpretation of a
    version or assertion follows the approved publication or terminal-successor
    policy and always returns the selected immutable identity.

## Logical conventions

| Convention | Required logical behavior |
| --- | --- |
| Primary keys | Numeric surrogate keys are internal relational keys. |
| Philotes | Every durable/versioned first-class row has a unique, immutable, table-specific GUID. |
| Entity candidate key | `Entity` exposes unique `(EntityId, EntityTypeId)` and `(EntityId, EntityTypeId, EntityPhiloteId)` candidate keys. |
| Subtype registration | An entity-bearing table stores its Entity key, constant catalog type, and own Philote, then FKs the triple to `Entity`. |
| Time | All timestamps are UTC. `CreatedAtUtc`, `PublishedAtUtc`, `AssertedAtUtc`, `OccurredAtUtc`, and `RecordedAtUtc` have distinct meanings. |
| Versions | Revision sequence is unique and monotonic within the durable parent. A predecessor belongs to that same parent. |
| Assertions | Assertions are insert-only. A successor may correct or retract one predecessor; one predecessor cannot have two direct successors. |
| External identities | AceCommander authority, tenant, session, and principal identifiers remain opaque contract values and never become mandatory FKs here. |
| Names and codes | Stable codes are immutable natural keys. Display labels and descriptions belong to immutable versions. |

## Foundation tables

### EntityType

Finite catalog of entity-bearing table types. It contains stable `EntityTypeCode`
values, never CLR names, schema names, or arbitrary table names.

| Logical column | Null | Contract |
| --- | --- | --- |
| `EntityTypeId` | No | Numeric PK. |
| `EntityTypeCode` | No | Immutable unique code naming one approved entity-bearing type. |
| `OwningSliceCode` | No | RDB work unit responsible for the subtype. |
| `IsVersionType` | No | Declares whether the type is an immutable version. |

Required constraints:

- unique `EntityTypeCode`;
- only reviewed codes may be seeded;
- a code is never repurposed after use.

### Entity

Shared internal supertype for every generic relationship.

| Logical column | Null | Contract |
| --- | --- | --- |
| `EntityId` | No | Numeric PK. |
| `EntityTypeId` | No | FK to `EntityType`. |
| `EntityPhiloteId` | No | Immutable GUID, unique across `Entity`. |
| `CreatedAtUtc` | No | Entity-registration system time. |

Required constraints:

- unique `(EntityId, EntityTypeId)`;
- unique `(EntityId, EntityTypeId, EntityPhiloteId)`;
- unique `EntityPhiloteId`;
- entity registration and subtype insertion occur atomically;
- an Entity row cannot remain without exactly one matching approved subtype.

### RelationshipRolePolicy

Finite catalog of generic relationship kinds and controlled semantic roles.

| Logical column | Null | Contract |
| --- | --- | --- |
| `RelationshipRolePolicyId` | No | Numeric PK. |
| `RelationshipKindCode` | No | Controlled kind such as `authority-assignment`, `domain-assignment`, `tag-assignment`, or `attribution`. |
| `RelationshipRoleCode` | No | Controlled semantic role within the kind. |
| `IsClassificationOnly` | No | Must be true for domain and tag policies. |
| `IsAuthorizationRole` | No | Must be false for every RDB-200 policy. |

Required constraints:

- unique `(RelationshipKindCode, RelationshipRoleCode)`;
- RDB-200 rows enforce `IsAuthorizationRole = false`;
- domain/tag policies enforce `IsClassificationOnly = true`.

### RelationshipRoleEndpointEntityType

Finite allow-list for one role endpoint.

| Logical column | Null | Contract |
| --- | --- | --- |
| `RelationshipRolePolicyId` | No | FK to `RelationshipRolePolicy`. |
| `EndpointCode` | No | Controlled endpoint name such as `authority`, `domain`, `tag`, `attributed`, `subject`, or `evidence`. |
| `EntityTypeId` | No | FK to permitted `EntityType`. |

Primary key: `(RelationshipRolePolicyId, EndpointCode, EntityTypeId)`.

Every generic relationship stores its endpoint code as a constrained constant
and uses this table in addition to its Entity FK. An application-only type
switch is insufficient.

## Durable identity and version tables

The four durable catalogs below use the same publication pattern:

- durable root: numeric PK, immutable root Philote, Entity registration,
  stable code, and creation time;
- immutable version: numeric PK, immutable version Philote, its own Entity
  registration, durable-parent FK, revision sequence, predecessor FK,
  publication time, display label, and description;
- unique `(DurableId, RevisionSequence)`;
- unique predecessor to prevent ambiguous direct successors;
- composite predecessor FK proving the predecessor has the same durable parent;
- a trusted publication operation must reject predecessor cycles and sequence
  regression before insertion.

### Authority and AuthorityVersion

`Authority` represents an ATAPUtilities-local organization, product, tenant
class, or other controlled steward identity. It is not an external
AceCommander principal and does not grant permission.

`AuthorityVersion` adds `AuthorityKindCode` from a controlled catalog. Parent,
steward, publisher, and controller relationships are represented by immutable
`EntityAuthorityAssignment` rows rather than a mutable parent column.

### Expert and ExpertVersion

`Expert` represents a stable author/editor/contributor identity without
sensitive profile data. `ExpertVersion` may contain a display label and a
non-secret descriptive note. It must not contain credentials, authentication
identifiers, private contact data, billing data, or an AceCommander user FK.

An opaque external principal identifier may be exchanged through a future
versioned consumer contract; it is not stored as a mandatory FK in this model.

### ExpertiseDomain and ExpertiseDomainVersion

`ExpertiseDomain` is the durable subject-taxonomy identity.
`ExpertiseDomainVersion` contains the immutable name, description, and an
optional exact parent `ExpertiseDomainVersion` reference.

Hierarchy constraints require:

- a parent version belongs to another domain root;
- no self-parent edge;
- no cycle;
- one exact parent version at most;
- hierarchy changes create a successor domain version.

The self-FK and different-root check are relational. Cycle rejection requires
the trusted publication validation owned by the later SQL slice.

### Tag and TagVersion

`Tag` is a durable classification token with immutable `TagNamespaceCode` and
`TagCode`. `TagVersion` contains its display label and description. Tag codes
are not EntityType codes, RuleKind codes, security roles, or permissions.

Unique natural key: `(TagNamespaceCode, TagCode)`.

## Immutable relationship assertions

Each assertion table has a numeric PK, unique assertion Philote, Entity
registration when the assertion is first-class, controlled role-policy FK,
typed endpoint FKs, actor Entity FK plus an `actor` endpoint-policy FK,
`AssertedAtUtc`, `RecordedAtUtc`, optional `Supersedes...Id`, and
`IsRetraction`.

The successor uses a composite predecessor FK containing the immutable claim
key. This proves that a correction/retraction does not silently change the
relationship kind, endpoints, or role. A unique predecessor constraint permits
at most one direct successor. A trusted insert operation rejects cycles. A
terminal retraction has no active semantic effect but remains auditable.

### EntityAuthorityAssignment

Records a non-authorization relationship from an exact `AuthorityVersion`
Entity to a subject Entity. Initial roles are `steward-of`, `published-by`, and
`controlled-catalog-owner`. The authority endpoint policy permits only
`AuthorityVersion`. Subject types are explicitly enumerated as RDB-210 through
RDB-260 register their entity types; no wildcard policy row is allowed.

This assignment does not authorize reading, publishing, executing, or mutating
the subject.

### EntityExpertiseDomainAssignment

Classifies a subject Entity with an exact `ExpertiseDomainVersion` Entity.
Initial role is `classified-in-domain`. The domain endpoint permits only
`ExpertiseDomainVersion`. Subject policies may include durable definitions,
exact immutable versions, plans, executions, artifacts, and projections only
when the owning slice explicitly adds that EntityType.

The assignment is classification only and cannot satisfy a permission or
approval FK.

### TagAssignment

Classifies a subject Entity with an exact `TagVersion` Entity. Initial role is
`tagged-with`. The tag endpoint permits only `TagVersion`; subject types are
explicitly enumerated. Tag assignment is classification only.

### Attribution

An immutable typed assertion connecting an attributed Entity to a subject
Entity under one controlled role.

| Logical column group | Contract |
| --- | --- |
| Identity | Numeric PK, unique Attribution Philote, and Entity subtype registration. |
| Role | FK to an `attribution` `RelationshipRolePolicy`. |
| Attributed endpoint | Typed Entity FK plus role-endpoint-policy FK. |
| Subject endpoint | Typed Entity FK plus role-endpoint-policy FK. |
| Evidence endpoint | Optional typed Entity FK plus role-endpoint-policy FK; when present it identifies an exact immutable evidence version. |
| Lineage | Optional same-claim `SupersedesAttributionId`; one direct successor maximum. |
| Audit | Asserting actor Entity, `AssertedAtUtc`, `RecordedAtUtc`, reason/evidence note limited to non-secret metadata, and `IsRetraction`. |

Initial attribution roles and allowed endpoint types are:

| Role | Attributed endpoint | Subject endpoint | Evidence endpoint |
| --- | --- | --- | --- |
| `authored-by` | `ExpertVersion`, `AuthorityVersion` | Exact authored definition/version types registered by RDB-210 through RDB-260 | Exact `SourceArtifactVersion` when available |
| `contributed-by` | `ExpertVersion`, `AuthorityVersion` | Exact authored definition/version or produced-artifact types | Exact `SourceArtifactVersion` when available |
| `licensed-by` | `AuthorityVersion` | Exact authored definition/version or produced-artifact types | Exact `SourceArtifactVersion` when available |
| `derived-from` | Exact internal source version | Exact derived definition/version or artifact | Exact `SourceArtifactVersion` when available |
| `verified-by` | `ExpertVersion`, `AuthorityVersion` | Exact attribution or evidence-bearing Entity | Exact `SourceArtifactVersion` when available |

The exact subject EntityType codes are closed during RDB-270 after all Wave 3
slices register their types. Until then, only the locally defined endpoint
types are valid; a broad `any entity` policy is prohibited.

An attribution is not ownership authorization. Produced/consumed provenance
that requires an execution, exact version, and content hash remains owned by
RDB-250 and uses its dedicated relationship rather than overloading
Attribution.

## Attribution disputes and correction lineage

### AttributionDispute

Durable first-class record linked to one exact `Attribution` assertion.

| Logical column | Null | Contract |
| --- | --- | --- |
| `AttributionDisputeId` | No | Numeric PK. |
| `AttributionDisputePhiloteId` | No | Unique immutable GUID and Entity subtype registration. |
| `AttributionId` | No | Direct FK to exact disputed assertion. |
| `DisputeActorRolePolicyId` | No | Controlled dispute-actor policy. |
| `RaisedByEndpointCode` | No | Constrained constant `raised-by`. |
| `RaisedByEntityId`, `RaisedByEntityTypeId` | No | Typed Entity FK plus dispute-actor endpoint-policy FK. |
| `RaisedAtUtc` | No | Occurrence time supplied by the controlled operation. |
| `RecordedAtUtc` | No | Database record time. |
| `AuthorityEntityId`, `AuthorityEntityTypeId` | No | Exact governing `AuthorityVersion` Entity. |
| `ReasonReference` | No | Privacy-minimized, non-secret reason/evidence reference. |

### AttributionDisputeEvent

Append-only event lineage for one dispute. It has a numeric PK, unique event
Philote, dispute FK, monotonically increasing `EventSequence`, controlled
`StatusCode`, optional controlled `OutcomeCode`, controlled event-actor policy,
typed actor Entity FK plus endpoint-policy FK,
`OccurredAtUtc`, `RecordedAtUtc`, governing AuthorityVersion Entity FK, and
reason/evidence reference.

Allowed statuses are `Raised`, `UnderReview`, `Resolved`, and `Withdrawn`.
Allowed resolved outcomes are `Upheld`, `Corrected`, and `Rejected`.
`CorrectedAttributionId` is required exactly when outcome is `Corrected` and
must identify a successor in the disputed attribution's correction lineage.

Required constraints:

- unique `(AttributionDisputeId, EventSequence)`;
- outcome is null unless status is `Resolved`;
- resolved status requires an outcome;
- `Corrected` requires `CorrectedAttributionId`; other outcomes prohibit it;
- an event cannot rewrite or delete an earlier event;
- legal/privacy/security holds and authorized tombstone/redaction lineage are
  preserved under ADR-149.

State-transition legality and proof that a corrected attribution is in the
same lineage require the trusted append operation and integrated RDB-280
fixtures.

## EntityType registration owned by this slice

RDB-200 reserves semantic codes, not numeric IDs or GUIDs:

- `authority`
- `authority-version`
- `expert`
- `expert-version`
- `expertise-domain`
- `expertise-domain-version`
- `tag`
- `tag-version`
- `entity-authority-assignment`
- `entity-expertise-domain-assignment`
- `tag-assignment`
- `attribution`
- `attribution-dispute`

`AttributionDisputeEvent` retains a unique Philote but is not a generic Entity
target in this slice. RDB-270 may promote it to an Entity-bearing type only if
an integrated generic-reference requirement proves that need.

## Temporal classification

| Concept | Durable root | Immutable version/assertion | Business-effective interval | Permitted selector |
| --- | --- | --- | --- | --- |
| Authority | Yes | `AuthorityVersion` | None | Exact published version; any compatibility selector must return it. |
| Expert | Yes | `ExpertVersion` | None | Exact published version. |
| ExpertiseDomain | Yes | `ExpertiseDomainVersion` | None | Exact published taxonomy version. |
| Tag | Yes | `TagVersion` | None | Exact published tag version. |
| Authority/domain/tag assignment | Assertion identity | Insert-only assertion successors | None | Exact assertion or unique terminal successor chain. |
| Attribution | Assertion identity | Insert-only correction/retraction successors | None | Exact assertion or unique terminal successor chain. |
| Attribution dispute | Durable dispute | Append-only event sequence | None | Exact dispute plus ordered events. |

No `latest row`, null end date, physical order, or display label is a valid
selector.

## Relational counterexamples

The physical implementation and RDB-280 fixtures must reject all of these:

1. An Entity uses a free-text type, or a relationship stores table name plus
   numeric ID or a lone Philote.
2. A subtype Philote or EntityType disagrees with its Entity registration.
3. An Entity exists without one matching subtype, or one subtype is registered
   as two Entities.
4. A relationship endpoint uses a valid Entity of a type absent from the
   endpoint policy.
5. A domain or tag assignment is used as a permission, approval, or executor
   authorization.
6. An authority assignment is treated as a runtime permission grant.
7. A version changes durable parent, Philote, content, predecessor,
   publication time, or revision sequence after publication.
8. A predecessor belongs to another durable root, forms a cycle, receives two
   direct successors, or causes sequence regression.
9. An ExpertiseDomain hierarchy references the same domain root as parent or
   creates a cycle.
10. A correction changes the immutable claim endpoints or role instead of
    superseding the same claim.
11. A corrected assertion is updated/deleted, a predecessor receives two
    successors, or a successor cycle is accepted.
12. Attribution stores free-text credit without typed attributed and subject
    Entities.
13. Attribution points to a mutable durable subject where its role requires an
    exact immutable version.
14. Attribution uses a URI/path string as internal evidence instead of an
    exact SourceArtifactVersion Entity.
15. Provenance requiring execution/version/hash is recorded only as
    attribution.
16. An attribution correction omits its predecessor, changes its claim key, or
    leaves ambiguous terminal successors.
17. A dispute omits the exact Attribution, actor, authority, time, or reason
    reference.
18. A resolved dispute omits its immutable event/outcome, or a `Corrected`
    outcome omits the successor attribution.
19. A dispute is reopened or withdrawn by rewriting an earlier event.
20. Credentials, sensitive profile data, personal contact data, or secret
    artifact content enters Expert or attribution audit metadata.
21. `ValidFromDTS`/`ValidToDTS` is added without a declared business-effective
    consumer, or publication/assertion time is misused as business validity.
22. An AceCommander table, tenant, user, session, or principal becomes a
    mandatory FK dependency.

## Integration obligations

RDB-270 must:

- merge EntityType registrations from every Wave 3 slice;
- close every relationship endpoint allow-list with exact EntityType codes;
- prove every entity-bearing subtype registration and every generic FK path;
- reconcile exact-version attribution subjects with RDB-210 through RDB-260;
- keep permission, approval, usage, execution provenance, and attribution as
  separate semantics;
- publish the integrated data-dictionary draft.

RDB-280 must execute invalid-row scenarios for every counterexample above.
RDB-400 must implement the foundation and this slice's trusted constraints and
write operations. RDB-500O/P owns stable identity allocation and fictional,
reference-safe domain/attribution seeds.

## Adversarial self-pass

Close variants that would defeat a superficial implementation include:

- accepting the correct EntityType but the wrong relationship endpoint role;
- using a durable root when a policy requires its exact published version;
- preserving one-successor uniqueness while allowing a longer correction
  cycle;
- correcting an attribution by changing its subject under the same predecessor;
- treating `AuthorityVersion` as authorization because its label contains
  `owner` or `controller`;
- adding future EntityTypes through an unrestricted policy wildcard;
- hiding an internal source behind an external URI to evade a typed FK;
- claiming a dispute is corrected when the referenced attribution is outside
  the disputed lineage.

These variants require composite FKs, finite endpoint policies, immutable
write operations, and graph/lineage validation together. Application-only
checks are not sufficient.
