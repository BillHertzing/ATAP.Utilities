# RPRRSBSI-V4 Seed Data and Loader Specification

## V3 seed baseline

The V3 consolidation currently establishes these minimum row counts: Philote 22, PhiloteValidityPeriod 22, RuleKind 2, RulePrimitive 15, RulePrimitiveInput 21, Rule 2, RuleSet 1, RuleSetRule 2, BuildSet 1, BuildSetRuleSet 1, and Instantiation 1. V4 tests SHALL characterize these rows before extending them.

## CSV packaging contract

- **V4-SEED-001:** Every reference row SHALL have a stable registered GUID and a stable human-readable code.
- **V4-SEED-002:** CSV files SHALL be UTF-8, comma-delimited, header-bearing, and use invariant formatting for booleans, decimal values, and UTC instants. GUID text SHALL use canonical lowercase dashed `D` format.
- **V4-SEED-003:** Null SHALL have one documented representation distinct from an empty string.
- **V4-SEED-004:** Each CSV schema SHALL be versioned through the Flyway migration/package that consumes it, not through mutable loader interpretation.
- **V4-SEED-005:** A manifest SHALL record each file path, schema identifier, expected row count or permitted range, SHA-256 hash, load order, and destination table.
- **V4-SEED-006:** Seed packages SHALL be deterministic: the same package applied to the same predecessor state yields the same rows and hashes.
- **V4-SEED-007:** Reference seeds SHALL be idempotent by registered identity. A changed semantic meaning requires a new state/variant rather than an in-place identity reassignment.

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

- **V4-LOAD-001:** A failed validation SHALL leave destination reference tables unchanged.
- **V4-LOAD-002:** Loader diagnostics SHALL identify the file, line, semantic identity, failed rule, and safe remediation.
- **V4-LOAD-003:** The loader SHALL reject a GUID reused for a different entity kind or natural key.
- **V4-LOAD-004:** The loader SHALL reject a PhiloteValidityPeriod not owned by the state row's Philote-bearing entity.
- **V4-LOAD-005:** The loader SHALL reject plaintext secret material and accept only secret reference names where allowed.
- **V4-LOAD-006:** SQL generated or executed by a loader SHALL be parameterized or staging-table based; CSV content SHALL never become executable SQL text.
- **V4-LOAD-007:** After parsing, loaders and migrations SHALL compare, join, and de-duplicate GUIDs as native values. Text case, spelling, and database collation SHALL NOT determine GUID equality.

## Foundational CSV files

| File                          | Seed content                                                                                        |
| ----------------------------- | --------------------------------------------------------------------------------------------------- |
| `EntityType.csv`              | All V4 generic-association entity kinds.                                                            |
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

- **V4-SEED-020:** A generic arithmetic/validation expert system SHALL prove that the core is not hard-coded to Tags or computers.
- **V4-SEED-021:** An overlay fixture SHALL have a baseline budget of 1000, a lower overlay of 1500, and a higher-ordinal overlay of 1200. The effective value SHALL be 1200 under D-2.
- **V4-SEED-022:** The same fixture SHALL include an earlier as-of instant at which only the baseline is active and an intermediate instant at which 1500 wins.
- **V4-SEED-023:** A Suppress fixture, an Override-without-base failure, an Add-collision failure, and a duplicate-ordinal failure SHALL be included as negative seed/test data.
- **V4-SEED-024:** Changing the effective budget SHALL dirty cost and downstream violation/output work but SHALL NOT dirty unrelated calculations.

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

- **V4-QUAL-001:** `expwhertzing` is the first live experimental target, but every execution against it requires an implementation task and an explicit human-in-the-loop gate.
- **V4-QUAL-002:** Promotion SHALL run increasingly broad tests; a higher tier SHALL never run fewer required suites than its predecessor.
- **V4-QUAL-003:** Package identity and hashes SHALL remain unchanged as the package moves upward in quality.
