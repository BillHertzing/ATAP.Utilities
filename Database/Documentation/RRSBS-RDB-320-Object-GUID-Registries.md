# RDB-320 — Object and Philote Registries

Status: Wave 4 source-frozen registry contract complete. This document does
not contain SQL, create or alter a migration, allocate a package, connect to a
live tier, authorize a reset, or weaken any RDB-850 exact-target gate.

## Decision

RRSBS V2 uses the `ATAPUtilities` schema for the 89 table and catalog objects
owned by the approved RDB-200 through RDB-260 logical slices. Object names are
the exact local, non-external PlantUML entity tokens in those seven approved
slice models. Constraint, index, and trigger names are derived by the closed
algorithm below. A physical fragment may not invent an alternate spelling or
an unregistered object.

Philotes are table-specific. The shared `Entity.EntityPhiloteId` repeats the
subtype Philote and is not a second identity. Reference identities are either
an explicitly retained source Philote or an RFC 4122 UUIDv5 derived from the
frozen RRSBS V2 namespace and canonical natural key. Runtime `NEWID()` is
prohibited for reference entities.

## Authorities and frozen inputs

- `RRSBS-RDB-200` through `RRSBS-RDB-260` logical-model Markdown and PlantUML
  files define the table, Philote, and relationship contracts.
- `RRSBS-RDB-270-Integrated-Logical-Model.md` defines the 43-code EntityType
  allow-list and cross-slice closure.
- `RRSBS-RDB-280-Integrated-Logical-Model-Adversarial-Review.md` defines the
  invalid-row obligations inherited by RDB-400 through RDB-460.
- RDB-010F and RDB-160 freeze 334 distinct source GUIDs and their origins.
- RDB-170 freezes 47 CSV inputs, 517 rows, their hashes, and the deterministic
  conversion shape.
- `RDB-320-Source-Identity-Resolution-Worksheet.md` is the HITL disposition
  authority for the 175 previously ambiguous GUIDs.
- RDB-300 fixes the new lineage at package `0.0.1`, baseline `00010`, and
  history table `rrsbs_flyway_schema_history`; RDB-310 owns all non-RRSBS
  carry, preserve, and retire decisions.
- `Database/Tools/Invoke-Rdb320RegistryValidation.ps1` is the durable verifier;
  its generated CSV mirrors and evidence remain under `_generated/RRSBS-V2/RDB-320/`.

## Object-name registry

The registry schema is `ATAPUtilities`. For every row below, the physical name
is `[ATAPUtilities].[<PlantUML entity token>]`. The verifier reads indented
`entity` declarations, rejects declarations marked `external`, and requires
the following slice totals.

| Owner | Registered local objects | Count |
| --- | --- | ---: |
| RDB-200 | EntityType, Entity, RelationshipRolePolicy, RelationshipRoleEndpointEntityType, Authority, AuthorityVersion, Expert, ExpertVersion, ExpertiseDomain, ExpertiseDomainVersion, Tag, TagVersion, EntityAuthorityAssignment, EntityExpertiseDomainAssignment, TagAssignment, Attribution, AttributionDispute, AttributionDisputeEvent | 18 |
| RDB-210 | RuleKind, RuleKindVersion, RuleKindVersionCompatibility, ExecutionClassification, SecurityCapabilityClassification, RoundTripPolicy, ExecutorContract, ExecutorContractVersion, Primitive, PrimitiveVersion, PrimitiveInputDefinition, ValueType, ValueTypeVersion, ScalarStorageKind, StructuredValueContract, StructuredValueContractVersion, SecretReferencePolicy, ValueTypeAllowedEntityType | 18 |
| RDB-220 | Rule, RuleVersion, RuleVersionNode, RuleVersionNodeInput, BindingShape, DerivationContractVersion, RuleInputDefinition, RuleDefaultInputValue, RuleOutputDefinition | 9 |
| RDB-230 | RuleSet, RuleSetVersion, RuleSetVersionMember, RuleSetMembershipRole, BuildSet, BuildSetVersion, BuildSetVersionMember, BuildSetMembershipRole | 8 |
| RDB-240 | Instantiation, InstantiationVersion, BuildSetRuleOccurrence, InstantiationOccurrenceBinding, BindingResolution, InputBlock, InputBlockVersion, InputValue, InstantiationVersionInputBlock, PermissionVerb, InstantiationPermissionGrant, EditSession | 12 |
| RDB-250 | ManifestationPlan, PlanArtifact, PlanApproval, PlanApprovalStateEvent, Manifestation, ManifestationAttempt, RuleExecution, ManifestationEvent, ManifestationArtifact, ErrorTaxonomy, RuleUsage | 11 |
| RDB-260 | Organization, Repository, RepositoryRootRegistration, SourceModule, SourceArtifact, SourceArtifactVersion, SourceArtifactLineage, ContentSummary, ContentSummaryVersion, ContentSummaryDependency, AgentTextProjection, AgentTextProjectionVersion, AgentTextProjectionRefresh | 13 |

The registry contains no RRSBS V2 views, synonyms, sequences, or triggers.
RDB-470 separately owns the already-dispositioned Tags and Gmail objects. A
later physical slice that proves a new object is necessary must amend this
registry before RDB-480 integrates it.

## Constraint, index, and trigger-name registry

Names use ASCII letters, digits, and underscores and are unique under ordinal
case-insensitive comparison. `Table`, `Parent`, and column tokens use their
registered PascalCase spelling. `Role` and `Purpose` are concise PascalCase
semantic tokens fixed in the owning fragment's registry evidence.

| Class | Canonical raw name |
| --- | --- |
| Primary key | `PK_<Table>` |
| Unique constraint | `UQ_<Table>_<ColumnsInDeclaredOrder>` |
| Foreign key | `FK_<ChildTable>_<ParentTable>_<Role>` |
| Check constraint | `CK_<Table>_<Invariant>` |
| Non-unique index | `IX_<Table>_<ColumnsOrPurpose>` |
| Trigger | `TR_<Table>_<EventPurpose>` |

If a raw name is at most 128 characters, it is the physical name. Otherwise,
the physical name is the first 111 characters, an underscore, and the first
16 uppercase hexadecimal characters of SHA-256 over the UTF-8 raw name. This
produces exactly 128 characters and makes shortening deterministic. The full
raw name and shortened name must both appear in the owning RDB-400 through
RDB-460 fragment evidence.

Every table receives `PK_<Table>`. Every Philote column receives
`UQ_<Table>_<PhiloteColumn>`. Additional candidate keys and FKs are derived in
the exact logical-model column order.

### Wave 5 proven trigger amendment

RDB-400 through RDB-470 first proved 99 physical triggers necessary. The
approved RDB-480 contract amendments then proved 10 more for the seven RDB-450
parents and the three RDB-460 physical parents/bridge, producing the 109-name
registry below. These names are frozen under the RDB-320 amendment rule. The
durable validator requires exactly this case-insensitive unique set; any later
physical trigger must be added by another explicit registry amendment before
integration.

<!-- RDB320-WAVE5-TRIGGERS:BEGIN -->
- `TR_Attribution_LineageImmutable`
- `TR_AttributionDispute_UpdateDeleteImmutable`
- `TR_AttributionDisputeEvent_StateLineageImmutable`
- `TR_Authority_UpdateDeleteImmutable`
- `TR_AuthorityVersion_LineageImmutable`
- `TR_Entity_UpdateDeleteImmutable`
- `TR_EntityAuthorityAssignment_LineageImmutable`
- `TR_EntityExpertiseDomainAssignment_LineageImmutable`
- `TR_EntityType_UpdateDeleteImmutable`
- `TR_ExecutionClassification_UpdateDeleteImmutable`
- `TR_ExecutorContract_UpdateDeleteImmutable`
- `TR_ExecutorContractVersion_LineageImmutable`
- `TR_Expert_UpdateDeleteImmutable`
- `TR_ExpertiseDomain_UpdateDeleteImmutable`
- `TR_ExpertiseDomainVersion_LineageImmutable`
- `TR_ExpertVersion_LineageImmutable`
- `TR_Primitive_UpdateDeleteImmutable`
- `TR_PrimitiveInputDefinition_OrdinalImmutable`
- `TR_PrimitiveVersion_LineageImmutable`
- `TR_RelationshipRoleEndpointEntityType_UpdateDeleteImmutable`
- `TR_RelationshipRolePolicy_UpdateDeleteImmutable`
- `TR_RoundTripPolicy_UpdateDeleteImmutable`
- `TR_RuleKind_UpdateDeleteImmutable`
- `TR_RuleKindVersion_LineageImmutable`
- `TR_RuleKindVersionCompatibility_ForwardImmutable`
- `TR_ScalarStorageKind_UpdateDeleteImmutable`
- `TR_SecretReferencePolicy_UpdateDeleteImmutable`
- `TR_SecurityCapabilityClassification_UpdateDeleteImmutable`
- `TR_StructuredValueContract_UpdateDeleteImmutable`
- `TR_StructuredValueContractVersion_LineageImmutable`
- `TR_Tag_UpdateDeleteImmutable`
- `TR_TagAssignment_LineageImmutable`
- `TR_TagVersion_LineageImmutable`
- `TR_ValueType_UpdateDeleteImmutable`
- `TR_ValueTypeAllowedEntityType_UpdateDeleteImmutable`
- `TR_ValueTypeVersion_LineageImmutable`
- `TR_BindingShape_Immutable`
- `TR_DerivationContractVersion_Immutable`
- `TR_Rule_Immutable`
- `TR_RuleDefaultInputValue_Immutable`
- `TR_RuleInputDefinition_Immutable`
- `TR_RuleOutputDefinition_Immutable`
- `TR_RuleVersion_Immutable`
- `TR_RuleVersionNode_CompositionIntegrity`
- `TR_RuleVersionNodeInput_Immutable`
- `TR_BuildSet_UpdateDeleteImmutable`
- `TR_BuildSetMembershipRole_UpdateDeleteImmutable`
- `TR_BuildSetVersion_InsertLineage`
- `TR_BuildSetVersion_UpdateDeleteImmutable`
- `TR_BuildSetVersionMember_InsertContract`
- `TR_BuildSetVersionMember_UpdateDeleteImmutable`
- `TR_RuleSet_UpdateDeleteImmutable`
- `TR_RuleSetMembershipRole_UpdateDeleteImmutable`
- `TR_RuleSetVersion_InsertLineage`
- `TR_RuleSetVersion_UpdateDeleteImmutable`
- `TR_RuleSetVersionMember_InsertContract`
- `TR_RuleSetVersionMember_UpdateDeleteImmutable`
- `TR_BindingResolution_UpdateDeleteImmutable`
- `TR_BuildSetRuleOccurrence_DerivationImmutable`
- `TR_EditSession_StateTransition`
- `TR_InputBlock_UpdateDeleteImmutable`
- `TR_InputBlockVersion_LineageImmutable`
- `TR_InputValue_TypeCardinalityImmutable`
- `TR_Instantiation_UpdateDeleteImmutable`
- `TR_InstantiationOccurrenceBinding_UpdateDeleteImmutable`
- `TR_InstantiationPermissionGrant_UpdateDeleteImmutable`
- `TR_InstantiationVersion_LineageImmutable`
- `TR_InstantiationVersionInputBlock_UpdateDeleteImmutable`
- `TR_PermissionVerb_UpdateDeleteImmutable`
- `TR_ErrorTaxonomy_UpdateDeleteImmutable`
- `TR_Manifestation_InsertApprovalEffective`
- `TR_Manifestation_UpdateDeleteImmutable`
- `TR_ManifestationArtifact_InsertCacheContract`
- `TR_ManifestationArtifact_UpdateDeleteImmutable`
- `TR_ManifestationAttempt_InsertContract`
- `TR_ManifestationAttempt_UpdateDeleteImmutable`
- `TR_ManifestationEvent_InsertSequence`
- `TR_ManifestationEvent_UpdateDeleteImmutable`
- `TR_ManifestationPlan_UpdateDeleteImmutable`
- `TR_PlanApproval_UpdateDeleteImmutable`
- `TR_PlanApprovalStateEvent_InsertContract`
- `TR_PlanApprovalStateEvent_UpdateDeleteImmutable`
- `TR_PlanArtifact_UpdateDeleteImmutable`
- `TR_RuleExecution_InsertGraphContract`
- `TR_RuleExecution_UpdateDeleteImmutable`
- `TR_RuleUsage_UpdateDeleteImmutable`
- `TR_AgentTextProjection_ImmutableIdentity`
- `TR_AgentTextProjectionRefresh_AppendOnly`
- `TR_AgentTextProjectionVersion_AppendOnly`
- `TR_ContentSummary_ImmutableIdentity`
- `TR_ContentSummaryDependency_AppendOnlyIntegrity`
- `TR_ContentSummaryVersion_AppendOnlyIntegrity`
- `TR_Organization_ImmutableIdentity`
- `TR_Repository_ImmutableIdentity`
- `TR_RepositoryRootRegistration_Immutable`
- `TR_SourceArtifact_ImmutableIdentity`
- `TR_SourceArtifactLineage_AppendOnly`
- `TR_SourceArtifactVersion_AppendOnly`
- `TR_SourceModule_ValidateHierarchy`
- `TR_AgentTextProjectionVersionContentSummaryVersion_AppendOnly`
- `TR_AuthorityPolicyVersion_UpdateDeleteImmutable`
- `TR_AuthorizationScope_UpdateDeleteImmutable`
- `TR_ExecutorBoundary_UpdateDeleteImmutable`
- `TR_ExecutorBuild_UpdateDeleteImmutable`
- `TR_ExternalReference_ImmutableControlled`
- `TR_LocatorPolicyVersion_UpdateDeleteImmutable`
- `TR_PolicyVersion_Immutable`
- `TR_TargetPolicyVersion_UpdateDeleteImmutable`
- `TR_TargetScope_UpdateDeleteImmutable`
<!-- RDB320-WAVE5-TRIGGERS:END -->

### Wave 5 physical-object amendment

The approved RDB-480 contract closure adds the following registered physical
objects without promoting table-addressable rows to Entity subtypes. The
machine-readable `TYPE|NAME` entries are validated as an ordinal
case-insensitive unique set.

<!-- RDB320-WAVE5-PHYSICAL:BEGIN -->
- `ROLE|RrsbsPublisher`
- `TABLE|TargetScope`
- `TABLE|TargetPolicyVersion`
- `TABLE|ExecutorBoundary`
- `TABLE|LocatorPolicyVersion`
- `TABLE|AuthorityPolicyVersion`
- `TABLE|AuthorizationScope`
- `TABLE|ExecutorBuild`
- `TABLE|PolicyVersion`
- `TABLE|ExternalReference`
- `TABLE|AgentTextProjectionVersionContentSummaryVersion`
- `PROCEDURE|usp_PublishRelationshipRolePolicy`
- `PROCEDURE|usp_PublishRuleKindVersion`
- `PROCEDURE|usp_PublishValueTypeVersion`
- `PROCEDURE|usp_PublishPrimitiveVersion`
- `PROCEDURE|usp_PublishEntityAuthorityAssignment`
- `PROCEDURE|usp_PublishEntityExpertiseDomainAssignment`
- `PROCEDURE|usp_PublishTagAssignment`
- `PROCEDURE|usp_PublishAttribution`
- `PROCEDURE|usp_PublishRuleKindVersionCompatibility`
- `PROCEDURE|usp_PublishAttributionDispute`
- `PROCEDURE|usp_AppendAttributionDisputeEvent`
- `PROCEDURE|usp_PublishRuleVersionGraph`
- `PROCEDURE|usp_PublishRuleSetVersion`
- `PROCEDURE|usp_PublishBuildSetVersion`
- `PROCEDURE|usp_RollItUpInstantiation`
- `PROCEDURE|usp_PublishManifestationPlan`
- `PROCEDURE|usp_RecordPlanApproval`
- `PROCEDURE|usp_AppendPlanApprovalStateEvent`
- `PROCEDURE|usp_AppendManifestationAttemptJournal`
- `PROCEDURE|usp_PublishAgentTextProjectionRefresh`
<!-- RDB320-WAVE5-PHYSICAL:END -->

The three retained `Tags.usp_GetTag*` read procedures remain owned by RDB-470
and are not trusted RRSBS publication operations.

## Table-to-Philote registry

The following 51 tables have a table-specific Philote in the approved models.
The column is `<Table>PhiloteId`, except the three assignment rows shown with
their approved column names. `Entity.EntityPhiloteId` equals the registered
subtype Philote.

| Owner | Philote-bearing tables |
| --- | --- |
| RDB-200 | Entity, Authority, AuthorityVersion, Expert, ExpertVersion, ExpertiseDomain, ExpertiseDomainVersion, Tag, TagVersion, EntityAuthorityAssignment (`AssignmentPhiloteId`), EntityExpertiseDomainAssignment (`AssignmentPhiloteId`), TagAssignment, Attribution, AttributionDispute, AttributionDisputeEvent |
| RDB-210 | RuleKind, RuleKindVersion, ExecutorContract, ExecutorContractVersion, Primitive, PrimitiveVersion, PrimitiveInputDefinition, ValueType, ValueTypeVersion, StructuredValueContract, StructuredValueContractVersion |
| RDB-220 | Rule, RuleVersion, RuleVersionNode, RuleInputDefinition, RuleDefaultInputValue, RuleOutputDefinition |
| RDB-230 | RuleSet, RuleSetVersion, RuleSetVersionMember, BuildSet, BuildSetVersion, BuildSetVersionMember |
| RDB-240 | Instantiation, InstantiationVersion, InputBlock, InputBlockVersion |
| RDB-250 | ManifestationPlan, PlanApproval, Manifestation, ManifestationArtifact |
| RDB-260 | Organization, Repository, SourceArtifact, ContentSummary, AgentTextProjection |

## EntityType-to-Philote registry

These mappings are the complete 43-code RDB-270 allow-list. Each value names
the subtype table and its table-specific Philote column.

| Owner | EntityType code mappings |
| --- | --- |
| RDB-200 | `authority=Authority.AuthorityPhiloteId`; `authority-version=AuthorityVersion.AuthorityVersionPhiloteId`; `expert=Expert.ExpertPhiloteId`; `expert-version=ExpertVersion.ExpertVersionPhiloteId`; `expertise-domain=ExpertiseDomain.ExpertiseDomainPhiloteId`; `expertise-domain-version=ExpertiseDomainVersion.ExpertiseDomainVersionPhiloteId`; `tag=Tag.TagPhiloteId`; `tag-version=TagVersion.TagVersionPhiloteId`; `attribution=Attribution.AttributionPhiloteId`; `attribution-dispute=AttributionDispute.AttributionDisputePhiloteId` |
| RDB-210 | `rule-kind=RuleKind.RuleKindPhiloteId`; `rule-kind-version=RuleKindVersion.RuleKindVersionPhiloteId`; `executor-contract=ExecutorContract.ExecutorContractPhiloteId`; `executor-contract-version=ExecutorContractVersion.ExecutorContractVersionPhiloteId`; `primitive=Primitive.PrimitivePhiloteId`; `primitive-version=PrimitiveVersion.PrimitiveVersionPhiloteId`; `primitive-input-definition=PrimitiveInputDefinition.PrimitiveInputDefinitionPhiloteId`; `value-type=ValueType.ValueTypePhiloteId`; `value-type-version=ValueTypeVersion.ValueTypeVersionPhiloteId`; `structured-value-contract=StructuredValueContract.StructuredValueContractPhiloteId`; `structured-value-contract-version=StructuredValueContractVersion.StructuredValueContractVersionPhiloteId` |
| RDB-220 | `rule=Rule.RulePhiloteId`; `rule-version=RuleVersion.RuleVersionPhiloteId`; `rule-input-definition=RuleInputDefinition.RuleInputDefinitionPhiloteId`; `rule-default-input-value=RuleDefaultInputValue.RuleDefaultInputValuePhiloteId`; `rule-output-definition=RuleOutputDefinition.RuleOutputDefinitionPhiloteId` |
| RDB-230 | `rule-set=RuleSet.RuleSetPhiloteId`; `rule-set-version=RuleSetVersion.RuleSetVersionPhiloteId`; `build-set=BuildSet.BuildSetPhiloteId`; `build-set-version=BuildSetVersion.BuildSetVersionPhiloteId` |
| RDB-240 | `instantiation=Instantiation.InstantiationPhiloteId`; `instantiation-version=InstantiationVersion.InstantiationVersionPhiloteId`; `input-block=InputBlock.InputBlockPhiloteId`; `input-block-version=InputBlockVersion.InputBlockVersionPhiloteId` |
| RDB-250 | `manifestation-plan=ManifestationPlan.ManifestationPlanPhiloteId`; `plan-approval=PlanApproval.PlanApprovalPhiloteId`; `manifestation=Manifestation.ManifestationPhiloteId`; `manifestation-artifact=ManifestationArtifact.ManifestationArtifactPhiloteId` |
| RDB-260 | `organization=Organization.OrganizationPhiloteId`; `repository=Repository.RepositoryPhiloteId`; `source-artifact=SourceArtifact.SourceArtifactPhiloteId`; `content-summary=ContentSummary.ContentSummaryPhiloteId`; `agent-text-projection=AgentTextProjection.AgentTextProjectionPhiloteId` |

Tables with a Philote but no EntityType code remain table-addressable only;
they cannot be used as a generic Entity endpoint. Adding an EntityType code
requires an approved logical-model amendment.

## Target Philote allocation

The frozen RRSBS V2 UUID namespace is
`509d3589-e658-445d-8bde-67ad2e9d64cf`. Allocation uses RFC 4122 UUIDv5 with
SHA-1. A canonical name is UTF-8 encoded after Unicode Form C normalization.
Each segment is trimmed, lowercased invariantly, and length-prefixed to prevent
delimiter ambiguity:

```text
rrsbs-v2/<entity-type-code>/<length>:<natural-key-segment>/.../<revision>
```

The HITL worksheet has 175 rows: 72 `RetainAsTargetPhilote` decisions and 103
`Not to be migrated` or `Do not migrate` decisions. There are no blank
decisions.

- Each retained Primitive reuses its source GUID as `PrimitivePhiloteId` under
  natural key `(RuleKindCode, PrimitiveCode)`.
- The worksheet spelling `Powershell` canonicalizes to target RuleKind code
  `PowerShell`; the retained source GUID does not change.
- Seven target RuleKinds are represented by the retained set: CSharp,
  Markdown, MSBuild, Path, PowerShell, Snippet, and SQL. Their RuleKind and
  first RuleKindVersion Philotes are UUIDv5 allocations.
- Each retained Primitive's first PrimitiveVersion Philote is a UUIDv5
  allocation from its canonical kind/code and revision `1`.
- The 103 non-migrated source GUIDs allocate no target row and cannot be used
  by a later seed task.
- Later RDB-500 tasks use this same namespace and canonical-name algorithm for
  newly approved reference identities. They must append their complete natural
  keys to the seed catalog and rerun collision validation before integration.

The generated `TargetPhiloteManifest.csv` enumerates the resulting 158 target
rows: 72 retained Primitive identities, 72 allocated PrimitiveVersion
identities, seven RuleKinds, and seven RuleKindVersions.

## Collision and reconstruction closure

Static validation proves:

- all 334 source GUIDs are canonical and distinct after normalization;
- all 175 HITL worksheet rows have exactly one recognized disposition;
- all 72 retained target natural keys and retained Philotes are unique;
- all 86 UUIDv5 allocations are deterministic, version-5, and unique;
- no UUIDv5 allocation collides with any of the 334 source GUIDs; and
- all 158 target manifest Philotes are unique.

RDB-170's two clean conversions already matched for all 47 inputs and 517
rows. RDB-320 closes the identity ambiguity that RDB-170 intentionally left
open: retained Primitive rows now have exact target identities, while every
other ambiguous row has an explicit non-migration decision. Frozen source
artifacts remain the byte authority and their SHA-256 values are rechecked;
non-migrated graph rows are intentionally absent from the V2 target and are not
misrepresented as reconstructed target data.

This is source-static proof. RDB-010B/C live-tier capture was released
uncompleted by user direction, so RDB-320 does not claim live database
collision freedom or live byte equivalence. Before any RDB-850 reset, RDB-810
through RDB-845 must compare the exact package and registry against the named
target and stop on an unregistered object or GUID.

## Adversarial controls and successor gates

The verifier rejects a blank or unknown disposition, duplicate retained
natural key, one GUID assigned to two target keys, UUIDv5/source collision,
unregistered EntityType code, external PlantUML entity admitted as a local
table, object count drift, a generated reference UUID with the wrong version,
and any registered name longer than SQL Server's 128-character limit.

RDB-400 through RDB-460 must consume these names without substitution. RDB-480
must compare the integrated baseline to the registries and reject drift. RDB-500
and RDB-510 own seed content and may add identities only through the allocation
contract above. Package, live-tier, backup, and reset work remain gated by
their later owners.
