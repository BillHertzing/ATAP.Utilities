# Rules Compendium — SQL

This file contains an overview of the SQL-specific Rules used within the ATAP.Utilities databases and the Ace Commander application built from these rules.

## Philote Identity Convention

Every Primitive, Rule, Rule Set, and Build Set defined in this document carries a **Philote ID**. A Philote is a .NET generic type `IPhilote<T>` where `T` is either `GUID` or `int`. All identifiers in this document use the `GUID` variant. The GUID is allocated once when the element is defined and never changes; it is the stable key back into the Ace Commander Instantiations database.

Format: `IPhilote<GUID>` — rendered in this document as a quoted GUID string, e.g. `"a3f2e1d0-1b2c-4a5b-8c9d-0e1f2a3b4c5d"`.

## Overview

This file documents SQL Rules and Rule Sets that make up modules and features.

Rules are created from Rule Primitives.

Rule Sets are created from Rules and include a directed graph that controls how execution flows from one Rule to another.

In order to define a feature or module in the ATAP.Utilities libraries or the Ace Commander application, a Rule Set is tagged with a feature identifier, which means that to implement the feature the Ace Commander Module will include that Rule Set in its Build Set.

## The purpose of Rules, Rule Sets, and Build Sets

Here is a simplifying acronym to shorten the long name "Rules, Rule Sets and Build Sets". We will refer to all of those compositely as "RRSBS".

Everything in the ATAP.Utilities libraries and the Ace Commander application, and all bolt-on modules for Ace Commander, are built from RRSBS. There are RRSBS that define the Ace Commander GUI. There are RRSBS for all visual display elements, RRSBS for composing visual elements into screens / pages, and RRSBS for stiching the screens / pages together into logical workflows. All data elements in the ecosystem are defined by RRSBS. Hardware for the computer systems that run the backend and on which the front end application runs are defined by RRSBS. Build processes for creating .dll libraries, .so libraries, .exe programs, are all defined by RRSBS. All tests for all software component are defined by RRSBS. Test Processes are defined by RRSBS. The processes to create and maintain database schemas and data are defined by RRSBS, as are the instructions how to backup and restore these databases. Documentation about how the RRSBS work are themselves defined by RRSBS. In sum, every concept, every bit of data, every software tool, the complete Ace Commander application, interfaces to third-party hardware and software are all defined by RRSBS. Specific instantiations of the Ace Commander or ATAP.Utilities libraries owned / used by owners / users are stored in the Instantiations database, and that database, and its schema and operational processes are defined by RRSBS. The API's for the backend and how the Ace Commander front-end communicates with the back-end APIs are defined by RRSBS

## Rule Primitives

Rule Primitives are the atomic building blocks from which a Rule is constructed. Each primitive maps to a single BNF non-terminal in the T-SQL grammar. When a primitive is instantiated, its inputs are bound to specific values; the rendered output is the exact SQL text that corresponds to that non-terminal node in the parse tree.

---

### `<sql-script-file>` Rule Primitive

**Philote ID:** `"a3f2e1d0-1b2c-4a5b-8c9d-0e1f2a3b4c5d"`

Description: Top-level container for a `.sql` file. A SQL Server script file is a sequence of one or more batches, where each batch is a sequence of T-SQL statements terminated by a `GO` separator. Batches may be preceded or followed by blank lines and comments that are not part of any batch.

```bnf
<sql-script-file>        ::= <script-element-list>

<script-element-list>    ::= <script-element>
                           | <script-element-list> <script-element>

<script-element>         ::= <batch>
                           | <go-separator>
                           | <single-line-comment>
                           | <block-comment>
                           | <new-line>
```

Body: The complete rendered text of the `.sql` file, assembled from its constituent elements in order.

Inputs:

- `Elements` (ordered list of `<script-element>` instances) — the top-level elements of the file.
- `FileEncoding` (string, default `UTF-8`) — character encoding written to the output file.

Output: The rendered `.sql` file text.

Processing: Each element is rendered in sequence and concatenated. The result is written to the output file path.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/language-reference?view=sql-server-ver16
2. https://learn.microsoft.com/en-us/sql/ssms/scripting/sqlcmd-use-the-utility?view=sql-server-ver16
```

---

### `<batch>` Rule Primitive

**Philote ID:** `"b4e3f2c1-2c3d-4b6c-9d0e-1f2a3b4c5d6e"`

Description: A batch is a sequence of one or more T-SQL statements sent to SQL Server as a unit for compilation and execution. Batches are delimited from each other by `GO` separators. Each batch constitutes a single compilation scope; DDL changes made in one batch are not visible in the same batch.

```bnf
<batch>                  ::= <batch-statement-list>

<batch-statement-list>   ::= <batch-statement>
                           | <batch-statement-list> <batch-statement>

<batch-statement>        ::= <use-statement>
                           | <set-option-statement>
                           | <declare-statement>
                           | <set-variable-statement>
                           | <select-from-order-statement>
                           | <object-existence-guard>
                           | <create-function-tvf-statement>
                           | <create-table-statement>
                           | <single-line-comment>
                           | <block-comment>
                           | <separator-comment-block>
                           | <new-line>
```

Body: The sequence of rendered statement texts that make up a single batch.

Inputs:

- `Statements` (ordered list of `<batch-statement>` instances) — the statements in the batch.

Output: The rendered batch text (without trailing `GO`; the `<go-separator>` is a separate sibling element).

Processing: Each statement is rendered in order; a newline is appended after each.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/language-elements/begin-end-transact-sql?view=sql-server-ver16
2. https://learn.microsoft.com/en-us/sql/ssms/scripting/edit-sqlcmd-scripts-with-query-editor?view=sql-server-ver16
```

---

### `<go-separator>` Rule Primitive

**Philote ID:** `"c5d4e3b2-3d4e-4c7d-ae1f-2a3b4c5d6e7f"`

Description: The `GO` command is not a T-SQL statement; it is a batch separator recognized by SSMS, `sqlcmd`, and `sqlpackage`. It signals the end of a batch and instructs the client tool to send the accumulated statements to the server. `GO` may optionally be followed by an integer count to execute the preceding batch that many times.

```bnf
<go-separator>           ::= "GO" <go-count>? <new-line>

<go-count>               ::= <ws> <decimal-digits>

<decimal-digits>         ::= <digit>
                           | <decimal-digits> <digit>

<digit>                  ::= "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
```

Body: The single token line `GO`, optionally followed by a repetition count.

Inputs:

- `RepeatCount` (int, optional) — when provided, the preceding batch is executed this many times. Default is 1 (omitted).

Output: The rendered `GO` line.

Processing: Writes `GO`, appends `<RepeatCount>` when provided, then a newline.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/language-elements/sql-server-utilities-statements-go?view=sql-server-ver16
```

---

### `<use-statement>` Rule Primitive

**Philote ID:** `"d6c5d4a3-4e5f-4d8e-bf20-3b4c5d6e7f80"`

Description: The `USE` statement changes the current database context for the session. The database name may be a plain identifier or a bracket-quoted identifier.

```bnf
<use-statement>          ::= "USE" <ws> <database-name> <statement-terminator>?

<database-name>          ::= <regular-identifier>
                           | <bracketed-identifier>

<regular-identifier>     ::= <id-start-char> <id-chars>*

<bracketed-identifier>   ::= "[" <bracketed-id-chars>* "]"

<id-start-char>          ::= <letter> | "_" | "@" | "#"

<id-chars>               ::= <id-start-char> | <digit> | "$"

<bracketed-id-chars>     ::= any character except "]"
```

Body: A single `USE <name>` statement line.

Inputs:

- `DatabaseName` (string) — the target database name.
- `BracketQuoted` (bool, default `false`) — whether to render the name as `[Name]` or as a plain identifier.

Output: The rendered `USE` statement text.

<!-- markdownlint-disable MD038 -->

Processing: Writes `USE ` then the database name (bracketed if `BracketQuoted = true`), then a newline.

<!-- markdownlint-enable MD038 -->

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/language-elements/use-transact-sql?view=sql-server-ver16
```

---

### `<set-option-statement>` Rule Primitive

**Philote ID:** `"e7b6c5f4-5f60-4e9f-c031-4c5d6e7f8091"`

Description: The `SET` option statement configures a session-level behavior flag such as `ANSI_NULLS` or `QUOTED_IDENTIFIER`. These must appear in their own batch preceding any DDL that depends on them, because SQL Server bakes the flag values into the compiled form of UDFs, stored procedures, views, and triggers.

```bnf
<set-option-statement>   ::= "SET" <ws> <option-name> <ws> <option-value> <statement-terminator>?

<option-name>            ::= "ANSI_NULLS"
                           | "QUOTED_IDENTIFIER"
                           | "ANSI_PADDING"
                           | "ANSI_WARNINGS"
                           | "NOCOUNT"
                           | "XACT_ABORT"
                           | <identifier>

<option-value>           ::= "ON" | "OFF"
```

Body: A single `SET <option> <value>` statement line.

Inputs:

- `OptionName` (string) — the session option name.
- `OptionValue` (enum: `ON` | `OFF`) — the value to assign.

Output: The rendered `SET` option statement text.

Processing: Writes `SET <OptionName> <OptionValue>`, then a newline.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/statements/set-ansi-nulls-transact-sql?view=sql-server-ver16
2. https://learn.microsoft.com/en-us/sql/t-sql/statements/set-quoted-identifier-transact-sql?view=sql-server-ver16
3. https://learn.microsoft.com/en-us/sql/t-sql/statements/set-statements-transact-sql?view=sql-server-ver16
```

---

### `<single-line-comment>` Rule Primitive

**Philote ID:** `"f8a7d6e5-6071-4f0a-d142-5d6e7f809102"`

Description: A single-line T-SQL comment begins with `--` and extends to the end of the line. It may appear on its own line or at the end of a statement line (inline comment). When multiple `--` lines begin with repeating punctuation characters such as `=` or `-`, they form a visual separator, but syntactically each remains an independent single-line comment.

```bnf
<single-line-comment>    ::= "--" <comment-text>? <new-line>

<comment-text>           ::= <comment-char>
                           | <comment-text> <comment-char>

<comment-char>           ::= any character except <new-line-character>
```

Body: A single `-- <text>` line.

Inputs:

- `CommentText` (string, optional) — text after `--`. May be empty (produces `--` alone) or contain any characters except newline.

Output: The rendered comment line.

Processing: Writes `--`, then a space and `CommentText` when provided, then a newline.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/language-elements/comment-transact-sql?view=sql-server-ver16
```

---

### `<block-comment>` Rule Primitive

**Philote ID:** `"09b8e7f6-7182-4a1b-e253-6e7f8091a234"`

Description: A T-SQL block comment is delimited by `/*` and `*/` and may span multiple lines. It may appear anywhere that whitespace is valid. Block comments may be used for both inline annotation and section headers. SQL Server supports nested block comments.

```bnf
<block-comment>          ::= "/*" <block-comment-body> "*/"

<block-comment-body>     ::= <block-comment-char>*
                           | <block-comment>

<block-comment-char>     ::= any character except the sequence "*/"
```

Body: The full `/* ... */` text, including interior newlines.

Inputs:

- `CommentBody` (string) — the raw interior text. May be empty, single-line, or multi-line.
- `InlineStyle` (bool, default `false`) — when `true`, renders on a single line; when `false`, each interior line is indented.

Output: The rendered block-comment text.

Processing: Writes `/*`, then `CommentBody`, then `*/`.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/language-elements/slash-star-comment-transact-sql?view=sql-server-ver16
```

---

### `<separator-comment-block>` Rule Primitive

**Philote ID:** `"1ac9f8e7-8293-4b2c-f364-7f8091ab2345"`

Description: A separator comment block is a visual divider composed of two or more `<single-line-comment>` lines: an opening rule line (a `--` followed by a run of `=` or `-` characters), one or more body lines carrying prose text, and a closing rule line of the same style. This is a higher-level compositional primitive; it renders to a sequence of `<single-line-comment>` instances.

```bnf
<separator-comment-block> ::= <comment-rule-line>
                              <comment-body-line>+
                              <comment-rule-line>

<comment-rule-line>       ::= "--" <rule-chars>+ <new-line>

<rule-chars>              ::= "=" | "-" | " "

<comment-body-line>       ::= "--" <ws>? <comment-text>? <new-line>
```

Body: Three or more rendered `<single-line-comment>` lines forming a box.

Inputs:

- `RuleChar` (char, default `=`) — the repeating character used for the top and bottom rule lines.
- `RuleWidth` (int, default 48) — total character width of the rule line (including `--`). -<!-- markdownlint-disable MD038 -->
- `BodyLines` (ordered list of strings) — one or more lines of prose rendered between the two rule lines, each prefixed with `-- `.
  <!-- markdownlint-enable MD038 -->
  Output: The rendered separator block text.

Processing: Renders the opening rule line, then each body line as a `<single-line-comment>`, then the closing rule line.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/language-elements/comment-transact-sql?view=sql-server-ver16
2. https://www.sqlstyle.guide/ (visual separator convention)
```

---

### `<object-existence-guard>` Rule Primitive

**Philote ID:** `"2bdae9f8-93a4-4c3d-a475-8091a2bc3456"`

Description: An object-existence guard uses `OBJECT_ID()` to test whether a database object exists before attempting to drop it. This pattern makes DDL scripts idempotent — safe to re-run on environments where the object may or may not already exist.

```bnf
<object-existence-guard>  ::= "IF" <ws> <object-id-test> <new-line>?
                              <ws>* <drop-statement> <statement-terminator>?

<object-id-test>          ::= "OBJECT_ID" <ws>? "(" <object-id-args> ")" <ws> "IS NOT NULL"

<object-id-args>          ::= <string-literal>
                            | <string-literal> "," <ws>? <string-literal>

<drop-statement>          ::= "DROP" <ws> <object-type> <ws> <object-name>

<object-type>             ::= "FUNCTION" | "PROCEDURE" | "TABLE" | "VIEW"
                            | "TRIGGER" | "INDEX" | "TYPE"
```

Body: The complete `IF OBJECT_ID(...) IS NOT NULL DROP <type> <name>` statement.

Inputs:

- `ObjectIdArg1` (string) — the object name string passed as first argument to `OBJECT_ID()`.
- `ObjectIdArg2` (string, optional) — the object type code string, e.g., `'U'` for table.
- `ObjectType` (enum: `FUNCTION` | `PROCEDURE` | `TABLE` | `VIEW` | `TRIGGER`) — the DDL object type.
- `ObjectName` (string) — the fully-qualified name of the object to drop.
- `UseNPrefix` (bool, default `false`) — prepend `N` to the first `OBJECT_ID` argument for Unicode.

Output: The rendered existence-guard statement.

Processing: Writes the `IF OBJECT_ID(...)` test on one line and the `DROP` statement indented on the next.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/functions/object-id-transact-sql?view=sql-server-ver16
2. https://learn.microsoft.com/en-us/sql/t-sql/statements/drop-function-transact-sql?view=sql-server-ver16
3. https://learn.microsoft.com/en-us/sql/t-sql/statements/drop-table-transact-sql?view=sql-server-ver16
```

---

### `<declare-statement>` Rule Primitive

**Philote ID:** `"3cebfa09-a4b5-4d4e-b586-91a2b3cd4567"`

Description: The `DECLARE` statement introduces one or more local variables into the current batch scope. Multiple variables may be declared in a single `DECLARE` statement, separated by commas. Each variable has a name prefixed with `@`, a data type, an optional length/precision/scale, and an optional initial value.

```bnf
<declare-statement>       ::= "DECLARE" <new-line>?
                              <declare-variable-list>
                              <statement-terminator>?

<declare-variable-list>   ::= <declare-variable>
                            | <declare-variable-list> <new-line>? "," <declare-variable>

<declare-variable>        ::= <ws>* "@" <identifier> <ws> <data-type-spec>
                              <declare-default>?

<declare-default>         ::= <ws> "=" <ws> <scalar-expression>

<data-type-spec>          ::= <type-name>
                            | <type-name> "(" <decimal-digits> ")"
                            | <type-name> "(" <decimal-digits> "," <decimal-digits> ")"
                            | <type-name> "(" "max" ")"
```

Body: The `DECLARE` keyword followed by a comma-separated (or comma-prefixed) list of variable declarations.

Inputs:

- `Variables` (ordered list of `{Name, DataType, DefaultValue?}`) — the variable declarations.
- `LeadingCommaStyle` (bool, default `false`) — when `true`, commas precede each non-first variable.

Output: The rendered `DECLARE` statement text.

Processing: Writes `DECLARE`, then renders each variable declaration on its own indented line; commas either trail (default) or lead (when `LeadingCommaStyle = true`).

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/language-elements/declare-local-variable-transact-sql?view=sql-server-ver16
2. https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-types-transact-sql?view=sql-server-ver16
```

---

### `<set-variable-statement>` Rule Primitive

**Philote ID:** `"4dfc0b1a-b5c6-4e5f-c697-a2b3c4de5678"`

Description: The `SET @variable = expression` statement assigns a scalar value to a previously declared local variable. The expression may be a literal, a function call, a subquery, or any valid scalar expression.

```bnf
<set-variable-statement>  ::= "set" <ws> "@" <identifier> <ws>
                              "=" <ws> <scalar-expression>
                              <statement-terminator>?

<scalar-expression>       ::= <literal>
                            | "@" <identifier>
                            | <function-call>
                            | "(" <scalar-expression> ")"
                            | <scalar-expression> <arithmetic-op> <scalar-expression>
```

Body: A single `set @var = expr` statement line.

Inputs:

- `VariableName` (string) — the variable name (without `@`; the primitive renders it).
- `Expression` (string) — the right-hand-side expression text.
- `InlineComment` (string, optional) — a trailing `-- comment` appended to the line.

Output: The rendered `set @variable = expression` statement.

Processing: Writes `set @<VariableName> = <Expression>`, appends inline comment when provided, then a newline.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-local-variable-transact-sql?view=sql-server-ver16
```

---

### `<select-from-order-statement>` Rule Primitive

**Philote ID:** `"5e0d1c2b-c6d7-4f60-d7a8-b3c4d5ef6789"`

Description: A `SELECT ... FROM ... ORDER BY` statement retrieves rows from a table, view, or table-valued function. The `FROM` clause can reference a UDF call with arguments. This primitive captures the complete query form used to test a TVF, including an optional `ORDER BY` clause.

```bnf
<select-from-order-statement> ::= "SELECT" <ws> <select-list>
                                  <new-line> "FROM" <new-line>
                                  <table-source>
                                  <order-by-clause>?

<select-list>             ::= "*"
                            | <select-item>
                            | <select-list> "," <select-item>

<table-source>            ::= <table-name>
                            | <function-call> <alias>?

<function-call>           ::= <schema-qualified-name> "(" <argument-list>? ")"

<argument-list>           ::= <scalar-expression>
                            | <argument-list> "," <ws>? <scalar-expression>

<order-by-clause>         ::= "ORDER BY" <ws> <order-item> <order-direction>?

<order-direction>         ::= "ASC" | "DESC"
```

Body: The complete `SELECT ... FROM ... ORDER BY` query block.

Inputs:

- `SelectList` (string, default `*`) — the column or expression list.
- `FromSource` (string) — the table name or TVF call expression.
- `FunctionArgs` (ordered list of `{Expression}`, optional) — arguments to the TVF.
- `OrderByColumn` (string, optional) — the column name for `ORDER BY`.
- `OrderByDirection` (enum: `ASC` | `DESC`, default `ASC`) — sort direction.

Output: The rendered SELECT query text.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/queries/select-transact-sql?view=sql-server-ver16
2. https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql?view=sql-server-ver16
3. https://learn.microsoft.com/en-us/sql/t-sql/queries/select-order-by-clause-transact-sql?view=sql-server-ver16
```

---

### `<function-parameter>` Rule Primitive

**Philote ID:** `"70a3e4d4-e8f9-4182-f9ca-d5e6f7a14901"`

Description: A single parameter declaration in the header of a `CREATE FUNCTION` or `CREATE PROCEDURE` statement. Each parameter has a name prefixed with `@`, a data type with optional length/precision, and an optional default value.

```bnf
<function-parameter>      ::= <ws>* "@" <identifier> <ws> <data-type-spec>
                              <parameter-default>?

<parameter-default>       ::= <ws> "=" <ws> <scalar-expression>
```

Body: One parameter declaration line, e.g., `@period_units char`.

Inputs:

- `ParameterName` (string) — name without `@` prefix.
- `DataType` (string) — T-SQL data type.
- `DefaultValue` (string, optional) — default value expression.
- `LeadingCommaStyle` (bool, default `true`) — when `true` and not the first parameter, prefix the line with `,`.

Output: The rendered parameter declaration text.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/statements/create-function-transact-sql?view=sql-server-ver16#parameters
```

---

### `<returns-table-clause>` Rule Primitive

**Philote ID:** `"81b4f5e5-f9a0-4293-aadb-e6f7081b5a12"`

Description: The `RETURNS @variable TABLE (...)` clause in a multi-statement TVF declares the return variable and the schema of the returned table.

```bnf
<returns-table-clause>    ::= "RETURNS" <ws> <returns-variant>

<returns-variant>         ::= "@" <identifier> <ws> "TABLE" <new-line>?
                              "(" <new-line>? <table-column-spec-list> <new-line>? ")"
                            | "TABLE"

<table-column-spec-list>  ::= <table-column-spec>
                            | <table-column-spec-list> <new-line>? "," <table-column-spec>

<table-column-spec>       ::= <ws>* <column-name> <ws> <data-type-spec> <nullability>?

<nullability>             ::= "NULL" | "NOT NULL"
```

Body: The `RETURNS @variable TABLE (column-list)` declaration block.

Inputs:

- `ReturnVariable` (string, optional) — the name of the table variable (without `@`). When absent, renders `RETURNS TABLE`.
- `Columns` (ordered list of `{Name, DataType, Nullable?}`) — the return table column definitions.

Output: The rendered `RETURNS` clause text.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/statements/create-function-transact-sql?view=sql-server-ver16#table-valued-functions
```

---

### `<create-function-tvf-statement>` Rule Primitive

**Philote ID:** `"6f1e2d3c-d7e8-4071-e8b9-c4d5e6f07890"`

Description: The `CREATE FUNCTION` statement defines a multi-statement table-valued function (mTVF). An mTVF declares a return table variable, populates it within a `BEGIN ... END` block, and returns it with a bare `RETURN` statement.

```bnf
<create-function-tvf-statement> ::= "CREATE FUNCTION" <ws> <schema-qualified-name>
                                    "(" <new-line>? <function-parameter-list>? ")"
                                    <new-line>
                                    <returns-table-clause>
                                    <new-line>
                                    "AS" <new-line>
                                    "begin" <new-line>
                                    <function-body-statement-list>
                                    "end"

<function-parameter-list>       ::= <function-parameter>
                                  | <function-parameter-list> "," <function-parameter>

<function-body-statement-list>  ::= <function-body-statement>+

<function-body-statement>       ::= <cte-clause>
                                  | <insert-into-select-statement>
                                  | <return-statement>
                                  | <set-variable-statement>
                                  | <single-line-comment>
```

Body: The full `CREATE FUNCTION ... AS begin ... end` text block.

Inputs:

- `SchemaName` (string, default `dbo`) — schema qualifier.
- `FunctionName` (string) — unqualified function name.
- `BracketQuoted` (bool, default `true`) — whether to bracket-quote the schema and function name.
- `Parameters` (ordered list of `<function-parameter>` instances) — the input parameters.
- `ReturnsClause` (a `<returns-table-clause>` instance) — the return type declaration.
- `BodyStatements` (ordered list of function-body statement instances) — the statements in `begin ... end`.

Output: The rendered `CREATE FUNCTION` statement text.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/statements/create-function-transact-sql?view=sql-server-ver16
2. https://learn.microsoft.com/en-us/sql/relational-databases/user-defined-functions/create-user-defined-functions-database-engine?view=sql-server-ver16
```

---

### `<cte-clause>` Rule Primitive

**Philote ID:** `"92c5a6f6-0ab1-43a4-bbec-f7081c2c6b23"`

Description: A Common Table Expression (CTE) introduced by the `WITH` keyword defines a named, temporary result set within the scope of a single DML statement. CTEs may be recursive (using `UNION ALL` with a self-reference), which is the pattern used in `udf_dateperiod` to generate a sequence of period numbers.

```bnf
<cte-clause>              ::= "with" <ws> <cte-name> <ws>?
                              "(" <column-name-list>? ")" <ws>
                              "as" <ws> "(" <cte-query> ")"

<cte-query>               ::= <union-all-query>
                            | <select-body>

<union-all-query>         ::= <select-body>
                              "Union All"
                              <select-body> <where-clause>?

<where-clause>            ::= "where" <ws> <search-condition>
```

Body: The `with <name>(<cols>) as (<query>)` block that precedes the DML statement consuming it.

Inputs:

- `CteNames` (ordered list of `{Name, ColumnNames?, QueryBody}`) — one CTE anchor per entry.
- `IsRecursive` (bool) — when `true`, the CTE uses `Union All` self-reference and requires `OPTION (MAXRECURSION N)` on the outer query.

Output: The rendered CTE block text.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/queries/with-common-table-expression-transact-sql?view=sql-server-ver16
```

---

### `<insert-into-select-statement>` Rule Primitive

**Philote ID:** `"a3d6b7e7-1bc2-44b5-ccfd-081d2d3d7c34"`

Description: An `INSERT INTO @variable SELECT ... FROM ... OPTION(...)` statement populates a table variable or physical table from a query. When the `FROM` clause references a CTE, the CTE must immediately precede this statement (they share a single batch scope). A `<query-hint-clause>` following the query can limit recursion depth.

```bnf
<insert-into-select-statement> ::= "Insert into" <ws> "@" <identifier>
                                   <ws> "SELECT" <new-line>
                                   <select-item-list>
                                   <new-line> "from" <ws> "(" <subquery> ")" <ws> <alias>
                                   <query-hint-clause>?

<select-item-list>        ::= <select-item>
                            | <select-item-list> <new-line>? "," <select-item>
```

Body: The complete `Insert into @t SELECT ... from (...) option(...)` text.

Inputs:

- `TargetVariable` (string) — the table variable name (without `@`).
- `SelectItems` (ordered list of strings) — the column expressions.
- `FromSubquery` (string) — the subquery or CTE-reference expression in the FROM clause.
- `FromAlias` (string) — the alias for the FROM source.
- `QueryHint` (a `<query-hint-clause>` instance, optional) — appended after the FROM clause.

Output: The rendered INSERT-SELECT statement text.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/statements/insert-transact-sql?view=sql-server-ver16
```

---

### `<case-when-expression>` Rule Primitive

**Philote ID:** `"b4e7c8f8-2cd3-45c6-ddae-192e3e4e8d45"`

Description: A `CASE WHEN ... THEN ... END` expression evaluates conditions in order and returns the value of the first matching `WHEN` branch. The `udf_dateperiod` function uses a searched `CASE` (with explicit `WHEN <condition>` rather than `CASE <expr> WHEN <value>`) to dispatch on `@period_units`.

```bnf
<case-when-expression>    ::= "case" <ws>?
                              <when-clause>+
                              <else-clause>?
                              <ws>? "end"

<when-clause>             ::= <ws>* "when" <ws> <search-condition>
                              <ws> "then" <new-line> <ws>* <scalar-expression>

<else-clause>             ::= <ws>* "else" <new-line> <ws>* <scalar-expression>
```

Body: The multi-line `case when ... then ... end` expression text.

Inputs:

- `WhenClauses` (ordered list of `{Condition: string, ResultExpression: string, InlineComment?: string}`) — the WHEN/THEN branches.
- `ElseExpression` (string, optional) — the ELSE value.
- `ResultAlias` (string, optional) — the column alias appended after `end`.

Output: The rendered CASE expression text.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/language-elements/case-transact-sql?view=sql-server-ver16
```

---

### `<query-hint-clause>` Rule Primitive

**Philote ID:** `"c5f8d9a9-3de4-46d7-eebf-2a3f4f5f9e56"`

Description: The `OPTION (...)` clause appended to a DML statement provides hints to the query optimizer. The `MAXRECURSION` hint is mandatory for recursive CTEs that can iterate beyond the default 100 times.

```bnf
<query-hint-clause>       ::= "option" <ws> "(" <query-hint-list> ")"

<query-hint-list>         ::= <query-hint>
                            | <query-hint-list> "," <ws>? <query-hint>

<query-hint>              ::= "maxrecursion" <ws> <decimal-digits>
                            | "recompile"
                            | "fast" <ws> <decimal-digits>
                            | "force order"
```

Inputs:

- `Hints` (ordered list of `{HintName: string, HintValue?: string}`) — one or more optimizer hints.

Output: The rendered `option (...)` string.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query?view=sql-server-ver16
2. https://learn.microsoft.com/en-us/sql/t-sql/queries/with-common-table-expression-transact-sql?view=sql-server-ver16#recursive-ctes
```

---

### `<return-statement>` Rule Primitive

**Philote ID:** `"091cdecd-7128-4abb-22f3-6e7383939290"`

Description: The bare `return` statement inside a multi-statement TVF exits the function body, returning the populated table variable to the caller.

```bnf
<return-statement>        ::= "return" <statement-terminator>?
```

Inputs:

- `ReturnExpression` (string, optional) — a scalar expression following `return`. Absent for TVFs.

Output: The rendered `return` statement.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/language-elements/return-transact-sql?view=sql-server-ver16
```

---

### `<create-table-statement>` Rule Primitive

**Philote ID:** `"d6e9eaba-4ef5-47e8-ffc0-3b405060af67"`

Description: The `CREATE TABLE` statement defines a new base table in the database. The table definition includes a schema-qualified name, an ordered list of column definitions, and optional inline constraints.

```bnf
<create-table-statement>  ::= "CREATE TABLE" <ws> <schema-qualified-name>
                              <new-line>? "("
                              <new-line>? <table-element-list>
                              <new-line>? ")" ";"?

<table-element-list>      ::= <table-element>
                            | <table-element-list> <new-line>? "," <table-element>

<table-element>           ::= <column-definition>
                            | <inline-table-constraint>
```

Inputs:

- `SchemaName` (string, default `dbo`) — schema qualifier.
- `TableName` (string) — unqualified table name.
- `BracketQuoted` (bool, default `false`) — whether to bracket-quote schema and table names.
- `TableElements` (ordered list of `<column-definition>` and `<inline-table-constraint>` instances).

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql?view=sql-server-ver16
```

---

### `<column-definition>` Rule Primitive

**Philote ID:** `"e7fabcbb-5f06-48f9-00d1-4c5161717078"`

Description: A column definition declares the name, data type, nullability, and identity settings for a single column within a `CREATE TABLE` or `RETURNS TABLE` clause.

```bnf
<column-definition>       ::= <column-name> <ws> <data-type-spec>
                              <identity-spec>?
                              <nullability>?

<column-name>             ::= <regular-identifier>
                            | <bracketed-identifier>

<identity-spec>           ::= "IDENTITY" "(" <decimal-digits> "," <decimal-digits> ")"

<nullability>             ::= "NULL" | "NOT NULL"
```

Inputs:

- `ColumnName` (string) — the column name; bracket-quoted if it is a reserved word.
- `DataType` (string) — the T-SQL data type with optional length / precision / scale.
- `Identity` (`{Seed: int, Increment: int}`, optional) — renders `IDENTITY(seed,increment)`.
- `Nullable` (enum: `NULL` | `NOT NULL` | `omit`, default `omit`) — nullability constraint.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql?view=sql-server-ver16#column_definition
2. https://learn.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql-identity-property?view=sql-server-ver16
```

---

### `<inline-table-constraint>` Rule Primitive

**Philote ID:** `"f80bcdcc-6017-49ea-11e2-5d6272828189"`

Description: An inline table constraint is declared inside the `CREATE TABLE` column list and defines a named constraint that applies to one or more columns of the table.

```bnf
<inline-table-constraint> ::= "CONSTRAINT" <ws> <constraint-name>
                              <ws> <constraint-type-clause>

<constraint-type-clause>  ::= "PRIMARY KEY" <clustered>? "(" <column-name-list> ")"
                            | "UNIQUE" <clustered>? "(" <column-name-list> ")"
                            | "CHECK" "(" <search-condition> ")"
                            | "FOREIGN KEY" "(" <column-name-list> ")"
                              "REFERENCES" <ws> <schema-qualified-name> "(" <column-name-list> ")"

<clustered>               ::= "CLUSTERED" | "NONCLUSTERED"
```

Inputs:

- `ConstraintName` (string) — the constraint name.
- `ConstraintType` (enum: `PRIMARY KEY` | `UNIQUE` | `CHECK` | `FOREIGN KEY`) — the constraint type.
- `Clustered` (enum: `CLUSTERED` | `NONCLUSTERED` | `omit`, default `omit`).
- `Columns` (list of strings) — the column names participating in the constraint.

Attribution:

```text
1. https://learn.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql?view=sql-server-ver16#constraints
2. https://learn.microsoft.com/en-us/sql/relational-databases/tables/primary-and-foreign-key-constraints?view=sql-server-ver16
```

---

## A Single Rule Definition

A Rule is a named composition of one or more Rule Primitives with bound input values. A Rule has a Philote ID, a name, a purpose statement, a source file path, and an ordered Primitive Composition Table. The composition table lists each primitive instance in render order with its bound input values. A Rule is the specification from which a single SQL script file can be rendered exactly.

## How Rules Combine into Rule Sets

A Rule Set groups related Rules and defines the directed execution graph — which Rule feeds into which. For database schema management, a Rule Set might group a `CREATE TABLE` Rule, a `CREATE INDEX` Rule, and a seed-data Rule, with a directed edge ensuring the table is created before the index.

## How an Instantiation Processes Inputs

An instantiation is a specific execution of a Build Set. For SQL scripts, "execution" means rendering the script text and then running it against a target SQL Server instance. Inputs include the target database name, environment, and any variable values substituted into script templates.

---

## Feature / Module / Rule Set

### Philote Database — SQL Script Rules

The three Rules below generate the SQL scripts found in the `src/ATAP.Utilities.Philote/Database/` directory tree. Each Rule is self-contained: binding the inputs listed in its Primitive Composition Table and rendering each primitive in order produces the exact file content.

---

#### Rule: Test_udf_dateperiod

**Philote ID:** `"7a1b2c3d-4e5f-4061-8273-a4b5c6d7e8f9"`

**Purpose:** Generate a runnable T-SQL query script that exercises the `dbo.udf_dateperiod` table-valued function by declaring test parameters, assigning sample values, calling the TVF, and ordering the results.

**Source file:** `src/ATAP.Utilities.Philote/Database/Queries/Test_udf_dateperiod.sql`

**Top-level BNF derivation:**

```text
<sql-script-file>
├── <use-statement>          →  "USE [Coral8_ETL]"
├── <go-separator>
└── <batch>  [main test batch]
    ├── <separator-comment-block>
    ├── <declare-statement>   →  DECLARE (5 variables)
    ├── <set-variable-statement> ×5
    ├── <single-line-comment> ×8 (inline notes and commented-out alternates)
    ├── <select-from-order-statement>  →  SELECT * FROM DBO.udf_dateperiod(...)
    └── <single-line-comment> ×16 (commented-out alternative block)
```

**Primitive Composition Table**

| #     | Primitive                       | Philote ID                             | Role                  | Bound Inputs                                                                                         |
| ----- | ------------------------------- | -------------------------------------- | --------------------- | ---------------------------------------------------------------------------------------------------- |
| 1     | `<sql-script-file>`             | `a3f2e1d0-1b2c-4a5b-8c9d-0e1f2a3b4c5d` | File container        | `Elements` = [items 2–end]                                                                           |
| 2     | `<use-statement>`               | `d6c5d4a3-4e5f-4d8e-bf20-3b4c5d6e7f80` | Database context      | `DatabaseName` = `Coral8_ETL`; `BracketQuoted` = `true`                                              |
| 3     | `<go-separator>`                | `c5d4e3b2-3d4e-4c7d-ae1f-2a3b4c5d6e7f` | Batch delimiter       | _(no count)_                                                                                         |
| 4     | `<batch>`                       | `b4e3f2c1-2c3d-4b6c-9d0e-1f2a3b4c5d6e` | Main test batch       | `Statements` = [items 5–end]                                                                         |
| 5     | `<separator-comment-block>`     | `1ac9f8e7-8293-4b2c-f364-7f8091ab2345` | Section header        | `RuleChar` = `=`; `BodyLines` = `["Test UDF that ....", "Version vvv (date)"]`                       |
| 6     | `<declare-statement>`           | `3cebfa09-a4b5-4d4e-b586-91a2b3cd4567` | Variable declarations | `LeadingCommaStyle` = `true`; `Variables` = see table below                                          |
| 7     | `<single-line-comment>`         | `f8a7d6e5-6071-4f0a-d142-5d6e7f809102` | Inline note           | `CommentText` = `" Use hours"`                                                                       |
| 8     | `<set-variable-statement>`      | `4dfc0b1a-b5c6-4e5f-c697-a2b3c4de5678` | Assign period units   | `VariableName` = `periodunits`; `Expression` = `'s'`                                                 |
| 9     | `<single-line-comment>`         | `f8a7d6e5-6071-4f0a-d142-5d6e7f809102` | Inline note           | `CommentText` = `"  24 units (hour) in a period..."`                                                 |
| 10    | `<set-variable-statement>`      | `4dfc0b1a-b5c6-4e5f-c697-a2b3c4de5678` | Assign period count   | `VariableName` = `numunitsinperiod`; `Expression` = `1`                                              |
| 11    | `<single-line-comment>`         | `f8a7d6e5-6071-4f0a-d142-5d6e7f809102` | Inline note           | `CommentText` = `"Set the start date to yesterday, midnight"`                                        |
| 12    | `<single-line-comment>`         | `f8a7d6e5-6071-4f0a-d142-5d6e7f809102` | Commented-out stmt    | `CommentText` = `"set @startdate = Dateadd(d,-1,convert(datetime,floor(convert(float,GETDATE()))))"` |
| 13    | `<set-variable-statement>`      | `4dfc0b1a-b5c6-4e5f-c697-a2b3c4de5678` | Assign start date     | `VariableName` = `startdate`; `Expression` = `'2008-01-01 1:00:00'`                                  |
| 14    | `<single-line-comment>`         | `f8a7d6e5-6071-4f0a-d142-5d6e7f809102` | Inline note           | `CommentText` = `" The Enddate is always yesterday, 3ms before midnight today"`                      |
| 15    | `<single-line-comment>`         | `f8a7d6e5-6071-4f0a-d142-5d6e7f809102` | Commented-out stmt    | `CommentText` = `"set @enddate = Dateadd(ms,-3,convert(datetime,floor(convert(float,GETDATE()))))"`  |
| 16    | `<set-variable-statement>`      | `4dfc0b1a-b5c6-4e5f-c697-a2b3c4de5678` | Assign end date       | `VariableName` = `enddate`; `Expression` = `'2008-01-01 22:00:00'`                                   |
| 17    | `<single-line-comment>`         | `f8a7d6e5-6071-4f0a-d142-5d6e7f809102` | Inline note           | `CommentText` = `" Calculate @tzoffset from SQL Server's system time"`                               |
| 18    | `<set-variable-statement>`      | `4dfc0b1a-b5c6-4e5f-c697-a2b3c4de5678` | Assign tz offset      | `VariableName` = `tzoffset`; `Expression` = `-5`                                                     |
| 19    | `<select-from-order-statement>` | `5e0d1c2b-c6d7-4f60-d7a8-b3c4d5ef6789` | TVF query             | see inputs below                                                                                     |
| 20–35 | `<single-line-comment>` ×16     | `f8a7d6e5-6071-4f0a-d142-5d6e7f809102` | Commented-out block   | Each line of the alternative SELECT rendered verbatim as `--` comments                               |

**DECLARE variable list (item 6):**

| #   | `@Name`            | `DataType` |
| --- | ------------------ | ---------- |
| 1   | `startdate`        | `datetime` |
| 2   | `enddate`          | `datetime` |
| 3   | `tzoffset`         | `int`      |
| 4   | `periodunits`      | `char(1)`  |
| 5   | `numunitsinperiod` | `int`      |

**TVF function arguments (item 19):**

| Position | Expression          |
| -------- | ------------------- |
| 1        | `@periodunits`      |
| 2        | `@numunitsinperiod` |
| 3        | `@startdate`        |
| 4        | `@enddate`          |
| 5        | `@tzoffset`         |

`SelectList` = `*`; `FromSource` = `DBO.udf_dateperiod`; `OrderByColumn` = `EarlierDTS`; `OrderByDirection` = `ASC`.

---

#### Rule: Create_udf_dateperiod

**Philote ID:** `"8b2c3d4e-5f60-4172-9384-b5c6d7e8f9a0"`

**Purpose:** Generate the DDL script that conditionally drops then creates the `[dbo].[udf_dateperiod]` multi-statement table-valued function, including the recursive CTE that generates time-period rows.

**Source file:** `src/ATAP.Utilities.Philote/Database/Queries/Create_udf_dateperiod.sql`

**Top-level BNF derivation:**

```text
<sql-script-file>
├── <use-statement>          →  USE [Coral8_ETL]
├── <go-separator>
├── <block-comment>          →  /****** Object: UserDefinedFunction ... ******/
├── <go-separator>
├── <separator-comment-block> + <object-existence-guard>
├── <go-separator>
├── <set-option-statement>   →  SET ANSI_NULLS ON
├── <go-separator>
├── <set-option-statement>   →  SET QUOTED_IDENTIFIER ON
├── <go-separator>
├── <separator-comment-block>
├── <go-separator>
└── <create-function-tvf-statement>
    ├── 5 × <function-parameter>
    ├── <returns-table-clause>  →  RETURNS @tx TABLE (2 cols)
    ├── <cte-clause>            →  with rangeperiods(pnum) as (...)
    ├── <insert-into-select-statement>  →  Insert into @tx SELECT ... OPTION(maxrecursion 32767)
    └── <return-statement>
```

**Primitive Composition Table**

| #   | Primitive                         | Philote ID                             | Role             | Bound Inputs                                                                                                                                                                         |
| --- | --------------------------------- | -------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | `<sql-script-file>`               | `a3f2e1d0-1b2c-4a5b-8c9d-0e1f2a3b4c5d` | File container   | `Elements` = [items 2–end]                                                                                                                                                           |
| 2   | `<use-statement>`                 | `d6c5d4a3-4e5f-4d8e-bf20-3b4c5d6e7f80` | Database context | `DatabaseName` = `Coral8_ETL`; `BracketQuoted` = `true`                                                                                                                              |
| 3   | `<go-separator>`                  | `c5d4e3b2-3d4e-4c7d-ae1f-2a3b4c5d6e7f` | Batch delimiter  | _(no count)_                                                                                                                                                                         |
| 4   | `<block-comment>`                 | `09b8e7f6-7182-4a1b-e253-6e7f8091a234` | Script metadata  | `CommentBody` = `"****** Object:  UserDefinedFunction [dbo].[udf_dateperiod]    Script Date: 09/18/2007 11:00:30 ******"`; `InlineStyle` = `true`                                    |
| 5   | `<go-separator>`                  | `c5d4e3b2-3d4e-4c7d-ae1f-2a3b4c5d6e7f` | Batch delimiter  | _(no count)_                                                                                                                                                                         |
| 6   | `<separator-comment-block>`       | `1ac9f8e7-8293-4b2c-f364-7f8091ab2345` | Section header   | `RuleChar` = `=`; `BodyLines` = `["Drop function if it exists"]`                                                                                                                     |
| 7   | `<object-existence-guard>`        | `2bdae9f8-93a4-4c3d-a475-8091a2bc3456` | Idempotent drop  | `ObjectIdArg1` = `N'dbo.udf_dateperiod'`; `UseNPrefix` = `true`; `ObjectType` = `FUNCTION`; `ObjectName` = `[dbo].[udf_dateperiod]`                                                  |
| 8   | `<go-separator>`                  | `c5d4e3b2-3d4e-4c7d-ae1f-2a3b4c5d6e7f` | Batch delimiter  | _(no count)_                                                                                                                                                                         |
| 9   | `<set-option-statement>`          | `e7b6c5f4-5f60-4e9f-c031-4c5d6e7f8091` | Session flag     | `OptionName` = `ANSI_NULLS`; `OptionValue` = `ON`                                                                                                                                    |
| 10  | `<go-separator>`                  | `c5d4e3b2-3d4e-4c7d-ae1f-2a3b4c5d6e7f` | Batch delimiter  | _(no count)_                                                                                                                                                                         |
| 11  | `<set-option-statement>`          | `e7b6c5f4-5f60-4e9f-c031-4c5d6e7f8091` | Session flag     | `OptionName` = `QUOTED_IDENTIFIER`; `OptionValue` = `ON`                                                                                                                             |
| 12  | `<go-separator>`                  | `c5d4e3b2-3d4e-4c7d-ae1f-2a3b4c5d6e7f` | Batch delimiter  | _(no count)_                                                                                                                                                                         |
| 13  | `<separator-comment-block>`       | `1ac9f8e7-8293-4b2c-f364-7f8091ab2345` | Section header   | `RuleChar` = `=`; `BodyLines` = `["Create Inline Table-valued Function template"]`                                                                                                   |
| 14  | `<go-separator>`                  | `c5d4e3b2-3d4e-4c7d-ae1f-2a3b4c5d6e7f` | Batch delimiter  | _(no count)_                                                                                                                                                                         |
| 15  | `<create-function-tvf-statement>` | `6f1e2d3c-d7e8-4071-e8b9-c4d5e6f07890` | TVF definition   | `SchemaName` = `dbo`; `FunctionName` = `udf_dateperiod`; `BracketQuoted` = `true`; `Parameters` = [item 16]; `ReturnsClause` = returns table below; `BodyStatements` = [items 17–20] |

**CREATE FUNCTION parameter list:**

| #   | `@ParameterName`  | `DataType` |
| --- | ----------------- | ---------- |
| 1   | `period_units`    | `char`     |
| 2   | `period_duration` | `int`      |
| 3   | `dtstart`         | `datetime` |
| 4   | `dtend`           | `datetime` |
| 5   | `TZOffset`        | `int`      |

**RETURNS table columns (`<returns-table-clause>`, `ReturnVariable` = `tx`):**

| #   | `ColumnName` | `DataType` |
| --- | ------------ | ---------- |
| 1   | `earlierdts` | `datetime` |
| 2   | `laterdts`   | `datetime` |

**Function body statements:**

| #   | Primitive                        | Philote ID                             | Role               | Bound Inputs                                                                                                                                                                                     |
| --- | -------------------------------- | -------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 16  | `<function-parameter>` ×5        | `70a3e4d4-e8f9-4182-f9ca-d5e6f7a14901` | Input params       | See parameter table above; `LeadingCommaStyle` = `true` for items 2–5                                                                                                                            |
| 17  | `<cte-clause>`                   | `92c5a6f6-0ab1-43a4-bbec-f7081c2c6b23` | Recursive sequence | `CteNames` = `[{Name: "rangeperiods", ColumnNames: ["pnum"], QueryBody: "select 0 Union All select pnum + 1 from rangeperiods where pnum < <CASE-WHEN-bounds>"}]`; `IsRecursive` = `true`        |
| 18  | `<insert-into-select-statement>` | `a3d6b7e7-1bc2-44b5-ccfd-081d2d3d7c34` | Populate result    | `TargetVariable` = `tx`; `SelectItems` = [`<case-when>` for earlierDTS, `<case-when>` for laterDTS]; `FromSubquery` = `select pnum from rangeperiods`; `FromAlias` = `rp`; `QueryHint` = item 19 |
| 19  | `<query-hint-clause>`            | `c5f8d9a9-3de4-46d7-eebf-2a3f4f5f9e56` | Recursion limit    | `Hints` = `[{HintName: "maxrecursion", HintValue: "32767"}]`                                                                                                                                     |
| 20  | `<return-statement>`             | `091cdecd-7128-4abb-22f3-6e7383939290` | Exit function      | `ReturnExpression` = _(none)_                                                                                                                                                                    |

**`CASE WHEN` branches dispatching on `@period_units` (abridged):**

| Branch | `Condition`           | Role                                |
| ------ | --------------------- | ----------------------------------- |
| 1      | `@period_units = 'm'` | Compute minute-based offset / bound |
| 2      | `@period_units = 'h'` | Compute hour-based offset / bound   |
| 3      | `@period_units = 's'` | Compute second-based offset / bound |

---

#### Rule: V00.01.000010\_\_Create_Philote_Core_Schema

**Philote ID:** `"9c3d4e5f-60a1-4283-a495-c6d7e8f9b0a1"`

**Purpose:** Generate the Flyway versioned migration script that sets session options, safely drops any pre-existing `dbo.Philotes` table in dependency order, and creates the `dbo.Philotes` base table with its primary key constraint.

**Source file:** `src/ATAP.Utilities.Philote/Database/Flyway/DATA/V00.01.000010__Create_Philote_Core_Schema.sql`

**Top-level BNF derivation:**

```text
<sql-script-file>
├── <use-statement>           →  USE Philotes
├── <go-separator>
├── <set-option-statement> ×2 →  SET ANSI_NULLS ON / SET QUOTED_IDENTIFIER ON
├── <go-separator>
├── <block-comment> ×4        →  dependency-order drop placeholders (triggers, views, procs, tables)
│   each followed by <go-separator>
├── <block-comment>           →  /* Drop tables in dependency order */
├── <object-existence-guard>  →  IF OBJECT_ID('dbo.Philotes','U') IS NOT NULL DROP TABLE dbo.Philotes
├── <go-separator>
├── <block-comment>           →  /* === Tables === */
├── <single-line-comment>     →  -- Create referenced tables FIRST
├── <create-table-statement>  →  CREATE TABLE dbo.Philotes (2 cols + PK constraint)
└── <go-separator>
```

**Primitive Composition Table**

| #   | Primitive                  | Philote ID                             | Role                      | Bound Inputs                                                                                                                             |
| --- | -------------------------- | -------------------------------------- | ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `<sql-script-file>`        | `a3f2e1d0-1b2c-4a5b-8c9d-0e1f2a3b4c5d` | File container            | `Elements` = [items 2–end]                                                                                                               |
| 2   | `<use-statement>`          | `d6c5d4a3-4e5f-4d8e-bf20-3b4c5d6e7f80` | Database context          | `DatabaseName` = `Philotes`; `BracketQuoted` = `false`                                                                                   |
| 3   | `<go-separator>`           | `c5d4e3b2-3d4e-4c7d-ae1f-2a3b4c5d6e7f` | Batch delimiter           | _(no count)_                                                                                                                             |
| 4   | `<set-option-statement>`   | `e7b6c5f4-5f60-4e9f-c031-4c5d6e7f8091` | Session flag              | `OptionName` = `ANSI_NULLS`; `OptionValue` = `ON`                                                                                        |
| 5   | `<set-option-statement>`   | `e7b6c5f4-5f60-4e9f-c031-4c5d6e7f8091` | Session flag              | `OptionName` = `QUOTED_IDENTIFIER`; `OptionValue` = `ON`                                                                                 |
| 6   | `<go-separator>`           | `c5d4e3b2-3d4e-4c7d-ae1f-2a3b4c5d6e7f` | Batch delimiter           | _(no count)_                                                                                                                             |
| 7   | `<block-comment>`          | `09b8e7f6-7182-4a1b-e253-6e7f8091a234` | Section intent            | `CommentBody` = `" Drop in dependency order if re-running on a dev box (optional safety) "`; `InlineStyle` = `true`                      |
| 8   | `<block-comment>`          | `09b8e7f6-7182-4a1b-e253-6e7f8091a234` | Drop triggers placeholder | `CommentBody` = `" Drop triggers first (depend on tables) "`; `InlineStyle` = `true`                                                     |
| 9   | `<go-separator>`           | `c5d4e3b2-3d4e-4c7d-ae1f-2a3b4c5d6e7f` | Batch delimiter           | _(no count)_                                                                                                                             |
| 10  | `<block-comment>`          | `09b8e7f6-7182-4a1b-e253-6e7f8091a234` | Drop views placeholder    | `CommentBody` = `" Drop views (depend on tables) "`; `InlineStyle` = `true`                                                              |
| 11  | `<go-separator>`           | `c5d4e3b2-3d4e-4c7d-ae1f-2a3b4c5d6e7f` | Batch delimiter           | _(no count)_                                                                                                                             |
| 12  | `<block-comment>`          | `09b8e7f6-7182-4a1b-e253-6e7f8091a234` | Drop procs placeholder    | `CommentBody` = `" Drop stored procedures "`; `InlineStyle` = `true`                                                                     |
| 13  | `<go-separator>`           | `c5d4e3b2-3d4e-4c7d-ae1f-2a3b4c5d6e7f` | Batch delimiter           | _(no count)_                                                                                                                             |
| 14  | `<block-comment>`          | `09b8e7f6-7182-4a1b-e253-6e7f8091a234` | Section label             | `CommentBody` = `" Drop tables in dependency order "`; `InlineStyle` = `true`                                                            |
| 15  | `<object-existence-guard>` | `2bdae9f8-93a4-4c3d-a475-8091a2bc3456` | Idempotent drop           | `ObjectIdArg1` = `'dbo.Philotes'`; `ObjectIdArg2` = `'U'`; `UseNPrefix` = `false`; `ObjectType` = `TABLE`; `ObjectName` = `dbo.Philotes` |
| 16  | `<go-separator>`           | `c5d4e3b2-3d4e-4c7d-ae1f-2a3b4c5d6e7f` | Batch delimiter           | _(no count)_                                                                                                                             |
| 17  | `<block-comment>`          | `09b8e7f6-7182-4a1b-e253-6e7f8091a234` | Section header            | `CommentBody` = `" === Tables === "`; `InlineStyle` = `true`                                                                             |
| 18  | `<single-line-comment>`    | `f8a7d6e5-6071-4f0a-d142-5d6e7f809102` | Design note               | `CommentText` = `" Create referenced tables FIRST (no foreign key dependencies)"`                                                        |
| 19  | `<create-table-statement>` | `d6e9eaba-4ef5-47e8-ffc0-3b405060af67` | Table DDL                 | `SchemaName` = `dbo`; `TableName` = `Philotes`; `BracketQuoted` = `false`; `TableElements` = [items 20–22]                               |
| 20  | `<go-separator>`           | `c5d4e3b2-3d4e-4c7d-ae1f-2a3b4c5d6e7f` | Final delimiter           | _(no count)_                                                                                                                             |

**`CREATE TABLE` elements for item 19:**

| #   | Type                        | Name          | `DataType` / Definition            |
| --- | --------------------------- | ------------- | ---------------------------------- |
| 1   | `<column-definition>`       | `ID`          | `int`, `IDENTITY(1,1)`, `NOT NULL` |
| 2   | `<column-definition>`       | `[Name]`      | `nvarchar(400)`, `NULL`            |
| 3   | `<inline-table-constraint>` | `PK_Philotes` | `PRIMARY KEY`, `Columns` = `[ID]`  |
