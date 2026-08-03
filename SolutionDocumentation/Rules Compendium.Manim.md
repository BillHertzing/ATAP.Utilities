# Rules Compendium — Manim

<!-- METADATA
  Language: ManimScene
  Created: pre-existing; normalized 2026-08-03
  Kind Count: 1
  Primitive Count: 7
  Rule Count: 0
  Instantiation Count: 0
  Template version: 1.0
  Authority: GRAMMAR-01; retained-kind decision and prior Manim compendium
-->

This normalized compendium describes the retained ManimScene documentation
corpus. It records grammar coverage and legacy documentation identities only;
it does not authorize a migration, seed change, renderer, package, or render.

## Philote Identity Convention

A Philote is a stable, table-specific GUID for a durable or versioned
first-class RRSBS row. The current ManimScene corpus supplies only documented
GUIDs, not retained database seed rows. Those identifiers are preserved as
legacy documentation identities pending source-to-target mapping; this document
does not assert that they are database-backed or allocate a Kind GUID.

## Overview

ManimScene Rules describe deterministic Python scene source for Manim Community
rendering. The source corpus contains one documented Kind and seven documented
Rule Primitives. It contains no retained ManimScene Rule, Rule Set, Build Set,
or Instantiation seed rows.

## Language / Tooling Version

The grammar is a bounded Manim/Python profile derived from the pre-existing
compendium and subsystem overview. It does not set a Python, Manim, ffmpeg,
MiKTeX, renderer, sandbox, or output-retention policy; those decisions are
outside RDB-180C.

## Part I — Grammar Specification

<!-- rule-grammar-start -->

### Kind: ManimScene

**Philote ID:** `b2a7f8c3-4e1d-4a90-8f35-3d9e2b5c7f01` (legacy documentation
identity; no retained seed mapping found).

**Grammar file:** `SolutionDocumentation/grammers/ManimScene.grammar.ebnf`

**DB record:** Not present in the retained Flyway source corpus; no database
identity, KindId, or migration is inferred.

**Description:** Deterministic Python scene-source rendering from the documented
ManimScene Rule Primitives.

#### Grammar

<!-- EMBEDDED from SolutionDocumentation/grammers/ManimScene.grammar.ebnf -->
```ebnf
manim-scene-file = import-section, new-line, scene-class-list ;
scene-class = "class", whitespace, identifier, "(", scene-base-class, "):" , new-line,
              construct-method ;
statement = mobject-assignment | play-statement | wait-statement | add-statement |
            remove-statement | camera-statement | comment-statement ;
```
<!-- END EMBEDDED -->

#### Composition Constraints

- A rendered source file starts with a Manim import section and contains one or
  more scene classes.
- Each scene class has exactly one supported Manim base class and a
  `construct(self)` method with indented statements.
- Statement and animation order are preserved from their owning bindings.
- The profile supports only the documented primitive subset; arbitrary Python,
  filesystem access, subprocess execution, network access, and renderer
  invocation are outside this grammar.

#### Valid Expression Example

```python
from manim import *

class Greeting(Scene):
    def construct(self):
        text = Text("Hello")
        self.play(Write(text))
        self.wait(1)
```

<!-- rule-grammar-end -->

## Part II — Rule Primitives

<!-- rule-primitives-start -->

| Rule Primitive | Philote ID | DB record | Grammar non-terminal | Description | Disposition |
| --- | --- | --- | --- | --- | --- |
| `<manim-scene-file>` | `c1f3a8e2-5b7d-4c91-9e23-4f0b8d6a2e35` | No retained seed row | `manim-scene-file` | Top-level Manim Python source file. | preserve legacy documentation identity pending mapping |
| `<scene-class>` | `d7e4b2c9-6a1f-4d80-be57-8c3a9f1b7e42` | No retained seed row | `scene-class` | One Manim scene class and `construct` method. | preserve legacy documentation identity pending mapping |
| `<mobject-expr>` | `e9a5c3f1-7b2e-4f92-ad68-5d4c0e8b3f19` | No retained seed row | `mobject-expression` | Displayable Manim Mobject constructor expression. | preserve legacy documentation identity pending mapping |
| `<anim-expr>` | `f2b8d6e4-3c9a-4e01-9f74-6e5d1b2a8c37` | No retained seed row | `animation-expression` | Animation expression passed to `self.play`. | preserve legacy documentation identity pending mapping |
| `<play-stmt>` | `a4d7f1b3-2e9c-4b83-8a56-7c2e4f9d1b08` | No retained seed row | `play-statement` | Ordered animation playback statement. | preserve legacy documentation identity pending mapping |
| `<wait-stmt>` | `b6c0e5a8-1d4f-4c72-9e37-3f8b5c7d2a91` | No retained seed row | `wait-statement` | Timeline pause statement. | preserve legacy documentation identity pending mapping |
| `<mobject-assignment>` | `c8a3d6f2-4e1b-4d93-be48-9a7c2e5f0b14` | No retained seed row | `mobject-assignment` | Local Mobject binding. | preserve legacy documentation identity pending mapping |

<!-- rule-primitives-end -->

## Part III — Rule Repository

<!-- rule-repository-start -->

No retained ManimScene `Rule` seed rows are present. No Rule identity,
source-path alias, or retirement is inferred.

<!-- rule-repository-end -->

## Part IV — Instantiations and Rule Sets

<!-- rule-sets-start -->

No retained ManimScene Rule Set, Build Set, or Instantiation seed rows are
present. The documented primitive identities remain preserved without inventing
future composition identities.

<!-- rule-sets-end -->

## Sources and Boundaries

- `SolutionDocumentation/Rules Compendium.Manim.md` (pre-normalization corpus)
- `src/ATAP.Utilities.ManimVideoGenerator/Documentation/Overview.md`
- `InformationForTheFuture/RRSBS-Rationalization/Plan-RRSBS-Final.md` (retained-kind decision)

RDB-180C normalizes documentation only. No Python source, Manim package,
renderer, media output, database migration, seed, or live-system action is
part of this work unit.

*Last updated: 2026-08-03 | Maintained by: RDB-180C ManimScene normalization*
