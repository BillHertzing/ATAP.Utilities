# Rules Compendium.Markdown

## Markdown

| Property | Value |
|---|---|
| **Language** | Markdown |
| **Grammar** | Embedded below |
| **Added** | 2026-07-26 |
| **Sprint task** | 13.85 |
| **PrimitiveLanguageKindId** | 9 |

Markdown models CommonMark/GFM documents as RRSBS data that can be loaded from existing
source files, stored with stable identity and ordered content, and instantiated back into
byte-identical files. It is the first Kind added after the Instantiation correction, and
the first whose Rules are intended to be manifested to the filesystem rather than only
described.

### Purpose

The Markdown kind covers the constructs required to reproduce the documents in scope,
determined by scanning the frozen corpus rather than by enumerating all of CommonMark:

- ATX headings, levels 1 through 3 in the corpus, 1 through 6 in the grammar.
- Paragraphs and the blank lines that separate blocks.
- Fenced code blocks carrying an info string.
- Unordered lists and their continuation lines.
- GFM pipe tables with a delimiter row.
- Inline code spans, links, and emphasis.
- Plain text runs, including non-ASCII characters.

Deliberately **not** covered, because the corpus contains none: ordered lists, block
quotes, images, setext headings, HTML blocks, bare autolinks, reference-style links,
footnotes, and task lists. A later RuleVersion adds them when a document needs them.

### Corpus

Scope was fixed by operator decision on 2026-07-26 (Sprint task 13.85.b) to two files:

| File | Bytes | SHA-256 |
|---|---:|---|
| `src/ATAP.Utilities.PowerShell/Documentation/INDEX.md` | 2,401 | `5F55E818ABF0B688FFDA37BDDB7BBF8075F11E1EEF39C76B742290AC56C03BE5` |
| `src/ATAP.Utilities.PowerShell/Documentation/Write-ArrayIndented.md` | 7,514 | `1EFAA5653D8599CBAB47303BAC59FD0E8617BD1969874A4E6EF99EB114EFD807` |

Construct census across both files, from
`_generated/InstantiationFix/13.85/Scan-Constructs.ps1`:

| Construct | Count | Construct | Count |
|---|---:|---|---:|
| ATX heading, level 1 | 2 | Fenced code block | 14 |
| ATX heading, level 2 | 14 | — info string `powershell` | 8 |
| ATX heading, level 3 | 5 | — info string `text` | 6 |
| Blank line | 61 | Pipe table | 5 |
| Paragraph line | 55 | Table row | 19 |
| Unordered list item | 8 | Inline code span | 81 |
| List continuation line | 2 | Link | 12 |
| Strong emphasis | 1 | Emphasis | 1 |

The only non-ASCII character in the corpus is the em dash, `—` U+2014, appearing 8 times.
One apparent HTML tag is a false positive: `<FunctionName>` occurs inside an inline code
span in `INDEX.md` and is not markup.

### Primitives

| Primitive | BNF Symbol | Data type | Required | Description |
|---|---|---|---|---|
| MarkdownBlock | `markdown-block` | union | yes | Routing primitive selecting one block-level construct. Mirrors the `Path` kind's `<path>` primitive, which routes on `PathType`. |
| AtxHeading | `atx-heading` | object | yes | A `#`-prefixed heading, level 1 through 6. |
| Paragraph | `paragraph` | object | zero or more | A run of inline content terminated by a blank line. |
| BlankLine | `blank-line` | object | zero or more | One or more empty lines separating blocks. |
| FencedCodeBlock | `fenced-code-block` | object | zero or more | Backtick-fenced block with an info string and verbatim body. |
| UnorderedList | `unordered-list` | object | zero or more | A contiguous run of list items sharing one marker. |
| ListItem | `list-item` | object | one or more per list | A single item, optionally followed by indented continuation lines. |
| PipeTable | `pipe-table` | object | zero or more | GFM table: header row, delimiter row, then body rows. |
| TableRow | `table-row` | object | two or more per table | One pipe-delimited row of cells. |
| InlineCode | `inline-code` | inline | zero or more | Backtick-delimited code span. |
| Link | `link` | inline | zero or more | Inline link `[text](target)`. |
| Emphasis | `emphasis` | inline | zero or more | `*emphasis*` or `**strong**`. |
| TextRun | `text-run` | inline | zero or more | Literal text, including non-ASCII. |
| SourceLine | `source-line` | object | zero or more | One verbatim source line with its ordinal. Supports the byte-faithful initial RuleVersion; see "Initial RuleVersion model" below. |

Every primitive above is new. No existing primitive of any other Kind expresses a
Markdown block construct, so nothing is reused; the `Path` kind is referenced only as the
structural precedent for a routing primitive.

### Inputs

| Primitive | Input | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| MarkdownBlock | BlockType | string | yes |  | `atx-heading`, `paragraph`, `blank-line`, `fenced-code-block`, `unordered-list`, `pipe-table`, or `source-line`. |
| MarkdownBlock | BlockContent | object | yes |  | Instance of the selected block primitive. |
| AtxHeading | Level | int | yes |  | 1 through 6. Exactly one level-1 heading per document, on the first line. |
| AtxHeading | Text | string | yes |  | Inline content after the marker and its single space. |
| Paragraph | Text | string | yes |  | Inline content; hard-wrapped source lines are preserved as written. |
| BlankLine | Count | int | no | 1 | Consecutive blank lines. The lint configuration forbids more than one. |
| FencedCodeBlock | InfoString | string | yes | text | Language tag. Required because the lint configuration leaves MD040 enabled. |
| FencedCodeBlock | Body | string | yes |  | Verbatim body, never re-indented or re-wrapped. May be empty. |
| FencedCodeBlock | FenceChar | string | no | `` ` `` | Fence character. |
| FencedCodeBlock | FenceLength | int | no | 3 | Fence character count. |
| UnorderedList | Marker | string | no | `-` | `-`, `*`, or `+`, uniform within one list. |
| ListItem | Text | string | yes |  | Item content. |
| ListItem | IndentSpaces | int | no | 0 | Nesting indent; the lint configuration sets MD007 to 2. |
| ListItem | ContinuationText | string | no |  | Indented lines belonging to the item. |
| PipeTable | Alignments | string[] | no |  | Per-column `left`, `right`, `center`, or `none`, from the delimiter row. |
| TableRow | Cells | string[] | yes |  | Cell contents in column order. |
| TableRow | IsHeader | bit | no | 0 | Set on the row preceding the delimiter row. |
| InlineCode | Text | string | yes |  | Span content, backticks excluded. |
| Link | Text | string | yes |  | Link label. |
| Link | Target | string | yes |  | Destination, stored exactly as written. |
| Link | IsPercentEncoded | bit | no | 0 | Set when the target percent-encodes characters, as `Powershell%20Useage%20in%20ATAP.Utilities.md` does in the corpus. |
| Emphasis | Text | string | yes |  | Emphasized content. |
| Emphasis | Strength | string | yes | strong | `emphasis` for `*x*`, `strong` for `**x**`. |
| TextRun | Text | string | yes |  | Literal text, including `—` U+2014. |
| SourceLine | Ordinal | int | yes |  | 1-based line number; must be gap-free within its Rule. |
| SourceLine | Text | string | yes |  | Verbatim line content, line terminator excluded. May be empty. |
| SourceLine | LineEnding | string | no | CRLF | `CRLF` or `LF`. The corpus is 100% CRLF with a final newline. |

### Composition

Composition in the deployed schema is scoped to a **Rule**, not to a Kind, and is ordered
by `RulePrimitiveComposition.SequenceKey`, an `NVARCHAR(40)`. There is no `Position`,
`IsOptional`, or `Cardinality` column, so the cardinality and optionality below live in
this document and in `RulePrimitiveComposition.Notes`; the database cannot enforce them.

Composition of the `MarkdownDocument` Rule:

| SequenceKey | Primitive | Cardinality | Optional | Notes |
|---|---|---|---|---|
| `001` | AtxHeading | 1 | no | Required anchor. The lint configuration keeps MD041 and MD025 enabled, so a document begins with exactly one level-1 heading. |
| `002` | MarkdownBlock | * | yes | Every subsequent block, in document order, routed by `BlockType`. |

Two rows rather than one row per construct is deliberate. A flat composition listing
`paragraph`, then `fenced-code-block`, then `pipe-table` would assert that documents
contain all their paragraphs before all their code blocks, which is false. Real documents
interleave block types freely, so the ordering lives in the repeated `MarkdownBlock`
instances and the routing primitive selects the construct.

The inline primitives — `inline-code`, `link`, `emphasis`, `text-run` — appear in the
grammar as helper productions rather than as composition rows, exactly as `identifier` and
`tool-name` do for the AgentText kind.

### Grammar

```ebnf
# Markdown.grammar.ebnf
# Language: Markdown
# Kind: Markdown
# Created: 2026-07-26
# Description: CommonMark/GFM subset sufficient to reproduce ATAP module documentation byte for byte.

markdown-document   ::= atx-heading markdown-block*

# --- Primitive definitions ---
markdown-block      ::= atx-heading
                      | paragraph
                      | blank-line
                      | fenced-code-block
                      | unordered-list
                      | pipe-table
                      | source-line

atx-heading         ::= ("#" | "##" | "###" | "####" | "#####" | "######") " " inline-content line-ending
paragraph           ::= inline-content line-ending (inline-content line-ending)*
blank-line          ::= line-ending
fenced-code-block   ::= fence info-string line-ending code-body fence line-ending
unordered-list      ::= list-item+
list-item           ::= list-marker " " inline-content line-ending continuation-line*
pipe-table          ::= table-row delimiter-row table-row+
table-row           ::= "|" (cell "|")+ line-ending
delimiter-row       ::= "|" (alignment "|")+ line-ending

# --- Inline productions ---
inline-content      ::= (text-run | inline-code | link | emphasis)+
inline-code         ::= "`" code-text "`"
link                ::= "[" link-text "]" "(" link-target ")"
emphasis            ::= "*" text-run "*" | "**" text-run "**"
text-run            ::= character+

# --- Terminals ---
source-line         ::= character* line-ending
line-ending         ::= "\r\n" | "\n"
fence               ::= "```"
info-string         ::= identifier
list-marker         ::= "-" | "*" | "+"
continuation-line   ::= "  " character+ line-ending
alignment           ::= "---" | ":--" | "--:" | ":-:"
cell                ::= inline-content
character           ::= <any Unicode scalar value except a line terminator>
```

### Initial RuleVersion model

The `source-line` primitive exists because the initial ingestion of a file is
line-faithful, matching how the PowerShell kind ingested `Write-ArrayIndented.ps1` in
InstantiationVersion 1: the first RuleVersion reproduces exact bytes, and decomposition
into structural primitives follows in a later version without changing the meaning of the
earlier immutable one.

Whether that initial version binds its lines through ordered `RuleInstantiation` rows or
through a separate ordered source-line entity is **not decided here**. It is the open
decision in Sprint 0013 Task 13.79.g, and this Kind is deliberately compatible with either
outcome: `source-line` carries its own `Ordinal`, so it works as a standalone ordered
entity, and its inputs are simple scalars, so they bind cleanly as `RuleInstantiation`
values.

### Round-trip rules

Documents ingested under this Kind round-trip **byte for byte**, not semantically. The
renderer must preserve, without normalization:

- Line endings exactly as ingested. The corpus is CRLF throughout.
- The final newline, present in both corpus files.
- Blank lines, including their count and position.
- Hard-wrap positions inside paragraphs and table cells.
- Table cell padding, which is aligned by column width in the corpus and is not
  significant to Markdown but is significant to the bytes.
- Fenced-code bodies verbatim, including an empty body.
- UTF-8 encoding with no BOM.

A renderer that pretty-prints tables, re-wraps paragraphs, collapses blank lines, or adds
a BOM produces a different file and fails the hash comparison, whatever a Markdown parser
would say about equivalence.

### Constraints the database cannot enforce

Recorded here because the deployed schema has no column for them, so a violation passes
every foreign key and check constraint and appears only as wrong output:

- `SequenceKey` uniqueness and gap-freedom within a Rule.
- Cardinality and optionality of each composition row.
- `SourceLine.Ordinal` contiguity from 1.
- Exactly one level-1 heading, on the first line.
- `FencedCodeBlock.InfoString` non-empty, required by MD040.

Task 13.85.s adds a verification SQL artifact covering each of these.
