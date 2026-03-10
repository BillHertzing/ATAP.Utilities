# BuildSets Database Refactoring Summary

## Date: February 26, 2026

## Overview

Refactored the BuildSets database to separate data into **slowly changing** (language primitives) and **swiftly changing** (rules) categories, following the principle that core language constructs should be managed separately from rule configurations.

## Changes Made

### 1. Schema Updates (V00.01.000020__Create_BuildSets_Core_Schema.sql)

#### Added Tables:
- **`Language`**: Stores programming/markup language definitions (SQL, C#, PowerShell, MSBuild, Ansible)
  - `ID` (int, PK)
  - `Name` (nvarchar(50), unique)
  - `Description` (nvarchar(500))

- **`RulePrimitive`**: Stores language construct primitives (BNF non-terminals) with Philote GUID identifiers
  - `PhiloteID` (uniqueidentifier, PK) - Stable GUID identifier
  - `LanguageID` (int, FK to Language)
  - `SymbolicName` (nvarchar(128)) - e.g., "<sql-script-file>"
  - `Description` (nvarchar(1000))
  - `BNFDefinition` (nvarchar(max)) - BNF grammar definition
  - `CreatedDate` (datetime2)

#### Modified Tables:
- **`RuleItem`**: Added `PrimitiveID` column
  - `PrimitiveID` (uniqueidentifier, nullable, FK to RulePrimitive)
  - This allows rules to optionally reference language primitives

#### Added Indexes:
- `IX_RulePrimitive_Language` - On RulePrimitive(LanguageID)
- `IX_RulePrimitive_SymbolicName` - On RulePrimitive(SymbolicName)
- `IX_RuleItem_Primitive` - On RuleItem(PrimitiveID)

### 2. Data Migration Reorganization

#### Created: V00.01.000030__Load_LanguagePrimitives_Data.sql
- **Purpose**: Load SLOWLY CHANGING reference data
- **Loads**:
  - Languages (SQL, C#, PowerShell, MSBuild, Ansible)
  - Rule Primitives (language constructs from Rules Compendium)
- **CSV Files**:
  - `Language.csv` (5 languages)
  - `RulePrimitive.csv` (6 primitives initially)
- **Validation**: Ensures at least 3 languages and 5 primitives loaded
- **Change Frequency**: Rarely - only when adding new languages or core grammar constructs

#### Renamed/Updated: V00.01.000040__Load_Rules_Data.sql
- **Previously**: V00.01.000030__Load_BuildSets_Data_From_BCP.sql
- **Purpose**: Load SWIFTLY CHANGING rule data
- **Loads**:
  - Rule Sets
  - Rule Items (configurations/instances)
  - RuleSet-RuleItem associations
- **CSV Files**:
  - `RuleSet.csv`
  - `RuleItem.csv` (updated to include PrimitiveID column)
  - `RuleSetHavingRuleItem.csv`
- **Change Frequency**: Frequently - as rules are added/modified

#### Renamed/Updated: V00.01.000120__Load_BuildSets_Data.sql
- **Previously**: V00.01.000110__Load_BuildSets_Data_From_BCP.sql
- **Purpose**: Load BuildSet configurations
- **Loads**:
  - Build Sets
  - BuildSet-RuleSet associations
- **CSV Files**:
  - `BuildSet.csv`
  - `BuildSetHavingRuleSet.csv`

### 3. Data Files

#### New CSV Files:

**Language.csv** - Defines supported languages:
```csv
ID,Name,Description
1,SQL,Structured Query Language - database query and management language
2,CSharp,C# programming language for .NET applications
3,PowerShell,PowerShell scripting and automation language
4,MSBuild,Microsoft Build Engine project files and targets
5,Ansible,Ansible YAML playbooks and roles for infrastructure automation
```

**RulePrimitive.csv** - Defines language construct primitives with Philote IDs:
```csv
PhiloteID,LanguageID,SymbolicName,Description,BNFDefinition
a3f2e1d0-1b2c-4a5b-8c9d-0e1f2a3b4c5d,1,<sql-script-file>,Top-level container for a .sql file,"<sql-script-file> ::= <script-element-list>"
b4e3f2c1-2c3d-4b6c-9d0e-1f2a3b4c5d6e,1,<batch>,A batch is a sequence of one or more T-SQL statements...
...
```

#### Updated CSV Files:

**RuleItem.csv** - Added PrimitiveID column:
```csv
ID,ParentID,PeerSortOrder,PrimitiveID,SymbolicName,ItemText
0,,,, _sym_Rule0,Rule 0
1,,0,,_sym_Rule1,Rule 1
...
```

### 4. Documentation

#### Created: Databases/BuildSets/README.md
Comprehensive documentation covering:
- Database structure and relationships
- Migration file sequence and purpose
- Data organization philosophy (slowly vs swiftly changing)
- CSV file locations and formats
- Instructions for adding new data
- Schema relationships diagram

## Migration Sequence

The new Flyway migration order:

1. **V00.01.000020** - Create core schema (DDL only, no data)
2. **V00.01.000030** - Load language primitives (SLOWLY CHANGING)
3. **V00.01.000040** - Load rules data (SWIFTLY CHANGING)
4. **V00.01.000100** - Add BuildSet tables
5. **V00.01.000120** - Load BuildSets data
6. **R__Functions.sql** - Repeatable: User-defined functions
7. **R__VerifyRuleSets.sql** - Repeatable: Data validation

## Design Philosophy

### Slowly Changing Data (Language Primitives)
- Represents stable language constructs
- Maps to BNF non-terminals in language grammars
- Uses Philote GUID identifiers for stability
- Loaded once, rarely updated
- Changes require coordinated updates across systems
- Examples: Adding new language, adding new BNF primitives

### Swiftly Changing Data (Rules)
- Represents configuration and business logic
- Built from primitives or custom specifications
- Updated frequently as features evolve
- Can change independently without affecting primitives
- Examples: New rules, modified configurations, updated rule sets

## Benefits

1. **Clear Separation of Concerns**: Language constructs separate from configurations
2. **Stable Identifiers**: Philote GUIDs ensure referential integrity across system evolution
3. **Flexible Rule Definition**: Rules can reference primitives or be standalone
4. **Better Change Management**: Different update frequencies for different data types
5. **Traceability**: Rules can be traced back to primitives for governance
6. **Multi-Language Support**: Single database supports SQL, C#, PowerShell, MSBuild, Ansible

## Relationships

```
┌─────────────┐
│  Language   │ 1
└──────┬──────┘
       │
       │ M
       ↓
┌──────────────────┐
│  RulePrimitive   │
└────────┬─────────┘
         │
         │ (optional)
         │
         ↓
┌──────────────┐      M ┌──────────┐ M      ┌───────────┐
│   RuleItem   │────────│ RuleSet  │────────│ BuildSet  │
└──────────────┘        └──────────┘        └───────────┘
  (self-ref hierarchy)
```

## Next Steps

1. **Populate RulePrimitive**: Extract remaining primitives from Rules Compendium documents
2. **Link Rules to Primitives**: Update RuleItem.csv to set PrimitiveID where appropriate
3. **Testing**: Run Pester tests in `tests/DataLoad.Tests.ps1`
4. **Validation**: Execute migrations and verify data quality guardrails

## Files Changed

### Modified:
- `Databases/BuildSets/SQL/V00.01.000020__Create_BuildSets_Core_Schema.sql`
- `Databases/BuildSets/DATA/RuleItem.csv`

### Renamed:
- `V00.01.000030__Load_BuildSets_Data_From_BCP.sql` → `V00.01.000040__Load_Rules_Data.sql`
- `V00.01.000110__Load_BuildSets_Data_From_BCP.sql` → `V00.01.000120__Load_BuildSets_Data.sql`

### Created:
- `Databases/BuildSets/SQL/V00.01.000030__Load_LanguagePrimitives_Data.sql`
- `Databases/BuildSets/DATA/Language.csv`
- `Databases/BuildSets/DATA/RulePrimitive.csv`
- `Databases/BuildSets/README.md`
- `Databases/BuildSets/REFACTORING_SUMMARY.md` (this file)

## References

- [Rules Compendium.SQL.md](../../SolutionDocumentation/Rules%20Compendium.SQL.md)
- [Rules Compendium.CSharp.md](../../SolutionDocumentation/Rules%20Compendium.CSharp.md)
- [Rules Compendium.Powershell.md](../../SolutionDocumentation/Rules%20Compendium.Powershell.md)
- [Rules Compendium.MSBuild.md](../../SolutionDocumentation/Rules%20Compendium.MSBuild.md)
