# RPRRSBSI V3 physical data dictionary

## Authority and conventions

This is the implemented SQL Server 2022 physical contract for the consolidated
RPRRSBSI V3 initial lineage. It matches the PTV-G0-ratified temporal contract and
the active `V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql` source.
Documentation of this contract does not itself authorize database creation,
package publication, promotion, or deployment.

Content retrieval was requested with retrieval labels [RPRRSBSI,V3,physical-schema,data-dictionary], depth 3, width 2, production. gather-content-summary was unavailable (no registered command), so the direct-read fallback used the amended V3 plan, IPhilote.cs, and retained Path and PowerShell compendiums.

All objects are in schema ATAPUtilities. Every foreign key has ON DELETE NO ACTION and ON UPDATE NO ACTION. Identifiers have no defaults and come from the seed registry. Every Ordinal is zero-based int NOT NULL with CHECK (Ordinal >= 0). No audit, extension, property-bag, ownership, or soft-delete column is allowed.

## Exact eleven-table inventory

| # | Table | Purpose |
| -: | --- | --- |
| 1 | Philote | Philote registry row. |
| 2 | PhiloteValidityPeriod | Ordered half-open business-validity periods for a Philote. |
| 3 | RuleKind | PowerShell or Path domain. |
| 4 | RulePrimitive | Retained primitive in a kind. |
| 5 | RulePrimitiveInput | Primitive-input definition metadata. |
| 6 | Rule | Exact renderable content. |
| 7 | RuleSet | Named Rule collection. |
| 8 | RuleSetRule | Ordered Rule membership. |
| 9 | BuildSet | Named RuleSet collection. |
| 10 | BuildSetRuleSet | Ordered RuleSet membership. |
| 11 | Instantiation | Direct selection of one BuildSet. |

## Table contracts

### Philote

| Column | Type | Null | Constraint / meaning |
| --- | --- | --- | --- |
| PhiloteId | uniqueidentifier | No | PK_Philote; maps IAbstractPhilote.Id. |
| AdditionalIdsStub | nvarchar(max) | Yes | CK_Philote_AdditionalIdsStubIsNull: AdditionalIdsStub IS NULL. |

A Philote-bearing entity has exactly one matching Philote row. The entity key and PhiloteId deliberately equal the registry key; that GUID cannot identify a different semantic object.

### PhiloteValidityPeriod

| Column | Type | Null | Meaning |
| --- | --- | --- | --- |
| PhiloteValidityPeriodId | uniqueidentifier | No | Stable caller- or registry-supplied period-row identity; primary key. |
| PhiloteId | uniqueidentifier | No | Parent identity; foreign key to `Philote(PhiloteId)`. |
| PreviousValidToUtc | datetime2(7) | Yes | End of the immediate predecessor; null only for the first row. |
| ValidFromUtc | datetime2(7) | No | Included UTC business-validity boundary. |
| ValidToUtc | datetime2(7) | Yes | Excluded UTC boundary; null means open-ended. |

Constraints: `PK_PhiloteValidityPeriod`;
`FK_PhiloteValidityPeriod_Philote` with `NO ACTION` update/delete;
`CK_PhiloteValidityPeriod_NonEmpty`;
`CK_PhiloteValidityPeriod_PredecessorNotAfterStart`;
`UQ_PhiloteValidityPeriod_Philote_ValidFromUtc`;
`UQ_PhiloteValidityPeriod_Philote_ValidToUtc`;
`UQ_PhiloteValidityPeriod_Philote_PreviousValidToUtc`; and the self-reference
`FK_PhiloteValidityPeriod_Predecessor` from
`(PhiloteId, PreviousValidToUtc)` to `(PhiloteId, ValidToUtc)` with `NO ACTION`
update/delete. One Philote has zero or more rows. The approved initial seed has
one open-ended row for each of the 22 Philotes.

### RuleKind

| Column | Type | Null |
| --- | --- | --- |
| RuleKindId | uniqueidentifier | No |
| PhiloteId | uniqueidentifier | No |
| RuleKindCode | varchar(64) | No |
| RuleKindName | nvarchar(128) | No |

Constraints: PK_RuleKind(RuleKindId); FK_RuleKind_Philote(PhiloteId) -> Philote(PhiloteId); UQ_RuleKind_Philote(PhiloteId); UQ_RuleKind_Code(RuleKindCode); UQ_RuleKind_Name(RuleKindName); CK_RuleKind_Philote_Equals_Id: RuleKindId = PhiloteId; CK_RuleKind_Code_NotEmpty and CK_RuleKind_Name_NotEmpty: DATALENGTH(value) > 0. One kind has zero or more primitives and Rules.

### RulePrimitive

| Column | Type | Null |
| --- | --- | --- |
| RulePrimitiveId | uniqueidentifier | No |
| PhiloteId | uniqueidentifier | No |
| RuleKindId | uniqueidentifier | No |
| RulePrimitiveCode | nvarchar(128) | No |

Constraints: PK_RulePrimitive(RulePrimitiveId); FK_RulePrimitive_Philote(PhiloteId) -> Philote(PhiloteId); FK_RulePrimitive_RuleKind(RuleKindId) -> RuleKind(RuleKindId); UQ_RulePrimitive_Philote(PhiloteId); UQ_RulePrimitive_RuleKind_Code(RuleKindId,RulePrimitiveCode); UQ_RulePrimitive_Id_RuleKind(RulePrimitiveId,RuleKindId), supporting Rule's matching-kind FK; CK_RulePrimitive_Philote_Equals_Id; CK_RulePrimitive_Code_NotEmpty: DATALENGTH(RulePrimitiveCode) > 0. A primitive has one kind and zero or more metadata rows and Rules.

### RulePrimitiveInput

| Column | Type | Null |
| --- | --- | --- |
| RulePrimitiveInputId | uniqueidentifier | No |
| RulePrimitiveId | uniqueidentifier | No |
| InputName | nvarchar(128) | No |
| InputType | nvarchar(256) | No |
| InputDescription | nvarchar(1024) | No |
| DefaultValue | nvarchar(4000) | Yes |
| IsRequired | bit | No |
| Ordinal | int | No |

Constraints: PK_RulePrimitiveInput(RulePrimitiveInputId); FK_RulePrimitiveInput_RulePrimitive(RulePrimitiveId) -> RulePrimitive(RulePrimitiveId); UQ_RulePrimitiveInput_Name(RulePrimitiveId,InputName); UQ_RulePrimitiveInput_Ordinal(RulePrimitiveId,Ordinal); CK_RulePrimitiveInput_Name_NotEmpty; CK_RulePrimitiveInput_Type_NotEmpty; CK_RulePrimitiveInput_Description_NotEmpty; CK_RulePrimitiveInput_Ordinal_NonNegative.

One primitive declares zero or more definitions. The approved initial catalog has 21 retained Path declarations and none for either PowerShell primitive. That Path-only seed rule is enforced by the loader/assertion migration: a table check would require an unapproved redundant kind column or a trigger.

### Rule

| Column | Type | Null |
| --- | --- | --- |
| RuleId | uniqueidentifier | No |
| PhiloteId | uniqueidentifier | No |
| RuleKindId | uniqueidentifier | No |
| RulePrimitiveId | uniqueidentifier | No |
| RuleCode | varchar(128) | No |
| RuleBody | nvarchar(max) | No |

Constraints: PK_Rule(RuleId); FK_Rule_Philote(PhiloteId) -> Philote(PhiloteId); FK_Rule_RuleKind(RuleKindId) -> RuleKind(RuleKindId); FK_Rule_RulePrimitive_MatchingKind(RulePrimitiveId,RuleKindId) -> RulePrimitive(RulePrimitiveId,RuleKindId); UQ_Rule_Philote(PhiloteId); UQ_Rule_RuleKind_Code(RuleKindId,RuleCode); CK_Rule_Philote_Equals_Id; CK_Rule_Code_NotEmpty; CK_Rule_Body_NotEmpty.

Each Rule selects one kind and one primitive of that same kind. Initial Path content is exactly HelloWorld.ps1 under retained <relative-path>.

### RuleSet

| Column | Type | Null |
| --- | --- | --- |
| RuleSetId | uniqueidentifier | No |
| PhiloteId | uniqueidentifier | No |
| RuleSetCode | varchar(128) | No |

Constraints: PK_RuleSet(RuleSetId); FK_RuleSet_Philote(PhiloteId) -> Philote(PhiloteId); UQ_RuleSet_Philote(PhiloteId); UQ_RuleSet_Code(RuleSetCode); CK_RuleSet_Philote_Equals_Id; CK_RuleSet_Code_NotEmpty.

### RuleSetRule

| Column | Type | Null |
| --- | --- | --- |
| RuleSetId | uniqueidentifier | No |
| RuleId | uniqueidentifier | No |
| Ordinal | int | No |

Constraints: PK_RuleSetRule(RuleSetId,RuleId); FK_RuleSetRule_RuleSet(RuleSetId) -> RuleSet(RuleSetId); FK_RuleSetRule_Rule(RuleId) -> Rule(RuleId); UQ_RuleSetRule_Ordinal(RuleSetId,Ordinal); CK_RuleSetRule_Ordinal_NonNegative. A Rule can be in many RuleSets but the pair occurs once. Initial order: PowerShell 0, Path 1.

### BuildSet

| Column | Type | Null |
| --- | --- | --- |
| BuildSetId | uniqueidentifier | No |
| PhiloteId | uniqueidentifier | No |
| BuildSetCode | varchar(128) | No |

Constraints: PK_BuildSet(BuildSetId); FK_BuildSet_Philote(PhiloteId) -> Philote(PhiloteId); UQ_BuildSet_Philote(PhiloteId); UQ_BuildSet_Code(BuildSetCode); CK_BuildSet_Philote_Equals_Id; CK_BuildSet_Code_NotEmpty.

### BuildSetRuleSet

| Column | Type | Null |
| --- | --- | --- |
| BuildSetId | uniqueidentifier | No |
| RuleSetId | uniqueidentifier | No |
| Ordinal | int | No |

Constraints: PK_BuildSetRuleSet(BuildSetId,RuleSetId); FK_BuildSetRuleSet_BuildSet(BuildSetId) -> BuildSet(BuildSetId); FK_BuildSetRuleSet_RuleSet(RuleSetId) -> RuleSet(RuleSetId); UQ_BuildSetRuleSet_Ordinal(BuildSetId,Ordinal); CK_BuildSetRuleSet_Ordinal_NonNegative. A RuleSet can be in many BuildSets but the pair occurs once. Initial membership is ordinal 0.

### Instantiation

| Column | Type | Null |
| --- | --- | --- |
| InstantiationId | uniqueidentifier | No |
| PhiloteId | uniqueidentifier | No |
| BuildSetId | uniqueidentifier | No |
| InstantiationCode | varchar(128) | No |

Constraints: PK_Instantiation(InstantiationId); FK_Instantiation_Philote(PhiloteId) -> Philote(PhiloteId); FK_Instantiation_BuildSet(BuildSetId) -> BuildSet(BuildSetId); UQ_Instantiation_Philote(PhiloteId); UQ_Instantiation_Code(InstantiationCode); CK_Instantiation_Philote_Equals_Id; CK_Instantiation_Code_NotEmpty. Each Instantiation selects one BuildSet; a BuildSet has zero or more selecting Instantiations.

## Temporal-validity exactness

Periods use half-open semantics: `[ValidFromUtc, ValidToUtc)`. The start belongs
to the period; a finite end does not. `ValidToUtc = NULL` means no known end.
`PreviousValidToUtc` links each non-first row to the exact end of its immediate
predecessor. Equality between predecessor end and current start is adjacency;
strict inequality is an allowed gap.

The predecessor foreign key plus the three Philote-scoped unique constraints form
one non-branching chain. The non-empty and predecessor-order checks reject zero or
reversed periods and overlap. No ordinal, duration, computed end, execution-time
default, or anytime sentinel is stored. Valid time is business state and is not
SQL Server transaction time.

All mutations cross the eight-procedure boundary:
`CreateFirstPhiloteValidityPeriod`, `CloseCurrentPhiloteValidityPeriod`,
`ReactivatePhiloteValidityPeriod`, `CorrectPhiloteValidityPeriodBoundary`,
`SplitPhiloteValidityPeriod`, `MergeAdjacentPhiloteValidityPeriods`,
`DeletePhiloteValidityPeriod`, and `ReplacePhiloteValidityPeriodSet`. Each
serializes writers per Philote, validates the complete desired chain, applies the
rewrite atomically, and returns the resulting five-column set ordered by start.

Point containment uses
`ValidFromUtc <= @AsOfUtc AND (ValidToUtc IS NULL OR @AsOfUtc < ValidToUtc)`.
Bounded overlap uses
`ValidFromUtc < @SearchToUtc AND (ValidToUtc IS NULL OR @SearchFromUtc < ValidToUtc)`.
`BETWEEN` is prohibited because it would include the excluded end.

## Positive and invalid-row controls

All symbols below are distinct valid GUIDs unless marked absent. Each invalid case must fail the named constraint.

| Rule | Positive example | Invalid-row counterexample | Constraint |
| --- | --- | --- | --- |
| Philote stub | Philote(P1,NULL) | Philote(P2,N'non-null') | CK_Philote_AdditionalIdsStubIsNull |
| Philote equality | RuleKind(K1,K1,...); same key pair for RulePrimitive, Rule, RuleSet, BuildSet, Instantiation | any entity has Id=X1 and PhiloteId=P1 | all six CK_*_Philote_Equals_Id |
| Philote uniqueness | RuleKind(K1,K1,...) | second RuleKind with PhiloteId=K1 | UQ_RuleKind_Philote; equivalent UQs on all Philote-bearing tables |
| Validity-period parent | `VP1(P1,NULL,S,NULL)`, with `Philote(P1)` | same row has absent `PhiloteId=PX` | `FK_PhiloteValidityPeriod_Philote` |
| Validity-period boundaries | `VP1(P1,NULL,01:00,02:00)` | zero/reversed end, predecessor after start, duplicate start/end/root, broken predecessor, overlap, cycle, or a successor after an open end | the two checks, three unique constraints, and predecessor self-FK |
| RuleKind FK | RuleKind(K1,K1,...), with Philote(K1) | same row has absent PhiloteId=KX | FK_RuleKind_Philote |
| Primitive FKs | RulePrimitive(PR1,PR1,K1,N'<relative-path>'), with parents | absent Philote PX or kind KX | FK_RulePrimitive_Philote; FK_RulePrimitive_RuleKind |
| Input FK | RulePrimitiveInput(I1,PR1,N'PathTail',N'<path-tail>',N'desc',NULL,1,0) | same row has absent primitive PRX | FK_RulePrimitiveInput_RulePrimitive |
| Rule FKs | Rule(R1,R1,K1,PR1,'HelloWorld.Path',N'HelloWorld.ps1') | absent Philote/kind; or K2 while PR1 belongs to K1 | all three FK_Rule_* |
| RuleSet FKs | RuleSet(RS1,RS1,...); RuleSetRule(RS1,R1,0) | absent Philote, RuleSet, or Rule parent | FK_RuleSet_Philote; both FK_RuleSetRule_* |
| BuildSet FKs | BuildSet(BS1,BS1,...); BuildSetRuleSet(BS1,RS1,0) | absent Philote, BuildSet, or RuleSet parent | FK_BuildSet_Philote; both FK_BuildSetRuleSet_* |
| Instantiation FKs | Instantiation(IN1,IN1,BS1,'HelloWorld') | absent Philote INX or BuildSet BSX | both FK_Instantiation_* |
| Stable code/name | one Path kind code and name | different key repeats its code or name | UQ_RuleKind_Code; UQ_RuleKind_Name |
| Primitive/input natural keys | one (K1,<relative-path>); one (PR1,PathTail) | repeats either pair | UQ_RulePrimitive_RuleKind_Code; UQ_RulePrimitiveInput_Name |
| Other codes | one Rule code per kind and one collection code | repeat the applicable scope | UQ_Rule_RuleKind_Code; UQ_RuleSet_Code; UQ_BuildSet_Code; UQ_Instantiation_Code |
| Membership uniqueness | RuleSetRule(RS1,R1,0); BuildSetRuleSet(BS1,RS1,0) | repeat either pair | PK_RuleSetRule; PK_BuildSetRuleSet |
| All ordinals | first member has Ordinal=0 | Ordinal=-1; or another same-parent member at 0 | all CK_*_Ordinal_NonNegative and UQ_*_Ordinal |
| Required text | all code/name/input/body values contain text | set a required value to empty string | every CK_*_NotEmpty |

## Explicit physical exclusions

These names and families are exclusions only: they must not become a table, view, procedure, trigger, loader, or compatibility object.

- RulePrimitiveVersion, RuleVersion, RuleSetVersion, BuildSetVersion, InstantiationVersion, ManifestationVersion, or any version/effective-dating/supersession/lineage object.
- Manifestation, ManifestationArtifact, publication, approval, plan, attempt, execution, retry, journal, outbox, ingestion, SourceArtifact, source observation, source locator, or provenance object.
- InputBlock, Rule-input binding, parameter-value, or runtime-input object. RulePrimitiveInput remains definition metadata only.
- ContentSummary, AgentText, PKIArtifact, Organization, Repository, User, Gmail, Tags, BuildMaster, ProGet, or AceCommander domain object.
- additional-ID child, generic property bag, JSON extension, audit/ownership/soft-delete, or V1/V2 compatibility object.

## Contract verification checklist

- [x] The physical inventory is exactly the eleven tables listed above.
- [x] Every column, type/length, nullability, key, FK action, unique/check rule,
  and ordinal base matches the consolidated migration.
- [x] The runtime suite rejects the named temporal negative controls and passes
  the mutation, boundary, and concurrent-writer cases.
- [x] PTV-G4 accepted the database/package source before this documentation wave.

See [ADR-Philote-Temporal-Validity-Relational-Contract.md](ADR-Philote-Temporal-Validity-Relational-Contract.md)
for the complete proof, procedure signatures, and invalid-shape matrix.
