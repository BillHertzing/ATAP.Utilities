# Rules Compendium — {LanguageName}

<!-- METADATA
  Language:        {LanguageName}
  Created:         {ISO-date}
  Kind Count:      {n}
  Primitive Count: {n}
  Template version: 1.0
  Source skill:    .claude/skills/new-rule-kind/SKILL.md
-->

This file documents {LanguageName}-specific Rule Primitives, Rules, and Rule Sets
used within the ATAP.Utilities libraries and the Ace Commander application.

---

## Philote Identity Convention

Every Primitive, Rule, Rule Set, and Build Set defined in this document carries a
**Philote ID**. A Philote is a .NET generic type `IPhilote<T>` where `T` is either
`GUID` or `int`. All identifiers in this document use the `GUID` variant. The GUID
is allocated once when the element is defined and never changes; it is the stable
key back into the Ace Commander Instantiations database.

Format: `IPhilote<GUID>` — rendered in this document as a quoted GUID string,
e.g. `"a3f2e1d0-1b2c-4a5b-8c9d-0e1f2a3b4c5d"`.

---

## Overview

{LanguageName} Rules are built from {LanguageName} Rule Primitives. Each Rule
Primitive maps to a single BNF non-terminal in the {LanguageName} grammar. When a
primitive is instantiated, its inputs are bound to specific values; the rendered
output is the exact {LanguageName} text that corresponds to that non-terminal in
the parse tree.

Rules aggregate into Rule Sets. A Rule Set may define sequencing or dependency
(e.g., declarations before implementations). For each Rule defined here, the
Primitive Composition Table lists the primitives in render order; rendering each
primitive in sequence produces the final {LanguageName} artifact for that Rule.

---

## Language / Tooling Version

> Replace this section with version-specific guidance for {LanguageName}.

Unless there is a compelling reason to target an older version, all {LanguageName}
artifacts should target the latest stable tooling version to take advantage of
current features and improvements.

**Current stable version:** {version} (as of {date}).

---

## Part I — Grammar Specification

*This section is written once when each Kind is defined. Update only on grammar revision.*
*Regenerate from `docs/grammar/{KindName}.grammar.ebnf` using `Add-RuleKindToCompendium`.*

<!-- rule-grammar-start -->

### Kind: {KindName}

**Philote ID:** `"{KindPhiloteGUID}"`

**Grammar file:** `docs/grammar/{KindName}.grammar.ebnf`

**DB record:** `ATAPUtilities.PrimitiveLanguageKind` Id = {DbId}

**Description:** {One-sentence description of what this Kind produces.}

#### Grammar

<!-- EMBEDDED from docs/grammar/{KindName}.grammar.ebnf -->
```ebnf
<rule> ::= {production-rules-here}
```
<!-- END EMBEDDED -->

#### Composition Constraints

- Position 1 MUST be `{first-primitive}` (exactly one, non-optional)
- {Add one bullet per ordering constraint derived from the .ebnf}
- Cardinality values: `1` = exactly one, `?` = zero or one, `*` = zero or more, `+` = one or more

#### Valid Expression Examples

```
{LanguageName-example-1}
```

```
{LanguageName-example-2}
```

<!-- rule-grammar-end -->

---

## Part II — Rule Primitives

*Each primitive below maps to one row in `ATAPUtilities.RulePrimitive`.*
*Inputs map to rows in `ATAPUtilities.RulePrimitiveInput`.*

<!-- rule-primitives-start -->

---

### `<{primitive-name}>` Rule Primitive

**Philote ID:** `"{PrimitivePhiloteGUID}"`

**DB record:** `ATAPUtilities.RulePrimitive` Id = {DbId} | KindId = {KindDbId}

**Description:** {One sentence describing what this primitive produces.}

```bnf
<{primitive-name}> ::= {bnf-production}
```

**Inputs:**

- `{InputName}` (`{InputType}`, {required|optional}): {description}
- `{InputName}` (`{InputType}`, {required|optional}, default `{value}`): {description}

**Output:** {One sentence describing the rendered text output.}

**Attribution:**

```text
1. {URL or citation}
```

---

<!-- REPEAT the primitive block above for each RulePrimitive in this Kind -->

<!-- rule-primitives-end -->

---

## Part III — Rule Repository

*This section grows as Rules are written using this Kind.*
*Each Rule entry is appended here when a new Rule is instantiated.*
*Do not edit the `<!-- rule-repository-start/end -->` markers — they are used by*
*`Sync-RuleDocumentation` to locate insertion points.*

<!-- rule-repository-start -->

### Rule: {RuleName}

**Philote ID:** `"{RulePhiloteGUID}"`

**Purpose:** {What this Rule generates.}

**Source file:** `{relative/path/to/generated-file.ext}`

**Top-level derivation:**

```text
<rule>
{  └── tree of primitives with bound values }
```

**Primitive Composition Table**

| Position | Primitive | Cardinality | Key Inputs |
|----------|-----------|-------------|-----------|
| 1 | `<{primitive-name}>` | 1 | {InputName} = `{value}` |
| 2 | `<{primitive-name}>` | ? | {InputName} = `{value}` |

**Inputs to the Rule:**

- `{InputName}` = `{bound-value}`

**Attribution:**

```text
1. {URL or citation}
```

---

<!-- ADDITIONAL RULES ARE APPENDED ABOVE THIS LINE -->

<!-- rule-repository-end -->

---

## Part IV — Rule Sets

*Rule Sets group related Rules and define execution flow (directed graph).*
*This section is optional; add only when Rule Sets are formally defined.*

<!-- rule-sets-start -->

### Rule Set: {RuleSetName}

**Philote ID:** `"{RuleSetPhiloteGUID}"`

**Purpose:** {What this Rule Set implements.}

**Rules in Set:**

| Order | Rule | Condition |
|-------|------|-----------|
| 1 | {RuleName} | Always |
| 2 | {RuleName} | If {condition} |

<!-- rule-sets-end -->

---

*Last updated: {ISO-date} | Maintained by: `.claude/skills/new-rule-kind/SKILL.md`*
