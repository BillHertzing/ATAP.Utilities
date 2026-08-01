# Rules, Rule Sets, and Build Sets (RRSBS) Database Schema

## Overview

This directory contains the core RRSBS (Rules, Rule Sets, and Build Sets) schema and data for the ATAPUtilities database. The RRSBS system provides a flexible framework for defining language-specific primitives, composing them into rules, organizing rules into sets, and tracking instantiations.

## Database Migration Structure

The RRSBS implementation follows Flyway's migration pattern with strict DDL/DML separation:

### Versioned Migrations (SQL/)

| File | Purpose |
|------|---------|
| `V00.01.000010__Create_ATAPUtilities_Core_Schema.sql` | DDL-only: Creates all RRSBS tables (Philote, PrimitiveLanguageKind, RulePrimitive, Rule, etc.) |
| `V00.01.000020__Load_ATAPUtilities_Data_From_BCP.sql` | DML-only: Loads seed data from CSV files via BULK INSERT |

### Data Files (Data/)

| File | Rows | Purpose |
|------|------|---------|
| `Philote_Primitives.csv` | 51 | Philote GUID entries for all rule primitives |
| `RulePrimitive.csv` | 51 | Rule primitive definitions (BNF non-terminals) |
| `Philote_Rules.csv` | 24 | Philote GUID entries for all rules |
| `Rule.csv` | 24 | Rule definitions with purpose and source file references |

## RRSBS Table Structure

## Effective-Dated Lifecycle

RRSBS does not use the largest `VersionNumber` as the definition of current.
Every temporal RRSBS row has an UTC validity interval:

- `EffectiveFrom` is inclusive.
- `EffectiveTo` is exclusive and `NULL` only for the current version.
- A revision closes the current row at one UTC timestamp and inserts the
  successor at that same timestamp; the logical parent Philote ID is retained.
- The effective-date check constraint, filtered unique current indexes, and
  close-only triggers prevent overlapping current versions, rewrites, and
  deletes.

The durable identity remains the parent Philote ID such as `RulePhiloteId`.
The version row has its own Philote ID so the complete historical graph can be
addressed without ambiguity. The same contract applies to the Instantiation
tree through BuildSet, RuleSet, Rule, composition, membership, instantiation,
and input-binding rows.

### Identity Layer

- **Philote**: Stable GUID-based identity (IPhilote<GUID>) for primitives and rules
  - Enables identity persistence across renames, refactors, and database migrations
  - Links to Rules Compendium markdown documentation

### Language-Specific Primitives

- **PrimitiveLanguageKind**: Static lookup table (4 languages)
  - 1 = CSharp
  - 2 = Powershell
  - 3 = SQL
  - 4 = MSBuild

- **RulePrimitive**: Atomic BNF building blocks (51 total)
  - 8 MSBuild primitives (e.g., `<csproj-file>`, `<property-group>`)
  - 18 CSharp primitives (e.g., `<class-declaration>`, `<method-declaration>`)
  - 23 SQL primitives (e.g., `<create-function-tvf-statement>`, `<cte-clause>`)
  - 2 PowerShell primitives (e.g., `<complete-powershell-cmdlet>`)

- **RulePrimitiveInput**: Parameter inputs for parameterized primitives
  - Captured as name-value pairs (not yet populated in seed data)

### Rule Composition

- **Rule**: Named compositions of ordered primitives (24 total)
  - 14 MSBuild rules (e.g., project file templates)
  - 7 CSharp rules (e.g., interface/record templates)
  - 3 SQL rules (e.g., function creation templates)

- **RulePrimitiveComposition**: Defines the ordered composition of primitives within each rule
  - Links Rule → RulePrimitive via CompositionOrder
  - Enables BNF derivation trees (not yet populated in seed data)

### Rule Organization

- **RuleSet**: Groups related rules for specific purposes
  - Parent-child hierarchy support via ParentRuleSetId
  - Links to Philote for stable identity (not yet populated in seed data)

- **RuleSetMember**: Many-to-many mapping between RuleSets and Rules
  - Includes MembershipOrder for sequencing (not yet populated in seed data)

### Instantiation Tracking

- **RuleInstantiation**: Records when/where a rule was applied
  - Links to Rule via RuleId
  - Records FilePath, LineNumber, InstantiationDateTime (not yet populated in seed data)

- **RuleInstantiationBinding**: Captures parameter bindings for parameterized rules
  - Links to RuleInstantiation and RulePrimitiveInput
  - Stores actual BindingValue used (not yet populated in seed data)

## Data Loading Process

The V00.01.000020 migration executes the following steps:

1. **Create Staging Tables**: Temporary `_stg_*` tables with nvarchar columns for CSV import
2. **BULK INSERT**: Load CSV files into staging tables
3. **Clear Existing Data**: DELETE in dependency order (children first)
4. **Load Production Tables**: INSERT with TRY_CONVERT and LTRIM/RTRIM
5. **Cleanup**: DROP staging tables
6. **Validation**: Verify row counts meet minimum thresholds

### Expected Row Counts After Load

- **PrimitiveLanguageKind**: 4 rows (static)
- **Philote**: 75 rows (51 primitives + 24 rules)
- **RulePrimitive**: 51 rows
- **Rule**: 24 rows
- **Others**: 0 rows (no seed data yet)

## CSV File Format

All CSV files follow this pattern:

```csv
Column1,Column2,Column3,...
value1,value2,value3,...
```

- **UTF-8 encoding** with BOM
- **Comma-separated** fields
- **`0x0A` (LF) line terminators** (Unix-style)
- **Header row** included (FIRSTROW = 2 in BULK INSERT)
- **No quoting** unless values contain commas

### Philote_Primitives.csv Structure

```csv
PhiloteId,Comment
f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d,<csproj-file> MSBuild primitive
...
```

- **PhiloteId**: GUID (36 chars)
- **Comment**: Human-readable description (not stored in database, for maintainer reference only)

### RulePrimitive.csv Structure

```csv
PhiloteId,PrimitiveLanguageKindId,Name,Description
f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d,4,<csproj-file>,Root project document with Sdk attribute and child groups
...
```

- **PhiloteId**: Foreign key to Philote.PhiloteId
- **PrimitiveLanguageKindId**: Foreign key to PrimitiveLanguageKind.PrimitiveLanguageKindId
- **Name**: BNF non-terminal name (e.g., `<csproj-file>`)
- **Description**: Explanation of the primitive's purpose

### Philote_Rules.csv Structure

```csv
PhiloteId,Comment
2f8b8c1b-3e25-44a0-9c6d-6b2f9f3f5e6c,ATAP.Utilities.StronglyTypedIds.Interfaces.csproj MSBuild rule
...
```

- Same format as Philote_Primitives.csv

### Rule.csv Structure

```csv
PhiloteId,PrimitiveLanguageKindId,Name,Purpose,SourceFileReference
2f8b8c1b-3e25-44a0-9c6d-6b2f9f3f5e6c,4,ATAP.Utilities.StronglyTypedIds.Interfaces.csproj,Render the project file for the StronglyTypedIds interfaces library.,src/ATAP.Utilities.StronglyTypedIds.Interfaces/ATAP.Utilities.StronglyTypedIds.Interfaces.csproj
...
```

- **PhiloteId**: Foreign key to Philote.PhiloteId
- **PrimitiveLanguageKindId**: Foreign key to PrimitiveLanguageKindId
- **Name**: Rule name (often matches file/class name)
- **Purpose**: Human-readable explanation of what the rule generates
- **SourceFileReference**: Relative path to the exemplar file

## Connection to Rules Compendiums

The database schema materializes concepts from these markdown documentation files:

- `SolutionDocumentation/Rules Compendium.MSBuild.md` - MSBuild .csproj primitives and rules
- `SolutionDocumentation/Rules Compendium.CSharp.md` - C# source code primitives and rules
- `SolutionDocumentation/Rules Compendium.SQL.md` - T-SQL script primitives and rules
- `SolutionDocumentation/Rules Compendium.Powershell.md` - PowerShell cmdlet primitives and rules

**Key Principle**: All information needed to recreate the compendium markdown files should be queryable from the database.

## Querying the RRSBS Schema

### Get All Primitives for a Language

```sql
SELECT
    rp.Name,
    rp.Description,
    plk.Name AS Language,
    p.PhiloteId
FROM dbo.RulePrimitive rp
JOIN dbo.PrimitiveLanguageKind plk ON rp.PrimitiveLanguageKindId = plk.PrimitiveLanguageKindId
JOIN dbo.Philote p ON rp.PhiloteId = p.PhiloteId
WHERE plk.Name = 'MSBuild'
ORDER BY rp.Name;
```

### Get All Rules for a Language

```sql
SELECT
    r.Name,
    r.Purpose,
    r.SourceFileReference,
    plk.Name AS Language,
    p.PhiloteId
FROM dbo.Rule r
JOIN dbo.PrimitiveLanguageKind plk ON r.PrimitiveLanguageKindId = plk.PrimitiveLanguageKindId
JOIN dbo.Philote p ON r.PhiloteId = p.PhiloteId
WHERE plk.Name = 'CSharp'
ORDER BY r.Name;
```

### Count Primitives and Rules by Language

```sql
SELECT
    plk.Name AS Language,
    COUNT(DISTINCT rp.PhiloteId) AS PrimitiveCount,
    COUNT(DISTINCT r.PhiloteId) AS RuleCount
FROM dbo.PrimitiveLanguageKind plk
LEFT JOIN dbo.RulePrimitive rp ON plk.PrimitiveLanguageKindId = rp.PrimitiveLanguageKindId
LEFT JOIN dbo.Rule r ON plk.PrimitiveLanguageKindId = r.PrimitiveLanguageKindId
GROUP BY plk.Name
ORDER BY plk.Name;
```

## Future Enhancements

The versioned RRSBS surface now includes RuleVersion, RuleSetVersion,
BuildSetVersion, RuleInstantiationVersion, ordered snapshot memberships,
effective dating, manifestation provenance, and immutable ordered source
lines. Task 13.79 seeds the first exact-byte graph for
`Write-ArrayIndented.ps1`; see
[Task-13.79-Instantiation-V1.md](../../SolutionDocumentation/Task-13.79-Instantiation-V1.md).

Remaining enhancements should build on these versioned tables rather than
introducing a `Build` layer or mutating durable identities.

## Related Documentation

- [Rules Compendium.MSBuild.md](../../SolutionDocumentation/Rules%20Compendium.MSBuild.md) - MSBuild rules and primitives
- [Rules Compendium.CSharp.md](../../SolutionDocumentation/Rules%20Compendium.CSharp.md) - C# rules and primitives
- [Rules Compendium.SQL.md](../../SolutionDocumentation/Rules%20Compendium.SQL.md) - SQL rules and primitives
- [Rules Compendium.Powershell.md](../../SolutionDocumentation/Rules%20Compendium.Powershell.md) - PowerShell rules and primitives
- [Rules Compendium.md](../../SolutionDocumentation/Rules%20Compendium.md) - Master RRSBS documentation

## Maintenance Notes

### Adding New Primitives

1. Generate new Philote GUID (e.g., [System.Guid]::NewGuid())
2. Add entry to appropriate Rules Compendium.*.md file with Philote ID
3. Add row to `Data/Philote_Primitives.csv`
4. Add row to `Data/RulePrimitive.csv`
5. Create new versioned migration or update repeatable migration
6. Run Flyway migrate

### Adding New Rules

1. Generate new Philote GUID
2. Add rule definition to appropriate Rules Compendium.*.md file
3. Add row to `Data/Philote_Rules.csv`
4. Add row to `Data/Rule.csv`
5. Optionally add RulePrimitiveComposition entries to show derivation
6. Create new versioned migration or update repeatable migration
7. Run Flyway migrate

### Updating Existing Rules

**Never change Philote GUIDs** - they are stable identity anchors.

For non-breaking changes (description, purpose, source reference):
1. Update the CSV file
2. Update the corresponding Rules Compendium.*.md file
3. Create new repeatable migration (R__Update_RRSBS_Metadata.sql)
4. Run Flyway migrate

For breaking changes (name changes, language changes):
1. Consider creating a new rule with new Philote GUID
2. Mark old rule as deprecated (add IsDeprecated column if needed)
3. Update documentation to reference new rule

---

**Last Updated**: 2026-07-30
**Schema Source Version**: V00.02.000110
