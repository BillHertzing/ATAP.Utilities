# RDB-160 — Source-to-Target Disposition Manifest

Status: **implemented source-to-target disposition decision** (2026-08-03).

## Authority and boundary

This document is the durable RDB-160 working manifest for the frozen Sprint
0014 source corpus. It is derived only from the RDB-010A, RDB-010D, RDB-010F,
and RDB-015 evidence under `_generated/RRSBS-V2/`. It does not authorize SQL,
seed integration, package/feed action, live-tier action, reset, archival, or
deletion.

The allowed dispositions are `preserve`, `transform`, `merge`, `alias`,
`archive`, and `retire`. The conversion decisions recorded here use only
`transform` and `archive`; no target object or identity allocation follows from
either decision.

## Frozen input references

| Evidence | Frozen result | RDB-160 use |
| --- | --- | --- |
| `RDB-010A/frozen-source-inventory.md` | 21 migrations; 47 CSV files / 517 rows; 68 inputs | Source baseline and aggregate hashes |
| `RDB-010D/ConsumerMap.md` | 44 consumer-map entries | Consumer proof references only; proposals are unapproved |
| `RDB-010F/structured-guid-origin-analysis.md` | 334 GUIDs; 115 expected reuse; 159 unresolved reuse | Identity ambiguity register |
| `RDB-015/source-permanent-object-inventory.md` | 64 permanent source candidates | Complete object coverage baseline |

## Permanent-object coverage and final source disposition

Every source-known permanent object is represented below. The generated,
row-level decision register is
`_generated/RRSBS-V2/RDB-160/PermanentObjectDispositionRegister.csv`: it
covers all 64 objects, with 39 `transform` and 25 `archive` decisions. The
decisions are authorized by the Stream C blanket approval and are source-only:
they do not authorize a database mutation, retention deletion, or live-tier
action.

| Source group | Objects (count) | Disposition | Rationale / retained evidence | Consumer proof |
| --- | ---: | --- | --- | --- |
| `ATAPUtilities` core RRSBS identity and rule graph | `Philote`, `PhiloteAdditionalId`, `PhiloteTimeBlock`, `PrimitiveLanguageKind`, `RulePrimitive`, `RulePrimitiveInput`, `Rule`, `RulePrimitiveComposition`, `RuleSet`, `RuleSetMember`, `BuildSet`, `BuildSetMember`, `RuleInstantiation`, `RuleInstantiationBinding` (14) | Transform | In-scope RRSBS source graph; reconcile through RDB-170 and later logical-model slices. | CM-001–CM-010, CM-031 |
| `ATAPUtilities` user data | `User`, `UserInformation`, `UserSettings` (3) | Archive | Outside the approved RRSBS target corpus; preserved in frozen source evidence, not deleted. | CM-011–CM-017; live catalog inventory |
| `ATAPUtilities` AgentText projection | `AgentAdapterTarget`, `AgentToolSurface`, `AgentInstruction`, `AgentTextRoundTrip`, `AgentText` (5) | Transform | In-scope content/provenance projection; RDB-190 defines reconciliation policy. | RDB-125 boundary; CM-036–CM-044 |
| `ATAPUtilities` organization/source topology | `Organization`, `OrganizationUser`, `Computer`, `Repository`, `SourceModule` (5) | Transform | Provenance/topology retained for RRSBS manifestations and source artifacts. | RDB-147; CM-009–CM-010 |
| `ATAPUtilities` instantiation/manifestation | `Instantiation`, `InstantiationVersion`, `InstantiationVersionComputer`, `InstantiationVersionRepository`, `InstantiationVersionSourceModule`, `ManifestationArtifact` (6) | Transform | In-scope manifest and derivation lineage. | CM-009–CM-010 |
| `ATAPUtilities` durable snapshots | `RuleVersion`, `RuleVersionPrimitiveComposition`, `RuleSetVersion`, `RuleSetVersionMember`, `BuildSetVersion`, `BuildSetVersionMember`, `RuleInstantiationVersion`, `InstantiationVersionRuleInstantiationVersion`, `RuleInstantiationVersionSourceLine` (9) | Transform | Retained historical identities and membership snapshots. | CM-009–CM-010 |
| `AceCommander` legacy copied graph | `Philote`, `PhiloteAdditionalId`, `PhiloteTimeBlock`, `PrimitiveLanguageKind`, `RulePrimitive`, `RulePrimitiveInput`, `Rule`, `RulePrimitiveComposition`, `RuleSet`, `RuleSetMember`, `RuleInstantiation`, `RuleInstantiationBinding` (12) | Archive | Separate product copy; retained as frozen evidence, excluded from this RRSBS target conversion. | RDB-125; RDB-010B live catalog |
| `AceCommander` user and scheduling | `User`, `UserInformation`, `UserSettings`, `ScheduledTask`, `ScheduledTaskRun` (5) | Archive | Separate product-owned data; no RRSBS target transform in this stream. | RDB-149; RDB-010B live catalog |
| `Tags` | `Tags`, `TagAliases`, `RelationshipTypes`, `TagRelationships` (4) | Archive | Out-of-scope tag subsystem retained in frozen evidence. | RDB-010B live catalog |
| `Gmail` | `gmailMessages` (1) | Archive | Out-of-scope communications data retained in frozen evidence. | RDB-149; RDB-010B live catalog |

The group counts total **64** objects. `Archive` is an exclusion from the new
seed corpus, not a destructive instruction; the source corpus remains frozen.

## Seeded-identity coverage

`_generated/RRSBS-V2/RDB-160/SeededIdentityDispositionRegister.csv` is the
complete generated decision register for the 334 normalized source GUID
literals. Each row has disposition `transform`: the literal is an immutable
source-identity mapping input. This is deliberately not a target identity
assignment.

| Identity class | Count | Disposition | Constraint |
| --- | ---: | --- | --- |
| Expected source reuse | 115 | Transform | Preserve as source mapping input; target allocation is deferred. |
| Unresolved source reuse | 159 | Transform | Preserve ambiguity as a source fact; do not infer target collision freedom. |
| Single-use source literal | 60 | Transform | Preserve as source mapping input; occurrence count is not entity typing. |

Thus all 334 literals have a final source disposition, but none is claimed
collision-free and no target identity is allocated at this boundary. This
prevents the close variant of the original failure mode: treating a repeated
literal or a single occurrence as proof of semantic identity.

## Completion gate

RDB-160 is complete as a source-to-target disposition decision. The later
RDB-320 identity registry must allocate target identities and prove collisions
there; this manifest does not weaken that gate.
