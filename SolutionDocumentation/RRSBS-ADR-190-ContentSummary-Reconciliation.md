# RRSBS ADR-190 — ContentSummary Reconciliation

Status: Approved for Wave 2 design on 2026-08-02.

## Decision

ContentSummary is retained as a required future RRSBS read model, but its
Sprint 0013 draft migrations remain parked outside the active Flyway tree and
are not a baseline instruction. The reserved `PrimitiveLanguageKindId` 9,
the documented ContentSummary GUID block, and the parked SQL are historical
inputs to the Wave 4 registry and baseline design; they are not allocations
for use by a new migration, seed, or live database.

The new model must represent ContentSummary through the approved
SourceArtifact/SourceArtifactVersion, immutable read-model versioning, and
prompt-provenance contracts. It must not recreate a parallel identity system,
reuse the stale migration numbering, or seed observed Manifestations.

## Required future-model capabilities

| Capability | Required contract |
| --- | --- |
| Artifact identity | Repository-relative, forward-slash path identity through SourceArtifact and its immutable versions |
| Content identity | SHA-256 on normalized LF content; a changed file creates a new artifact version |
| Summary lifecycle | `harvested`, `summarized`, `stale`, `excluded`, and `retired` are versioned states, not mutable replacements |
| Provenance | Summary generator, prompt RuleVersion, model identifier, evidence anchors, and source version are explicit references |
| Dependencies | Edges resolve to another SourceArtifactVersion or a typed external reference, never an untyped string-only edge |
| Redaction | No artifact content leaves the machine before exclusion/redaction; secrets and private material are excluded rather than summarized |
| Projection | Agent-facing summaries are read projections with watermark, refresh, and staleness semantics from ADR-125 |

## Parked-draft disposition

| Input | Disposition |
| --- | --- |
| `Draft-V00.02.000120__Add_ContentSummary_Rule_Kind.sql` | Preserve as historical design evidence; do not move or execute |
| `Draft-V00.02.000150__Assert_ContentSummary_Kind_Invariants.sql` | Preserve as historical assertion ideas; re-derive checks against the approved baseline |
| Kind ID 9 / GUID range in Sprint 0013 handoff | Reserve for RDB-320 collision review; no allocation is approved here |
| Stale migration-number plan | Retire as an execution instruction; Wave 4 owns a new canonical allocation |

## Negative controls

- A new migration that assumes version `00.02.000120` or `00.02.000150` is
  valid is rejected.
- A ContentSummary record without a SourceArtifactVersion and provenance
  reference is rejected.
- A summary that embeds a secret, key, resolved SecretName, or unredacted
  excluded content is rejected.
- A current summary row overwriting a prior version is rejected; a new version
  or explicit retirement is required.
- An observed Manifestation represented as seed data is rejected.

## Consequences

RDB-260 owns the logical-model slice that realizes these requirements. RDB-300
and RDB-320 own Flyway and identity allocation decisions. ContentSummary Phase
0 may proceed only after those slices and their gates are complete.
