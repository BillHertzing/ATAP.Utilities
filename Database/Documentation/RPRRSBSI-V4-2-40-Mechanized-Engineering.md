# RPRRSBSI-V4-2 Mechanized Engineering Specification

Status: reconciled documentation-only contract. It defines no SQL, allocates no GUID,
and grants no live-system authority.

## V4-2 platform relationship

Mechanized Engineering remains a later consumer of the plugin, ContentSummary, Tags,
edge-projection, and AISupervisor contracts. It is not part of the initial AceOutpost
service. This preserves the D-8 validated-plan boundary and prevents purchasing or
provisioning from widening the first Tags/ContentSummary and token-telemetry slice.

Editable source:
[RPRRSBSI-V4-2-Computer-Configuration.puml](RPRRSBSI-V4-2-Computer-Configuration.puml).
The previously rendered SVG is not embedded because the source changed; rendering is a
coordinator-owned step.

## Authority and first-output boundary

This specification consumes D-1 through D-8 from the
[V4 overview](RPRRSBSI-V4-2-00-Specification-Overview.md), the reconciled
[traceability](RPRRSBSI-V4-2-05-Source-Synthesis-And-Traceability.md),
[core schema](RPRRSBSI-V4-2-10-Core-Schema-Enhancements.md), and
[seed contract](RPRRSBSI-V4-2-20-Seed-Data-And-Loaders.md). It does not extend them.

Mechanized Engineering is the initial computer-system configuration expert system. Its
first output SHALL stop at an explained, schema-valid **validated
database-change/configuration plan**. The plan is information for review, not an
approval, order, reservation, deployment instruction, or provisioning payload.

- **V4-2-ME-001:** The first manifestation SHALL NOT purchase hardware, reserve inventory,
  invoke vendor APIs, change a live database, mutate infrastructure, or execute Ansible.
- **V4-2-ME-002:** Purchasing, provisioning, execution, and deployment remain deferred
  behind separately named tasks and HITL gates.
- **V4-2-ME-003:** No `HITL-PENDING` item gains normative force from an example, proposed
  field, diagram element, or seed-file name here.

## ATAP reference and ACE overlay boundary

Ratified D-5 is an ownership rule independent of deployment topology.

| Plane | Owner and content | Boundary |
| --- | --- | --- |
| Immutable reference | ATAP reference definitions, components/facts, baseline RuleSets/RuleVariants, and registered identities. | ACE SHALL NOT mutate them. |
| Overlay/session | ACE user RuleSets, same-`RuleId` overlay RuleVariants, BuildSet occurrences, sessions, inputs, and plans. | ACE SHALL NOT copy an ATAP Rule to override it. |
| Effective read | Topology-neutral union of authorized reference and overlay candidates. | No cross-database FK or location-based precedence. |

- **V4-2-ME-010:** ATAP SHALL own immutable reference definitions; ACE SHALL own user
  overlays and sessions.
- **V4-2-ME-011:** A topology-neutral union provider SHALL expose one logical candidate
  shape whether the planes are co-located, separate, or read through an adapter.
- **V4-2-ME-012:** Each candidate SHALL retain `SourceAuthority`, durable identity,
  State/Variant identity, as-of applicability, RuleSet occurrence, membership role, and
  explicit precedence. Transport location SHALL NOT supply precedence.
- **V4-2-ME-013:** Resolution SHALL occur once after union. Separately resolved ATAP and
  ACE results SHALL NOT be merged by an implicit caller rule.
- **V4-2-ME-014:** ATAP SHALL NOT require a foreign key into an ACE database.

## Identity, change, and overlay conformance

- **V4-2-ME-020 (D-1):** GUID text at CSV/API boundaries SHALL use canonical lowercase
  dashed `D` format. Database equality, joins, and duplicates SHALL compare native GUID
  values, not text, case, or collation.
- **V4-2-ME-021 (D-3):** A classified material declared-type change SHALL create a new
  registered semantic identity and leave earlier meaning immutable. Classified material
  cases are rule-kind changes, scalar-to-different-scalar changes, scalar/heap-object
  crossings, and any heap/object-type change, including single value to collection.
- **V4-2-ME-022 (D-3):** Default-value-only and display-only-text changes are non-material
  and MAY preserve semantic identity through a new State or Variant. The eight edge cases
  remain `HITL-PENDING` and SHALL NOT become positive fixtures.
- **V4-2-ME-023 (D-4):** An ACE overlay SHALL be a distinct `RuleVariant` of the same
  durable `RuleId`, selected by an occurrence with role `Override`; the Rule SHALL NOT be
  copied.
- **V4-2-ME-024 (D-2):** Higher `BuildSetRuleSetOccurrence.Ordinal` SHALL win through
  `Ordinal DESC`; duplicate ordinals in one BuildSet are invalid.
- **V4-2-ME-025:** A plan SHALL bind effective RuleVariants and reference facts by durable
  identity and as-of instant so later definition changes cannot rewrite its explanation.

## Required inputs and normalization

| Input group | Minimum inputs |
| --- | --- |
| Budget | Maximum total cost, currency, contingency policy. |
| Enclosure | Chassis, form factor, physical limits, expansion needs. |
| Compute | Processor/platform preference, performance targets, accelerator needs. |
| Memory | Minimum/target capacity, speed/ECC needs. |
| Storage | Capacity, performance, redundancy, interface, archive needs. |
| Connectivity | Network, display, USB, peripheral, and remote-management needs. |
| Power/thermal | Available power, PSU margin, acoustic/thermal envelope, cooling. |
| Workload | Local LLM context, software build/test workload, and concurrency. |

- **V4-2-ME-030:** Every input SHALL declare type, unit where applicable,
  required/default status, normalization, constraints, and provenance.
- **V4-2-ME-031:** Currency and quantities SHALL be normalized before calculation while
  retaining the submitted representation for explanation.
- **V4-2-ME-032:** Unknown, omitted, and intentionally unconstrained SHALL remain distinct.
- **V4-2-ME-033:** Input validation SHALL reject non-canonical GUID boundary text even
  when it parses to an existing native GUID. Formatting validation remains distinct from
  native-value identity comparison.

## Deterministic planning pipeline

The first manifestation has one non-effecting pipeline:

1. Validate and normalize requirements.
2. Read authorized ATAP reference and ACE overlay candidates through the
   topology-neutral union contract.
3. Resolve the effective BuildSet as-of, applying D-2 and D-4.
4. Evaluate compatibility, cost, power, thermal, memory, and workload calculations.
5. Validate plan completeness, identity bindings, explanations, and findings.
6. Emit the validated plan and stop.

- **V4-2-ME-040:** Compatibility rules SHALL evaluate socket/platform, memory, form
  factor, interfaces, power connectors, physical clearances, and supported capacities.
- **V4-2-ME-041:** Cost SHALL produce line items, subtotal, contingency, and total from
  as-of price facts. Missing or stale prices become findings, never implicit zeroes.
- **V4-2-ME-042:** Power and thermal rules SHALL expose load estimates, required margin,
  inputs, and assumptions.
- **V4-2-ME-043:** Memory adequacy SHALL account for workload reserve and local-LLM
  context, exposing assumptions and inputs.
- **V4-2-ME-044:** Workload scores SHALL remain separated and explainable, not one opaque
  ranking.
- **V4-2-ME-045:** Violations SHALL carry severity, Rule identity, implicated inputs or
  components, explanation, and suggested remediation.
- **V4-2-ME-046:** A budget change SHALL dirty cost, budget findings, and reachable plan
  outputs, but SHALL NOT dirty unrelated compatibility calculations.
- **V4-2-ME-047:** Identical normalized inputs, effective definitions, reference facts,
  and as-of instant SHALL produce canonically identical plan content.

## Validated plan contract

The output is a database-change/configuration plan record for review and later task
authoring. It is schema-valid only when all required sections exist and its validation
result is explicit.

| Section | Required content |
| --- | --- |
| Header | Plan, expert-system, and effective BuildSet identities; as-of instant; normalized-input hash; schema and validation status. |
| Effective definition | Selected same-`RuleId` RuleVariants, source authority, occurrence role/ordinal, and shadowed provenance. |
| Configuration | Component identities, quantities, as-of facts, and selection provenance. |
| Cost | Line items, subtotal, contingency, total, currency, and missing/stale-price findings. |
| Findings | Compatibility, budget, power, thermal, and completeness results with Rule explanations. |
| Workloads | Per-workload adequacy, assumptions, scores, and bottlenecks. |
| Deferred acquisition | Non-executing suggestions and alternatives; no order or reservation instruction. |
| Unresolved choices | Missing or conflicting requirements preventing a complete configuration. |

- **V4-2-ME-050:** `Validated` SHALL mean that plan schema, identity bindings, effective
  resolution, calculations, and required findings passed. It SHALL NOT mean approved for
  purchasing, provisioning, execution, or deployment.
- **V4-2-ME-051:** Failed or incomplete validation SHALL emit diagnostics and SHALL NOT be
  relabeled as a validated plan.
- **V4-2-ME-052:** Recommendations SHALL explain which RuleVariant and reference fact
  caused each selection or rejection.
- **V4-2-ME-053:** The plan SHALL retain shadowed candidates for explanation while
  exposing exactly one effective candidate per resolved RuleId.
- **V4-2-ME-054:** The plan SHALL contain no credential, secret value, executable SQL,
  vendor checkout payload, provisioning command, or live target instruction.

## Required overlay conformance scenario

The immutable ATAP baseline RuleVariant for one maximum-budget `RuleId` supplies 1000.
An ACE RuleVariant for the same `RuleId` is selected by an `Override` occurrence and
supplies 1500. A second ACE `Override` occurrence for another RuleVariant of that same
`RuleId`, at a higher BuildSet RuleSet ordinal, supplies 1200. Under D-2, 1200 is
effective. No overlay copies the basic Rule.

The scenario SHALL verify:

1. baseline-only resolution at the earliest as-of instant;
2. baseline plus the 1500 overlay at an intermediate instant;
3. all three active with 1200 winning by higher `Ordinal`;
4. same `RuleVariant.RuleId` for all candidates and role `Override` for ACE occurrences;
5. effective and shadowed provenance with source authority;
6. dirty propagation limited to cost, budget findings, and downstream outputs;
7. a schema-valid configuration or an explained validation failure; and
8. rejection of duplicate ordinals, copied-Rule overlays, different-`RuleId` overrides,
   unregistered identities, non-canonical GUID text, and native-value GUID duplicates.

## Proposed implementation inputs, not allocated seeds

These names are later task-authoring inputs only. They allocate no GUID and authorize no
CSV, loader, migration, or database write.

- `MechanizedEngineering-InputDefinitions.csv`
- `MechanizedEngineering-RuleVariants.csv`
- `MechanizedEngineering-RuleOccurrences.csv`
- `MechanizedEngineering-DependencyEdges.csv`
- `MechanizedEngineering-WorkflowNodes.csv`
- `MechanizedEngineering-WorkflowEdges.csv`
- `MechanizedEngineering-ReferenceComponents.csv`
- `MechanizedEngineering-CompatibilityFacts.csv`
- `MechanizedEngineering-ScenarioInputs.csv`
- `MechanizedEngineering-ExpectedPlans.csv`

The first data SHOULD be small, synthetic, and license-safe. A later approved
implementation SHALL register every semantic identity before packaging seeds and SHALL
use the shared deterministic loader contract.

## Pending gates and adversarial boundaries

The eight D-3 edge cases and C-16 through C-27 remain `HITL-PENDING` and non-normative.
This document does not decide actor/provenance policy, authorization, Tags ordering or
traversal, tenant/store topology, generic Tag entity codes, localization, live-schema
inventory, Tag collation, assignment confidence, or successor-chain behavior.

Close variants outside the first manifestation include:

- a plan item containing a vendor endpoint or checkout token;
- a component suggestion reinterpreted as authority to reserve or buy;
- generated Ansible inventory, playbook, shell command, or device configuration;
- a database-change plan reinterpreted as permission to execute Flyway;
- a copied Rule presented as an overlay;
- text-form GUID comparison used as identity equality;
- an unruled D-3 edge case classified by a loader or fixture; and
- a topology adapter whose location changes resolution precedence.

Each case SHALL fail closed or remain an unresolved finding. The first output stops at
the validated plan; purchasing, provisioning, and execution remain deferred.
