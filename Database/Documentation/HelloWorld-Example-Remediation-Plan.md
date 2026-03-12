# HelloWorld Rule/Instantiation Example — Remediation Plan

## Executive Summary

Three artifacts were created in a prior session. One is **completely non-functional** due to corruption. Another has **critical schema mismatches** with the actual DDL. The third has **PowerShell variable scoping bugs** that will cause test assertions to silently pass against null values. None of the three files are currently in a state that would produce a successful end-to-end Pester run.

---

## File-by-File Shortfall Analysis

### 1. `Database/Queries/Query_Generate_HelloWorld_From_Rules.sql` — CRITICAL: Fully Corrupted

**Shortfall: Every identifier was stripped during prior edits.**

| Element | Current State | Required State |
|---|---|---|
| `USE` target | `USE ;` | `USE ATAPUtilities;` |
| CTE names | `WITH AS (` ... `AS (` | `WITH Bindings AS (` ... `DirectoryArtifacts AS (` ... `FileArtifacts AS (` |
| Schema prefixes | `.` (empty) | `ATAPUtilities.` |
| Table aliases | blank (e.g. `FROM .[Rule] `) | named aliases (e.g. `r`, `ri`, `rib`, `plk`) |
| Column references | blank (e.g. `.[Name] AS ,`) | named columns (e.g. `r.[Name] AS RuleName`) |
| CASE comparison | `WHEN @ProgramRuleName THEN 20` | `WHEN RuleName = @ProgramRuleName THEN 20` |
| `NVARCHAR` max | `CAST(NULL AS NVARCHAR())` | `CAST(NULL AS NVARCHAR(MAX))` |
| JOIN conditions | `ON . = .` | `ON ri.RulePhiloteId = r.PhiloteId` etc. |

**Result:** The query cannot be parsed or executed. It must be fully rewritten.

---

### 2. Schema Reference Mismatch — CRITICAL: Pester Prerequisite Will Always Fail

**Shortfall: The DDL creates tables in `dbo` schema; the test queries `ATAPUtilities` schema.**

The Flyway migration `V00.01.000010__Create_ATAPUtilities_Core_Schema.sql` creates every table under `dbo`:

```sql
CREATE TABLE dbo.Philote (...)
CREATE TABLE dbo.[Rule] (...)
CREATE TABLE dbo.RuleInstantiation (...)
CREATE TABLE dbo.RuleInstantiationBinding (...)
```

The Pester prerequisite test queries:

```sql
WHERE s.name = N'ATAPUtilities'
  AND t.name IN (N'Philote', ..., N'RuleInstantiationBinding');
```

The seed SQL in `BeforeAll` inserts into `ATAPUtilities.RuleInstantiationBinding`, `ATAPUtilities.[Rule]`, etc.

**These will find zero rows and zero tables.** The prerequisite test will always report missing tables, blocking the generation test permanently.

**Resolution requires a definitive answer to:** Do the tables live in `dbo` or in a separate `ATAPUtilities` schema? Two paths:

- **Path A** (tables are actually in `dbo`): Update the test's prerequisite query and all seed SQL to use `dbo.` prefix.
- **Path B** (an `ATAPUtilities` schema exists or should be created): A Flyway migration must `CREATE SCHEMA ATAPUtilities` and either move tables or create them there. The query must also reflect this.

The markdown documentation and test consistently use `ATAPUtilities` schema, suggesting **Path B** is the design intent — but no migration creating that schema exists in the repository.

---

### 3. `Database/Powershell/tests/Generate-HelloWorldFromRules.Tests.ps1` — Variable Scope Bugs

**Shortfall: Three `$script:` prefixes are missing, causing test assertions to compare against `$null`.**

| Location | Current (broken) | Correct |
|---|---|---|
| `It` block line: folder path | `$GeneratedRoot` | `$script:GeneratedRoot` |
| `It` block line: `Should -Be $ExpectedProgram` | `$ExpectedProgram` | `$script:ExpectedProgram` |
| `It` block line: `Should -Be $ExpectedClass` | `$ExpectedClass` | `$script:ExpectedClass` |
| `It` block line: `Should -Be $ExpectedCsproj` | `$ExpectedCsproj` | `$script:ExpectedCsproj` |
| `AfterAll` block | `$SqlInstance`, `$DatabaseName` | `$script:SqlInstance`, `$script:DatabaseName` |

In Pester 5, variables set in `BeforeAll` are only accessible in subsequent blocks via the `$script:` scope. Without the prefix, the `It` block reads `$null`. The `Test-Path $null` call will return `$false`, but the `Should -BeTrue` test may silently evaluate against unexpected paths. The `Should -Be $null` string comparison will never match the actual file content, meaning tests will fail even when files are correctly generated.

---

### 4. `SolutionDocumentation/Example.RuleInstantiation.HelloWorld.md` — Minor: Schema Inconsistency

The seed data SQL in the markdown uses `ATAPUtilities.Philote`, `ATAPUtilities.[Rule]`, etc. — consistent with the test but inconsistent with the actual DDL. Once the schema question (Path A vs. Path B above) is resolved, the markdown must be updated to match.

---

## Remediation Plan

### Step 1 — Resolve the Schema Question (Blocker for all other steps)

Determine whether to use `dbo` or create an `ATAPUtilities` schema.

**Recommended:** Create a new Flyway migration `V00.01.000005__Create_ATAPUtilities_Schema.sql` containing only:

```sql
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'ATAPUtilities')
  EXEC(N'CREATE SCHEMA ATAPUtilities');
GO
```

Then update V00.01.000010 (or create a subsequent migration) to create tables under `ATAPUtilities` instead of `dbo`. This aligns with the explicit intent stated in the Pester test and markdown.

**Alternative (simpler):** Change all `ATAPUtilities.` references in the test and query to `dbo.` and leave the DDL as-is.

### Step 2 — Rewrite the Query File Completely

Replace `Database/Queries/Query_Generate_HelloWorld_From_Rules.sql` with a clean, complete implementation:

- `USE ATAPUtilities;` (or the resolved database name)
- Named CTEs: `Bindings`, `DirectoryArtifacts`, `FileArtifacts`
- Fully qualified schema.table references
- Named column aliases throughout
- Correct `CASE WHEN RuleName = @ProgramRuleName THEN 20` comparisons
- `CAST(NULL AS NVARCHAR(MAX))` for the null content column

### Step 3 — Fix Pester Variable Scoping

Add `$script:` prefix to the five variables in the `It` block and two in `AfterAll`:

- `$GeneratedRoot` → `$script:GeneratedRoot`
- `$ExpectedProgram` → `$script:ExpectedProgram`
- `$ExpectedClass` → `$script:ExpectedClass`
- `$ExpectedCsproj` → `$script:ExpectedCsproj`
- `$SqlInstance` / `$DatabaseName` in `AfterAll` → `$script:SqlInstance` / `$script:DatabaseName`

### Step 4 — Update Documentation

Sync the schema prefix in the markdown seed example to match the resolved schema choice.

---

## Verification Checklist

After implementing the remediation, verify success in this order:

- [ ] **Schema migration exists**: A Flyway migration creating the `ATAPUtilities` schema (or all seed/query/test files updated to use `dbo`) is present and applied.
- [ ] **Query parses**: The SQL query file has no blank identifiers; executing it in SSMS against the target database returns no parse errors.
- [ ] **Query USE target correct**: `USE ATAPUtilities;` (or correct database) is present at top of query file.
- [ ] **Query CTE names present**: `WITH Bindings AS (`, `DirectoryArtifacts AS (`, `FileArtifacts AS (` are all named.
- [ ] **Query CASE syntax correct**: `CASE WHEN RuleName = @ProgramRuleName THEN 20` (or equivalent) — not bare `WHEN @ProgramRuleName`.
- [ ] **Query returns 4 rows on seed data**: 1 Directory row + 3 File rows, ordered by SortOrder.
- [ ] **Pester $script: prefixes fixed**: All five variables in `It` block and two in `AfterAll` have `$script:` scope qualifier.
- [ ] **Prerequisite test passes**: `Invoke-Pester` reports "has all required ATAPUtilities schema tables" as Passed (not Skipped or Failed).
- [ ] **Generation BeforeAll does not throw**: `$script:SchemaTablesValidated` is `$true` when the generation describe runs.
- [ ] **Folder created**: `Database/_generated/HelloWorld` exists after test run.
- [ ] **Program.cs created and correct**: File exists; content matches `"using HelloWorld;\r\nConsole.WriteLine(Greeter.GetMessage());"`.
- [ ] **HelloWorld.cs created and correct**: File exists; content matches the multi-line namespace/class definition.
- [ ] **HelloWorld.csproj created and correct**: File exists; content matches the MSBuild XML.
- [ ] **AfterAll cleanup runs**: Seed rows are deleted from all four ATAPUtilities tables after test completes; no orphaned test data remains.
- [ ] **Markdown schema prefix consistent**: `Example.RuleInstantiation.HelloWorld.md` seed SQL uses same schema prefix as the actual test and query files.
