# RRSBS ADR-100: Glossary and Entity-Philote Authority

Status: Proposed for Wave 1 review  
Date: 2026-08-02  
Owner: RDB-100 / Task 14.20.b.01

## Decision

RRSBS uses a shared, FK-enforceable **Entity** supertype for cross-concept
references. A **Philote** is the stable GUID identity assigned to every durable
or versioned first-class RRSBS row that requires durable identity. An Entity
does not replace a Philote, and a Philote does not imply a global
`TableName + IntegerId` reference scheme.

The new baseline uses numeric surrogate keys where relational scale warrants
them, table-specific unique Philote GUIDs for durable or versioned first-class
rows, and typed Entity references for generic relationships. The exact table,
foreign-key, and exception pattern is owned by RDB-105; this ADR supplies its
vocabulary and non-negotiable authority boundary.

This ADR is an authored normative authority. It does not authorize logical
DDL, migrations, seed changes, database resets, package work, or an
AceCommander integration.

## Scope and authority

This document implements the Wave 1 RDB-100 glossary requirement and the
ENTITY-01 decision. It is authoritative for terminology used by subsequent
RRSBS ADRs, data contracts, tests, and documentation. The current database
documentation describes the legacy/versioned implementation and is evidence,
not authority for the new baseline; see
[RRSBS database documentation](../Database/Documentation/README.RRSBS.md) and
[Instantiation tables](ATAPUtilities-Instantiation-Tables.md).

## Normative glossary

| Term | Normative meaning | Not this term |
| --- | --- | --- |
| Entity | Shared supertype representing one referable domain subject, allowing an FK-enforceable typed relationship to that subject. | A stringly typed table-name/key pair, a serialization DTO, or an authorization grant. |
| Philote | Stable, table-specific GUID identity for a durable or versioned first-class row. It survives revision of that row's content but is not a substitute for a relational PK or a universal polymorphic pointer. | A mutable display name, an authorization principal, or permission. |
| Identity | The durable subject that remains the same while its descriptions or versions change. | A particular version, projection, execution, or cached artifact. |
| Version | An immutable recorded state of one durable identity, identified by its own key and Philote where first class. | The mutable current row or a label without a durable parent. |
| Publication | The atomic act that validates an editable graph and records an immutable published InstantiationVersion. | Any edit, draft save, or execution request. |
| RuleKind | The semantic/grammar/executor classification of Rules and Primitives. | An authorization class, a user tag, or an ExpertiseDomain. |
| ExpertiseDomain | A many-to-many classification taxonomy for expertise or subject matter. | A RuleKind, permission, or authorization decision. |
| Instantiation | An editable, durable authored configuration and its bindings. | A published snapshot, an execution attempt, or generated output. |
| InstantiationVersion | The immutable published snapshot selected by RollItUp, including exact selected InputBlockVersions. | The editable Instantiation or an arbitrary current-row query. |
| InputBlock | An authored reusable block of inputs with its own durable identity and immutable versions. | A single binding occurrence or an untyped JSON bag. |
| Plan | A non-writing proposal of an approved executable graph, inputs, target policy, and intended work. | An execution, manifestation, or approval itself. |
| Execution | One recorded attempt to perform an approved plan or approved subgraph. | Publication, planning, or a declaration that output exists. |
| Manifestation | A recorded materialization or cached artifact produced by an execution, retaining producing version, selector, executor/version, and hashes. | The Instantiation, the plan, or an unproven prospective file. |
| Attribution | A typed statement identifying an Entity's relationship to authored, sourced, or produced material. | Ownership authorization or a free-text credit without referential integrity. |
| Fork | A new durable identity that records derivation from another identity or version without mutating the source. | A revision of the same identity. |
| Permission | An authorization decision that grants or denies an action to a subject under an explicit policy. | A tag, ExpertiseDomain, Philote, or attribution. |
| Usage | Recorded provenance that a consumer, plan, execution, or artifact used an exact identity/version. | A mutable popularity count or an implied relationship. |

## Invariants

1. Generic relationships use typed Entity references with foreign keys, unless
   RDB-105 documents and approves a specific exception.
2. Every durable or versioned first-class RRSBS row has exactly one
   table-specific Philote identity that is unique in its table. High-volume
   event rows may use numeric surrogate keys while retaining a unique
   table-specific Philote when the row is a first-class durable record.
3. A revision creates a new immutable version for the same durable identity;
   it does not change the identity's Philote or overwrite published content.
4. RollItUp publishes an InstantiationVersion only after graph validation.
   UnRollIt consumes that exact published version, either as a whole graph or
   as an approved recorded subgraph.
5. A Manifestation records provenance to its producing execution and exact
   source version(s); it never stands in for the authored Instantiation or the
   executable plan.
6. RuleKind and ExpertiseDomain remain independently modeled. Neither grants
   permission; security decisions remain default-deny until an explicit policy
   allows an action.
7. Attribution, fork, permission, and usage have distinct typed semantics.
   One must not be inferred from another.

## Consequences

Subsequent logical-model work must preserve a clear identity/version split and
must use the glossary terms as defined here. Consumer contracts must expose
stable identities and exact version identifiers rather than physical table
keys or legacy polymorphic references. The shared Entity pattern prevents a
new generic-table-name registry while preserving database-enforced references.

RDB-105 must specify the physical Entity supertype and each allowed exception.
RDB-110, RDB-115, RDB-125, RDB-140, RDB-145, RDB-146, RDB-147, and RDB-148
must use these definitions without widening them.

## Negative controls

The following scenarios must be rejected by the eventual model, contracts, or
tests:

1. A provenance, tag, permission, or attribution record stores only
   `TableName = 'Rule'` and `IntegerId = 42` instead of a typed Entity FK.
2. A Rule revision changes its Philote GUID, or a new version overwrites the
   published content of an existing RuleVersion.
3. A RuleKind assignment is accepted as an ExpertiseDomain assignment, or an
   ExpertiseDomain/tag is treated as a permission grant.
4. A draft Instantiation is executed directly, or a plan selects unapproved
   mutable bindings instead of exact published InputBlockVersions.
5. A cached file is called a Manifestation without recorded execution,
   selector, executor/version, source version, and content hash provenance.
6. A fork reuses its source identity/Philote, or a revision is represented as a
   fork solely to evade immutable-version rules.
7. A consumer obtains a physical row key through an external contract when a
   stable identity/version contract is required.

## Acceptance checks

- Every Wave 1 ADR references these terms with their normative meanings.
- RDB-105 supplies FK proof or an approved exception for every generic Entity
  relationship.
- Wave 3 logical-model review rejects every negative control above.
- Wave 8 consumer work demonstrates that legacy generic references and
  overloaded Instantiation/Manifestation meanings have no remaining consumer.

## Related authorities

- [RRSBS database documentation](../Database/Documentation/README.RRSBS.md)
- [ATAPUtilities Instantiation Tables](ATAPUtilities-Instantiation-Tables.md)
