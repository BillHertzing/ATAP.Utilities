# RPRRSBSI V5 Ace and Mobile Target Architecture

> **V5 revision (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Successor of `Database/Documentation/RPRRSBSI-V4-Ace-Mobile-Integration/30-Target-Architecture.md`. Requirement and decision IDs keep their V4-2 numbers with the prefix `V5-` (for example `V4-2-CORE-034` is now `V5-CORE-034`); a V4-2 ID that is not repeated here is withdrawn only where the "V5 changes" section says so. The V5 decisions DEC-1 to DEC-6 and the 2026-11-05 training and gamification requirements are summarised in [the V5 overview](RPRRSBSI-V5-00-Specification-Overview.md#v5-decisions); open items are in [HANDOFF-V5.md](HANDOFF-V5.md). **Terminology (DEC-6):** an *Instantiation* is a produced file or row; the run of an executor that produces instantiations is a *Materialization*; the reusable configuration it runs is a *materialization specification*. Where carried-forward V4-2 text uses "Instantiation" for the configured act, read "materialization specification".


Status: required architecture shape; technology selections marked pending remain open.

## Architectural planes

| Plane | Owner | Writes | Reads |
| --- | --- | --- | --- |
| Published reference plane | ATAP.Utilities / controlled publication | ATAP migration and publication principals only | AceCommander and approved services through sanctioned contracts |
| Ace working plane | Ace / AceCommander | Ace runtime and Ace migration principals, each capability-limited | User-scoped AceCommander and approved services |
| Edge projection plane | Each Outpost installation | Outpost host repositories only | Same-device authorized client and plugin host |
| Publication control plane | Release/security governance | Candidate, approval, evidence, and promotion records | Reviewers and publication service |

## Central SQL Server architecture

The central database contains distinct `ATAPUtilities` and `Ace` schemas. Shared physical
placement does not merge authority.

- `ATAPUtilities` is the published reference and central shared-data plane.
- `Ace` is the mutable working plane for user overlays, plugin development, sessions,
  analyses, and user data.
- The authoritative `User` table is outside the Ace duplicate set. Ace rows reference an
  opaque durable user ID or an ownership root derived from it; user PII is not copied
  merely to support segmentation.
- A topology-neutral repository/union layer supplies V4 effective resolution. The caller
  does not merge separately resolved results, and schema location does not determine
  precedence.

The word "duplicate" means every ATAPUtilities application table has an Ace counterpart
unless it is `User` or an explicitly approved manifest exception. It does not mean that
the core migration creates both, that all data is copied, or that unrestricted
cross-schema foreign keys are allowed.

## Migration ownership architecture

ATAPUtilities core migrations may create and evolve both schema surfaces when the Ace
effects are explicit. The migration topology may use one coordinated forward-only
lineage or separately identifiable lineages; that selection remains an implementation
decision. Either topology must preserve these boundaries:

| Concern | Required contract |
| --- | --- |
| Package ownership | The responsible release identifies every ATAPUtilities and Ace effect before execution. |
| Schema authority | Migration authority is bounded and auditable; ordinary runtime authority remains schema-specific. |
| History | Applied ATAPUtilities and Ace object changes have unambiguous immutable version and checksum history. |
| Manifest | Objects, parity effects, permissions, seeds, predecessor, and recovery are explicit for each schema. |
| Verification | ATAP reference semantics and Ace parity/user-isolation semantics are tested separately even when one package changes both. |
| Promotion | The exact immutable bytes and schema-effect manifest move through the required tier gates. |

A parity generator or analyzer MAY derive Ace DDL from the ATAP schema manifest. It SHALL
produce reviewable source and hashes. A coordinated core migration MAY execute the
declared Ace DDL through its migration authority; loaders, tests, and application startup
shall not create undeclared Ace objects as incidental side effects.

## AceCommander runtime architecture

AceCommander uses separate repositories and database connections/principals:

1. `IAtapReferenceReader` exposes bounded, parameterized, read-only published queries.
2. `IAceWorkingRepository` exposes user-scoped reads and writes.
3. `IEffectiveDefinitionProvider` unions authorized ATAP reference and Ace overlay
   candidates, then performs D-2/D-4 resolution once.
4. `IPluginChangeWorkspace` owns `ModifyPlugin` proposal and isolated validation.
5. `IPublicationCandidateStore` records immutable candidates and evidence but cannot
   publish them.

Application code SHALL not accept a generic connection and arbitrary schema name.
Schema/principal selection is fixed by registered service role so a plugin or DTO cannot
turn an Ace write into an ATAP write.

## Edge architecture

Each Outpost contains these logical components:

| Component | Responsibility |
| --- | --- |
| Enrollment and identity | Device identity, bootstrap, credential rotation, revocation state. |
| Scheduler | Platform-appropriate scheduled/on-demand work and resource budgets. |
| Collectors | Windows file observations or Android/iOS activity acquisition. |
| Normalization pipeline | Unit, time, identifier, route/file, and source normalization with provenance. |
| Local projection store | Transactional observations, normalized facts, analysis results, sync state, and policy cache. |
| Plugin host | Trust verification, permission mediation, expert-system execution, and provenance. |
| Sync engine | Outbound batching, idempotency, cursors, acknowledgments, retry, and conflict handling. |
| Local API | Same-device authenticated query/command surface. |
| Diagnostics | Redacted health, audit, crash, and performance evidence. |

The local database is behind a repository abstraction with migrations and transactional
outbox support. SQLite/SQLCipher or another embedded database is a candidate, not a
ratified selection. Platform keystore integration is required regardless of engine.

## Expert-system distribution and execution

An expert-system release is a signed projection package, not a database clone. It
contains:

- package and contract versions;
- registered expert-system, BuildSet, Rule, RuleVariant, Tag, and fact identities;
- explicit as-of applicability and source authority;
- workflow and calculation graphs needed by the declared entry points;
- plugin and executor hashes plus requested permissions;
- schema/DTO compatibility and resource limits; and
- manifest hashes and revocation metadata.

Central packaging selects the smallest authorized projection. Outpost validates package
integrity before activation and records the exact package with every result. Edge
overlays are user-owned Ace content and do not become ATAP reference definitions through
synchronization.

## `ModifyPlugin` architecture

`ModifyPlugin` is a control-plane workflow, not a feature flag on the ordinary database
connection.

1. A policy service issues a short-lived change-workspace grant.
2. A workspace service creates an isolated disposable target from an approved Ace schema
   predecessor and synthetic/user-authorized fixtures.
3. A restricted authoring API accepts a declarative model or bounded DDL subset.
4. Static validation builds an object/dependency/permission graph and rejects escaping
   references.
5. Migration validation exercises fresh, upgrade, negative, tenancy, rollback-by-forward-
   fix, and resource-budget cases.
6. Supply-chain validation verifies source, dependencies, signatures, license policy,
   and malware scans.
7. A candidate builder emits immutable DDL/data/plugin bytes, manifests, hashes, and
   evidence.
8. A distinct Ace deployment service may apply a validated Ace candidate. A still more
   restricted publication service is the only component that may create an ATAP
   publication candidate.

This separation is required because a single shared SQL schema cannot provide row-level
DDL isolation. The per-change workspace supplies isolation; the shared schema receives
only gated migrations.

## Publication architecture

`productionPublishNewOrModifiedPLugin` is a one-way trust-boundary workflow:

```text
Ace candidate -> immutable intake -> independent validation -> explicit approval
-> ATAP translation/package -> tier promotion -> published ATAPUtilities reference
```

The service SHALL use pull-based intake of a content-addressed candidate. It SHALL not
grant the Ace runtime principal any ATAP write permission. The resulting ATAP package is
a new forward-only migration/data release with its own registered identities and
provenance.

Detailed approval quorum, production principal custody, allowed object transformations,
malware engines, sandbox topology, emergency revocation, and recovery remain
`HITL-PENDING`. Until those decisions close, the pathway remains disabled.

## Trust boundaries

- mobile operating system to Outpost;
- source application/file system to collector;
- same-device client to local API;
- plugin package to in-process host;
- Outpost to AceCommander API;
- AceCommander to ATAP read contract;
- Ace runtime to Ace schema;
- user-authored DDL to isolated change workspace;
- Ace candidate to publication control plane; and
- publication service to ATAP migration pipeline.

Every boundary requires explicit authentication, authorization, input validation,
classification, audit, resource limits, and failure behavior appropriate to its risk.
