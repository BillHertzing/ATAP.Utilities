# Rules Compendium — SQL

<!-- METADATA
  Language:        SQL
  Created:         2026-08-02
  Kind Count:      1
  Primitive Count: 23
  Template version: 1.0
  Source skill:    .claude/skills/new-rule-kind/SKILL.md
-->

This is the normalized compendium for the retained SQL RuleKind. It documents
the stable legacy corpus without authorizing a migration, seed change, executor,
package, or live-system action.

---

## Philote Identity Convention

A Philote is a stable, table-specific GUID for a durable or versioned
first-class RRSBS row. It is not a permission, mutable display name, or generic
table/key reference. The retained `PrimitiveLanguageKind` SQL row has numeric
Id `3`; this documentation does not invent a Kind Philote.

---

## Overview

SQL Rules render a bounded T-SQL source-file profile from Rule Primitives. The
retained corpus has 23 primitives, 3 Rules, and 3 instantiations. The grammar
authority is `SolutionDocumentation/grammers/SQL.grammar.ebnf`.

---

## Language / Tooling Version

The grammar is a bounded profile of Transact-SQL for SQL Server 2022. Runtime,
compatibility-level, executor, and deployment policies are outside RDB-180A.

---

## Part I — Grammar Specification

<!-- rule-grammar-start -->

### Kind: SQL

**Philote ID:** Not present in the retained `PrimitiveLanguageKind` schema.

**Grammar file:** `SolutionDocumentation/grammers/SQL.grammar.ebnf`

**DB record:** `ATAPUtilities.PrimitiveLanguageKind` Id = `3`; retained name `SQL`.

**Description:** T-SQL script-language primitives and Rules for the retained database corpus.

#### Grammar

<!-- EMBEDDED from SolutionDocumentation/grammers/SQL.grammar.ebnf -->
```ebnf
<sql-script-file> ::= { <script-element> }
<script-element> ::= <batch> | <go-separator> | <single-line-comment> | <block-comment> | <new-line>
<batch> ::= { <batch-statement> | <single-line-comment> | <block-comment> | <new-line> }
<batch-statement> ::= <use-statement> | <set-option-statement> | <declare-statement> | <set-variable-statement> | <select-from-order-statement> | <object-existence-guard> | <create-function-tvf-statement> | <create-table-statement> | <cte-clause> | <insert-into-select-statement> | <return-statement>
<go-separator> ::= "GO" [ <whitespace> <decimal-digits> ] <new-line>
<use-statement> ::= "USE" <whitespace> <database-name> [ <statement-terminator> ]
<set-option-statement> ::= "SET" <whitespace> <option-name> <whitespace> <option-value> [ <statement-terminator> ]
<single-line-comment> ::= "--" { text } <new-line>
<block-comment> ::= "/*" { text } "*/"
<separator-comment-block> ::= <comment-rule-line> { <comment-body-line> } <comment-rule-line>
<object-existence-guard> ::= "IF OBJECT_ID" "(" <string-literal> ") IS NOT NULL" <new-line> <drop-statement>
<declare-statement> ::= "DECLARE" <whitespace> <declare-variable> { "," <whitespace> <declare-variable> }
<set-variable-statement> ::= "SET" <whitespace> <variable> <whitespace> "=" <whitespace> <scalar-expression>
<select-from-order-statement> ::= "SELECT" <whitespace> <select-list> <whitespace> "FROM" <whitespace> <table-source> [ <whitespace> <order-by-clause> ]
<function-parameter> ::= <variable> <whitespace> <data-type-spec> [ <whitespace> "=" <whitespace> <scalar-expression> ]
<returns-table-clause> ::= "RETURNS" <whitespace> ( "TABLE" | <variable> <whitespace> "TABLE" "(" <table-column-spec> { "," <whitespace> <table-column-spec> } ")" )
<create-function-tvf-statement> ::= "CREATE FUNCTION" <whitespace> <schema-qualified-name> "(" [ <function-parameter> { "," <whitespace> <function-parameter> } ] ")" <whitespace> <returns-table-clause> <whitespace> "AS BEGIN" { <function-body-statement> } "END"
<cte-clause> ::= "WITH" <whitespace> <identifier> <whitespace> "AS" <whitespace> "(" <select-from-order-statement> ")"
<insert-into-select-statement> ::= "INSERT INTO" <whitespace> <table-name> [ "(" <identifier> { "," <whitespace> <identifier> } ")" ] <whitespace> <select-from-order-statement>
<case-when-expression> ::= "CASE" { "WHEN" <whitespace> <search-condition> <whitespace> "THEN" <whitespace> <scalar-expression> } [ "ELSE" <whitespace> <scalar-expression> ] "END"
<query-hint-clause> ::= "OPTION" <whitespace> "(" <query-hint> { "," <whitespace> <query-hint> } ")"
<return-statement> ::= "RETURN" [ <whitespace> <scalar-expression> ]
<create-table-statement> ::= "CREATE TABLE" <whitespace> <schema-qualified-name> <whitespace> "(" <table-element> { "," <whitespace> <table-element> } ")"
<column-definition> ::= <column-name> <whitespace> <data-type-spec> [ <whitespace> "IDENTITY" "(" <decimal-digits> "," <decimal-digits> ")" ] [ <whitespace> <nullability> ]
<inline-table-constraint> ::= "CONSTRAINT" <whitespace> <constraint-name> <whitespace> ( "PRIMARY KEY" | "UNIQUE" | "FOREIGN KEY" | "CHECK" | "DEFAULT" ) { text }
```
<!-- END EMBEDDED -->

#### Composition Constraints

- A script is ordered batches, SQLCMD/SSMS `GO` separators, comments, and new lines.
- `GO` is a client batch separator rather than a SQL Server statement.
- A table definition contains one or more column definitions or inline table constraints.
- This profile defers the complete T-SQL lexical and expression grammar to SQL Server documentation.

#### Valid Expression Examples

```sql
IF OBJECT_ID(N'[dbo].[Example]', N'U') IS NOT NULL
  DROP TABLE [dbo].[Example];
GO
CREATE TABLE [dbo].[Example] ([Id] int NOT NULL PRIMARY KEY);
```

```sql
WITH [source] AS (SELECT [Id] FROM [dbo].[Example])
SELECT [Id] FROM [source] ORDER BY [Id];
```

<!-- rule-grammar-end -->

---

## Part II — Rule Primitives

<!-- rule-primitives-start -->

The following table is the normalized one-to-one retained primitive inventory.
Each name is an EBNF non-terminal in the grammar artifact and maps to one
`ATAPUtilities.RulePrimitive` row with KindId `3`.

| Rule Primitive | Philote ID | Description |
| --- | --- | --- |
| `<sql-script-file>` | `a3f2e1d0-1b2c-4a5b-8c9d-0e1f2a3b4c5d` | Top-level `.sql` source-file container. |
| `<batch>` | `b4e3f2c1-2c3d-4b6c-9d0e-1f2a3b4c5d6e` | T-SQL statements compiled as one unit. |
| `<go-separator>` | `c5d4e3b2-3d4e-4c7d-ae1f-2a3b4c5d6e7f` | SSMS/sqlcmd `GO` batch separator. |
| `<use-statement>` | `d6c5d4a3-4e5f-4d8e-bf20-3b4c5d6e7f80` | Database-context selection. |
| `<set-option-statement>` | `e7b6c5f4-5f60-4e9f-c031-4c5d6e7f8091` | Session option configuration. |
| `<single-line-comment>` | `f8a7d6e5-6071-4f0a-d142-5d6e7f809102` | `--` comment line. |
| `<block-comment>` | `09b8e7f6-7182-4a1b-e253-6e7f8091a234` | `/* ... */` comment. |
| `<separator-comment-block>` | `1ac9f8e7-8293-4b2c-f364-7f8091ab2345` | Visual SQL comment separator. |
| `<object-existence-guard>` | `2bdae9f8-93a4-4c3d-a475-8091a2bc3456` | Conditional object drop guard. |
| `<declare-statement>` | `3cebfa09-a4b5-4d4e-b586-91a2b3cd4567` | Local-variable declaration. |
| `<set-variable-statement>` | `4dfc0b1a-b5c6-4e5f-c697-a2b3c4de5678` | Local-variable assignment. |
| `<select-from-order-statement>` | `5e0d1c2b-c6d7-4f60-d7a8-b3c4d5ef6789` | `SELECT ... FROM ... ORDER BY` query. |
| `<function-parameter>` | `70a3e4d4-e8f9-4182-f9ca-d5e6f7a14901` | Function/procedure parameter. |
| `<returns-table-clause>` | `81b4f5e5-f9a0-4293-aadb-e6f7081b5a12` | Table-valued-function return declaration. |
| `<create-function-tvf-statement>` | `6f1e2d3c-d7e8-4071-e8b9-c4d5e6f07890` | Table-valued-function DDL. |
| `<cte-clause>` | `92c5a6f6-0ab1-43a4-bbec-f7081c2c6b23` | Common table expression. |
| `<insert-into-select-statement>` | `a3d6b7e7-1bc2-44b5-ccfd-081d2d3d7c34` | `INSERT INTO ... SELECT` statement. |
| `<case-when-expression>` | `b4e7c8f8-2cd3-45c6-ddae-192e3e4e8d45` | `CASE WHEN` expression. |
| `<query-hint-clause>` | `c5f8d9a9-3de4-46d7-eebf-2a3f4f5f9e56` | `OPTION (...)` query hint. |
| `<return-statement>` | `091cdecd-7128-4abb-22f3-6e7383939290` | `RETURN` statement. |
| `<create-table-statement>` | `d6e9eaba-4ef5-47e8-ffc0-3b405060af67` | `CREATE TABLE` DDL. |
| `<column-definition>` | `e7fabcbb-5f06-48f9-00d1-4c5161717078` | Table column definition. |
| `<inline-table-constraint>` | `f80bcdcc-6017-49ea-11e2-5d6272828189` | Inline/table-level constraint. |

**Inputs and output:** Primitive-specific inputs remain the bound values in the
retained instantiation corpus; each primitive outputs its corresponding grammar
node as exact T-SQL text. No input rows were synthesized by this normalization.

**Attribution:** SQL Server Transact-SQL language reference and SQLCMD/SSMS `GO`
documentation; see Sources and Boundaries.

<!-- rule-primitives-end -->

---

## Part III — Rule Repository

<!-- rule-repository-start -->

| Rule | Philote ID | Purpose | Source file | Disposition |
| --- | --- | --- | --- | --- |
| `Test_udf_dateperiod` | `7a1b2c3d-4e5f-4061-8273-a4b5c6d7e8f9` | Generate a test query for `dbo.udf_dateperiod`. | `src/ATAP.Utilities.Philote/Database/Queries/Test_udf_dateperiod.sql` | preserve identity |
| `Create_udf_dateperiod` | `8b2c3d4e-5f60-4172-9384-b5c6d7e8f9a0` | Generate DDL for `dbo.udf_dateperiod`. | `src/ATAP.Utilities.Philote/Database/Queries/Create_udf_dateperiod.sql` | preserve identity |
| `V00.01.000010__Create_Philote_Core_Schema` | `9c3d4e5f-60a1-4283-a495-c6d7e8f9b0a1` | Generate the Philote core-schema Flyway migration. | `src/ATAP.Utilities.Philote/Database/Flyway/DATA/V00.01.000010__Create_Philote_Core_Schema.sql` | preserve identity |

No retained SQL composition rows identify a primitive render order. This
normalization records the Rule identities and source references without inferring
derivations or bindings beyond the three retained instantiations.

<!-- rule-repository-end -->

---

## Part IV — Rule Sets

<!-- rule-sets-start -->

No Rule Set or Build Set rows are present in the retained SQL CSV corpus.

<!-- rule-sets-end -->

---

## Sources and Boundaries

- [Transact-SQL reference](https://learn.microsoft.com/sql/t-sql/language-reference)
- [Use SQLCMD with scripting variables](https://learn.microsoft.com/sql/tools/sqlcmd/sqlcmd-use-utility)
- `Database/Flyway/Data/SQL_RulePrimitives.csv`
- `Database/Flyway/Data/SQL_Rules.csv`
- `Database/Flyway/Data/SQL_Instantiations.csv`
- `Database/Flyway/Data/SQL_InstantiationBindings.csv`

RDB-180A normalizes documentation only. Executor contracts, security
classification, seed changes, database migrations, and live database operations
remain outside this work unit.

*Last updated: 2026-08-02 | Maintained by: RDB-180A SQL normalization*
