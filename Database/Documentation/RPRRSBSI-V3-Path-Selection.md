# RPRRSBSI V3 Path Selection Record

## Decision

V3 retains the Path grammar and all existing Path Rule Primitives by reference to
[`Rules Compendium.Path.md`](../../SolutionDocumentation/Rules%20Compendium.Path.md).
It adds no Path primitive and makes no grammar amendment. The retained catalog has
13 Path primitives: 12 grammar primitives plus the specialized
`<atap-utilities-secrets-csproj-path>` primitive. The initial V3 Path Rule value
is exactly `HelloWorld.ps1`, selected under the retained `<relative-path>`
primitive, as directed by the HITL-reviewed V3 plan.

## Retained catalog

The retained compendium declares **13** Path Rule Primitives: 12 grammar
primitives plus one specialized primitive:

`<path>`, `<unc-path>`, `<absolute-path>`, `<relative-path>`, `<extended-path>`,
`<drive>`, `<path-tail>`, `<name>`, `<namechar>`, `<server>`, `<share>`, and
`<letter>`; and `<atap-utilities-secrets-csproj-path>`.

Together with the two retained PowerShell primitives, the V3 catalog contains
**15 total Rule Primitives**.

It declares **21 named input declarations** across those primitives:

| Primitive | Named inputs | Count |
| --- | --- | ---: |
| `<path>` | `PathType`, `PathContent` | 2 |
| `<unc-path>` | `Server`, `Share`, `PathTail` | 3 |
| `<absolute-path>` | `Drive`, `PathTail` | 2 |
| `<relative-path>` | `PathTail` | 1 |
| `<extended-path>` | `PathVariant`, `AbsolutePath`, `Server`, `Share`, `PathTail` | 5 |
| `<drive>` | `Letter` | 1 |
| `<path-tail>` | `Name`, `RestOfPath` | 2 |
| `<name>` | `NameChars` | 1 |
| `<namechar>` | `Character` | 1 |
| `<server>` | `ServerIdentifier` | 1 |
| `<share>` | `ShareName` | 1 |
| `<letter>` | `LetterChar` | 1 |
| `<atap-utilities-secrets-csproj-path>` | None | 0 |
| **Total** |  | **21** |

The `<extended-path>` input list presents `Server`, `Share`, and `PathTail` together
in one bullet; they are nevertheless three separately named declarations. This
explains why a physical Markdown-bullet count is 19 while the declared input-name
count is 21. The specialized primitive has no structured input metadata and
therefore contributes zero `RulePrimitiveInput` rows.

## Exact derivation

The retained grammar derives the selected value without an extension:

```text
<relative-path> ::= <path-tail>
                ::= <name>
                ::= "HelloWorld.ps1"
```

The final step uses the retained `<name>` production, `<name> ::= <namechar>
{<namechar>}`. No recursive `RestOfPath` is needed for this one-name path tail.

Source citations: retained compendium grammar at `<relative-path>`, `<path-tail>`,
and `<name>`; retained input metadata appears under each primitive in Part II.
The V3 plan selects `HelloWorld.ps1` under `<relative-path>` at lines 85–88 and
226–228.

## Non-selected seed values

`./HelloWorld.ps1` and `.\HelloWorld.ps1` are rejected as V3 seed values. No
`<dot-relative-path>` primitive is introduced. Other dot-prefixed spellings are also
not V3 seed values unless their acceptance is independently established by the
retained grammar; this record makes no broader grammar-acceptance claim.

## Evidence versus assertion

- **Verified from sources:** 13 retained Path primitive headings (12 grammar plus
  one specialized); 15 total retained primitives across Path and PowerShell; 21
  named structured Path input declarations, with zero for the specialized
  primitive; 22 semantic Philotes; the productions used in the derivation; and
  the amended plan's `<relative-path>` selection.
- **V3 selection assertion:** the initial seed value must be exactly
  `HelloWorld.ps1`; the rejected values above are excluded from the V3 seed, not a
  general parser conformance judgment.
