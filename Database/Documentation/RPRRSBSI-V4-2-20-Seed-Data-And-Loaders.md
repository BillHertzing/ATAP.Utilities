# RPRRSBSI-V4-2 Seed Data and Loader Specification

Status: reconciled documentation-only seed and loader contract. This document allocates
no GUID, creates no CSV or SQL, authorizes no migration, and performs no database or
package/feed action.

## V4-2 ingestion and telemetry fixtures

- **V4-2-SEED-030:** ContentSummary fixtures SHALL include agent and PowerShell envelope variants, duplicate/reordered records, multiple Tags, `Any`/`All` expected results, sensitive-field rejection, and crash/replay checkpoints.
- **V4-2-SEED-031:** AISupervisor fixtures SHALL cover Claude and Codex, streaming, retries, cancellation, missing usage, zero usage, reasoning metrics, unknown metrics, safe headers, and synthetic secret-bearing headers that must be rejected.
- **V4-2-SEED-032:** No fixture may contain a real credential, private prompt, or user conversation payload.
- **V4-2-SEED-033:** Controlled catalogs SHALL define ingestion status, assignment origin, header direction/disposition, exchange outcome, metric code, and metric unit. Exact rows and GUIDs require a separate allocation task.
- **V4-2-SEED-034:** Provider fixtures SHALL preserve source-field and provider-reported/derived distinctions while normalizing into the common contract.

## Authority and decision boundary

This contract applies the ratified identity, D-2 precedence, D-3 classified-change, and
D-4 overlay rules in the
[V4 overview](RPRRSBSI-V4-2-00-Specification-Overview.md), the
[core schema contract](RPRRSBSI-V4-2-10-Core-Schema-Enhancements.md), and the
[source synthesis and traceability](RPRRSBSI-V4-2-05-Source-Synthesis-And-Traceability.md).
The [V3 data dictionary](RPRRSBSI-V3-Data-Dictionary.md),
[V3 path selection](RPRRSBSI-V3-Path-Selection.md), and
[V3 GUID registry](RPRRSBSI-V3-GUID-Registry.csv) are retained baseline evidence; they
do not allocate V4 identities or decide a V4 pending gate.

D-1, retained D-2, D-3/C-02 for its explicitly classified cases, D-4/C-03, and
C-08 through C-15 are normative inputs. The eight D-3 edge cases, C-16 through C-27,
FU-4, and FU-6 remain `HITL-PENDING`. A pending question SHALL NOT be converted into a
catalog row, fixture value, default, validation rule, loader branch, or inferred GUID.

## Package classes and isolation

| Package class | Purpose | Destination behavior |
| --- | --- | --- |
| Reference | Immutable distributable catalogs and baseline expert-system definitions | May be applied after every identity and decision gate is satisfied. |
| Conformance-positive | Deterministic examples that must validate and resolve to an expected result | Loaded only into a test-owned transaction or disposable test database. |
| Rejection-negative | One intentionally invalid condition per fixture | Must fail before destination mutation; never merged into reference tables. |

A manifest SHALL record the package class, and the loader SHALL reject a file whose
class does not match the invoked mode. This prevents a negative overlay example or
unresolved design probe from becoming production reference data merely because it is
represented in CSV.

## V3 seed baseline

The V3 consolidation currently establishes these minimum row counts: Philote 22, PhiloteValidityPeriod 22, RuleKind 2, RulePrimitive 15, RulePrimitiveInput 21, Rule 2, RuleSet 1, RuleSetRule 2, BuildSet 1, BuildSetRuleSet 1, and Instantiation 1. V4 tests SHALL characterize these rows before extending them.

## CSV packaging contract

- **V4-2-SEED-001:** Every reference row SHALL have a stable registered GUID and a stable human-readable code.
- **V4-2-SEED-002:** CSV files SHALL be UTF-8, comma-delimited, header-bearing, and use invariant formatting for booleans, decimal values, and UTC instants. GUID text SHALL use canonical lowercase dashed `D` format.
- **V4-2-SEED-003:** Null SHALL have one documented representation distinct from an empty string.
- **V4-2-SEED-004:** Each CSV schema SHALL be versioned through the Flyway migration/package that consumes it, not through mutable loader interpretation.
- **V4-2-SEED-005:** A manifest SHALL record each file path, schema identifier, expected row count or permitted range, SHA-256 hash, load order, and destination table.
- **V4-2-SEED-006:** Seed packages SHALL be deterministic: the same package applied to the same predecessor state yields the same rows and hashes.
- **V4-2-SEED-007:** Reference seeds SHALL be idempotent by registered identity. A changed semantic meaning requires a new state/variant rather than an in-place identity reassignment.
- **V4-2-SEED-008:** A later approved implementation SHALL register every new identity
  before packaging it. The loader and migration SHALL NOT call `NEWID()`, generate a
  random or name-derived replacement GUID, allocate an identifier on first use, or
  repair an unregistered identifier. This specification allocates none.
- **V4-2-SEED-009:** After parsing, GUID equality, joins, uniqueness, registry checks, and
  de-duplication SHALL compare native database `uniqueidentifier` values. Text spelling,
  case, and collation SHALL NOT determine identity equality.
- **V4-2-SEED-010:** The loader SHALL reject non-canonical GUID text even when conversion
  would produce the same native database value. Formatting rejection is separate from
  native value comparison after parsing.
- **V4-2-SEED-011:** A GUID already registered for a different entity kind, natural key,
  or semantic meaning SHALL be rejected; it SHALL NOT be reassigned.

## Declared-type change identity contract

- **V4-2-SEED-012:** A fixture for a classified material declared-type change SHALL contain
  the previously registered semantic identity and a separately registered new semantic
  identity. The old identity and its historical state remain unchanged.
- **V4-2-SEED-013:** The classified material cases are any rule-kind change,
  scalar-to-different-scalar change, scalar/heap-object boundary crossing, and any
  heap/object-type change, including single value to collection. Each conformance case
  SHALL prove that the changed definition uses the new registered identity.
- **V4-2-SEED-014:** A default-value-only change or display-only-text change is
  non-material. Its fixture MAY retain the semantic identity and SHALL express the change
  through the applicable new State or validity history, never by mutating an immutable
  historical row.
- **V4-2-SEED-015:** The loader SHALL reject a classified material change that reuses the
  original semantic identity, and SHALL reject a purported new identity absent from the
  registry.
- **V4-2-SEED-016:** No fixture SHALL classify or seed any of the eight D-3 edge cases
  while they are `HITL-PENDING`: same-scalar nullability; same-scalar precision/scale;
  collection element type; renamed type with unchanged shape and semantics; combined
  default and type change; container cardinality/shape with unchanged element type;
  string length/constraint; or display text that feeds generated code or fixtures.

## Loader phases

1. **Discover:** Read the package manifest and reject missing, extra, duplicate, or path-escaping entries.
2. **Parse:** Validate UTF-8, headers, column order, null representation, and invariant scalar syntax.
3. **Stage:** Bulk-load into migration-owned staging tables with source filename and line number.
4. **Validate identity:** Check GUID registry membership, duplicate IDs, duplicate natural keys, and canonical text formatting.
5. **Validate references:** Check all foreign keys, EntityType admission, Philote ownership, and validity-period ownership.
6. **Validate semantics:** Check temporal overlap, graph rules, ordinal uniqueness, typed-value discriminants, constraints, and executor compatibility.
7. **Apply:** Insert or merge permitted rows in one transaction per migration unit.
8. **Assert:** Re-run counts, natural-key queries, graph checks, and representative effective-resolution queries.
9. **Record:** Persist package/migration identity, hashes, counts, UTC completion, and validation result without secrets.

- **V4-2-LOAD-001:** A failed validation SHALL leave destination reference tables unchanged.
- **V4-2-LOAD-002:** Loader diagnostics SHALL identify the file, line, semantic identity, failed rule, and safe remediation.
- **V4-2-LOAD-003:** The loader SHALL reject a GUID reused for a different entity kind or natural key.
- **V4-2-LOAD-004:** The loader SHALL reject a PhiloteValidityPeriod not owned by the state row's Philote-bearing entity.
- **V4-2-LOAD-005:** The loader SHALL reject plaintext secret material and accept only secret reference names where allowed.
- **V4-2-LOAD-006:** SQL generated or executed by a loader SHALL be parameterized or staging-table based; CSV content SHALL never become executable SQL text.
- **V4-2-LOAD-007:** After parsing, loaders and migrations SHALL compare, join, and de-duplicate GUIDs as native values. Text case, spelling, and database collation SHALL NOT determine GUID equality.
- **V4-2-LOAD-008:** Loader ordering SHALL come only from the manifest and explicit
  `Ordinal` columns. Filesystem enumeration order, CSV row order, insertion order, and
  GUID lexical order SHALL NOT supply semantic precedence.
- **V4-2-LOAD-009:** Rejection-negative mode SHALL stop after validation and SHALL never
  enter the Apply phase. Each negative fixture SHALL isolate one expected failure so a
  prior error cannot mask the contract under test.

## Foundational CSV files

| File                          | Seed content                                                                                        |
| ----------------------------- | --------------------------------------------------------------------------------------------------- |
| `EntityType.csv`              | Approved generic-association entity kinds only; row population is blocked by C-21.                  |
| `RulePurpose.csv`             | Validation, calculation, selection, normalization, explanation, planning.                           |
| `ValueType.csv`               | Semantic value types.                                                                               |
| `ScalarStorageKind.csv`       | Physical scalar discriminants.                                                                      |
| `ExecutorContract.csv`        | Supported deterministic executor interfaces.                                                        |
| `ExecutionClassification.csv` | Pure deterministic, deterministic-with-context, external-effecting, and prohibited-by-tier classes. |
| `RuleSetMembershipRole.csv`   | Add, Override, Suppress.                                                                            |
| `InputValueOrigin.csv`        | Default, User, Imported, Calculated, Inherited.                                                     |
| `InputWorkflowNodeKind.csv`   | Start, Group, Question, Branch, Review, Complete.                                                   |
| `InputWorkflowEdgeKind.csv`   | Next, WhenTrue, WhenFalse, Repeat, Return.                                                          |
| `RuleOutputDisposition.csv`   | Intermediate, Finding, PlanItem, Artifact, Explanation.                                             |
| `ExpertSystem.csv`            | Generic test system, Tags system, Mechanized Engineering starter.                                   |

## Overlay and graph CSV files

| File                                                                             | Purpose                                                         |
| -------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| `RuleVariant.csv` / `RuleVariantState.csv`                                       | Baseline and test variants.                                     |
| `RuleSetRuleOccurrence.csv`                                                      | Ordered Add/Override/Suppress examples.                         |
| `BuildSetRuleSetOccurrence.csv`                                                  | Ordered RuleSet layers, including D-2 precedence fixtures.      |
| `RuleInputDefinition.csv` / `RuleDefaultInputValue.csv`                          | Typed input contract and defaults.                              |
| `RuleOutputDefinition.csv`                                                       | Typed calculation and plan outputs.                             |
| `RuleValueConstraint.csv`                                                        | Range, allowed set, pattern, unit, and cross-field constraints. |
| `RuleDependencyEdge.csv` / `RuleOutputInputBinding.csv`                          | Calculation DAG and typed bindings.                             |
| `InputWorkflowNode.csv` / `InputWorkflowEdge.csv` / `InputWorkflowCondition.csv` | Question flow independent of calculation dependencies.          |

## Required reference fixtures

- **V4-2-SEED-020:** A generic arithmetic/validation expert system SHALL prove that the core is not hard-coded to Tags or computers.
- **V4-2-SEED-021:** A D-4 overlay fixture SHALL use one basic `RuleId` with distinct
  baseline, lower-overlay, and higher-overlay `RuleVariant` identities. The overlay
  occurrences SHALL use membership role `Override`; the basic Rule SHALL not be copied.
- **V4-2-SEED-022:** The overlay fixture SHALL have a baseline budget value of 1000, a
  lower-precedence overlay value of 1500, and a higher-`Ordinal` overlay value of 1200.
  Under D-2 `Ordinal DESC`, the expected effective value SHALL be 1200.
- **V4-2-SEED-023:** The same fixture SHALL include an earlier as-of instant at which only
  the baseline is active and an intermediate instant at which 1500 wins. Every as-of
  instant and `Ordinal` SHALL be explicit; CSV row order supplies neither time nor
  precedence.
- **V4-2-SEED-024:** Changing the effective budget SHALL dirty cost and downstream violation/output work but SHALL NOT dirty unrelated calculations.

Fixture names and semantic roles in this section are not allocated codes or GUID values.
An implementation SHALL replace each identity symbol only with a separately registered
identity and SHALL cite that registry entry in its manifest.

### Required rejection-negative overlay fixtures

| Fixture | Required rejection |
| --- | --- |
| Duplicate BuildSet ordinal | Two `BuildSetRuleSetOccurrence` rows in one BuildSet have the same `Ordinal`; no tie-break is allowed. |
| Override without base | An `Override` occurrence has no visible lower-precedence candidate for the same `RuleId`. |
| Override with different basic Rule | The overlay `RuleVariant.RuleId` differs from the lower-precedence candidate's `RuleId`. |
| Copied-rule overlay | An overlay introduces a copied basic Rule instead of a same-`RuleId` `RuleVariant`. |
| Add collision | An `Add` collides with an already visible candidate for the same `RuleId`. |
| Reused material-change identity | A classified material declared-type change retains the original semantic identity. |
| Unregistered replacement identity | A classified material change supplies a new GUID that has no registry entry. |
| Non-canonical GUID text | GUID text is not lowercase dashed `D`, even if it parses to a known native value. |
| Native-value duplicate | Two inputs parse to the same native database GUID value; the duplicate is rejected by value. |

A row-order perturbation positive fixture SHALL reorder CSV records while keeping
explicit ordinals unchanged; the effective result SHALL remain unchanged. This proves
that file order is not an accidental D-2 tie-break.

## Pending-item seed embargo

The following exclusions are release gates, not implementation suggestions:

- **C-21 — `HITL-PENDING`:** Do not populate `EntityType.csv` with inferred codes,
  including `rule` or `instantiation`. A filename reservation is not a row allocation.
- **C-24 — `HITL-PENDING`:** Do not migrate or seed legacy filing-taxonomy rows, even
  when a plausible mapping exists.
- **C-26 — `HITL-PENDING`:** Do not choose Tag-code collation or create fixtures whose
  expected validity depends on case, accent, width, or kana equivalence.
- **C-27 — `HITL-PENDING`:** Do not add or seed per-assignment confidence or relevance.
- **C-16 through C-20, C-22, C-23, and C-25 — `HITL-PENDING`:** Do not materialize
  actor/provenance policy, authorization semantics, Tag ordering, weighted traversal,
  tenant/store topology, relation-state endpoints, localization, or live-schema
  inventory.
- **FU-4 — `HITL-PENDING`:** Do not encode an assumed SQL Server edition or
  edition-sensitive enforcement path.
- **FU-6 — `HITL-PENDING`:** Do not seed successor chains, cycles, termination behavior,
  or erroneous-withdrawal behavior beyond the ruled requirement that a successor pointer
  exists on retraction.
- **D-3 edge cases 1 through 8 — `HITL-PENDING`:** Do not create positive or negative
  classification fixtures until the operator records the classification.

An implementation task SHALL re-read the authority documents and remove only the
specific embargo whose ruling is recorded. Silence, a recommendation, or an example from
V2/V3 is not a ruling.

## Migration and tier quality gates

| Gate           | Minimum evidence                                                                                                                          |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Static         | SQL parses; filenames and Flyway versions are unique; CSV schemas and hashes validate.                                                    |
| Fresh database | V3 plus the new layer migrates from empty; exact schema and reference rows match.                                                         |
| V3 upgrade     | A database at the V3 boundary upgrades without loss or reinterpretation of V3 rows.                                                       |
| Negative       | Invalid temporal intervals, IDs, types, ordinals, graphs, overlays, and secrets are rejected.                                             |
| Semantic       | As-of resolution, D-2 precedence, graph ordering, and incremental dirtying produce expected results.                                      |
| Domain         | Generic, Tags, then Mechanized Engineering scenarios pass in that order.                                                                  |
| Promotion      | The identical immutable migration package moves Experimental → Development → Integration → QA; Stable/Production requires named approval. |

- **V4-2-QUAL-001:** `expwhertzing` is the first live experimental target. AI agents MUST build an implementation task before executing against it, but execution under that task does not require an explicit human-in-the-loop gate.
- **V4-2-QUAL-002:** Promotion SHALL run increasingly broad tests; a higher tier SHALL never run fewer required suites than its predecessor.
- **V4-2-QUAL-003:** Package identity and hashes SHALL remain unchanged as the package moves upward in quality.
