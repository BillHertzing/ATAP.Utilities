# RPRRSBSI-V5 Instantiation and Materialization

> **New in V5 (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Implements DEC-1, DEC-2 (with [V5-25](RPRRSBSI-V5-25-ContentSummary-Data-Contract.md)), DEC-6, DEC-7, DEC-8 and DEC-10 from [the V5 overview](RPRRSBSI-V5-00-Specification-Overview.md#v5-decisions). Logical design only; no migration is authorized by this document. Diagram: [RPRRSBSI-V5-Instantiation-And-Materialization.puml](RPRRSBSI-V5-Instantiation-And-Materialization.puml).

Status: design contract for task authoring. Column lists are logical; physical types follow the V4-2/V5 conventions (`uniqueidentifier` keys, `datetime2(7)` UTC, `Latin1_General_100_BIN2` for codes) unless stated.

## 1. Vocabulary (normative)

| Term | Meaning |
| --- | --- |
| **Instantiation** | One produced artifact: a file at a path, or a row in a database table (DEC-6). |
| **Origin** | How an instantiation came to exist: `Asserted` (entered by a person; no materializer produced it) or `Generated` (produced by a materializer) (DEC-1). |
| **Materialization** | One run of a materializer that reads a BuildSet (its RuleSets and effective RuleVariants at an as-of instant) and a set of input values, and produces zero or more `Generated` instantiations (DEC-7). |
| **Materializer** | The executor component that performs materializations for a RuleKind (DEC-7). |
| **Materialization specification** | The reusable configuration that a materialization runs: BuildSet, input binding and materializer (DEC-7). This is what the V00010 table `ATAPUtilities.Instantiation` holds today. |
| **Supersession** | The replacement of an `Asserted` instantiation by a `Generated` one that produces the same (or knowingly different) content. |

"Execution" is not used for this act. Older documents use *Manifestation* for produced output (V2, ADR-140) and *Instantiation* for a configured act (V3/V4-2); both readings are superseded here.

## 2. Requirements

- **V5-INST-001:** Every instantiation SHALL have exactly one `OriginKind`, `Asserted` or `Generated`, from the shared catalog `InstantiationOriginKind`.
- **V5-INST-002:** A `Generated` instantiation SHALL reference exactly one `Materialization`. An `Asserted` instantiation SHALL reference no materialization and SHALL record the asserting user, the asserted-at instant and a source reference (evidence of what real artifact it mirrors).
- **V5-INST-003:** An `Asserted` instantiation MAY name the materialization specification intended to produce it, so that the path from instantiation back to rule and materializer exists before the rules are written.
- **V5-INST-004:** A file instantiation SHALL reference `SourceArtifact` and `SourceArtifactVersion` (V00100: repository-relative identity, byte and normalized hashes). A row instantiation SHALL reference a typed entity (`EntityType`, `EntityId`; interim catalog `TagAssignmentEntityType`, V5-CORE-013).
- **V5-INST-005:** Instantiations are append-only. Replacement SHALL close the old instantiation's state and record `InstantiationSupersession` with comparison evidence (equal normalized hash, or a recorded, reviewed difference). No instantiation row is updated in place or deleted.
- **V5-INST-006:** Every `Materialization` SHALL record the acting user, the owner on whose behalf it ran (`OwnerUserId` or `OwnerOrganizationId`, DEC-3), the specification, the as-of instant, the materializer identity and version, the normalized input hash, timestamps and status. Retries are `MaterializationAttempt` rows of one materialization.
- **V5-INST-007:** The rule bindings and input values used by a materialization SHALL be frozen with it (`MaterializationRuleBinding`, `MaterializationInputValue`) so that an instantiation remains explainable after definitions change (V5-CORE-063).
- **V5-INST-008:** `InstantiationOriginKind` SHALL be the single origin vocabulary for every origin-bearing table: instantiations, `ContentSummaryVersion.GeneratorKindCode` (V5-25) and `ACE.OrganizationFactProvenance.OriginKind` (whose value `Manual` becomes `Asserted`; `Template` becomes an orthogonal "derived from template" fact).
- **V5-INST-009:** Under DEC-3 every table in this document exists in `ATAPUtilities` (template rows, no owner columns) and in `Ace` (owned copies). Materializations run by users are `Ace` rows; reference materializations that produce `ATAPUtilities` template rows are `ATAPUtilities` rows run by the ATAP release process.
- **V5-INST-010:** Rules that govern AI agents SHALL be modelled as file instantiations. `.ai/core/main-instructions.md` is the first intended `Asserted` file instantiation; an AgentText-kind materializer later supersedes it (DEC-10, ADR-018).

## 3. Logical tables

| Table | Key columns | Notes |
| --- | --- | --- |
| `InstantiationOriginKind` | `OriginKindCode` PK (`Asserted`, `Generated`), description | Seeded catalog; immutable. |
| `MaterializationSpecification` | `MaterializationSpecificationId` PK = `PhiloteId`, `BuildSetId` FK, `MaterializationSpecificationCode` UQ, `MaterializerCode` | **Renamed from V00010 `Instantiation`** (DEC-8). Existing rows: `HelloWorld`, `CS-I01-contentsummary-initial-v1`. |
| `MaterializationSpecificationState` | PK, specification FK, validity period, lifecycle (`Draft`, `Active`, `Retired`), input-binding reference | Append/close-only (ADR-003 pattern). |
| `Materialization` | `MaterializationId` PK = `PhiloteId`, specification FK, `AsOfUtc`, `MaterializerCode`, `MaterializerVersion`, `NormalizedInputSha256`, `ActingUserId`, `OwnerUserId` / `OwnerOrganizationId` (Ace), `RequestedAtUtc`, `CompletedAtUtc`, `StatusCode` (`Requested`, `Running`, `Succeeded`, `Failed`, `Cancelled`) | Idempotency key: specification + effective definition + input hash (V5-CORE-061). |
| `MaterializationAttempt` | PK, materialization FK, attempt number, started/ended, status, diagnostics hash | Retries. |
| `MaterializationRuleBinding` | materialization FK, `RuleVariantId`, occurrence ids, precedence outcome | Output of `ResolveBuildSetRulesAsOf` frozen at run time. |
| `MaterializationInputValue` | materialization FK, input definition FK, typed value columns, value origin (`User`, `Default`, `Calculated`, `Imported`, `Inherited`) | Typed per V5-CORE-040…043. |
| `Instantiation` | `InstantiationId` PK = `PhiloteId`, `OriginKindCode` FK, `TargetKindCode` (`File`, `Row`), `SourceArtifactVersionId` (file) or `EntityTypeId` + `EntityId` (row), `MaterializationId` (required iff `Generated`), `IntendedMaterializationSpecificationId` (optional, `Asserted` only), `AssertedByUserId`, `AssertedAtUtc`, `SourceReference`, owner columns (Ace), `RecordedAtUtc` | `CHECK` enforces V5-INST-002 and the file/row exclusivity. |
| `InstantiationState` | PK, instantiation FK, validity period, `StatusCode` (`Current`, `Superseded`, `Retired`) | Append/close-only. |
| `InstantiationSupersession` | PK, `PredecessorInstantiationId`, `SuccessorInstantiationId`, `ComparisonCode` (`Equal`, `ReviewedDifference`), evidence hash, recorded by/at | Successor must be `Generated`. |

## 4. Migration of the built schema (forward only)

1. **Rename (DEC-8).** One new migration: `sp_rename` `ATAPUtilities.Instantiation` → `MaterializationSpecification`, its key and code columns, its constraints; rename `ContentSummaryVersion.InstantiationId` → `MaterializationSpecificationId` and its foreign key (V00100); retarget the `TagAssignmentEntityType` row `instantiation` (V00090) to the new `Instantiation` table and add `materialization-specification`. Update the procedures in V00100–V00120 that name the old column by `CREATE OR ALTER` in the same migration. `V00010` is in Production, so this migration is a breaking change for any consumer of the old name; today the only consumers are V00100–V00140 objects.
2. **Create** the tables in Section 3 in `ATAPUtilities`, then their owned copies in `Ace` (V5-60 generator).
3. **Seed** `InstantiationOriginKind`; seed the asserted ContentSummary rule set and specification (V5-25).
4. **Backfill**: register each existing `ContentSummaryVersion` as a `Generated` (or, for hand-entered rows, `Asserted`) row instantiation.
5. **Change** `ACE.OrganizationFactProvenance.OriginKind` `CHECK` and rows: `Manual` → `Asserted`.

Rehearse on a disposable database, then apply to `expwhertzing` under the forward-only protocol ([V5-50](RPRRSBSI-V5-50-Layered-Implementation-Handoff.md)). Because the rename touches a Production table, the recommendation in V5-50 is to hold it for the next consolidated baseline rather than promote it alone.

## 5. Typical flows

| Flow | Rows written |
| --- | --- |
| Hand-enter a content summary for a Tag | `ContentSummaryVersion` (asserted rule set, `GeneratorKindCode = 'Asserted'`); `Instantiation` (`Asserted`, row target); `TagAssignment` to `content-summary-version`. |
| Hand-register an existing file (for example `main-instructions.md`) | `SourceArtifactVersion` observation; `Instantiation` (`Asserted`, file target, intended specification = AgentText renderer). |
| Run rules for a user | `Materialization` (acting user, owner), `MaterializationRuleBinding`, `MaterializationInputValue`, `MaterializationAttempt`; one `Instantiation` (`Generated`) per produced file or row. |
| Replace an asserted artifact | New `Generated` instantiation; comparison; `InstantiationSupersession`; predecessor state closed as `Superseded`. |
| Work backwards from an artifact | `Instantiation` → `Materialization` → specification → BuildSet → RuleSets → RuleVariants (or, for `Asserted`, the intended specification and evidence). |

## 6. Open items

See [HANDOFF-V5.md](HANDOFF-V5.md): comparison rules for row instantiations; whether every `ContentSummaryVersion` is also a registered `Instantiation` or carries the columns directly (recommended: registered); timing of the rename relative to a consolidated baseline.
