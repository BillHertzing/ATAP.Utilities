# RRSBS ADR-125: ATAPUtilities External-Consumer Boundary

Status: Proposed for Wave 1 review
Date: 2026-08-02
Owner: RDB-125 / Task 14.20.b.05

## Decision

The Sprint 0014 RRSBS phase owns the ATAPUtilities schema, its package, and
its published consumer contracts. AceCommander is an external consumer. It may
read ATAPUtilities through a versioned query or API contract, but ATAPUtilities
does not read, foreign-key to, or otherwise require AceCommander-owned tables,
permissions, APIs, data, or tenant topology.

An external RRSBS contract exposes stable durable identities and exact immutable
version identities, not physical table names, schema names, integer surrogate
keys, mutable current-row selectors, or database connection details. A consumer
selects an explicitly versioned contract and receives only the fields and
operations that contract defines. The transport and endpoint shape remain a
future consumer-interface decision; this ADR defines the boundary they must
obey.

This ADR is the Wave 1 authority for the external-consumer boundary. It does
not authorize logical DDL, migrations, seed changes, resets, packages/feeds,
live-system access, cross-repository edits, or implementation of an
AceCommander interface.

## Scope and topology

The following ownership and direction rules are normative.

| Area | Phase owner | Permitted direction in this phase | Explicitly deferred |
| --- | --- | --- | --- |
| ATAPUtilities RRSBS | ATAP.Utilities | Publishes versioned read/query/API contracts to external consumers. | None within the approved ATAPUtilities scope. |
| AceCommander catalog, permissions, APIs, and tenant data | Future `Plan-AceCommander-Catalog-Rationalization` | May consume an approved ATAPUtilities contract. | Schema design, data migration, permissions, catalog ownership, and tenant topology. |
| Central Tags and Gmail | ATAP.Utilities reset scope | ATAPUtilities may read and use enforced FKs to central Tags/Gmail where the approved logical model requires them. | Any tenant-local Tags/Gmail design beside AceCommander. |
| Tenant-local Tags/Gmail | Future AceCommander/multi-tenant work | No dependency is assumed by the ATAPUtilities baseline. | Topology, ownership, synchronization, and cross-tenant behavior. |

ATAPUtilities must remain valid if AceCommander later co-locates in one
database, runs in separate tenant databases, or changes its deployment shape.
No baseline migration may require an AceCommander table to exist. No migration
or contract may read across tenant boundaries.

## External contract requirements

1. Each request and response identifies the selected contract version. An
   incompatible change creates a new contract version; it does not silently
   reinterpret an existing payload.
2. A durable subject is represented externally by its stable identity. A
   historical, executable, or rendered subject also carries the exact immutable
   version identity required to reproduce the result.
3. A contract may expose a projection of RRSBS data, but it must identify the
   projection version and source identity/version. It must not expose a
   persistence entity as an application DTO.
4. External authority, tenant, session, principal, and consumer references are
   opaque identifiers at the ATAPUtilities boundary. They have no mandatory
   foreign key into AceCommander-owned storage.
5. Authorization remains consumer-owned unless a later approved contract says
   otherwise. RRSBS RuleKind, ExpertiseDomain, tag, attribution, Philote, or
   returned identity does not grant a consumer permission.
6. A consumer may request an exact published version or an explicitly defined
   compatibility selector. A mutable "current" result is permitted only when
   the contract names its resolution policy and returns the resolved immutable
   version identity.
7. A contract must carry the compatibility information needed by its consumer
   and database package pairing. It must not rely on a consumer discovering a
   table shape or applying an ad hoc migration folder.
8. The contract surface is read/query/API oriented for this phase. Any
   cross-boundary write, publication, execution, or permission mutation needs
   a separate approved contract and its own authorization model.

## Legacy and migration boundary

Current cross-schema user views, Rule-export documents, and the shared
ATAPUtilities/AceCommander bootstrap objects are inventory and conversion
inputs. They do not establish a future same-database contract. RDB-015 and
RDB-310 own their physical disposition; RDB-655 owns every remaining consumer
disposition and test; RDB-670 retires legacy consumers only after that map has
zero remaining references.

The immutable Flyway rebaseline must preserve or explicitly retire
deferred-scope objects without relying on them for ATAPUtilities baseline
creation. A future AceCommander plan may adopt an approved versioned contract,
but cannot make the contract depend on its physical schema or tenant layout.

## Negative controls

The eventual model, contract fixtures, and consumer tests must reject these
counterexamples:

1. An ATAPUtilities migration has a foreign key to, joins, or requires an
   AceCommander-owned table.
2. A published RRSBS contract exposes `SchemaName`, `TableName`, a raw numeric
   persistence key, or a connection string as its interoperability identity.
3. A consumer receives a historical rule, input block, plan, execution, or
   manifestation without the exact immutable version identity needed to
   reproduce it.
4. A payload changes meaning while retaining the same contract version.
5. An opaque AceCommander tenant, session, authority, or principal identifier
   is converted into a mandatory ATAPUtilities foreign key.
6. An ATAPUtilities query assumes AceCommander is co-located, or a consumer
   contract assumes that tenant-local Tags/Gmail do not exist.
7. A query reads across tenant databases or makes a tenant selector part of a
   shared ATAPUtilities migration.
8. A RuleKind, ExpertiseDomain, tag, attribution, Philote, or returned entity
   identity is accepted as authorization to read, publish, execute, or mutate.
9. A consumer uses a mutable "current" selector without receiving the resolved
   immutable version and resolution policy.
10. A legacy user view, Rule-export procedure, or ad hoc query is treated as a
    new-baseline interface without an owner, disposition, versioned replacement,
    and passing consumer test.

## Projection lifecycle contract

A projection exposed through this boundary is a derived read model, never the
authoritative persistence model. Each projection response carries its contract
version, projection schema version, source watermark, and staleness state. The
watermark identifies the exact source-version/event position through which the
projection is known to be complete; it is not a wall-clock estimate and cannot
be fabricated from the response timestamp.

Projection state is one of `Current`, `Stale`, `Rebuilding`, `Failed`, or
`Unavailable`. A failed or rebuilding projection does not silently present
itself as current. A consumer that requires current data must reject `Stale`,
`Rebuilding`, `Failed`, and `Unavailable`; a consumer that explicitly permits
stale data must receive the state, watermark, and documented staleness policy.

A rebuild creates a new immutable projection schema/version and records its
source watermark, producing implementation identity, start/completion state,
and failure diagnostic category. It does not mutate prior projection evidence
or advance a consumer's compatibility selector implicitly. A failed rebuild
retains its failure record and last known successful projection separately.

Compatibility cutover is versioned. A consumer declares the projection contract
and schema versions it accepts. The producer publishes a new compatible
projection beside the previous supported version, verifies its watermark and
state, then moves consumers by explicit version selection. The prior version is
retired only after the RDB-655 consumer map proves no supported consumer still
selects it. Blue/green coexistence is required whenever a consumer cannot
tolerate a rebuild window; an explicit stale-tolerant contract is required
otherwise.

## Projection lifecycle negative controls

The eventual model, contract fixtures, and consumer tests must reject these
counterexamples:

1. A projection response omits contract/schema version, source watermark, or
   staleness state.
2. A response claims `Current` after a failed, incomplete, or unknown rebuild,
   or derives its watermark solely from wall-clock time.
3. A current-required consumer accepts `Stale`, `Rebuilding`, `Failed`, or
   `Unavailable` data without an explicit policy.
4. A rebuild overwrites prior projection provenance, advances a compatibility
   selector implicitly, or discards its failure diagnostic category.
5. A consumer is moved to an unaccepted schema/contract version, or the prior
   projection version is retired before zero-consumer proof.
6. A rebuild-window-intolerant consumer is cut over without concurrent
   blue/green availability and watermark verification.

## Consequences and acceptance checks

- RDB-200 through RDB-260 must declare no mandatory AceCommander dependency and
  must use opaque external-reference fields where such context is required.
- RDB-310 must give AceCommander users, views, procedures, Tags, Gmail, and
  ScheduledTask objects an explicit reset-scope disposition.
- RDB-550 through RDB-575 must prove package and consumer compatibility without
  changing feed state as part of this ADR.
- RDB-655 must assign an owner, disposition, contract version, and test to each
  legacy consumer. RDB-670 may retire one only after that proof.
- RDB-640/RDB-650 must implement projection watermark, state, rebuild, and
  compatibility tests without exposing persistence entities to consumers.
- RDB-760 must publish the resulting external-consumer/interface guide, with
  examples and compatibility policy derived from this ADR.
- Wave 3 through Wave 10 adversarial tests must include every negative control
  above, including separate-topology and tenant-boundary fixtures.

## Related authorities

- [RRSBS ADR-100: Glossary and Entity-Philote Authority](RRSBS-ADR-100-Glossary-and-Entity-Philote-Authority.md)
- [RRSBS ADR-105: Entity-Reference Contract](RRSBS-ADR-105-Entity-Reference-Contract.md)
- [Multi-Database and AceCommander Future Requirements](Database-MultiDB-Future-Requirements.md)
- [ATAPUtilities Instantiation Tables](ATAPUtilities-Instantiation-Tables.md)
- [Current RRSBS database documentation](../Database/Documentation/README.RRSBS.md)
