# RDB-160 — Source-to-Target Disposition Manifest

Status: **provisional source-evidence manifest** (2026-08-02).

## Authority and boundary

This document is the durable RDB-160 working manifest for the frozen Sprint
0014 source corpus. It is derived only from the RDB-010A, RDB-010D, RDB-010F,
and RDB-015 evidence under `_generated/RRSBS-V2/`. It does not authorize SQL,
seed integration, package/feed action, live-tier action, reset, archival, or
deletion.

The allowed final dispositions are `preserve`, `transform`, `merge`, `alias`,
`archive`, and `retire`. `Pending` means the source evidence does not establish
a safe final disposition; it is not a seventh disposition. A final manifest
may not replace `Pending` with a disposition without the listed evidence.

## Frozen input references

| Evidence | Frozen result | RDB-160 use |
| --- | --- | --- |
| `RDB-010A/frozen-source-inventory.md` | 21 migrations; 47 CSV files / 517 rows; 68 inputs | Source baseline and aggregate hashes |
| `RDB-010D/ConsumerMap.md` | 44 consumer-map entries | Consumer proof references only; proposals are unapproved |
| `RDB-010F/structured-guid-origin-analysis.md` | 334 GUIDs; 115 expected reuse; 159 unresolved reuse | Identity ambiguity register |
| `RDB-015/source-permanent-object-inventory.md` | 64 permanent source candidates | Complete object coverage baseline |

## Permanent-object coverage

Every source-known permanent object is represented below. `Transform candidate`
is a planning hypothesis based on approved Wave 1 contracts, not an approved
logical model or a SQL instruction. `Pending` entries require an explicit
consumer or retention decision before a final disposition is possible.

| Source group | Objects (count) | Candidate / status | Required evidence before final disposition | Consumer proof |
| --- | ---: | --- | --- | --- |
| `ATAPUtilities` core RRSBS identity and rule graph | `Philote`, `PhiloteAdditionalId`, `PhiloteTimeBlock`, `PrimitiveLanguageKind`, `RulePrimitive`, `RulePrimitiveInput`, `Rule`, `RulePrimitiveComposition`, `RuleSet`, `RuleSetMember`, `BuildSet`, `BuildSetMember`, `RuleInstantiation`, `RuleInstantiationBinding` (14) | Transform candidate | RDB-200 through RDB-240 approved logical slices and RDB-170 reconciliation | CM-001–CM-010, CM-031 |
| `ATAPUtilities` user data | `User`, `UserInformation`, `UserSettings` (3) | Pending | RDB-149 retention/privacy decision applied to live catalog and consumer map | CM-011–CM-017; live catalog inventory |
| `ATAPUtilities` AgentText projection | `AgentAdapterTarget`, `AgentToolSurface`, `AgentInstruction`, `AgentTextRoundTrip`, `AgentText` (5) | Transform candidate | RDB-190 lifecycle/provenance design and RDB-170 reconciliation | RDB-125 boundary; CM-036–CM-044 |
| `ATAPUtilities` organization/source topology | `Organization`, `OrganizationUser`, `Computer`, `Repository`, `SourceModule` (5) | Transform candidate | RDB-200 and RDB-240 approval; source-artifact proof | RDB-147; CM-009–CM-010 |
| `ATAPUtilities` instantiation/manifestation | `Instantiation`, `InstantiationVersion`, `InstantiationVersionComputer`, `InstantiationVersionRepository`, `InstantiationVersionSourceModule`, `ManifestationArtifact` (6) | Transform candidate | RDB-240/RDB-250 approval and RDB-170 byte-reconstruction proof | CM-009–CM-010 |
| `ATAPUtilities` durable snapshots | `RuleVersion`, `RuleVersionPrimitiveComposition`, `RuleSetVersion`, `RuleSetVersionMember`, `BuildSetVersion`, `BuildSetVersionMember`, `RuleInstantiationVersion`, `InstantiationVersionRuleInstantiationVersion`, `RuleInstantiationVersionSourceLine` (9) | Transform candidate | RDB-110, RDB-115, RDB-146 contracts implemented in approved logical model; RDB-170 reconciliation | CM-009–CM-010 |
| `AceCommander` legacy copied graph | `Philote`, `PhiloteAdditionalId`, `PhiloteTimeBlock`, `PrimitiveLanguageKind`, `RulePrimitive`, `RulePrimitiveInput`, `Rule`, `RulePrimitiveComposition`, `RuleSet`, `RuleSetMember`, `RuleInstantiation`, `RuleInstantiationBinding` (12) | Pending | RDB-125 external-consumer boundary and AceCommander topology/consumer proof | RDB-125; RDB-010B live catalog |
| `AceCommander` user and scheduling | `User`, `UserInformation`, `UserSettings`, `ScheduledTask`, `ScheduledTaskRun` (5) | Pending | Consumer ownership, retention, and live-catalog proof | RDB-149; RDB-010B live catalog |
| `Tags` | `Tags`, `TagAliases`, `RelationshipTypes`, `TagRelationships` (4) | Pending | Scope/owner decision and consumer proof | RDB-010B live catalog |
| `Gmail` | `gmailMessages` (1) | Pending | Scope/owner and retention/privacy decision | RDB-149; RDB-010B live catalog |

The group counts total **64** objects. No group marked `Pending` may be
implicitly archived or retired; such an action is separately gated.

## Seeded-identity coverage

`_generated/RRSBS-V2/RDB-160/SeededIdentityRegister.csv` is the complete,
generated source literal register (334 normalized GUID values). It records
occurrence count, source origins, and whether RDB-010F classified a reused
value as `Expected` or `Unresolved`.

| Identity class | Count | Current status | Final-disposition prerequisite |
| --- | ---: | --- | --- |
| Expected source reuse | 115 | Candidate semantic references; no final disposition asserted | Canonical identity/type register and RDB-170 reconciliation |
| Unresolved source reuse | 159 | Blocked; no disposition inferred | Structured SQL origin/column proof and coordinator live-tier comparison |
| Single-use source literal | 60 | Blocked; occurrence alone does not establish entity type | Canonical identity/type register and source-to-target mapping |

Thus all 334 literals are covered by a register, but no seeded identity is
claimed collision-free or finally disposed at this boundary. This deliberately
prevents the close variant of the original failure mode: treating a repeated
literal or a single occurrence as proof of semantic identity.

## Completion gate

RDB-160 remains incomplete until every `Pending` object and every identity
register row has one of the six allowed final dispositions, a rationale, and a
consumer-proof reference. The current evidence makes the blockers auditable;
it does not weaken the Wave 2 or later gates.
