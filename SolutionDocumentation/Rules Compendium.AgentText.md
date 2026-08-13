# Rules Compendium — AgentText

<!-- METADATA
  Language: AgentText
  Created: pre-existing; normalized 2026-08-02
  Kind Count: 1
  Primitive Count: 8
  Template version: 1.0
  Source skill: .claude/skills/new-rule-kind/SKILL.md
-->

This file documents AgentText Rule Primitives and Rules used to load, store,
and render AI-agent and instruction artifacts in ATAP.Utilities and Ace Commander.

## Philote Identity Convention

Every Primitive, Rule, Rule Set, and Build Set defined in this document carries
a **Philote ID**. A Philote is a .NET generic type `IPhilote<T>` where `T` is
either `GUID` or `int`. All identifiers in this document use the `GUID` variant.
The GUID is allocated once when the element is defined and never changes; it is
the stable key back into the Ace Commander Instantiations database.

Format: `IPhilote<GUID>` — rendered in this document as a quoted GUID string,
for example, `"a3f2e1d0-1b2c-4a5b-8c9d-0e1f2a3b4c5d"`.

## Overview

AgentText models agent identity, instruction text, minimal tool surfaces,
ordered runbooks, guardrails, return contracts, and adapter targets. Rules bind
these primitives into deterministic AgentText documents; adapter-specific
rendering remains a later projection and compatibility concern.

The grammar deliberately bounds its scope to the AgentText document envelope.
It treats Markdown, TOML, and JSON Schema references as opaque payloads rather
than claiming to parse their full syntaxes.

## Language / Tooling Version

AgentText is an RRSBS document contract rather than a versioned programming
language. The current contract is the bounded deterministic-rendering grammar
in `grammers/AgentText.grammar.ebnf`, normalized on 2026-08-02.

## Part I — Grammar Specification

*This section is written once when the Kind is defined. Update only on grammar revision.*
*The grammar below is authored at `grammers/AgentText.grammar.ebnf`; its rendered*
*`docs/` copy remains deferred until grammar artifacts become database-stored.*

<!-- rule-grammar-start -->

### Kind: AgentText

**Philote ID:** Not allocated in the current documentation corpus. The legacy
numeric kind record is source evidence only; retained-kind identity allocation
remains behind the later baseline/seed gate.

**Grammar file:** `grammers/AgentText.grammar.ebnf`

**DB record:** The frozen source corpus establishes legacy
`ATAPUtilities.PrimitiveLanguageKind` Id = 8 / `AgentText`; database conformance
and projection redesign remain later gated work.

**Description:** Deterministic AgentText document rendering from retained
identity, body, tool, runbook, guardrail, return-contract, target, and
round-trip-policy primitives.

#### Grammar

<!-- EMBEDDED from grammers/AgentText.grammar.ebnf -->
```ebnf
agent-text-document = agent-identity, instruction-body, [ tool-surface ],
                      { runbook-step }, { guardrail }, [ return-contract ],
                      { adapter-target }, round-trip-policy ;
```
<!-- END EMBEDDED -->

#### Composition Constraints

- An AgentText document requires exactly one `agent-identity`, one
  `instruction-body`, and one `round-trip-policy`, in that order.
- `tool-surface` occurs at most once before any runbook step or guardrail.
- `runbook-step` values occur in authored order; the grammar validates their
  envelope, while contiguous or unique sequence-key validation is a later
  semantic contract.
- `guardrail` values follow all runbook steps; `return-contract` occurs at most
  once after the guardrails.
- `adapter-target` values occur after the optional return contract and before
  the required round-trip policy.
- Every documented Rule Primitive maps to a non-terminal in
  `grammers/AgentText.grammar.ebnf`.

#### Valid Expression Examples

```text
agent version-control-commit kind="CodexCustomAgentSource"
tools ["terminal", "read"]
target Codex ".codex/agents/version-control-commit.toml" copy
roundtrip byte-for-byte
```

```text
agent powershell-language-rule kind="LanguageRule"
target Claude ".claude/Rules/Powershell.md" generated-wrapper
roundtrip semantic
```

<!-- rule-grammar-end -->

---

## Part II — Rule Primitives

Rule Primitives are the atomic building blocks from which a Rule is constructed.
Each primitive maps to an AgentText grammar non-terminal.

<!-- rule-primitives-start -->

---

### `<agent-identity>` Rule Primitive

**Philote ID:** `"c3b4c3b8-7d41-41e4-8d85-793b83f4be01"`

**DB record:** Legacy source migration `V00.02.000040` seeds this primitive for
the AgentText numeric Kind Id 8; no current database conformance is asserted.

**Description:** Stable agent, skill, or instruction identity plus metadata.

```bnf
<agent-identity> ::= "agent" <whitespace> <identifier> (<whitespace> <metadata>)*
```

**Inputs:**

- `SourceId` (`string`, required): Stable manifest or RRSBS identifier.
- `DisplayName` (`string`, optional): Human-readable name.

**Output:** Agent identity declaration with optional metadata.

---

### `<instruction-body>` Rule Primitive

**Philote ID:** `"c3b4c3b8-7d41-41e4-8d85-793b83f4be02"`

**DB record:** Legacy source migration `V00.02.000040` seeds this primitive for
the AgentText numeric Kind Id 8; no current database conformance is asserted.

**Description:** Markdown, TOML, or text body loaded from canonical source files.

```bnf
<instruction-body> ::= <markdown-block> | <toml-block> | <text-block>
```

**Inputs:**

- `Body` (`string`, required): Raw source body.
- `BodyFormat` (`string`, required, default `markdown`): `markdown`, `toml`, or `text`.

**Output:** One opaque instruction-body payload in its declared format.

---

### `<tool-surface>` Rule Primitive

**Philote ID:** `"c3b4c3b8-7d41-41e4-8d85-793b83f4be03"`

**DB record:** Legacy source migration `V00.02.000040` seeds this primitive for
the AgentText numeric Kind Id 8; no current database conformance is asserted.

**Description:** Minimal native tool declarations for an agent or skill.

```bnf
<tool-surface> ::= "tools" <whitespace> "[" <tool-name> ("," <whitespace> <tool-name>)* "]"
```

**Inputs:**

- `Tools` (`string[]`, optional, default `[]`): Minimal native tool list.

**Output:** Ordered tool declaration list.

---

### `<runbook-step>` Rule Primitive

**Philote ID:** `"c3b4c3b8-7d41-41e4-8d85-793b83f4be04"`

**DB record:** Legacy source migration `V00.02.000040` seeds this primitive for
the AgentText numeric Kind Id 8; no current database conformance is asserted.

**Description:** Ordered workflow step text.

```bnf
<runbook-step> ::= "step" <whitespace> <sequence-key> ":" <whitespace> <markdown-block>
```

**Inputs:**

- `SequenceKey` (`string`, required): Authored ordering key.
- `Text` (`string`, required): Step body.

**Output:** One ordered runbook step.

---

### `<guardrail>` Rule Primitive

**Philote ID:** `"c3b4c3b8-7d41-41e4-8d85-793b83f4be05"`

**DB record:** Legacy source migration `V00.02.000040` seeds this primitive for
the AgentText numeric Kind Id 8; no current database conformance is asserted.

**Description:** Boundary, safety, or ownership instruction.

```bnf
<guardrail> ::= "guardrail" ":" <whitespace> <markdown-block>
```

**Inputs:**

- `Text` (`string`, required): Guardrail text.

**Output:** One guardrail declaration.

---

### `<return-contract>` Rule Primitive

**Philote ID:** `"c3b4c3b8-7d41-41e4-8d85-793b83f4be06"`

**DB record:** Legacy source migration `V00.02.000040` seeds this primitive for
the AgentText numeric Kind Id 8; no current database conformance is asserted.

**Description:** Structured result contract expected by an orchestrator.

```bnf
<return-contract> ::= "returns" <whitespace> <json-schema-reference>
```

**Inputs:**

- `SchemaRef` (`string`, optional): Return schema reference.

**Output:** One opaque schema-reference declaration.

---

### `<adapter-target>` Rule Primitive

**Philote ID:** `"c3b4c3b8-7d41-41e4-8d85-793b83f4be07"`

**DB record:** Legacy source migration `V00.02.000040` seeds this primitive for
the AgentText numeric Kind Id 8; no current database conformance is asserted.

**Description:** Native rendered target path and materialization mode.

```bnf
<adapter-target> ::= "target" <whitespace> <tool-name> <whitespace> <path>
                     <whitespace> <materialization-mode> [ <whitespace> <rendered-hash> ]
```

**Inputs:**

- `Tool` (`string`, required): Native tool family.
- `Path` (`string`, required): Rendered path relative to the consuming repository.
- `Materialization` (`string`, required, default `copy`): `copy`, `symlink`,
  `junction`, or `generated-wrapper`.
- `RenderedSha256` (`string`, optional): Expected rendered hash.

**Output:** One adapter-target declaration.

---

### `<round-trip-policy>` Rule Primitive

**Philote ID:** `"c3b4c3b8-7d41-41e4-8d85-793b83f4be08"`

**DB record:** Legacy source migration `V00.02.000040` seeds this primitive for
the AgentText numeric Kind Id 8; no current database conformance is asserted.

**Description:** Byte-for-byte or semantic round-trip expectation.

```bnf
<round-trip-policy> ::= "roundtrip" <whitespace> ( "byte-for-byte" | "semantic" )
```

**Inputs:**

- `Policy` (`string`, required, default `semantic`): `byte-for-byte` or `semantic`.

**Output:** Required final round-trip-policy declaration.

<!-- rule-primitives-end -->

---

## Part III — Rule Repository

This section grows as Rules are written using this Kind.

<!-- rule-repository-start -->

### Rule: AgentTextDocument

**Philote ID:** `"c3b4c3b8-7d41-41e4-8d85-793b83f4bf00"`

**Purpose:** Composes the AgentText document envelope from identity, body,
optional tool/runbook/guardrail/return/target values, and a final policy.

**Source file:** `SolutionDocumentation/Rules Compendium.AgentText.md#grammar`

**Top-level derivation:**

```text
<agent-text-document>
├── <agent-identity>
├── <instruction-body>
├── <tool-surface>?
├── <runbook-step>*
├── <guardrail>*
├── <return-contract>?
├── <adapter-target>*
└── <round-trip-policy>
```

**Primitive Composition Table**

| Position | Primitive | Cardinality | Key Inputs |
| ---: | --- | --- | --- |
| 1 | `<agent-identity>` | 1 | `SourceId`, `DisplayName` |
| 2 | `<instruction-body>` | 1 | `Body`, `BodyFormat` |
| 3 | `<tool-surface>` | ? | `Tools` |
| 4 | `<runbook-step>` | * | `SequenceKey`, `Text` |
| 5 | `<guardrail>` | * | `Text` |
| 6 | `<return-contract>` | ? | `SchemaRef` |
| 7 | `<adapter-target>` | * | `Tool`, `Path`, `Materialization` |
| 8 | `<round-trip-policy>` | 1 | `Policy` |

**Attribution:**

```text
1. Database/Flyway/SQL/V00.02.000040__Add_AgentText_Rule_Kind.sql
2. SolutionDocumentation/grammers/AgentText.grammar.ebnf
```

<!-- rule-repository-end -->

---

## Part IV — Rule Sets

No formal AgentText Rule Set identity is present in the legacy source migration
or the pre-normalization compendium. This section remains intentionally empty.

<!-- rule-sets-start -->
<!-- rule-sets-end -->

---

## Round-Trip Boundary

Generated adapters may require byte-for-byte round trips when their canonical
source owns the output. Imported legacy files may round-trip semantically until
frontmatter, whitespace, and generated headers have been normalized and
documented. Adapter rendering, projection freshness, and compatibility views
remain later-gated work; this document does not assert their implementation.

*Last updated: 2026-08-02 | Maintained by: `.claude/skills/new-rule-kind/SKILL.md`*
