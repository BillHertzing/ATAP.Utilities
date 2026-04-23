# Rules Compendium

This file contains an overview of the Powershell-specific Rules used within the ATAP.Utilities, its databases, and the Ace Commander application built from these rules.

## Philote Identity Convention

Every Primitive, Rule, Rule Set, and Build Set defined in this document carries a **Philote ID**. A Philote is a .NET generic type `IPhilote<T>` where `T` is either `GUID` or `int`. All identifiers in this document use the `GUID` variant. The GUID is allocated once when the element is defined and never changes; it is the stable key back into the Ace Commander Instantiations database.

Format: `IPhilote<GUID>` — rendered in this document as a quoted GUID string, e.g. `"a3f2e1d0-1b2c-4a5b-8c9d-0e1f2a3b4c5d"`.

## Overview

This file documents Rules and Rule Sets that make up modules and features.

Rules are created from Rule Primitives.

Rule Sets are created from Rules, and include a directed graph that control how execution flows from one Rule to another.

In order to define a feature or module in the ATAP.Utilities libraries or the Ace Commander application, a Rule Set is tagged with a feature identifier, which means that to implement the feature, the Ace Commander Module will include that Rule Set in its Build Set.

## The purpose of Rules, Rule Sets, and Build Sets

Here is a simplifying acronym to shorten the long name "Rules, Rule Sets and Build Sets". We will refer to all of those compositely as "RRSBS".

Everything in the ATAP.Utilities libraries and the Ace Commander application, and all bolt-on modules for Ace Commander, are built from RRSBS. There are RRSBS that define the Ace Commander GUI. There are RRSBS for all visual display elements, RRSBS for composing visual elements into screens / pages, and RRSBS for stiching the screens / pages together into logical workflows. All data elements in the ecosystem are defined by RRSBS. Hardware for the computer systems that run the backend and on which the front end application runs are defined by RRSBS. Build processes for creating .dll libraries, .so libraries, .exe programs, are all defined by RRSBS. All tests for all software component are defined by RRSBS. Test Processes are defined by RRSBS. The processes to create and maintain database schemas and data are defined by RRSBS, as are the instructions how to backup and restore these databases. Documentation about how the RRSBS work are themselves defined by RRSBS. In sum, every concept, every bit of data, every software tool, the complete Ace Commander application, interfaces to third-party hardware and software are all defined by RRSBS. Specific instantiations of the Ace Commander or ATAP.Utilities libraries owned / used by owners / users are stored in the Instantiations database, and that database, and its schema and operational processes are defined by RRSBS. The API's for the backend and how the Ace Commander front-end communicates with the back-end APIs are defined by RRSBS

## Rule Primitives

Rule Primitives are the atomic building blocks from which a Rule is constructed. Each primitive maps to a single BNF non-terminal in the Powershell grammar. When a primitive is instantiated, its inputs are bound to specific values; the rendered output is the exact Powershell text that corresponds to that non-terminal node in the parse tree.

### Complete Powershell Cmdlet Rule Primitive

**Philote ID:** `"e1a2b3c4-d5e6-4f78-9012-a3b4c5d6e7f8"`

Description: This primitive holds an entire Powershell cmdlet

Body: A text block that contains a complete powershell cmdlet

Inputs: The cmdlet parameters are the primitives inputs.

Output: The cmdlet outputs are the primitives outputs.

Processing: The primitive is invoked in a Powershell engine context, or, it is rendered into a standalone Powershell file, or it is rendered into a larger powershell container.

### Composed Powershell Cmdlet Rule Primitive

**Philote ID:** `"f2b3c4d5-e6f7-4089-a123-b4c5d6e7f8a9"`

Description: This primitive defines a container into which Powershell cmdlet sections can be inserted. The Backus–Naur Form (BNF) of the Composed Powershell Cmdlet is as follows:

A cmdlet call consists of a Verb-Noun name followed by zero or more arguments:

```bnf
<cmdlet-invocation> ::= <cmdlet-name> <ws> <argument-list>
| <cmdlet-name>

<cmdlet-name> ::= <verb> "-" <noun>
<verb> ::= <letter> | <verb> <letter>
<noun> ::= <letter> | <noun> <letter> | <noun> <digit>
```

PowerShell enforces an Approved Verb convention (e.g., Get, Set, New, Remove) joined by a hyphen to a Pascal-cased noun.

#### Arguments and Parameters

```bnf
<argument-list> ::= <argument>
| <argument-list> <ws> <argument>

<argument> ::= <named-parameter>
| <switch-parameter>
| <positional-argument>

<named-parameter> ::= <parameter-name> <ws> <parameter-value>
| <parameter-name> ":" <parameter-value>

<switch-parameter> ::= <parameter-name>

<positional-argument> ::= <parameter-value>

<parameter-name> ::= "-" <first-param-char> <param-chars>
<first-param-char> ::= <letter> | "_"
<param-chars> ::= "" | <param-chars> <param-char>
<param-char> ::= <letter> | <digit> | "_"
```

The official spec defines command-parameter as dash first-parameter-char parameter-chars colon~opt~, where the trailing colon binds the value directly (e.g., -Path:"C:\temp").

#### Parameter Values

```bnf
<parameter-value> ::= <literal>
| <variable>
| <array-expr>
| <script-block>
| <subexpression>

<literal> ::= <integer-literal>
| <real-literal>
| <string-literal>

<string-literal> ::= '"' <expandable-chars> '"'
| "'" <verbatim-chars> "'"

<integer-literal> ::= <decimal-digits>
| "0x" <hex-digits>

<variable> ::= "$" <variable-name>
                        | "$" "{" <variable-name> "}"

<variable-name> ::= <variable-char> | <variable-name> <variable-char>
<variable-char> ::= <letter> | <digit> | "\_"

<array-expr> ::= "@(" <argument-list> ")"
<script-block> ::= "{" <script-block-body> "}"
<subexpression> ::= "$(" <statement-list> ")"
```

##### Primitives

```bnf
<decimal-digits> ::= <digit> | <decimal-digits> <digit>
<hex-digits> ::= <hex-digit> | <hex-digits> <hex-digit>

<digit> ::= "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
<hex-digit> ::= <digit> | "a" | "b" | "c" | "d" | "e" | "f"
| "A" | "B" | "C" | "D" | "E" | "F"
<letter> ::= any Unicode letter (Lu, Ll, Lt, Lm, Lo)
<ws> ::= " " | "\t" | <ws> " " | <ws> "\t"
```

#### Pipeline Context

Cmdlets are typically used within a pipeline:
​

```bnf
<pipeline> ::= <cmdlet-invocation>
| <cmdlet-invocation> "|" <pipeline>
```

#### Example Derivation

For Get-ChildItem -Path "C:\temp" -Recurse:

```text
<cmdlet-name> → Get-ChildItem

<named-parameter> → -Path "C:\temp" (name = Path, value = string-literal)

<switch-parameter> → -Recurse (no value — presence alone activates it)

The -Recurse case is a switch parameter, where omitting a value is semantically meaningful — this is captured in the grammar by the <switch-parameter> ::= <parameter-name> production
```

Processing: The primitive is rendered into a standalone Powershell file, or it is rendered into a larger Powershell container.

Attribution:

```text
1. https://learn.microsoft.com/en-us/powershell/scripting/lang-spec/chapter-15?view=powershell-7.5
2. https://cs61.seas.harvard.edu/site/2021/BNFGrammars/
3. https://www2.cs.sfu.ca/CourseCentral/383/tjd/ebnf_intro_in_go.html
4. https://help.qlik.com/en-US/sense/November2025/Subsystems/Hub/Content/Sense_Hub/Scripting/Backus-Naur-formalism.htm
5. https://stackoverflow.com/questions/51773245/is-there-a-language-specification-document-for-powershell-5-or-later
6. https://en.wikipedia.org/wiki/Extended_Backus–Naur_form
7. https://www.freecodecamp.org/news/what-are-bnf-and-ebnf/
8. https://forums.powershell.org/t/backus-naur-form-bnf/5148
9. https://docs.microsoft.com/he-il/cpp/atl/understanding-backus-naur-form-bnf-syntax?view=msvc-150
10. https://www.ibm.com/docs/SSZJPZ_11.3.0/com.ibm.swg.im.iis.conn.msole.doc/topics/r_cmsftref_Backus_Naur_Form_BNF_Notation.html
11. https://stackoverflow.com/questions/33221132/backus-naur-form-bnf-recursion
12. https://moleseyhill.com/2010-05-05-backus-naur-form.html
13. https://bnfc.digitalgrammars.com/LBNF-report.pdf
```

#### Powershell cmdlet parameter block

Description: This primitive specifies the components that make up the parameter block of a powershell cmdlet.

#### Powershell cmdlet parameter validation

Description: Powershell cmdlet parameter validation is performed with the powershell cmdlet `Get-ParameterValueFromNeoConfigurationRoot` (alias is `Get-PVal`). This cmdlet populates the parameter using the following hierarchy of sources
(1) a value passed in the PSBoundParameter when the cmdlet is called
(2) an environment variable by the same name
(3) a value stored in `$global:settings`, having the parameter name as a key
(4) a value stored in a specified hash, having the parameter name as a key
(5) a value stored in a specified hash, having a specified dotted path as a key
(6) the built-in default value assigned to the parameter in the cmdlet's parameter declaration block

Body: A text block that contains a single line of powershell that invokes `Get-PVal` and populates its inputs

Inputs: TBD - replace with the parameters to `Get-ParameterValueFromNeoConfigurationRoot`.

Output: The resolved value of the parameter. The result is placed in the parameter value.

Processing: The primitive writes its text block to the Powershell cmdlet Begin block in the `Parameter Validation region`

#### Powershell cmdlet body

Description: This primitive specifies the components that make up the body of a powershell cmdlet.

Here is a complete BNF for the body of a PowerShell cmdlet, built directly from the official PowerShell Language Specification grammar.[28]
The Cmdlet Function Wrapper

```bnf
<function-statement>     ::= "function" <ws> <function-name> <ws>
                             <function-parameter-declaration>? <ws>
                             "{" <script-block> "}"

<function-name>          ::= <cmdlet-name>
<cmdlet-name>            ::= <verb> "-" <noun>

Script Block (The { } Body)
<script-block>           ::= <param-block>? <statement-terminators>?
                             <script-block-body>?

<script-block-body>      ::= <named-block-list>
                           | <statement-list>
```

The two alternatives mean: either you use named blocks (begin/process/end) OR you write bare statements — but not both.[28]
Named Block List (Begin / Process / End)

```bnf
<named-block-list>       ::= <named-block>
                           | <named-block-list> <named-block>

<named-block>            ::= <block-name> <statement-block> <statement-terminators>?

<block-name>             ::= "dynamicparam"
                           | "begin"
                           | "process"
                           | "end"

<statement-block>        ::= <new-lines>? "{" <statement-list>? <new-lines>? "}"
```

All four named blocks are optional and can appear in any order, though the conventional order is dynamicparam → begin → process → end.[28]
Param Block

```bnf
<param-block>            ::= <new-lines>? <attribute-list>? <new-lines>?
                             "param" <new-lines>?
                             "(" <parameter-list>? <new-lines>? ")"

<parameter-list>         ::= <script-parameter>
                           | <parameter-list> <new-lines>? "," <script-parameter>

<script-parameter>       ::= <new-lines>? <attribute-list>? <new-lines>?
                             <variable> <script-parameter-default>?

<script-parameter-default> ::= <new-lines>? "=" <new-lines>? <expression>

<attribute-list>         ::= <attribute>
                           | <attribute-list> <new-lines>? <attribute>

<attribute>              ::= "[" <new-lines>? <attribute-name>
                             "(" <attribute-arguments> <new-lines>? ")"
                             <new-lines>? "]"
                           | <type-literal>
```

Statement List (Inside Each Block)

```bnf
<statement-list>         ::= <statement>
                           | <statement-list> <statement>

<statement>              ::= <if-statement>
                           | <label>? <labeled-statement>
                           | <function-statement>
                           | <flow-control-statement> <statement-terminator>
                           | <trap-statement>
                           | <try-statement>
                           | <pipeline> <statement-terminator>

<statement-terminator>   ::= ";"
                           | <new-line-character>

<flow-control-statement> ::= "return" <pipeline>?
                           | "break"  <label-expression>?
                           | "continue" <label-expression>?
                           | "throw" <pipeline>?
                           | "exit"  <pipeline>?
```

Full Cmdlet Example Derivation

```text
function Get-Greeting {         ← <function-statement>
    param (                     ← <param-block>
        [string]$Name           ←   <script-parameter> with <type-literal>
    )
    begin {                     ← <named-block>  (block-name = "begin")
        $msg = "Hello"          ←   <pipeline> <statement-terminator>
    }
    process {                   ← <named-block>  (block-name = "process")
        Write-Output "$msg, $Name"  ← <pipeline> <statement-terminator>
    }
    end {                       ← <named-block>  (block-name = "end")
        Write-Output "Done"     ←   <pipeline> <statement-terminator>
    }
}
```

The key structural rule is:

```text
<script-block-body>  →  <named-block-list>
<named-block-list>   →  <named-block> <named-block> <named-block>
                     →  "begin" <statement-block>
                        "process" <statement-block>
                        "end" <statement-block>

Each <statement-block> ultimately reduces to { <statement-list> }, where statements are pipelines, control flow, or nested function definitions.[28]
```

Attribution:

```text
1. https://learn.microsoft.com/en-us/powershell/scripting/lang-spec/chapter-15?view=powershell-7.5
2. https://cs61.seas.harvard.edu/site/2021/BNFGrammars/
3. https://www2.cs.sfu.ca/CourseCentral/383/tjd/ebnf_intro_in_go.html
4. https://help.qlik.com/en-US/sense/November2025/Subsystems/Hub/Content/Sense_Hub/Scripting/Backus-Naur-formalism.htm
5. https://stackoverflow.com/questions/51773245/is-there-a-language-specification-document-for-powershell-5-or-later
6. https://en.wikipedia.org/wiki/Extended_Backus–Naur_form
7. https://www.freecodecamp.org/news/what-are-bnf-and-ebnf/
8. https://forums.powershell.org/t/backus-naur-form-bnf/5148
9. https://docs.microsoft.com/he-il/cpp/atl/understanding-backus-naur-form-bnf-syntax?view=msvc-150
10. https://www.ibm.com/docs/SSZJPZ_11.3.0/com.ibm.swg.im.iis.conn.msole.doc/topics/r_cmsftref_Backus_Naur_Form_BNF_Notation.html
11. https://stackoverflow.com/questions/33221132/backus-naur-form-bnf-recursion
12. https://moleseyhill.com/2010-05-05-backus-naur-form.html
13. https://bnfc.digitalgrammars.com/LBNF-report.pdf
14. https://learn.microsoft.com/en-us/previous-versions/windows/desktop/indexsrv/description-of-the-ebnf-notation
15. https://learn.microsoft.com/en-us/powershell/scripting/lang-spec/chapter-15?view=powershell-7.5
```

### `<script-file>` Rule Primitive

Description: This primitive represents the top-level container for a PowerShell `.ps1` file. A script file is a sequence of zero or more top-level elements, where each element is a region-block, a comment-line, a function-statement, or a bare statement.

```bnf
<script-file>        ::= <script-file-element-list>?

<script-file-element-list> ::= <script-file-element>
                             | <script-file-element-list> <new-lines>? <script-file-element>

<script-file-element> ::= <region-block>
                         | <comment-line>
                         | <function-statement>
                         | <pipeline> <statement-terminator>
```

Body: A text block that is the entire rendered content of the `.ps1` file, assembled from its constituent elements in order.

Inputs: An ordered list of `<script-file-element>` instances.

Output: The rendered `.ps1` file text.

Processing: Each element is rendered in sequence, separated by newlines, and written to the output file path.

### `<region-block>` Rule Primitive

Description: This primitive represents a PowerShell region comment block — a VS Code / PowerShell ISE collapsible section delimited by `#region` and `#endregion` markers. The optional region-label appears on the same line as `#region`.

```bnf
<region-block>       ::= "#region" <region-label>? <new-line-character>
                         <region-body>?
                         "#endregion" <new-line-character>?

<region-label>       ::= <ws> <comment-text>

<region-body>        ::= <region-body-line>
                       | <region-body> <region-body-line>

<region-body-line>   ::= <comment-line>
                       | <pipeline> <statement-terminator>
                       | <region-block>
                       | <new-line-character>
```

Body: A text block consisting of the `#region` header line, zero or more body lines, and the `#endregion` footer line.

Inputs:

- `RegionLabel` (string, optional) — text placed after `#region` on the opening line.
- `RegionBody` (ordered list of `<region-body-line>` instances, optional) — the content inside the region.

Output: The rendered region block text.

Processing: The primitive writes `#region` (plus label if present), then each body line, then `#endregion`.

### `<comment-line>` Rule Primitive

Description: This primitive represents a single-line PowerShell comment, beginning with `#` and extending to the end of the line.

```bnf
<comment-line>       ::= "#" <comment-text>? <new-line-character>

<comment-text>       ::= <comment-char>
                       | <comment-text> <comment-char>

<comment-char>       ::= any character except <new-line-character>
```

Body: A single text line of the form `# <text>`.

Inputs:

- `CommentText` (string, optional) — the text following the `#` character. May be empty, producing a bare `#` line.

Output: The rendered comment line.

Processing: The primitive writes `#` followed optionally by a space and `CommentText`, then a newline.

### `<function-statement>` Rule Primitive

Description: This primitive represents the `function` keyword declaration that defines a named script-level function. This is the _definition_ form, distinct from a cmdlet _invocation_. The function-name may be either a verb-noun `<cmdlet-name>` or a plain `<identifier>`.

```bnf
<function-statement> ::= "function" <ws> <function-name> <ws>?
                         <function-parameter-declaration>?
                         "{" <new-lines>? <script-block> <new-lines>? "}"

<function-name>      ::= <cmdlet-name>
                       | <identifier>

<function-parameter-declaration> ::= "(" <parameter-list>? ")"
```

The `<function-parameter-declaration>` is the inline form that may optionally appear between the function name and the opening brace. This is distinct from the `<param-block>` that may appear _inside_ the script block body.

Body: The complete `function <name> { ... }` text block.

Inputs:

- `FunctionName` (string) — the name of the function.
- `FollowsVerbNounConvention` (bool) — whether the name conforms to the PowerShell Approved Verb convention.
- `FunctionParameterDeclaration` (string, optional) — inline parameter list, if used instead of an internal `param` block.
- `ScriptBlock` (a `<script-block>` instance) — the body.

Output: The rendered function statement text.

Processing: The primitive writes `function <name>`, optionally the inline parameter declaration, then `{`, the rendered script block, then `}`.

### `<identifier>` Rule Primitive

Description: This primitive represents a plain PowerShell identifier — a sequence of letters, digits, and underscores starting with a letter or underscore. Unlike `<cmdlet-name>`, an identifier does not require the verb-hyphen-noun form.

```bnf
<identifier>         ::= <first-id-char> <id-chars>

<first-id-char>      ::= <letter> | "_"

<id-chars>           ::= ""
                       | <id-chars> <id-char>

<id-char>            ::= <letter> | <digit> | "_"
```

Body: A text token that is a valid PowerShell identifier.

Inputs:

- `Name` (string) — the identifier text; must match the grammar above.

Output: The identifier token as a string.

Processing: The primitive validates that `Name` matches `<identifier>` and returns the text.

### `<script-block>` Rule Primitive

Description: This primitive represents the `{ }` body of a function, scriptblock literal, or named block. It optionally contains a `<param-block>` followed by either a `<named-block-list>` (begin/process/end blocks) or a bare `<statement-list>`.

```bnf
<script-block>       ::= <param-block>? <new-lines>?
                         <script-block-body>?

<script-block-body>  ::= <named-block-list>
                       | <statement-list>
```

The two alternatives for `<script-block-body>` are mutually exclusive: a script block uses _either_ named blocks _or_ bare statements, never both.

Body: The rendered interior content of a `{ }` pair (excludes the braces themselves; the enclosing primitive supplies them).

Inputs:

- `ParamBlock` (a `<param-block>` instance, optional) — the parameter declaration inside the block.
- `BodyVariant` (enum: `NamedBlocks` | `BareStatements`) — which alternative to use.
- `NamedBlockList` (a `<named-block-list>` instance, optional) — required when `BodyVariant = NamedBlocks`.
- `StatementList` (a `<statement-list>` instance, optional) — required when `BodyVariant = BareStatements`.

Output: The rendered script block interior text.

Processing: The primitive renders the optional param block, then either the named-block-list or the statement-list according to `BodyVariant`.

### `<param-block>` Rule Primitive

Description: This primitive represents the `param ( ... )` construct that declares the parameters of a function or script. It may appear either inside a function's script-block body or at the top of a script file.

```bnf
<param-block>        ::= <new-lines>? <attribute-list>? <new-lines>?
                         "param" <new-lines>?
                         "(" <new-lines>? <parameter-list>? <new-lines>? ")"
```

Body: The complete `param ( <parameter-list> )` text.

Inputs:

- `AttributeList` (a `<attribute-list>` instance, optional) — attributes applied to the param block itself (e.g., `[CmdletBinding()]`).
- `ParameterList` (a `<parameter-list>` instance, optional) — the comma-separated list of declared parameters.
- `IndentLevel` (int, default 1) — the indentation level applied to the content.

Output: The rendered param block text.

Processing: The primitive writes `param (`, then each script-parameter indented one level, then `)`.

### `<parameter-list>` Rule Primitive

Description: This primitive represents a comma-separated list of `<script-parameter>` declarations inside a `<param-block>`.

```bnf
<parameter-list>     ::= <script-parameter>
                       | <parameter-list> <new-lines>? "," <new-lines>? <script-parameter>
```

Body: The comma-separated sequence of rendered `<script-parameter>` instances.

Inputs:

- `Parameters` (ordered list of `<script-parameter>` instances) — one or more parameter declarations.
- `TrailingComma` (bool, default false) — whether to add a trailing comma after the last parameter (not standard PowerShell, but supported in some linters as a style preference).

Output: The rendered parameter list text.

Processing: Each `<script-parameter>` is rendered in sequence; commas separate consecutive entries. Each parameter appears on its own indented line.

### `<script-parameter>` Rule Primitive

Description: This primitive represents a single parameter declaration within a `<param-block>`. It consists of an optional attribute list (including optional type literal), the parameter variable, and an optional default-value expression.

```bnf
<script-parameter>         ::= <new-lines>? <attribute-list>? <new-lines>?
                               <variable> <script-parameter-default>?

<script-parameter-default> ::= <new-lines>? "=" <new-lines>? <expression>
```

Body: The rendered parameter declaration line, such as `[string] $path` or `[Parameter(Mandatory)] [string] $path = 'default'`.

Inputs:

- `AttributeList` (a `<attribute-list>` instance, optional) — includes the optional type literal and any `[Parameter(...)]` attributes.
- `VariableName` (string) — the parameter name, without the leading `$`.
- `DefaultValue` (string expression, optional) — the default value expression.

Output: The rendered script-parameter text.

Processing: The primitive renders the attribute list (if any) followed by a space, `$<VariableName>`, and optionally ` = <DefaultValue>`.

### `<type-literal>` Rule Primitive

Description: This primitive represents a PowerShell type-constraint annotation in the form `[<type-name>]`. When used as the sole element of an `<attribute-list>` on a parameter, it constrains the parameter to that type.

```bnf
<type-literal>       ::= "[" <type-name> "]"

<type-name>          ::= <type-identifier>
                       | <type-name> "." <type-identifier>
                       | <type-name> "[]"
                       | <type-name> "[" <decimal-digits> "]"

<type-identifier>    ::= <identifier>
```

Common built-in type names: `string`, `int`, `bool`, `double`, `datetime`, `object`, `hashtable`, `array`, `scriptblock`, `PSCustomObject`.

Body: The `[<type-name>]` token.

Inputs:

- `TypeName` (string) — the fully-qualified or short name of the .NET type.

Output: The rendered type-literal token, e.g., `[string]`.

Processing: The primitive validates `TypeName` is a legal identifier chain and writes `[<TypeName>]`.

### `<statement-list>` Rule Primitive

Description: This primitive represents a sequence of one or more statements in the body of a script block (bare-statements variant), a named block, or a script file.

```bnf
<statement-list>     ::= <statement>
                       | <statement-list> <statement>

<statement>          ::= <if-statement>
                       | <label>? <labeled-statement>
                       | <function-statement>
                       | <flow-control-statement> <statement-terminator>
                       | <trap-statement>
                       | <try-statement>
                       | <pipeline> <statement-terminator>
```

Body: The sequence of rendered statement texts, each followed by a statement terminator.

Inputs:

- `Statements` (ordered list of `<statement>` instances) — the statements to render.
- `IndentLevel` (int, default 1) — the indentation level applied to each statement.

Output: The rendered statement list text.

Processing: Each statement is rendered in order, indented to `IndentLevel`, and followed by a newline.

### `<pipeline-statement>` Rule Primitive

Description: This primitive represents the most common form of statement: a `<pipeline>` followed by a statement terminator. Within a bare-statements script-block body or a named block, most executable lines are pipeline statements.

```bnf
<pipeline-statement> ::= <pipeline> <statement-terminator>

<pipeline>           ::= <cmdlet-invocation>
                       | <cmdlet-invocation> "|" <pipeline>

<statement-terminator> ::= ";"
                          | <new-line-character>
```

Body: A single rendered pipeline expression, e.g., `Write-Output $path`, terminated by newline or semicolon.

Inputs:

- `Pipeline` (one or more `<cmdlet-invocation>` instances joined by `|`) — the pipeline to render.
- `Terminator` (enum: `Newline` | `Semicolon`, default `Newline`) — the statement terminator style.

Output: The rendered pipeline statement text.

Processing: Each `<cmdlet-invocation>` in the pipeline is rendered left to right, joined by `|`. The terminator is appended.

### `<block-comment>` Rule Primitive

Description: This primitive represents a PowerShell block comment delimited by `<#` and `#>`. Block comments may span multiple lines and are used for both inline commentary and comment-based help.

```bnf
<block-comment>      ::= "<#" <block-comment-body> "#>"

<block-comment-body> ::= <block-comment-char>*
                       | <block-comment-body> <new-line-character>

<block-comment-char> ::= any character except the sequence "#>"
```

Body: The full `<# ... #>` text, including interior newlines.

Inputs:

- `CommentBody` (string) — the raw interior text. May be empty.

Output: The rendered block-comment text.

Processing: The primitive writes `<#`, then `CommentBody`, then `#>`.

### `<comment-based-help-block>` Rule Primitive

Description: This primitive represents a PowerShell comment-based help block — a `<# ... #>` block whose body is structured with `.KEYWORD` sections recognized by `Get-Help`. It must appear at the start of a function body or at the top of a script file.

```bnf
<comment-based-help-block> ::= "<#" <new-line-character>
                               <help-section>+
                               "#>"

<help-section>       ::= "." <help-keyword> <new-line-character>
                         <help-section-body>

<help-keyword>       ::= "SYNOPSIS" | "DESCRIPTION" | "PARAMETER" <ws> <identifier>
                       | "OUTPUTS" | "EXAMPLE" | "NOTES" | "LINK"
                       | "INPUTS" | "COMPONENT" | "ROLE" | "FUNCTIONALITY"

<help-section-body>  ::= <help-line>*

<help-line>          ::= <comment-char>* <new-line-character>
```

Body: A structured block comment whose keywords are rendered in order.

Inputs:

- `Synopsis` (string) — text for `.SYNOPSIS`.
- `Description` (string) — text for `.DESCRIPTION`.
- `Parameters` (list of `{Name, Text}`) — one `.PARAMETER <name>` entry per parameter.
- `Outputs` (string) — text for `.OUTPUTS`.
- `Examples` (list of strings) — one `.EXAMPLE` entry per example.
- `Notes` (string, optional) — text for `.NOTES`.
- `Links` (list of strings, optional) — one `.LINK` entry per URL.

Output: The rendered comment-based help block.

Processing: Each keyword and its body are written in declaration order, separated by blank lines.

### `<cmdlet-binding-attribute>` Rule Primitive

Description: This primitive represents the `[CmdletBinding(...)]` attribute declared on the `<param-block>` (or as part of the `<attribute-list>` for the function). It promotes a function to an advanced function and enables `$PSCmdlet`, `ShouldProcess`, `ShouldContinue`, and common parameters.

```bnf
<cmdlet-binding-attribute> ::= "[CmdletBinding(" <cmdlet-binding-arg-list>? ")]"

<cmdlet-binding-arg-list>  ::= <cmdlet-binding-arg>
                             | <cmdlet-binding-arg-list> "," <ws>? <cmdlet-binding-arg>

<cmdlet-binding-arg>       ::= "SupportsShouldProcess" <ws>? "=" <ws>? <bool-literal>
                             | "DefaultParameterSetName" <ws>? "=" <ws>? <string-literal>
                             | "ConfirmImpact" <ws>? "=" <ws>? <string-literal>
                             | "HelpUri" <ws>? "=" <ws>? <string-literal>
                             | "PositionalBinding" <ws>? "=" <ws>? <bool-literal>
                             | "SupportsPaging" <ws>? "=" <ws>? <bool-literal>

<bool-literal>             ::= "$true" | "$false"
```

Body: The `[CmdletBinding(...)]` token line.

Inputs:

- `SupportsShouldProcess` (bool, default `$false`).
- `DefaultParameterSetName` (string, optional).
- `ConfirmImpact` (string, optional; one of `None`, `Low`, `Medium`, `High`).

Output: The rendered `[CmdletBinding(...)]` attribute text.

Processing: The primitive writes `[CmdletBinding(` then each non-default argument as `Key = $value`, separated by `, `, then `)]`.

### `<suppress-message-attribute>` Rule Primitive

Description: This primitive represents a `[Diagnostics.CodeAnalysis.SuppressMessageAttribute(...)]` decoration applied to a function or param block to suppress specific PSScriptAnalyzer or FxCop rules.

```bnf
<suppress-message-attribute> ::= "[Diagnostics.CodeAnalysis.SuppressMessageAttribute("
                                 <string-literal> "," <ws>? <string-literal>
                                 ("," <ws>? "Justification" <ws>? "=" <ws>? <string-literal>)?
                                 ")]"
```

Body: The full `[Diagnostics.CodeAnalysis.SuppressMessageAttribute(...)]` line.

Inputs:

- `Category` (string) — the rule category string, e.g., `'PSAvoidUsingPlainTextForPassword'`.
- `CheckId` (string) — the parameter name or rule ID being suppressed, e.g., `'CredentialsKey'`.
- `Justification` (string, optional) — human-readable reason for the suppression.

Output: The rendered suppression attribute line.

Processing: The primitive writes the attribute, inserting `Justification = '...'` when provided.

### `<parameter-attribute>` Rule Primitive

Description: This primitive represents a `[Parameter(...)]` attribute applied to a `<script-parameter>`. It controls the parameter's binding behavior: whether it is mandatory, its position, whether it accepts pipeline input, and which parameter set(s) it belongs to.

```bnf
<parameter-attribute>  ::= "[Parameter(" <parameter-arg-list>? ")]"

<parameter-arg-list>   ::= <parameter-arg>
                         | <parameter-arg-list> "," <ws>? <parameter-arg>

<parameter-arg>        ::= "Mandatory" <ws>? "=" <ws>? <bool-literal>
                         | "Position" <ws>? "=" <ws>? <decimal-digits>
                         | "ValueFromPipeline" <ws>? "=" <ws>? <bool-literal>
                         | "ValueFromPipelineByPropertyName" <ws>? "=" <ws>? <bool-literal>
                         | "ValueFromRemainingArguments" <ws>? "=" <ws>? <bool-literal>
                         | "ParameterSetName" <ws>? "=" <ws>? <string-literal>
                         | "HelpMessage" <ws>? "=" <ws>? <string-literal>
```

Body: One `[Parameter(...)]` attribute line per parameter-set membership. A single `<script-parameter>` may carry multiple `[Parameter(...)]` attributes — one per parameter set it belongs to.

Inputs:

- `Mandatory` (bool, default `$false`).
- `Position` (int, optional).
- `ValueFromPipeline` (bool, default `$false`).
- `ValueFromPipelineByPropertyName` (bool, default `$false`).
- `ParameterSetName` (string, optional).

Output: One or more `[Parameter(...)]` attribute lines.

Processing: One attribute line is rendered for each unique combination of parameter-set membership and binding settings.

### `<validate-attribute>` Rule Primitive

Description: This primitive represents one of the built-in PowerShell validation attributes applied to a `<script-parameter>`. Common members include `ValidateNotNullOrEmpty`, `ValidateNotNull`, `ValidateSet`, `ValidateRange`, `ValidatePattern`, and `ValidateScript`.

```bnf
<validate-attribute>   ::= "[ValidateNotNullOrEmpty()]"
                         | "[ValidateNotNull()]"
                         | "[ValidateSet(" <string-literal-list> ")]"
                         | "[ValidateRange(" <literal> "," <ws>? <literal> ")]"
                         | "[ValidatePattern(" <string-literal> ")]"
                         | "[ValidateScript({" <script-block-body> "})]"

<string-literal-list>  ::= <string-literal>
                         | <string-literal-list> "," <ws>? <string-literal>
```

Body: The rendered validation attribute line.

Inputs:

- `ValidatorKind` (enum: `NotNullOrEmpty` | `NotNull` | `Set` | `Range` | `Pattern` | `Script`).
- `Values` (list of strings — for `Set`) | `Min,Max` (for `Range`) | `Pattern` (string for `Pattern`) | `ScriptBody` (string for `Script`).

Output: The rendered `[Validate...]` attribute.

Processing: The primitive selects the appropriate attribute form from `ValidatorKind` and renders the values.

### `<alias-attribute>` Rule Primitive

Description: This primitive represents the `[Alias(...)]` attribute on a `<script-parameter>`, which declares one or more alternative names by which the parameter can be addressed.

```bnf
<alias-attribute>      ::= "[Alias(" <string-literal-list> ")]"
```

Body: The `[Alias('name1', 'name2')]` attribute line.

Inputs:

- `AliasNames` (list of strings, one or more) — the alternate parameter names.

Output: The rendered `[Alias(...)]` attribute line.

Processing: The primitive writes `[Alias(` then each alias as a quoted string separated by `, `, then `)]`.

### `<assignment-statement>` Rule Primitive

Description: This primitive represents a simple or compound assignment statement: `$variable = <expression>` or an augmented form such as `$variable += <expression>`. It also covers member assignments (`$obj.Property = value`) and environment variable assignments (`$env:VAR = value`).

```bnf
<assignment-statement> ::= <assignable-expression> <ws>? <assignment-operator> <ws>? <expression>
                           <statement-terminator>

<assignable-expression> ::= <variable>
                           | <member-access>      /* $obj.Prop */
                           | <index-access>       /* $arr[$i] */
                           | <env-variable>       /* $env:NAME */

<env-variable>         ::= "$env:" <identifier>

<assignment-operator>  ::= "=" | "+="  | "-=" | "*=" | "/=" | "%="
```

Body: One assignment line, e.g., `$fn = 'Build-DatabaseWithFlyway'`.

Inputs:

- `Lhs` (string) — the left-hand side expression text.
- `Operator` (string, default `=`).
- `Rhs` (string) — the right-hand side expression text.
- `IndentLevel` (int, default 1).

Output: The rendered assignment statement.

Processing: Writes `<LHS> <OP> <RHS>` at the given indent level, terminated by newline.

### `<hashtable-literal>` Rule Primitive

Description: This primitive represents a PowerShell hashtable literal `@{ key = value; ... }`. When used for splatting parameters it is typically named (`$params = @{...}` then `Cmdlet @params`) or passed inline.

```bnf
<hashtable-literal>    ::= "@{" <new-lines>? <hashtable-body>? <new-lines>? "}"

<hashtable-body>       ::= <hashtable-entry>
                         | <hashtable-body> <new-lines>? <hashtable-entry>

<hashtable-entry>      ::= <hashtable-key> <ws>? "=" <ws>? <expression> <statement-terminator>?

<hashtable-key>        ::= <identifier>
                         | <string-literal>
```

Body: The `@{ ... }` block text, with each key-value pair on its own indented line.

Inputs:

- `Entries` (ordered list of `{Key: string, Value: string}`) — the key-value pairs.
- `IndentLevel` (int, default 1) — indentation of the entries.
- `InlineStyle` (bool, default `$false`) — render on one line with `;` separators instead of newlines.

Output: The rendered hashtable literal text.

Processing: Each entry is rendered as `Key = Value` indented one level inside the braces. Multi-line style uses newlines; inline style uses `;` separators.

### `<PSCustomObject-literal>` Rule Primitive

Description: This primitive represents the cast-hashtable form of a `PSCustomObject` creation: `[PSCustomObject]@{ ... }`. It is the canonical way to create a typed custom object without `New-Object`.

```bnf
<PSCustomObject-literal> ::= "[PSCustomObject]" <hashtable-literal>
```

Body: `[PSCustomObject]@{ ... }` with entries rendered using `<hashtable-literal>`.

Inputs:

- `Entries` (ordered list of `{Key: string, Value: string}`) — the property-name/value pairs.
- All `<hashtable-literal>` inputs apply.

Output: The rendered `[PSCustomObject]@{...}` expression text.

Processing: Prepends `[PSCustomObject]` to the rendered `<hashtable-literal>`.

### `<dot-source-statement>` Rule Primitive

Description: This primitive represents a dot-sourcing statement `. 'path\to\script.ps1'` that loads and executes a script file into the current scope, making its functions and variables available to the caller.

```bnf
<dot-source-statement> ::= "." <ws> <source-path> <statement-terminator>

<source-path>          ::= <string-literal>
                         | <variable>
                         | <subexpression>
```

Body: The `. 'path'` statement line.

Inputs:

- `SourcePath` (string expression) — the path expression to the script being dot-sourced. May be a string literal, variable, or subexpression.
- `IndentLevel` (int, default 2).

Output: The rendered dot-source statement.

Processing: Writes `. ` followed by the path expression at the given indent level, terminated by newline.

### `<module-load-guard>` Rule Primitive

Description: This primitive encapsulates the idiomatic PowerShell pattern for conditionally loading a function or module only if it is not yet available in the current session. It composes an `<if-statement>` whose condition tests for the absence of a command, and whose body is either a `<dot-source-statement>` or an `Install-Module` / `Import-Module` pipeline.

```bnf
<module-load-guard>    ::= <if-statement>

/* Specialized instantiation: */
/* if (-not (Get-Command -Name '<name>' -CommandType Function -ErrorAction SilentlyContinue)) { */
/*   . '<path>'  (or  Import-Module '<name>' -ErrorAction Stop) */
/* } */
```

Body: An `if (-not (Get-Command ...)) { . '...' }` block.

Inputs:

- `GuardKind` (enum: `Function` | `Module`) — whether guarding a function (dot-source) or a module (Import-Module).
- `CommandName` (string) — the name passed to `Get-Command -Name`.
- `SourcePath` (string, used when `GuardKind = Function`) — path to dot-source.
- `ModuleName` (string, used when `GuardKind = Module`) — module name for `Install-Module` / `Import-Module`.
- `InstallIfMissing` (bool, default `$false`) — add an `Install-Module` call before importing.
- `ErrorAction` (string, default `Stop`) — value passed to the load statement.

Output: The rendered conditional-load block.

Processing: Renders an `if` whose condition is `(-not (Get-Command -Name '<CommandName>' ...))` and whose body is the load statement appropriate to `GuardKind`.

### `<try-catch-finally-statement>` Rule Primitive

Description: This primitive represents a PowerShell structured error-handling block: `try { } catch [<type>] { } finally { }`. The catch clause type filter and the finally clause are both optional. Catch blocks can be stacked.

```bnf
<try-catch-finally-statement> ::= "try" <statement-block>
                                  <catch-clause>*
                                  <finally-clause>?

<catch-clause>         ::= "catch" <ws>? <catch-type-list>? <statement-block>

<catch-type-list>      ::= "[" <type-name> "]"
                         | <catch-type-list> "," <ws>? "[" <type-name> "]"

<finally-clause>       ::= "finally" <statement-block>
```

Body: The complete `try { } catch { } finally { }` structure.

Inputs:

- `TryBody` (a `<statement-list>`) — statements in the `try` block.
- `CatchClauses` (ordered list of `{TypeFilter: string | null, Body: <statement-list>}`) — one entry per catch block; `TypeFilter` is `null` for bare `catch`.
- `FinallyBody` (`<statement-list>`, optional) — statements in the `finally` block.
- `IndentLevel` (int, default 1).

Output: The rendered try-catch-finally block.

Processing: Renders `try { <TryBody> }`, then each catch clause, then optionally `finally { <FinallyBody> }`.

### `<if-else-statement>` Rule Primitive

Description: This primitive represents a PowerShell conditional: `if (<condition>) { } elseif (<condition>) { } else { }`. Both `elseif` and `else` clauses are optional and may be repeated / omitted freely.

```bnf
<if-statement>         ::= "if" <ws>? "(" <pipeline> ")" <statement-block>
                           <elseif-clause>*
                           <else-clause>?

<elseif-clause>        ::= "elseif" <ws>? "(" <pipeline> ")" <statement-block>

<else-clause>          ::= "else" <statement-block>
```

Body: The complete `if / elseif / else` structure.

Inputs:

- `IfCondition` (string expression) — the condition for the `if` branch.
- `IfBody` (a `<statement-list>`) — body of the `if` branch.
- `ElseIfClauses` (ordered list of `{Condition: string, Body: <statement-list>}`, optional).
- `ElseBody` (`<statement-list>`, optional) — body of the `else` branch.
- `IndentLevel` (int, default 1).

Output: The rendered conditional block.

Processing: Renders the `if` branch, then each `elseif` clause in order, then the optional `else` clause.

### `<splat-invocation>` Rule Primitive

Description: This primitive represents a cmdlet invocation that uses PowerShell splatting — passing a named hashtable variable as the argument list using the `@` sigil. Splatting is the canonical style for calls with many parameters.

```bnf
<splat-invocation>     ::= <cmdlet-name> <ws> "@" <variable-name> <statement-terminator>
```

Body: A line of the form `Invoke-Foo @params`.

Inputs:

- `CmdletName` (string) — the cmdlet being invoked.
- `SplatVariableName` (string) — the name of the hashtable variable (without `$` or `@` prefix; the `@` sigil is rendered by this primitive).
- `AdditionalArgs` (list of `<named-parameter>` or `<switch-parameter>`, optional) — any additional arguments passed directly alongside the splat.
- `IndentLevel` (int, default 2).

Output: The rendered splatted invocation line.

Processing: Writes `<CmdletName> @<SplatVariableName>` at the given indent level, appending any `AdditionalArgs` before the terminator.

### Complete SQL script

Description: This primitive holds an entire SQL script

Body: A text block that contains a complete SQL script

Inputs: The script's parameters are the primitives inputs.

Output: The script's outputs are the primitives outputs.

Processing: The primitive is invoked in a SQLServer context

TBD - a large set of Rule Primitives will be defined

## A single Rule definition in Backus–Naur Form (BNF)

TBD - express how the Rule Primitives can be legitimately combined.

## How Rules can be combined into Rule Sets

A Rule Set has a defined set of inputs, and a defined set of outputs. It may also cause the executing process to perform actions.

## How an instantiation processes inputs

An instantiation is a specific instance of a Build Set, itself made of Rule Sets, so the instantiation has a defined set of inputs to which it can react. Every Rule Set can be modeled as a state diagram. State Machine theory states that a system composed of multiple State Machines is itself a State Machine. The Build Set defines all of the Rule Sets and Rules, and so from a given starting state (the Initial State), the automata can execute through the directed graph of Rules, and eventually reach a final state with new output values. From this final state, changes to the inputs will again trigger execution through the directed graph of Rules, until a new final state is reached. This process repeats every time an input changes.

## Built-in Rules and reference Rule Sets, reference Build Sets, and reference instantiation

for the purpose of this paragraph 'reference' is used in the same fashion that manufactors of a computer chip will create a circuit board using that chip, and call the board a 'reference implementation'. Similarly, the following paragraph mentions 'reference Rule Sets' and 'reference Build Sets'. These are the reference implementations of a Rule Set that implements a module or feature, and a Build Set that creates a complete frontend and backend system.

ATAP.Utilities and Ace Commander have an enormous set of pre-defined Rules. From these, a large number of reference Rule Sets have been pre-defined. The reference Build Set for ATAP.Utilities creates the ATAP.Utilities libraries and databases, and the reference Build Set for Ace Commander assembles the Built-in and custom Rule Sets to create the reference implementation of Ace Commander.

## Custom rules and Rule Sets

All owners / users of Ace Commander can contribute to the ecosystem of bolt-on modules for Ace Commander. These bolt-ons are defined by a Rule Set. A uniquely new Rule Set can be created to form a completely new module. Or, an existing module can be functionally or performance enhanced by expanding on the Rules in its Rule Set. As long as a new Rule Set has a superset of the original Rule Set's inputs, and has the same or a superset of the originals' outputs, the new Rule Set can replace the original Rule Set and be used to create a new version of the original Build Set (one in which the original Rule Set has been replaced by the new Rule Set).

## Feature / Module / Rule Set

This section is where the nomenclature and taxonomy of the ATAP.Utilities and Ace Commander are specified, and the individual Rules that make up each Rule Set are referenced.

During the design phase of this project, this document will serve as the 'source of truth' for the nomenclature and taxonomy of the ATAP.Utilities and Ace Commander Rule Sets and this feature / module tagging. As the program / project evolves, the actual Rules and Rule Sets stored in the Ace Commander databases will slowly take over the 'source of truth' , and this document will be updated by Ace Commander to keep it in sync with the databases contents. MOdules and Rule Sets can be hierarchal decomposed into smaller functional units. The Module defintions in the following sections will demonstrate this by listing submodules under 'higher' modules.

### Ace Commander browser-based User Interface

This Rule Set will create the browser-based user interface to the Ace Commander program. Much of this Rule Set will be modules that define the visual look and feel of the application. Other modules will define how the application is instantiated for various browsers. Another set of modules will define how Ace Commander front-end communicates to the backend systems.

#### Ace Commander - A Blazor Web App using Auto render mode

This Rule Set defines the overall technology being used for the Ace Commander browser-based User Interface. This will incorporate the DotNet project template for "Blazor Web App" in the repository. Ace Commander will use the InteractiveAuto mode.

The repository will contain two projects

```text
AceCommander/                    ← Server project (ASP.NET Core host)
├── Components/
├── Program.cs
└── AceCommander.csproj

AceCommander.Client/             ← Client project (runs in browser via WASM)
├── Pages/
├── Program.cs
└── AceCommander.Client.csproj
```

### AI coding agents instruction files

This Rule Set defines how AI coding assistant instructions are organized and shared between GitHub Copilot and Claude Code within a repository, maintaining a single source of truth while supporting each tool's native file structure.

#### Rule: Central Global Instructions File

**Purpose:** Establish a single source of truth for project-wide AI instructions.

**Implementation:** Maintain `.github/copilot-instructions.md` as the authoritative file containing global repository instructions. This file is read natively by GitHub Copilot and will be referenced by Claude Code through import directives.

#### Rule: Claude Root Instructions Import

**Purpose:** Enable Claude Code to read global instructions without duplicating content.

**Implementation:** Create a file named `CLAUDE.md` (uppercase) in the repository root containing a single import directive: `@.github/copilot-instructions.md`. This approach prevents VS Code from injecting the same content twice (once from Copilot's native read, once from Claude's read) while allowing both tools to access the same instructions.

#### Rule: Language-Specific Instructions Directory

**Purpose:** Centralize language-specific coding rules and conventions.

**Implementation:** Store language-specific instruction files in `.github/instructions/` directory using the naming pattern `<language>.instructions.md` (e.g., `python.instructions.md`, `typescript.instructions.md`, `CSharp.instructions.md`). These files use GitHub Copilot's `applyTo` frontmatter field to specify file patterns.

#### Rule: Claude Rules Directory Structure

**Purpose:** Provide Claude Code with its native directory for language-specific rules.

**Implementation:** Create a `.claude/rules/` directory in the repository root. This directory will contain rule files that reference the language-specific instructions from `.github/instructions/`.

#### Rule: Language Rule Import Pattern

**Purpose:** Share language-specific instruction content between Copilot and Claude Code without duplication.

**Implementation:** For each language instruction file in `.github/instructions/`, create a corresponding file in `.claude/rules/` with:

- Filename: `<language>.md` (e.g., `python.md`, `typescript.md`)
- Frontmatter: `paths: ["**/*.<ext>"]` to specify which files the rule applies to
- Body: `@../../.github/instructions/<language>.instructions.md` to import the shared content

#### Rule: CLAUDE.md Naming Convention

**Purpose:** Ensure cross-platform compatibility for Claude Code instruction files.

**Implementation:** Use uppercase `CLAUDE.md` for the root instruction file. While Windows NTFS is case-insensitive, Linux filesystems (WSL2, containers) require exact case matching. Using uppercase consistently prevents issues across development environments.

#### Rule: Avoid Root Instruction Symlinks

**Purpose:** Prevent duplicate instruction injection in VS Code with both Copilot and Claude Code active.

**Implementation:** Do not create a symlink for `CLAUDE.md` pointing to `.github/copilot-instructions.md`. Instead, use the `@import` directive syntax. Symlinks cause VS Code to read the same content twice — once through Copilot's native path and once through Claude's, resulting in redundant context usage.

#### Rule: Frontmatter Format Differentiation

**Purpose:** Properly scope language-specific rules for each AI tool.

**Implementation:**

- GitHub Copilot files use: `applyTo: "**/*.py"`
- Claude Code files use: `paths: ["**/*.py"]`

When maintaining separate but related files, ensure each uses the appropriate frontmatter format. If symlinking instead of importing (not recommended), be aware that Claude Code will ignore `applyTo` fields and treat the rule as applying to all files.

#### Rule: Single Source Content Pattern

**Purpose:** Maintain one authoritative version of each instruction set.

**Implementation:** Each distinct instruction topic (global, per-language, per-framework) exists in exactly one file within `.github/`. All other AI tool-specific files (`CLAUDE.md`, `.claude/rules/*.md`) use import directives to reference this source, never duplicating the actual instruction content.

#### Rule: Local Override Exclusion

**Purpose:** Allow developers personal AI instruction customizations without committing them.

**Implementation:** Ensure `.gitignore` includes `CLAUDE.local.md` and `.claude/CLAUDE.local.md`. These files allow individual developers to add personal instructions that override or supplement project instructions without affecting other team members.

#### Example Repository Structure

```text
repo-root/
├── CLAUDE.md                           ← Contains: @.github/copilot-instructions.md
├── .gitignore                          ← Includes: CLAUDE.local.md
├── .github/
│   ├── copilot-instructions.md         ← Single source: global instructions
│   └── instructions/
│       ├── python.instructions.md      ← applyTo: "**/*.py"
│       ├── typescript.instructions.md  ← applyTo: "**/*.ts,**/*.tsx"
│       ├── CSharp.instructions.md      ← applyTo: "**/*.cs"
│       └── markdown.instructions.md    ← applyTo: "**/*.md"
└── .claude/
    └── rules/
        ├── python.md                   ← paths: ["**/*.py"], body: @../../.github/instructions/python.instructions.md
        ├── typescript.md               ← paths: ["**/*.ts","**/*.tsx"], body: @../../.github/instructions/typescript.instructions.md
        ├── CSharp.md                   ← paths: ["**/*.cs"], body: @../../.github/instructions/CSharp.instructions.md
        └── markdown.md                 ← paths: ["**/*.md"], body: @../../.github/instructions/markdown.instructions.md
```

### PowerShell Script Authoring Rules

This section defines Rules that govern how PowerShell `.ps1` script files are structured and generated. Each rule is composed from the BNF-level Rule Primitives defined in the Rule Primitives section.

#### Rule: Minimal PowerShell Function File

**Purpose:** Produce a `.ps1` file containing a single collapsible region block followed by a plain-identifier function that accepts one typed parameter and emits it with `Write-Output`.

This rule instantiates exactly the structure shown in `TestData1.ps1`:

```powershell
#region
# stuff
#endregion

function test {
  param (
    [string] $path
  )
  write-output $path
}
```

**Rule Primitives used (in composition order):**

| Step | Primitive                             | Instantiation details                                                                                                                                                      |
| ---- | ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | `<region-block>`                      | `RegionLabel` = _(empty)_; `RegionBody` = one `<comment-line>`                                                                                                             |
| 2    | `<comment-line>`                      | `CommentText` = `" stuff"` (space + word)                                                                                                                                  |
| 3    | `<function-statement>`                | `FunctionName` = `"test"`; `FollowsVerbNounConvention` = `false`; `ScriptBlock` = step 4                                                                                   |
| 4    | `<script-block>`                      | `ParamBlock` = step 5; `BodyVariant` = `BareStatements`; `StatementList` = step 8                                                                                          |
| 5    | `<param-block>`                       | `AttributeList` = _(none)_; `ParameterList` = step 6; `IndentLevel` = 1                                                                                                    |
| 6    | `<parameter-list>`                    | `Parameters` = [step 7]                                                                                                                                                    |
| 7    | `<script-parameter>`                  | `AttributeList` = one `<type-literal>` (`[string]`); `VariableName` = `"path"`; `DefaultValue` = _(none)_                                                                  |
| 8    | `<statement-list>`                    | `Statements` = [step 9]; `IndentLevel` = 1                                                                                                                                 |
| 9    | `<pipeline-statement>`                | `Pipeline` = one `<cmdlet-invocation>` (step 10); `Terminator` = `Newline`                                                                                                 |
| 10   | `<cmdlet-invocation>` in `<pipeline>` | `CmdletName` = `"write-output"` (lowercase; PowerShell is case-insensitive); `ArgumentList` = one `<positional-argument>` whose `<parameter-value>` = `<variable>` `$path` |

**Parse tree derivation for TestData1.ps1:**

```text
<script-file>
├── <region-block>
│   ├── "#region" <new-line>
│   ├── <region-body>
│   │   └── <comment-line>  →  "# stuff\n"
│   └── "#endregion" <new-line>
├── <new-lines>
└── <function-statement>
    ├── "function" <ws> <function-name>  →  "function test"
    └── "{" <script-block> "}"
        └── <script-block>
            ├── <param-block>
            │   ├── "param" "("
            │   ├── <parameter-list>
            │   │   └── <script-parameter>
            │   │       ├── <attribute-list>
            │   │       │   └── <type-literal>  →  "[string]"
            │   │       └── <variable>          →  "$path"
            │   └── ")"
            └── <script-block-body>  →  (BareStatements variant)
                └── <statement-list>
                    └── <pipeline-statement>
                        └── <pipeline>
                            └── <cmdlet-invocation>
                                ├── <cmdlet-name>  →  "write-output"
                                └── <argument-list>
                                    └── <positional-argument>
                                        └── <variable>  →  "$path"
```

**Inputs to the Rule:**

| Input                   | Value            |
| ----------------------- | ---------------- |
| `RegionLabel`           | _(empty string)_ |
| `RegionBodyComments`    | `["stuff"]`      |
| `FunctionName`          | `"test"`         |
| `ParameterTypeName`     | `"string"`       |
| `ParameterVariableName` | `"path"`         |
| `OutputCmdletName`      | `"write-output"` |
| `IndentStyle`           | 2 spaces         |

**Output:** A `.ps1` file whose rendered text matches `TestData1.ps1` exactly (modulo trailing newline).

**Constraints and notes:**

- `FunctionName` = `"test"` is a plain `<identifier>`, not a verb-noun `<cmdlet-name>`. The `FollowsVerbNounConvention` flag is `false`. A script-analyzer warning (`PSUseApprovedVerbs`) would fire in production use; this is intentional for test data.
- The function body uses the `BareStatements` variant of `<script-block-body>`, not named `begin`/`process`/`end` blocks.
- `write-output` is lowercase in the source; this is valid because PowerShell is case-insensitive for cmdlet names.
- The `<type-literal>` `[string]` is the sole element of the `<attribute-list>` on the `<script-parameter>`. No `[Parameter(...)]` attribute is present.
- The `<region-block>` has an empty `RegionLabel` (nothing after `#region` on the opening line).

### Database Management rules

This section defines rules for provisioning, migrating, and maintaining SQL Server databases in the ATAP.Utilities ecosystem.

#### Rule: Build-DatabaseWithFlyway

**Purpose:** Generate the complete `Build-DatabaseWithFlyway.ps1` cmdlet — a single parameterized entry point that drops and recreates a SQL Server database via `DatabaseProvisioning`, then applies all schema migrations via Flyway, for any supported environment.

**Source file:** `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Build-DatabaseWithFlyway.ps1`

**Top-level BNF derivation:**

```text
<script-file>
└── <function-statement>
    ├── <function-name>          → "Build-DatabaseWithFlyway"  (<cmdlet-name>: verb="Build", noun="DatabaseWithFlyway")
    └── "{" <script-block> "}"
        └── <script-block>  (BareStatements variant — all content in named blocks)
            └── <script-block-body>  →  <named-block-list>
                ├── <named-block>  block-name = "begin"   → BEGIN { ... }
                ├── <named-block>  block-name = "process" → PROCESS { ... }
                └── <named-block>  block-name = "end"     → END { ... }
```

The `<param-block>` is inside the function `<script-block>` body and precedes the named blocks.

---

**Primitive Composition Table**

| #   | Primitive                                                            | Role in the file                                                                                                                                                                                   | Instantiation details                                                                                                                                                |
| --- | -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `<function-statement>`                                               | Outer function wrapper                                                                                                                                                                             | `FunctionName` = `"Build-DatabaseWithFlyway"`; `FollowsVerbNounConvention` = `true`                                                                                  |
| 2   | `<comment-based-help-block>`                                         | `.SYNOPSIS` / `.DESCRIPTION` / `.PARAMETER` …/ `.EXAMPLE` / `.NOTES` / `.LINK` block immediately after `function` opening brace                                                                    | See help inputs table below                                                                                                                                          |
| 3   | `<cmdlet-binding-attribute>`                                         | `[CmdletBinding(...)]` on the `<param-block>`                                                                                                                                                      | `SupportsShouldProcess` = `$true`; `DefaultParameterSetName` = `'ConnectionParameters'`                                                                              |
| 4   | `<suppress-message-attribute>`                                       | `[Diagnostics.CodeAnalysis.SuppressMessageAttribute(...)]` on the `<param-block>`                                                                                                                  | `Category` = `'PSAvoidUsingPlainTextForPassword'`; `CheckId` = `'CredentialsKey'`; `Justification` = `'CredentialsKey is a vault lookup key name, not a credential'` |
| 5   | `<param-block>`                                                      | Declares all 18 parameters in two parameter sets                                                                                                                                                   | `AttributeList` = [primitive 3, primitive 4]; `ParameterList` = primitives 6–23                                                                                      |
| 6   | `<script-parameter>` × 2 (`DatabaseName`)                            | Mandatory string present in both parameter sets                                                                                                                                                    | Two `<parameter-attribute>` instances (one per set) + `<validate-not-null-or-empty-attribute>` + `[string]` type-literal                                             |
| 7   | `<script-parameter>` (`Environment`)                                 | Optional string in both sets                                                                                                                                                                       | Two `<parameter-attribute>` + `[string]`                                                                                                                             |
| 8   | `<script-parameter>` (`DatabaseHost`)                                | Optional string with `Alias('HostName')`                                                                                                                                                           | Two `<parameter-attribute>` + `<alias-attribute>` + `[string]`                                                                                                       |
| 9   | `<script-parameter>` (`SqlInstance`)                                 | Optional string in both sets                                                                                                                                                                       | Two `<parameter-attribute>` + `[string]`                                                                                                                             |
| 10  | `<script-parameter>` (`ConnectionMethod`)                            | Optional string in both sets                                                                                                                                                                       | Two `<parameter-attribute>` + `[string]`                                                                                                                             |
| 11  | `<script-parameter>` (`Port`)                                        | Optional int in both sets                                                                                                                                                                          | Two `<parameter-attribute>` + `[int]`                                                                                                                                |
| 12  | `<script-parameter>` (`IntegratedSecurity`)                          | Optional switch in both sets                                                                                                                                                                       | Two `<parameter-attribute>` + `[switch]`                                                                                                                             |
| 13  | `<script-parameter>` (`CredentialsKey`)                              | Optional string in both sets                                                                                                                                                                       | Two `<parameter-attribute>` + `[string]`                                                                                                                             |
| 14  | `<script-parameter>` (`SqlConnection`)                               | Mandatory only in `ExistingConnection` set                                                                                                                                                         | One `<parameter-attribute>` (Mandatory=$true) + `<validate-not-null-attribute>` + `[Microsoft.Data.SqlClient.SqlConnection]`                                         |
| 15  | `<script-parameter>` (`DatabasePath`)                                | Optional string in both sets                                                                                                                                                                       | Two `<parameter-attribute>` + `[string]`                                                                                                                             |
| 16  | `<script-parameter>` (`ProvisioningScriptsPath`)                     | Optional string in both sets                                                                                                                                                                       | Two `<parameter-attribute>` + `[string]`                                                                                                                             |
| 17  | `<script-parameter>` (`FlywayBasePath`)                              | Optional string in both sets                                                                                                                                                                       | Two `<parameter-attribute>` + `[string]`                                                                                                                             |
| 18  | `<script-parameter>` (`flywaySqlMigrationsPath`)                     | Optional string in both sets                                                                                                                                                                       | Two `<parameter-attribute>` + `[string]`                                                                                                                             |
| 19  | `<script-parameter>` (`flywaySharedSqlMigrationsPath`)               | Optional string in both sets                                                                                                                                                                       | Two `<parameter-attribute>` + `[string]`                                                                                                                             |
| 20  | `<script-parameter>` (`FlywayDataPath`)                              | Optional string in both sets                                                                                                                                                                       | Two `<parameter-attribute>` + `[string]`                                                                                                                             |
| 21  | `<script-parameter>` (`FlywayTomlPath`)                              | Optional string in both sets                                                                                                                                                                       | Two `<parameter-attribute>` + `[string]`                                                                                                                             |
| 22  | `<script-parameter>` (`Force`)                                       | Optional switch in both sets                                                                                                                                                                       | Two `<parameter-attribute>` + `[switch]`                                                                                                                             |
| 23  | `<region-block>` × 2                                                 | `# region Database connection parameters` / `# endregion` enclosing parameters 6–14 in the param block                                                                                             | `RegionLabel` = `"Database connection parameters"`                                                                                                                   |
| 24  | `<named-block>` (BEGIN)                                              | `BEGIN { ... }` wrapper                                                                                                                                                                            | Contains primitives 25–44                                                                                                                                            |
| 25  | `<assignment-statement>` × 2                                         | `$fn = 'Build-DatabaseWithFlyway'`; `$mn = 'ATAP.Utilities.DatabaseManagement.Powershell'`                                                                                                         | `[PSFramework] Write-PSFMessage` logging context variables                                                                                                           |
| 26  | `<pipeline-statement>` (Write-PSFMessage)                            | `Write-PSFMessage … -Level Debug -Message 'Function started'`                                                                                                                                      | First log entry in BEGIN                                                                                                                                             |
| 27  | `<try-catch-finally-statement>` (module-load try)                    | Outer try/catch that wraps all module-load guards and throws on failure                                                                                                                            | `TryBody` = primitives 28–33; `CatchClauses` = one bare catch logging and rethrowing                                                                                 |
| 28  | `<module-load-guard>` (`dbatools` module)                            | `if (-not (Get-Module -Name dbatools -ListAvailable)) { Install-Module … }` + `Import-Module dbatools`                                                                                             | `GuardKind` = `Module`; `InstallIfMissing` = `$true`                                                                                                                 |
| 29  | `<module-load-guard>` (`Get-ParameterValueFromNeoConfigurationRoot`) | `if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' …)) { . '…ps1' }`                                                                                                        | `GuardKind` = `Function`; `SourcePath` = hardcoded absolute path                                                                                                     |
| 30  | `<module-load-guard>` (`Get-RepositoryRoot`)                         | Same pattern for `Get-RepositoryRoot`                                                                                                                                                              | `GuardKind` = `Function`                                                                                                                                             |
| 31  | `<module-load-guard>` (`New-DBAConnStrBuilder`)                      | Same pattern for `New-DBAConnStrBuilder`                                                                                                                                                           | `GuardKind` = `Function`                                                                                                                                             |
| 32  | `<module-load-guard>` (`DatabaseProvisioning`)                       | Same pattern for `DatabaseProvisioning`                                                                                                                                                            | `GuardKind` = `Function`                                                                                                                                             |
| 33  | `<module-load-guard>` (`Invoke-Flyway`)                              | Same pattern for `Invoke-Flyway`                                                                                                                                                                   | `GuardKind` = `Function`                                                                                                                                             |
| 34  | `<assignment-statement>` (`$usingExistingConnection`)                | `$usingExistingConnection = $PSCmdlet.ParameterSetName -eq 'ExistingConnection'`                                                                                                                   | Boolean sentinel tracking which parameter set is active                                                                                                              |
| 35  | `<assignment-statement>` (`$databasesCollection`)                    | `$databasesCollection = $global:settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']]`                                                                                              | Pulls the per-database settings sub-tree from global settings                                                                                                        |
| 36  | `<region-block>`                                                     | `# region Database connection parameter validation` / `# endregion`                                                                                                                                | Wraps the 8 Get-PVal calls for connection parameters                                                                                                                 |
| 37  | `<pipeline-statement>` × 14 (Get-PVal calls)                         | One `Get-PVal` invocation per parameter resolving from `$PSBoundParameters` → env → `$global:settings` dotted-path → default                                                                       | See parameter-validation detail table below                                                                                                                          |
| 38  | `<if-else-statement>` (SqlInstance defaulting)                       | `if (-not $SqlInstance) { $SqlInstance = if ($Environment -eq 'Experimental') { "Exp$($env:USERNAME)" } elseif ($Environment -eq 'Development') { "Dev$($env:USERNAME)" } else { $Environment } }` | Derives `$SqlInstance` from `$Environment` and `$env:USERNAME` when caller did not supply it; instance names use 3-char prefix + username, max 16 chars total        |
| 39  | `<if-else-statement>` (IntegratedSecurity defaulting)                | `if (-not $CredentialsKey -and -not $IntegratedSecurity) { $IntegratedSecurity = $true }`                                                                                                          | Defaults to Windows Integrated Auth when no credential key is supplied                                                                                               |
| 40  | `<assignment-statement>` (`$result`)                                 | `$result = [PSCustomObject]@{ Success=…; DatabaseName=…; … }`                                                                                                                                      | Creates the output result object                                                                                                                                     |
| 41  | `<PSCustomObject-literal>`                                           | `[PSCustomObject]@{ Success=$false; DatabaseName=$DatabaseName; Environment=$Environment; SqlInstance=$SqlInstance; Errors=@(); StartTime=Get-Date; EndTime=$null }`                               | Entries table: see result-object entries below                                                                                                                       |
| 42  | `<pipeline-statement>` × 2 (Set-DbatoolsConfig)                      | `Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true …`; `Set-DbatoolsConfig -FullName sql.connection.encrypt -Value $false …`                                                      | Configures dbatools SSL / encryption for dev environments                                                                                                            |
| 43  | `<named-block>` (PROCESS)                                            | `PROCESS { try { … } catch { … } finally { … } }`                                                                                                                                                  | Contains primitive 44                                                                                                                                                |
| 44  | `<try-catch-finally-statement>` (PROCESS outer)                      | Main PROCESS try/catch/finally                                                                                                                                                                     | `TryBody` = primitives 45–60; `CatchClauses` = one bare catch; `FinallyBody` = location-restore                                                                      |
| 45  | `<if-else-statement>` (`$FlywaySQLDataPath`)                         | Sets `$env:FLYWAY_PLACEHOLDERS_DATA_DIR` when `FlywayDataPath` is provided                                                                                                                         | Condition: `$FlywaySQLDataPath`; body: `<env-variable-assignment>` + `<pipeline-statement>` (Write-PSFMessage)                                                       |
| 46  | `<assignment-statement>` (`$originalLocation`)                       | `$originalLocation = Get-Location`                                                                                                                                                                 | Saves cwd for restoration in `finally`                                                                                                                               |
| 47  | `<pipeline-statement>` (`Set-Location`)                              | `Set-Location $FlywayBasePath`                                                                                                                                                                     | Changes working directory to the Flyway root                                                                                                                         |
| 48  | `<pipeline-statement>` × 2 (Write-PSFMessage Important)              | Log messages: `"Starting database provisioning…"` / `"Target Server: $DatabaseHost"`                                                                                                               | Progress logging                                                                                                                                                     |
| 49  | `<assignment-statement>` × 3                                         | `$sqlConnection = $null`; `$sqlConnectionOpenedHere = $false`; `$useIntegratedSecurityForFlyway = $IntegratedSecurity`                                                                             | Initialise connection-tracking sentinels                                                                                                                             |
| 50  | `<if-else-statement>` (usingExistingConnection)                      | Branches on `$usingExistingConnection` — existing-connection path vs. new-connection path                                                                                                          | `IfBody` = primitives 51–52; `ElseBody` = primitives 53–57                                                                                                           |
| 51  | `<try-catch-finally-statement>` (existing-connection validation)     | Validates and opens the caller-supplied `$SqlConnection`                                                                                                                                           | `TryBody`: open-if-not-open; `CatchClauses`: log + append to `$result.Errors` + throw                                                                                |
| 52  | `<assignment-statement>` (`$existingConnBuilder`)                    | `$existingConnBuilder = [Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new($SqlConnection.ConnectionString)`                                                                               | Extracts `IntegratedSecurity` from the existing connection                                                                                                           |
| 53  | `<hashtable-literal>` (`$connStrBuilderParams`)                      | `$connStrBuilderParams = @{ DatabaseName='master'; DatabaseHost=…; ConnectionMethod=…; SqlInstance=… }`                                                                                            | Params for `New-DBAConnStrBuilder`                                                                                                                                   |
| 54  | `<if-else-statement>` (Port / CredentialsKey additions)              | Conditionally adds `Port` and `CredentialsKey` / `IntegratedSecurity` to `$connStrBuilderParams`                                                                                                   | Two nested `if` blocks                                                                                                                                               |
| 55  | `<splat-invocation>` (`New-DBAConnStrBuilder`)                       | `$connStrBuilderResult = New-DBAConnStrBuilder @connStrBuilderParams`                                                                                                                              | Calls the connection-string builder with splatted params                                                                                                             |
| 56  | `<assignment-statement>` × 3 (connectionStringBuilder modifications) | Retrieves `.Builder` from result; sets `TrustServerCertificate=$true`; `Encrypt=$false`; `Connect Timeout=30`                                                                                      | Configures ADO.NET connection string for dev SSL                                                                                                                     |
| 57  | `<try-catch-finally-statement>` (open new connection)                | `try { $sqlConnection.Open(); … } catch { … log; dispose; throw }`                                                                                                                                 | Opens the freshly-built `SqlConnection`                                                                                                                              |
| 58  | `<try-catch-finally-statement>` (connectivity test)                  | `try { … SELECT @@SERVERNAME … } catch { … }`                                                                                                                                                      | Verifies the connection with a lightweight query                                                                                                                     |
| 59  | `<hashtable-literal>` (`$provisioningParams`)                        | Splatted args for `DatabaseProvisioning`: `DatabaseName`, `SqlConnection`, `DatabasePath`, `ProvisioningScriptsPath`, `Force`                                                                      |                                                                                                                                                                      |
| 60  | `<if-else-statement>` (ShouldProcess guard)                          | `if ($PSCmdlet.ShouldProcess($DatabaseName, 'Provision database')) { … }`                                                                                                                          | WhatIf / Confirm support                                                                                                                                             |
| 61  | `<try-catch-finally-statement>` (DatabaseProvisioning + Flyway)      | `try { DatabaseProvisioning @provisioningParams } finally { close connection }` then Flyway call                                                                                                   | Ensures connection cleanup                                                                                                                                           |
| 62  | `<splat-invocation>` (`DatabaseProvisioning`)                        | `DatabaseProvisioning @provisioningParams`                                                                                                                                                         | Drops and recreates the database                                                                                                                                     |
| 63  | `<hashtable-literal>` (`$FlywayParams`)                              | Splatted args for `Invoke-Flyway`: all Flyway path and connection parameters                                                                                                                       | 12-entry hashtable                                                                                                                                                   |
| 64  | `<if-else-statement>` (CredentialsKey for Flyway)                    | `if ($CredentialsKey) { $FlywayParams['CredentialsKey'] = $CredentialsKey }`                                                                                                                       | Conditionally adds credential key                                                                                                                                    |
| 65  | `<splat-invocation>` (`Invoke-Flyway`)                               | `Invoke-Flyway @FlywayParams`                                                                                                                                                                      | Runs the `migrate` command                                                                                                                                           |
| 66  | `<named-block>` (END)                                                | `END { Write-PSFMessage …; return $result }`                                                                                                                                                       | Final named block                                                                                                                                                    |
| 67  | `<pipeline-statement>` (Write-PSFMessage Debug)                      | `Write-PSFMessage … -Level Debug -Message 'Function completed'`                                                                                                                                    | Completion log entry                                                                                                                                                 |
| 68  | `<flow-control-statement>` (return)                                  | `return $result`                                                                                                                                                                                   | Returns the result PSCustomObject to the caller                                                                                                                      |

---

**Comment-based help inputs (primitive 2):**

| Section                              | Content                                                                                                                    |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| `.SYNOPSIS`                          | `Builds a SQL Server database from scratch using Flyway migrations.`                                                       |
| `.DESCRIPTION`                       | 4-line description: orchestrates env-var loading, connection setup, DatabaseProvisioning drop/recreate, and Flyway migrate |
| `.PARAMETER DatabaseName`            | `The name of the database to build.`                                                                                       |
| `.PARAMETER Environment`             | `The target environment: 'Development', 'Testing', 'Production', or 'Experimental'.`                                       |
| `.PARAMETER DatabaseHost`            | `The SQL Server host. Default is 'localhost'.`                                                                             |
| `.PARAMETER FlywayBasePath`          | `Path to the Flyway directory containing flyway.toml. If not specified, attempts to auto-detect.`                          |
| `.PARAMETER SqlMigrationsPath`       | `Path to the SQL migrations directory. Defaults to FlywayBasePath\SQL.`                                                    |
| `.PARAMETER SharedSqlMigrationsPath` | `Path to the shared SQL scripts directory.`                                                                                |
| `.PARAMETER Force`                   | `Force database drop even if it exists. Default is $true.`                                                                 |
| `.OUTPUTS`                           | `System.Object — returns a result object with Success (bool) and any error messages.`                                      |
| `.EXAMPLE`                           | `Build-DatabaseWithFlyway -DatabaseName 'Tags' -Environment 'Experimental' -DatabaseHost 'localhost'`                      |
| `.EXAMPLE`                           | `Build-DatabaseWithFlyway -DatabaseName 'PCMSC' -Environment 'Development'`                                                |
| `.NOTES`                             | `AI assisted using Powershell.instructions.md as guidelines. Requires dbatools. Requires Flyway CLI.`                      |
| `.LINK`                              | `https://github.com/whertzing/ATAP.Utilities`                                                                              |

---

**Parameter-validation detail (primitive 37 — Get-PVal calls):**

| Parameter                        | `ParameterName`             | `dottedPath`                                           | `AllowMissing` | `ValidValues`                                            |
| -------------------------------- | --------------------------- | ------------------------------------------------------ | -------------- | -------------------------------------------------------- |
| `$DatabaseName`                  | `"DatabaseName"`            | `"$databaseName.$Environment.DatabaseName"`            | —              | —                                                        |
| `$Environment`                   | `"Environment"`             | —                                                      | —              | `@('Production','Testing','Development','Experimental')` |
| `$DatabaseHost`                  | `"DatabaseHost"`            | `"$databaseName.$Environment.DatabaseHost"`            | —              | —                                                        |
| `$SqlInstance`                   | `"SqlInstance"`             | `"$databaseName.$Environment.SqlInstance"`             | `$true`        | —                                                        |
| `$ConnectionMethod`              | `"ConnectionMethod"`        | `"$databaseName.$Environment.ConnectionMethod"`        | —              | `@('tcp','np','lpc')`                                    |
| `$Port`                          | `"Port"`                    | `"$databaseName.$Environment.Port"`                    | `$true`        | —                                                        |
| `$CredentialsKey`                | `"CredentialsKey"`          | `"$databaseName.$Environment.CredentialsKey"`          | `$true`        | —                                                        |
| `$DatabasePath`                  | `"DatabasePath"`            | `"$databaseName.$Environment.DatabasePath"`            | —              | —                                                        |
| `$FlywayBasePath`                | `"FlywayBasePath"`          | `"$databaseName.$Environment.FlywayBasePath"`          | —              | —                                                        |
| `$flywaySqlMigrationsPath`       | `"SqlMigrationsPath"`       | `"$databaseName.$Environment.SqlMigrationsPath"`       | —              | —                                                        |
| `$flywaySharedSqlMigrationsPath` | `"SharedSqlMigrationsPath"` | `"$databaseName.$Environment.SharedSqlMigrationsPath"` | —              | —                                                        |
| `$FlywayDataPath`                | `"FlywayDataPath"`          | `"$databaseName.$Environment.FlywayDataPath"`          | —              | —                                                        |
| `$FlywayTomlPath`                | `"FlywayTomlPath"`          | `"$databaseName.$Environment.FlywayTomlPath"`          | —              | —                                                        |

---

**Result-object entries (primitive 41):**

| Key            | Initial value   |
| -------------- | --------------- |
| `Success`      | `$false`        |
| `DatabaseName` | `$DatabaseName` |
| `Environment`  | `$Environment`  |
| `SqlInstance`  | `$SqlInstance`  |
| `Errors`       | `@()`           |
| `StartTime`    | `Get-Date`      |
| `EndTime`      | `$null`         |

---

**Parameter sets:**

- `ConnectionParameters` — caller supplies individual connection parameters; cmdlet builds and owns the `SqlConnection`.
- `ExistingConnection` — caller supplies a pre-existing `Microsoft.Data.SqlClient.SqlConnection`; `$SqlConnection` is mandatory in this set; the cmdlet reuses it and only closes it if this cmdlet opened it.

**Preconditions:**

- `dbatools` PowerShell module available (auto-installed to `CurrentUser` scope if missing).
- Flyway CLI on `PATH` or discoverable via `Invoke-Flyway`.
- `$global:settings` contains key structure under `$global:configRootKeys['DatabasesCollectionConfigRootKey']`.
- SQL Server Browser service running for named-instance connections.
- `TrustServerCertificate=true` and `Encrypt=false` are applied automatically for dev environments.

**Flyway authentication note:**

When using Windows Integrated Authentication, `FLYWAY_<ENV>_USER` or `FLYWAY_<ENV>_PASSWORD` environment variables should not exist. The `IntegratedSecurity` switch controls whether those variables are expected to be absent before invoking Flyway.

**Outputs:** `PSCustomObject` with properties `Success` (bool), `DatabaseName`, `Environment`, `SqlInstance`, `Errors` (string array), `StartTime`, `EndTime`.

**Example invocations:**

```powershell
# Build the Tags database in the Experimental environment using integrated security
Build-DatabaseWithFlyway -DatabaseName 'Tags' -Environment 'Experimental' -DatabaseHost 'localhost'

# Build the GMail database in Development using all defaults from $global:settings
Build-DatabaseWithFlyway -DatabaseName 'GMail' -Environment 'Development'

# Build using an already-open SqlConnection (e.g., within a larger pipeline)
Build-DatabaseWithFlyway -DatabaseName 'Philote' -SqlConnection $existingConn
```

**Implementation:**

The cmdlet `Build-DatabaseWithFlyway` (located at `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Build-DatabaseWithFlyway.ps1`) is invoked with the following canonical inputs:

| Parameter                       | Source                                                                           | Notes                                                                                                    |
| ------------------------------- | -------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `DatabaseName`                  | Required — caller supplied or `$global:settings`                                 | Identifies the target database                                                                           |
| `Environment`                   | Optional — caller supplied or `$global:settings`; defaults to key in settings    | One of `Development`, `Testing`, `Production`, `Experimental`                                            |
| `DatabaseHost`                  | Optional — caller supplied or settings                                           | Defaults to `localhost`                                                                                  |
| `SqlInstance`                   | Optional — inferred from `Environment` if absent                                 | `Dev$env:USERNAME` for `Development`; `Exp$env:USERNAME` for `Experimental`; matches tier name otherwise |
| `ConnectionMethod`              | Optional — caller supplied or settings                                           | One of `tcp`, `np`, `lpc`                                                                                |
| `Port`                          | Optional — caller supplied or settings                                           | Omitted for default port                                                                                 |
| `IntegratedSecurity`            | Switch — defaulted to `$true` when no `CredentialsKey` supplied                  | Windows Integrated Auth                                                                                  |
| `CredentialsKey`                | Optional — vault lookup key for SQL auth credentials                             | Mutually exclusive with `IntegratedSecurity`                                                             |
| `SqlConnection`                 | Optional — existing open `Microsoft.Data.SqlClient.SqlConnection`                | Uses `ExistingConnection` parameter set                                                                  |
| `DatabasePath`                  | Optional — path for database `.mdf`/`.ldf` files                                 | Retrieved from settings if absent                                                                        |
| `ProvisioningScriptsPath`       | Optional — path to pre-migration T-SQL scripts                                   | Retrieved from settings if absent                                                                        |
| `FlywayBasePath`                | Required (resolved) — root directory of `flyway.toml`                            | Retrieved from settings if absent                                                                        |
| `flywaySqlMigrationsPath`       | Optional — path to database-specific SQL migrations                              | Defaults to `FlywayBasePath\SQL`                                                                         |
| `flywaySharedSqlMigrationsPath` | Optional — path to shared SQL migrations                                         | Retrieved from settings if absent                                                                        |
| `FlywayDataPath`                | Optional — path to seed data scripts; exported as `FLYWAY_PLACEHOLDERS_DATA_DIR` | Retrieved from settings if absent                                                                        |
| `FlywayTomlPath`                | Optional — explicit path to `flyway.toml`                                        | Retrieved from settings if absent                                                                        |
| `Force`                         | Switch                                                                           | Passed through to `DatabaseProvisioning`; drops DB if it exists                                          |

**Execution flow:**

1. **BEGIN block** — loads dependent cmdlets (`New-DBAConnStrBuilder`, `DatabaseProvisioning`, `Invoke-Flyway`, etc.) if not already in session; resolves all parameters via `Get-PVal` from `$global:settings`; configures dbatools to trust server certificates and disable encryption for development environments.
2. **PROCESS block** — sets `FLYWAY_PLACEHOLDERS_DATA_DIR` env var if `FlywayDataPath` is provided; changes working directory to `FlywayBasePath`; opens (or reuses) a `SqlConnection`; verifies connectivity; calls `DatabaseProvisioning`; closes the SQL connection; then calls `Invoke-Flyway` with `FlywayCommand = 'migrate'`.
3. **END block** — returns a `PSCustomObject` with `Success`, `DatabaseName`, `Environment`, `SqlInstance`, `Errors`, `StartTime`, and `EndTime`.

**Parameter sets:**

- `ConnectionParameters` — Caller supplies individual connection parameters; cmdlet builds and owns the `SqlConnection`.
- `ExistingConnection` — Caller supplies a pre-existing `Microsoft.Data.SqlClient.SqlConnection`; cmdlet uses it and does not close it unless it opened it.

**Preconditions:**

- `dbatools` PowerShell module must be available (auto-installed to `CurrentUser` scope if missing).
- Flyway CLI must be on `PATH` or discoverable via `Invoke-Flyway`.
- `$global:settings` must contain a key structure of `$global:configRootKeys['DatabasesCollectionConfigRootKey']` with per-database, per-environment configuration.
- SQL Server Browser service must be running for named-instance connections.
- For self-signed certificates, the `TrustServerCertificate=true` and `Encrypt=false` JDBC/ADO options are automatically applied by this cmdlet.

**Flyway authentication note:**

When using Windows Integrated Authentication, no `FLYWAY_<ENV>_USER` or `FLYWAY_<ENV>_PASSWORD` environment variables must be set. The presence of those placeholders in `flyway.toml` causes Flyway to attempt SQL authentication and fail. The `IntegratedSecurity` switch on this cmdlet controls whether those variables are expected to be absent before invoking Flyway.

**Outputs:** `PSCustomObject` with properties `Success` (bool), `DatabaseName`, `Environment`, `SqlInstance`, `Errors` (string array), `StartTime`, `EndTime`.

**Example invocations:**

```powershell
# Build the Tags database in the Experimental environment using integrated security
Build-DatabaseWithFlyway -DatabaseName 'Tags' -Environment 'Experimental' -DatabaseHost 'localhost'

# Build the GMail database in Development using all defaults from $global:settings
Build-DatabaseWithFlyway -DatabaseName 'GMail' -Environment 'Development'

# Build using an already-open SqlConnection (e.g., within a larger pipeline)
Build-DatabaseWithFlyway -DatabaseName 'Philote' -SqlConnection $existingConn
```

### Logging Rule Set

**Philote ID:** `"9369e02d-4218-42dc-a487-4a176f9eac46"`

**Priority:** P1 (correctness — apply before all other Rule Sets)

**Description:** This Rule Set defines the canonical PSFramework logging conventions for
all PowerShell functions and cmdlets in ATAP.Utilities and Ace Commander. Every logging
call and external-call instrumentation pattern derives from these rules. Compliance is
required for all production-grade PowerShell code in this repository.

**Source:** `SolutionDocumentation/AI prompt to create Copilot instruction files.md` lines 138-292.

**Cross-references:** Task 1.2 (Error Handling Rule Set), Task 1.3 (GELF/SEQ provider sub-section).

#### Rule L-1 — Approved logging cmdlet

Use `Write-PSFMessage` exclusively for all diagnostic and operational logging.

**Forbidden alternatives:**

| Forbidden       | Reason                                                            |
| --------------- | ----------------------------------------------------------------- |
| `Write-Host`    | Bypasses the logging pipeline; cannot be suppressed or redirected |
| `Write-Verbose` | Ignores PSFramework level routing and tagging                     |
| `Write-Debug`   | Same as above                                                     |
| `Write-Output`  | Intended for pipeline output, not logging                         |

**Correct form:**

```powershell
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' `
    -Level Debug -Message 'Some trace message'
```

#### Rule L-2 — Approved log levels

`-Level Info` is **never** a valid level with `Write-PSFMessage`.

| Level       | When to use                                                                        |
| ----------- | ---------------------------------------------------------------------------------- |
| `Debug`     | Trace-level detail: entering/leaving functions, before/after external calls        |
| `Verbose`   | Lifecycle events: configuration loaded, connection established, finally-block exit |
| `Important` | Notable operational events worth surfacing to operators in non-debug runs          |
| `Error`     | Failures caught in catch blocks                                                    |

#### Rule L-3 — Mandatory `-FunctionName` and `-ModuleName`

Every `Write-PSFMessage` call inside a function must include both named parameters:

```powershell
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' `
    -Level Verbose -Message 'some message'
```

Where `<functionName>` and `<moduleName>` are replaced with the literal name of the
enclosing function and the module it belongs to, respectively.

#### Rule L-4 — Function entry and exit logging

The **first executable line** of the `begin` block must be:

```powershell
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' `
    -Level Debug -Message 'Entering Function <functionName> in module <moduleName>'
```

The **next-to-last executable line** of the `end` block (before the return value) must be:

```powershell
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' `
    -Level Debug -Message 'Leaving Function <functionName> in module <moduleName>'
```

#### Rule L-5 — External call instrumentation and tags

All calls to the following cmdlets must be preceded and followed by a
`Write-PSFMessage -Level Debug` call using the corresponding `-Tag` value.

| Cmdlet              | `-Tag` value             | Before-call message             | After-call message                                         |
| ------------------- | ------------------------ | ------------------------------- | ---------------------------------------------------------- |
| `Invoke-RestMethod` | `'RestCall'`             | `"Calling <URLOfEndpoint>"`     | `"Successfully returned from <URLOfEndpoint>"`             |
| `Invoke-WebRequest` | `'WebRequestCall'`       | `"Calling <URLOfEndpoint>"`     | `"Successfully returned from <URLOfEndpoint>"`             |
| `Invoke-Expression` | `'InvokeExpressionCall'` | `"Invoke-Expression <command>"` | `"Successfully returned from Invoke-Expression <command>"` |
| `Invoke-Command`    | `'InvokeCommandCall'`    | _(see Rule L-5a)_               | same pattern                                               |

**Rule L-5a — `Invoke-Command` before-call log message format:**

```powershell
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' `
    -Level Debug -Message $(
        "Calling Invoke-Command " + `
        "-ComputerName $computername -ScriptBlock {$scriptBlockToRun} " + `
        "-Credential $($credential.ToString()) " + `
        "$(if ($useSSL) { ' -useSSL ' })" + `
        "$(if ($useSelfSignedCert) { ' -SessionOption $(New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck)' })"
    ) -Tag 'InvokeCommandCall'
```

#### Rule L-6 — Wrap all external calls in try/catch/finally

All four external-call cmdlets (`Invoke-RestMethod`, `Invoke-WebRequest`,
`Invoke-Expression`, `Invoke-Command`) must be wrapped in a `try/catch/finally` block.
Use `-ErrorAction Stop` on any call whose failure must abort the enclosing operation.

#### Rule L-7 — Catch and finally block template

```powershell
try {
    # ... call with -ErrorAction Stop if failure must abort ...
}
catch {
    $errorMessage = "<description of the attempted operation>. Exception: $($_.Exception.Message)"
    Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' `
        -Level Error -Message $errorMessage -Exception $_.Exception `
        -Tag '<RestCall|WebRequestCall|InvokeExpressionCall|InvokeCommandCall>'
    throw $_
}
finally {
    Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' `
        -Level Verbose -Message "Exiting function: <functionName>"
}
```

### Error Handling Rule Set

**Philote ID:** `"3cc57c81-2fa6-408b-af37-1098ce68d51c"`

**Priority:** P1 (correctness — apply before all other Rule Sets)

**Description:** This Rule Set defines the canonical input-validation and error-handling
conventions for all PowerShell functions and cmdlets in ATAP.Utilities and Ace Commander.
Every function boundary check, try/catch/finally template, and exception logging pattern
derives from these rules.

**Source:** `SolutionDocumentation/AI prompt to create Copilot instruction files.md` lines 167-305.

**Cross-references:** Logging Rule Set (Rules L-6, L-7); Task 1.3 (GELF/SEQ provider).

#### Rule EH-1 — Validate all inputs at the function boundary

Prefer parameter-attribute validation over imperative checks. Use the following in order
of preference:

1. `[ValidateNotNullOrEmpty()]`, `[ValidateNotNull()]`, `[ValidateSet(...)]`,
   `[ValidateRange(...)]`, `[ValidatePattern(...)]`, `[ValidateScript({...})]`
   as parameter attributes — they run before the function body and produce clear errors.

2. For complex invariants that attributes cannot express, use
   `[string]::IsNullOrWhiteSpace()` or `[string]::IsNullOrEmpty()` in the `begin` block
   immediately after the entry log (Rule L-4). Prefer the static .NET methods over
   PowerShell idioms like `-eq $null -or -eq ''`.

3. When using `ValidateScript`, always `throw` an explicit, descriptive message on
   failure — do not rely on the default PowerShell expression-only message.

```powershell
[ValidateScript({
    if ([string]::IsNullOrWhiteSpace($_)) {
        throw "Parameter 'DatabaseName' must be a non-empty, non-whitespace string."
    }
    $true
})]
[string] $DatabaseName
```

#### Rule EH-2 — Wrap all external calls in try/catch/finally

Any call that can fail and whose failure must abort the current operation must be
placed inside a `try/catch/finally` block. This applies especially to the four
instrumented call types (`Invoke-RestMethod`, `Invoke-WebRequest`, `Invoke-Expression`,
`Invoke-Command`) per Logging Rule L-6, and also to:

- calls to external executables (e.g., `flyway`, `dotnet`, `git`)
- calls to dbaTools cmdlets and other third-party modules
- file I/O that may fail on access permissions or missing paths
- any operation that populates a required downstream variable

Add `-ErrorAction Stop` to any cmdlet call whose failure should trigger the `catch`
block; without it, non-terminating errors are silently swallowed.

```powershell
Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
```

#### Rule EH-3 — Catch block template

The `catch` block must:

1. Compose a descriptive error message that includes what operation was attempted.
2. Log with `Write-PSFMessage -Level Error` (Rule L-7), including `-Exception $_.Exception`.
3. Apply the appropriate `-Tag` for the instrumented call type (Rule L-5).
4. Re-throw with `throw $_` to preserve the original exception and stack trace.

Never swallow exceptions silently. Never log and return a success indicator when an
exception has occurred.

```powershell
catch {
    $errorMessage = "<description of the attempted operation>. Exception: $($_.Exception.Message)"
    Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' `
        -Level Error -Message $errorMessage -Exception $_.Exception `
        -Tag '<RestCall|WebRequestCall|InvokeExpressionCall|InvokeCommandCall>'
    throw $_
}
```

#### Rule EH-4 — Finally block template

The `finally` block must:

1. Execute any mandatory cleanup (e.g., close connections, remove temp files, release
   locks) regardless of success or failure.
2. Emit a `Write-PSFMessage -Level Verbose` exit message (Rule L-7). This serves as
   the exit-trace companion to the entry message in the `begin` block (Rule L-4).

```powershell
finally {
    Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' `
        -Level Verbose -Message "Exiting function: <functionName>"
}
```

#### Rule EH-5 — Full try/catch/finally skeleton

The canonical pattern combining Rules EH-2 through EH-4:

```powershell
try {
    # Instrumentation before external call (Rule L-5)
    Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' `
        -Level Debug -Message "Calling <URLOfEndpoint>" -Tag 'RestCall'

    $result = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop

    # Instrumentation after external call (Rule L-5)
    Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' `
        -Level Debug -Message "Successfully returned from <URLOfEndpoint>" -Tag 'RestCall'
}
catch {
    $errorMessage = "<description of attempted operation>. Exception: $($_.Exception.Message)"
    Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' `
        -Level Error -Message $errorMessage -Exception $_.Exception -Tag 'RestCall'
    throw $_
}
finally {
    Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' `
        -Level Verbose -Message "Exiting function: <functionName>"
}
```

### GELF/SEQ Named Logging Provider Instances

**Philote:** `"e5e1529a-8a4d-4304-addb-0ca1225d6e67"`

This section extends the **Logging Rule Set** with rules specific to configuring
PSFramework logging providers that route messages to remote structured-logging
sinks such as SEQ (via the GELF provider) or Graylog.

#### Rule GELF-1: One named instance per sink

Configure exactly one PSFramework logging provider instance per remote sink.
Use the `includeinstances` PSFConfig key to bind a named provider activation to a
single instance name. Never reuse the same instance name across two different
provider configurations — doing so causes both providers to compete for messages
from the same instance and can result in duplicate forwarding or dropped messages.

```powershell
# One provider → one sink

# GELF provider bound to the 'SendToSEQ' instance
Set-PSFConfig -FullName 'psframework.logging.gelf.server'           -Value '127.0.0.1'
Set-PSFConfig -FullName 'psframework.logging.gelf.port'             -Value 12201
Set-PSFConfig -FullName 'psframework.logging.gelf.protocol'         -Value 'udp'
Set-PSFConfig -FullName 'psframework.logging.gelf.encrypt'          -Value $false
Set-PSFConfig -FullName 'psframework.logging.gelf.minlevel'         -Value 3        # Information
Set-PSFConfig -FullName 'psframework.logging.gelf.includeinstances' -Value @('SendToSEQ')
Set-PSFLoggingProvider -Name gelf -Enable $true
```

#### Rule GELF-2: Naming convention `SendTo<Sink>`

Name every logging instance using the pattern `SendTo<Sink>` where `<Sink>` matches
the human-readable product or endpoint name (e.g. `SendToSEQ`, `SendToGraylog`,
`SendToSplunk`). This makes routing intent immediately visible in both source code
and log records.

```powershell
# Correct
Write-PSFMessage -Instance 'SendToSEQ' -Level Important -Message "Structured log event"

# Incorrect — ambiguous instance name that doesn't communicate routing
Write-PSFMessage -Instance 'remote' -Level Important -Message "Structured log event"
```

#### Rule GELF-3: Configure filters at the provider level, not in application code

Apply level and instance filters via `Set-PSFConfig` on the provider, not via
`if`-guards around `Write-PSFMessage`. Provider-level filtering keeps routing
decisions in configuration and allows them to be adjusted without code changes.

```powershell
# Correct — filter at provider level
Set-PSFConfig -FullName 'psframework.logging.gelf.minlevel'         -Value 3  # Information and above
Set-PSFConfig -FullName 'psframework.logging.gelf.includeinstances' -Value @('SendToSEQ')

# Incorrect — gate logging in application code
if ($VerbosePreference -eq 'Continue') {
    Write-PSFMessage -Instance 'SendToSEQ' -Level Verbose -Message "..."
}
```

#### Rule GELF-4: Use `Set-PSFConfig` for instance filtering, not `Set-PSFLoggingProvider` parameters

The `Set-PSFLoggingProvider` cmdlet does **not** expose `-IncludeInstances` or
`-ExcludeInstances` parameters. Passing these as parameters raises `"A parameter
cannot be found that matches parameter name 'IncludeInstances'."`. Set all
instance-routing filters via `Set-PSFConfig` before enabling the provider.

```powershell
# CORRECT
Set-PSFConfig -FullName 'psframework.logging.gelf.includeinstances' -Value @('SendToSEQ')
Set-PSFLoggingProvider -Name gelf -Enable $true

# INCORRECT — parameter does not exist
Set-PSFLoggingProvider -Name gelf -Enable $true -IncludeInstances 'SendToSEQ'
```

#### Rule GELF-5: Persist configuration with `Register-PSFConfig`

Call `Register-PSFConfig -Module PSFramework` after finalising provider
configuration to persist all `psframework.logging.*` settings across sessions.
Without this, provider configuration is lost when the PowerShell process exits.

```powershell
Register-PSFConfig -Module PSFramework
```

### Input Validation Rule Set

**Philote:** `"b57a4b16-293e-4938-ba7e-b809aff30066"`

Rules governing how PowerShell function parameters and internal values are validated
before use. Cross-references the **Error Handling Rule Set** for the try/catch/finally
pattern that wraps validated inputs.

#### Rule IV-1: Prefer `[string]::IsNullOrWhiteSpace` over manual null/empty comparison

Use the static .NET method `[string]::IsNullOrWhiteSpace()` rather than the equivalent
manual comparison `-eq $null -or -eq ''`. The .NET method also catches whitespace-only
strings (e.g. `" "`), which the manual form misses and which are semantically invalid
in almost all parameter contexts.

```powershell
# Correct
if ([string]::IsNullOrWhiteSpace($value)) { throw "Value must not be null, empty or whitespace." }

# Also acceptable when only null/empty matters (not whitespace)
if ([string]::IsNullOrEmpty($value)) { throw "Value must not be null or empty." }

# Incorrect — misses whitespace-only strings
if ($value -eq $null -or $value -eq '') { throw "Value must not be null or empty." }
```

#### Rule IV-2: Prefer declarative `[Validate*]` parameter attributes over imperative guards

Apply built-in validation attributes (`[ValidateNotNull()]`, `[ValidateNotNullOrEmpty()]`,
`[ValidateRange()]`, `[ValidateSet()]`, `[ValidatePattern()]`) directly on parameters.
This makes constraints visible at the function signature and produces consistent,
framework-generated error messages without body code.

```powershell
function Get-Feed {
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FeedName,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [int]$Port = 8624
    )
    # body
}
```

#### Rule IV-3: Use `[ValidateScript]` with an explicit `throw` for complex invariants

When the built-in attributes cannot express a constraint, use `[ValidateScript()]`.
Always include an explicit `throw` with a descriptive message inside the script block;
without it PowerShell reports the opaque message `"The argument ... does not belong
to the set"` and the caller cannot diagnose the failure.

```powershell
function Set-FeedUrl {
    param (
        [Parameter(Mandatory)]
        [ValidateScript({
            if ([string]::IsNullOrWhiteSpace($_)) {
                throw "FeedUrl must not be null, empty, or whitespace."
            }
            if (-not ($_ -match '^https?://')) {
                throw "FeedUrl must begin with 'http://' or 'https://'."
            }
            $true  # must return $true when validation passes
        })]
        [string]$FeedUrl
    )
    # body
}
```

#### Rule IV-4: Prefer `[string]::IsNullOrWhiteSpace` inside `[ValidateScript]`

When writing a `[ValidateScript]` block that checks a string parameter, use
`[string]::IsNullOrWhiteSpace($_)` rather than a bare `-not $_` check. A whitespace-only
string is truthy in PowerShell (`-not " "` is `$false`), so `-not $_` does not catch it.

```powershell
# Correct
[ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]

# Incorrect — whitespace-only string passes this check
[ValidateScript({ -not [string]::IsNullOrEmpty($_) })]

# Also incorrect — whitespace-only string is truthy, so -not $_ is $false
[ValidateScript({ $_ })]
```

### Debugging Tools Appendix

**Philote:** `"b70ddc13-9453-4b76-9689-24460a3fc41f"`

Three mechanisms for dropping into the PowerShell debugger programmatically,
conditionally triggered at runtime. All approaches work in VS Code, the ISE,
and non-GUI (service / CI) hosts. Guard every hook behind an environment
variable or compile-time constant so they cannot fire in production.

#### Rule DBG-1: `Wait-Debugger` — unconditional pause until a debugger attaches

`Wait-Debugger` (PowerShell 6+) halts the runspace immediately and waits for a
debugger to connect. Use this in scripts that run as services or in CI pipelines
where you cannot attach before launch; the script appears to "hang" until you
attach from VS Code with **Run → Attach to PowerShell Interactive Session**.

```powershell
if ($env:DEBUG_ATTACH -eq '1') {
    Wait-Debugger   # execution halts here; attach in VS Code to continue
}
```

- Remove or guard the call for production — an unguarded `Wait-Debugger` will
  hang the process indefinitely.
- PowerShell 5.1 does not have `Wait-Debugger`; use Rule DBG-3 instead.

#### Rule DBG-2: `[System.Diagnostics.Debugger]::Break()` — break only when a debugger is already attached

`[System.Diagnostics.Debugger]::Break()` behaves exactly like a manual breakpoint
when a debugger is already attached (e.g. the script was launched via F5 in VS Code).
If no debugger is attached: on Windows, the JIT-attach dialog appears; on non-Windows,
the call is silently ignored.

```powershell
if ($SuspiciousValue -gt 1000) {
    [System.Diagnostics.Debugger]::Break()
}
```

Use this form when you have already launched the script under a debugger and want
to halt at a specific condition without modifying the IDE breakpoint list.

#### Rule DBG-3: `Set-PSBreakpoint` — insert a breakpoint dynamically at runtime

`Set-PSBreakpoint` inserts a line, command, or variable breakpoint at runtime without
editing source. Works in both Windows PowerShell 5.1 and PowerShell 7+. Execution
continues past the `Set-PSBreakpoint` call; the interpreter pauses only when it
reaches the targeted line/command.

```powershell
if ($OrderCount -gt 1000) {
    # Set a line breakpoint on the next line; execution will pause there
    $nextLine = $MyInvocation.ScriptLineNumber + 1
    Set-PSBreakpoint -Script $PSCommandPath -Line $nextLine | Out-Null
}

# Debugger stops here (the line referenced above)
Write-PSFMessage -Level Debug -Message "Entering large-batch code path."
```

Command-watch variant (pauses whenever the named cmdlet is called):

```powershell
Set-PSBreakpoint -Command 'Invoke-RestMethod' | Out-Null
```

Variable-watch variant (pauses whenever a variable is read or written):

```powershell
Set-PSBreakpoint -Variable 'OrderCount' -Mode ReadWrite | Out-Null
```

Remove all dynamic breakpoints when done to avoid stale pauses in later runs:

```powershell
Get-PSBreakpoint | Remove-PSBreakpoint
```

#### Summary — Which mechanism to choose

| Need                                                        | Mechanism                         |
| ----------------------------------------------------------- | --------------------------------- |
| Pause and wait for a debugger to attach (service / CI host) | `Wait-Debugger` (PS 6+)           |
| Break only if already running under a debugger (VS Code F5) | `[Diagnostics.Debugger]::Break()` |
| Create breakpoints dynamically without editing source lines | `Set-PSBreakpoint`                |
