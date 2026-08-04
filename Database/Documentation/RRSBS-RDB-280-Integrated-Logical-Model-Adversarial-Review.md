# RDB-280 — Integrated Logical Model Adversarial Review

Status: Wave 3 design-only invalid-row review. This is a test design and does
not execute SQL, create a database, mutate a tier, publish a package, or grant
any deployment authorization.

## Review method

Each scenario corrupts one close variant of an otherwise valid integrated row
set. A passing future test must reject the inserted/updated row or fail the
trusted publication operation before it can become observable. The RDB-270
draft dictionary is the integration authority; RDB-200 through RDB-260 remain
authoritative for slice-local keys and columns.

## Invalid-row matrix

| ID | Invalid row / close variant | Violated integrated contract | Expected rejection owner |
| --- | --- | --- | --- |
| I-01 | Register a `rule-version` Entity with the `primitive-version` EntityType. | Closed subtype-to-EntityType registration. | RDB-400 FK/check. |
| I-02 | Add an endpoint policy with a wildcard type or an unregistered `EntityTypeCode`. | Closed endpoint allow-list; no generic Entity endpoint. | RDB-400 seed/constraint. |
| I-03 | Use an ExpertiseDomain or Tag assignment as an RDB-240 permission grant. | Classification is never authorization. | RDB-440 authorization procedure. |
| I-04 | Point a PrimitiveVersion at a RuleKindVersion of another RuleKind. | Exact same-kind version binding. | RDB-410 composite FK. |
| I-05 | Bind a structured/collection value through a scalar or unallow-listed Entity type. | Exact ValueTypeVersion shape and entity allow-list. | RDB-410/420 typed-value constraint. |
| I-06 | Add a RuleVersionNode whose PrimitiveVersion kind differs from the RuleVersion kind. | Node-to-owner exact RuleKindVersion. | RDB-420 composite FK. |
| I-07 | Give a node both a constant and derivation input, or neither. | Discriminated node-input shape. | RDB-420 constraint/procedure. |
| I-08 | Reuse a RuleSet/BuildSet `MemberOccurrenceKey` under one parent, or make ordinals gapped. | Parent-scoped occurrence identity and order. | RDB-430 unique/check. |
| I-09 | Construct a BuildSetRuleOccurrence from a BuildSet member and RuleSet member from different BuildSetVersions. | Complete occurrence composite chain. | RDB-440 composite FK. |
| I-10 | Select an InputBlockVersion for an InstantiationOccurrenceBinding of another Instantiation. | Common Instantiation and compatible occurrence selection. | RDB-440 composite FK. |
| I-11 | Select an InputValue whose RuleInputDefinition or ValueTypeVersion differs from the selected RuleVersion. | Exact typed input contract. | RDB-440 composite FK/check. |
| I-12 | Publish an InstantiationVersion while its selected inputs or graph hash changed after the snapshot. | Immutable selected-input and graph fingerprint. | RDB-440 publication procedure. |
| I-13 | Approve a plan with the right InstantiationVersion but a different target, executor, graph, or input fingerprint. | Approval repeats the exact plan boundary. | RDB-450 composite FK/procedure. |
| I-14 | Start a Manifestation from a revoked, expired, or another-plan approval. | Exact currently-effective approval. | RDB-450 execution procedure. |
| I-15 | Execute a RuleVersion different from the referenced BuildSetRuleOccurrence. | Execution consumes exact selected occurrence. | RDB-450 composite FK. |
| I-16 | Produce two ManifestationArtifacts for one attempt and PlanArtifact slot, or attribute it to another attempt. | One observed producer per slot and exact attempt provenance. | RDB-450 unique/FK. |
| I-17 | Record RuleUsage with only a display name or without observed/planned source facts. | Typed subject/version and governed provenance. | RDB-450 constraint. |
| I-18 | Register one active root for two Repositories or derive two Repository identities from stable/sprint roots. | Root-independent Repository identity and unique active root. | RDB-460 unique/FK. |
| I-19 | Summarize a SourceArtifactVersion belonging to another SourceArtifact, or use a later dependency. | Summary's exact source ownership and no-future dependency. | RDB-460 composite FK/publication procedure. |
| I-20 | Store excluded source text, a resolved SecretName, key, or credential in a ContentSummary/AgentText projection. | Redaction/exclusion and secret boundary. | RDB-460 validation/classification procedure. |
| I-21 | Mark AgentText current when its selected summaries are after its watermark or a refresh failed. | Watermark, freshness, and append-only refresh semantics. | RDB-460 projection procedure. |
| I-22 | Create an attribution successor for another claim or two direct successors for one assertion. | Same-claim correction chain and single direct successor. | RDB-400 attribution constraint. |

## Adversarial conclusions

The integration design has no permitted escape hatch through generic identity,
natural names, display labels, or a hash-only reference. The close variants
most likely to reintroduce the same defects are “same code, different version,”
“same child, different parent occurrence,” and “same plan, different approval
fingerprint”; each has an explicit composite FK or trusted-operation requirement.

The matrix also identifies the boundary of the logical model: graph
reachability/acyclicity, gap-free sequencing, effective approval, watermark
freshness, and redaction-safe content cannot be guaranteed by a simple FK
alone. RDB-420, RDB-440, RDB-450, and RDB-460 must implement them as documented
database constraints or trusted stored procedures and execute these fixtures.

## Exit criteria

- Every RDB-270 foreign-key closure row has at least one negative scenario.
- Every scenario names a physical owner; none is misrepresented as already
  executed.
- RDB-400–460, seed, package, live-tier, and HITL gates remain unchanged.
- A later physical test suite must use these IDs as fixture names or trace them
  to its own more granular negative cases.
