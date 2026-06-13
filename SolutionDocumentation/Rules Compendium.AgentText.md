# Rules Compendium.AgentText

## AgentText

| Property | Value |
|---|---|
| **Language** | AgentText |
| **Grammar** | Embedded below |
| **Added** | 2026-06-12 |
| **Sprint task** | 8.23 |

AgentText models AI agent and instruction text as RRSBS data that can be loaded from existing native files, stored with stable identity and minimal tool surfaces, and instantiated back into native adapters for Claude, Codex, GitHub Copilot, and future tools.

### Purpose

The AgentText kind covers:

- Agent identity and metadata.
- Instruction body text in Markdown, TOML, or plain text.
- Declared tool surfaces.
- Ordered runbook steps.
- Guardrails and return contracts.
- Adapter targets and materialization mode.
- Round-trip expectations, including byte-for-byte generated adapters and semantic-only normalization.

### Primitives

| Primitive | BNF Symbol | Data type | Required | Description |
|---|---|---|---|---|
| AgentIdentity | `agent-identity` | object | yes | Stable agent, skill, or instruction identity plus metadata. |
| InstructionBody | `instruction-body` | markdown/toml/text | yes | Source instruction text to load or render. |
| ToolSurface | `tool-surface` | string array | no | Minimal native tool declarations for the agent or skill. |
| RunbookStep | `runbook-step` | ordered markdown list | zero or more | Executable or review steps. |
| Guardrail | `guardrail` | markdown list | zero or more | Safety, ownership, and scope constraints. |
| ReturnContract | `return-contract` | schema reference | no | Structured result shape expected by an orchestrator. |
| AdapterTarget | `adapter-target` | object array | zero or more | Native output path, tool name, and materialization mode. |
| RoundTripPolicy | `round-trip-policy` | enum | yes | `byte-for-byte` for generated adapters, `semantic` for normalized imports. |

### Inputs

| Primitive | Input | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| AgentIdentity | SourceId | string | yes |  | Stable manifest or RRSBS identifier. |
| AgentIdentity | DisplayName | string | no |  | Human-readable title. |
| InstructionBody | Body | string | yes |  | Raw text after frontmatter normalization. |
| InstructionBody | BodyFormat | string | yes | markdown | `markdown`, `toml`, or `text`. |
| ToolSurface | Tools | string[] | no | [] | Native names such as `read`, `terminal`, or `agent/runSubagent`. |
| RunbookStep | SequenceKey | string | yes |  | Ordered key such as `001`. |
| RunbookStep | Text | string | yes |  | Step body. |
| Guardrail | Text | string | yes |  | Guardrail body. |
| ReturnContract | SchemaRef | string | no |  | Inline schema id or path. |
| AdapterTarget | Tool | string | yes |  | Claude, Codex, GitHub Copilot, or other adapter family. |
| AdapterTarget | Path | string | yes |  | Native output path relative to the consuming repo. |
| AdapterTarget | Materialization | string | yes | copy | `copy`, `symlink`, `junction`, or `generated-wrapper`. |
| AdapterTarget | RenderedSha256 | string | no |  | Expected rendered hash. |
| RoundTripPolicy | Policy | string | yes | semantic | `byte-for-byte` or `semantic`. |

### Composition

| Pos | Primitive | Cardinality | Optional |
|---:|---|---|---|
| 1 | AgentIdentity | 1 | no |
| 2 | InstructionBody | 1 | no |
| 3 | ToolSurface | ? | yes |
| 4 | RunbookStep | * | yes |
| 5 | Guardrail | * | yes |
| 6 | ReturnContract | ? | yes |
| 7 | AdapterTarget | * | yes |
| 8 | RoundTripPolicy | 1 | no |

### Grammar

```ebnf
# AgentText.grammar.ebnf
# Language: AgentText
# Kind: AgentText
# Created: 2026-06-12
# Description: Agent and instruction text model for loading, storing, and rendering AI tool adapters.

agent-text-document     ::= agent-identity instruction-body tool-surface? runbook-step* guardrail* return-contract? adapter-target* round-trip-policy

# --- Primitive definitions ---
agent-identity          ::= "agent" identifier metadata*
instruction-body        ::= markdown-block | toml-block | text-block
tool-surface            ::= "tools" "[" tool-name ("," tool-name)* "]"
runbook-step            ::= "step" integer ":" markdown-block
guardrail               ::= "guardrail" ":" markdown-block
return-contract         ::= "returns" json-schema-ref
adapter-target          ::= "target" tool-name path materialization-mode rendered-hash?
round-trip-policy       ::= "roundtrip" ("byte-for-byte" | "semantic")

metadata                ::= identifier "=" quoted-string
identifier              ::= letter (letter | digit | "-" | "_" | ".")*
tool-name               ::= identifier ("/" identifier)?
path                    ::= quoted-string
materialization-mode    ::= "copy" | "symlink" | "junction" | "generated-wrapper"
rendered-hash           ::= "sha256:" hex-digit{64}
json-schema-ref         ::= quoted-string
markdown-block          ::= fenced-markdown | quoted-string
toml-block              ::= fenced-toml | quoted-string
text-block              ::= quoted-string
```

### Round-Trip Rules

Generated adapters are expected to round-trip byte-for-byte when the source manifest owns the output. Imported legacy files may round-trip semantically until their frontmatter, whitespace, and generated headers have been normalized and documented.

### Pilot Files

The Sprint 0008 pilot loads and exports:

- `SharedVSCode/.ai/manifests/instruction-map.json`
- `SharedVSCode/.ai/agents/claude/version-control-commit.agent.md`
- `SharedVSCode/.ai/agents/codex/version-control-commit.toml`
- `SharedVSCode/.ai/languages/powershell.instructions.md`
- `SharedVSCode/.ai/skills/codex/git-commit/SKILL.md`

### Examples

```text
agent version-control-commit kind="CodexCustomAgentSource"
tools ["terminal", "read"]
target "Codex" ".codex/agents/version-control-commit.toml" "copy"
roundtrip byte-for-byte
```

```text
agent powershell-language-rule kind="LanguageRule"
target "GitHub Copilot" ".github/instructions/Powershell.instructions.md" "copy"
target "Claude" ".claude/Rules/Powershell.md" "generated-wrapper"
roundtrip semantic
```
