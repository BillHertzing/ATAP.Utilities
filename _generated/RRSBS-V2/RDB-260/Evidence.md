# RDB-260 Logical-Model Evidence

Status: design-only evidence. This does not prove physical SQL enforcement,
scanner/renderer behavior, summary generation, filesystem safety, package
delivery, or live deployment.

## Deliverables

- `Database/Documentation/RRSBS-RDB-260-Context-SourceArtifact-AgentText-ContentSummary-Logical-Model.md`
- `Database/Documentation/RRSBS-RDB-260-Context-SourceArtifact-AgentText-ContentSummary-Logical-Model.puml`

## Contract coverage

| Authority | RDB-260 representation |
| --- | --- |
| RDB-147 | One Repository identity across root registrations; binary repository-relative SourceArtifact identity; append-only bytes/hash metadata; explicit accepted lineage and retirement. |
| RDB-190 | First-class ContentSummary/Version lifecycle, exact source/prompt/model provenance, typed dependencies, redaction/exclusion controls, and no parked-draft reuse. |
| RDB-125 / RDB-150B | AgentTextProjection read model has immutable policy/version materialization, source watermarks, append-only refresh results, explicit failure, and staleness semantics. |
| Final plan RDB-260 | Organization/Repository/SourceModule context, SourceArtifact/Version, ContentSummary/Version, and AgentText projection contract. |

## Verification

Verified 2026-08-03 from the ATAP.Utilities Sprint 0014 worktree:

| Check | Command / result |
| --- | --- |
| Markdown structure | `rg -n "^#|^##|^###|^\\|" <logical-model>` completed successfully. |
| Scoped Markdown lint | `npx --no-install markdownlint-cli2 <logical-model> --config .markdownlint-cli2.jsonc --no-globs` completed successfully (0 issues). |
| Local links | Every relative Markdown link resolves from `Database/Documentation`; pass. |
| PlantUML syntax | `plantuml -checkonly <logical-model.puml>` completed successfully. |
| SVG / PNG renders | `plantuml -tsvg` and `plantuml -tpng` completed successfully into this evidence directory. |
| Visual inspection | Original-resolution PNG was inspected: context, provenance, summary lifecycle, and AgentText projection domains are distinct; root-to-repository, source-version, dependency, prompt, watermark, and refresh-result relationships are visible. |

| Artifact | SHA-256 |
| --- | --- |
| Logical-model Markdown | `5FED86EEE84D2B2FEADA6E43D01C84B53332C92C7B4F748162BCF9C7C19F3F3B` |
| PlantUML source | `805A1350BF35932E035F483AF61EF6F4FEC3F4476B6359ADD63857171D7D0193` |
| PNG render | `6A5C349B672DF01D561480F975C624ADE1DD5B29F27054B3F23A5E065899C392` |
| SVG render | `7C1EA85E19223767322791BFD7455A386017A111D3941D0C2227308233FFDAB2` |

RDB-270 owns cross-slice FK/entity-type closure. RDB-280 and RDB-460 own
executable invalid-row and physical-SQL proof.
