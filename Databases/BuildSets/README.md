# BuildSets Database Migration Structure

This document explains the organization of the BuildSets database schema and data migrations.

## Overview

The BuildSets database stores information about **Rules, Rule Sets, and Build Sets (RRSBS)** - the foundational system used to define all aspects of the ATAP.Utilities libraries and Ace Commander application.

## Database Structure

### Core Concepts

- **Languages**: Programming/markup languages (SQL, C#, PowerShell, MSBuild, Ansible)
- **Rule Primitives**: Atomic language constructs (BNF non-terminals) with stable Philote GUID identifiers
- **Rules (RuleItems)**: Specific instances/configurations of primitives or custom rules
- **Rule Sets**: Collections of related rules with execution flow
- **Build Sets**: Collections of rule sets that define complete features/modules

### Schema Tables

| Table | Purpose | Change Frequency |
|-------|---------|-----------------|
| `Language` | Language definitions | Rarely changes |
| `RulePrimitive` | Language construct primitives | Slowly changing |
| `RuleSet` | Rule set definitions | Moderate changes |
| `RuleItem` | Specific rule instances | Swiftly changing |
| `RuleSetHavingRuleItem` | Rule-to-RuleSet associations | Swiftly changing |
| `BuildSet` | Build set definitions | Moderate changes |
| `BuildSetHavingRuleSet` | RuleSet-to-BuildSet associations | Moderate changes |

### Philote Identifiers

Rule Primitives use **Philote GUIDs** (`IPhilote<GUID>`) as stable identifiers that never change once allocated. This ensures referential integrity across the system even as the database evolves.

## Migration Files

### Flyway Migration Sequence

Migrations are executed in order by Flyway. The versioning scheme is `V00.01.NNNNNN`:

#### V00.01.000020 - Core Schema
- **Purpose**: Creates all database objects (tables, indexes, constraints)
- **No Data**: This file contains ONLY DDL, no data
- **Tables Created**:
  - `Language`
  - `RulePrimitive`
  - `RuleSet`
  - `RuleItem`
  - `RuleSetHavingRuleItem`
  - `BuildSet` (added in V00.01.000100)
  - `BuildSetHavingRuleSet` (added in V00.01.000100)

#### V00.01.000030 - Load Language Primitives (SLOWLY CHANGING)
- **Purpose**: Loads reference data that rarely changes
- **Data Loaded**:
  - Languages (SQL, C#, PowerShell, etc.)
  - Rule Primitives (language constructs with Philote IDs)
- **CSV Files**:
  - `Language.csv`
  - `RulePrimitive.csv`
- **Change Frequency**: Rarely - only when adding new languages or primitives

#### V00.01.000040 - Load Rules Data (SWIFTLY CHANGING)
- **Purpose**: Loads rule configurations that change frequently
- **Data Loaded**:
  - Rule Sets
  - Rule Items (specific rule instances)
  - RuleSet-RuleItem associations
- **CSV Files**:
  - `RuleSet.csv`
  - `RuleItem.csv`
  - `RuleSetHavingRuleItem.csv`
- **Change Frequency**: Frequently - as rules are added/modified

#### V00.01.000100 - Add BuildSet Tables
- **Purpose**: Adds BuildSet-related tables to the schema
- **Tables Created**:
  - `BuildSet`
  - `BuildSetHavingRuleSet`

#### V00.01.000120 - Load BuildSets Data
- **Purpose**: Loads BuildSet configurations
- **Data Loaded**:
  - Build Sets
  - BuildSet-RuleSet associations
- **CSV Files**:
  - `BuildSet.csv`
  - `BuildSetHavingRuleSet.csv`
- **Change Frequency**: Moderate - as features/modules are defined

### Repeatable Migrations (R__ prefix)

These run every time after versioned migrations:

- `R__Functions.sql`: User-defined functions
- `R__VerifyRuleSets.sql`: Data validation checks

## Data Organization Philosophy

### Slowly Changing Data
Data that represents stable language constructs and primitives:
- Loaded once and rarely updated
- Changes typically require coordinated updates across multiple systems
- Examples: Adding a new language, adding new BNF non-terminal primitives

### Swiftly Changing Data
Data that represents configuration and business logic:
- Updated frequently as features evolve
- Can be changed independently without affecting primitives
- Examples: Adding new rules, modifying rule configurations, updating rule sets

## CSV File Locations

All CSV files are located in: `Databases/BuildSets/DATA/`

### Slowly Changing Data Files
- `Language.csv` - Language definitions
- `RulePrimitive.csv` - Language construct primitives with Philote IDs

### Swiftly Changing Data Files
- `RuleSet.csv` - Rule set definitions
- `RuleItem.csv` - Rule instances (may reference primitives via PrimitiveID)
- `RuleSetHavingRuleItem.csv` - Rule-to-RuleSet associations
- `BuildSet.csv` - Build set definitions
- `BuildSetHavingRuleSet.csv` - RuleSet-to-BuildSet associations

## Schema Relationships

```
Language (1) ──< (M) RulePrimitive
                      │
                      │ (optional reference)
                      ↓
RuleSet (M) ──< (M) RuleItem
   │
   │
   ↓
BuildSet (M) ──< (M) RuleSet

RuleItem may have:
- ParentID (self-reference for hierarchy)
- PrimitiveID (optional link to RulePrimitive)
```

## Adding New Data

### To Add a New Language
1. Add entry to `Language.csv`
2. Update the count validation in `V00.01.000030__Load_LanguagePrimitives_Data.sql`
3. Run Flyway migration

### To Add New Primitives
1. Add entries to `RulePrimitive.csv` with unique Philote GUIDs
2. Update the count validation in `V00.01.000030__Load_LanguagePrimitives_Data.sql`
3. Run Flyway migration

### To Add New Rules
1. Add entries to `RuleItem.csv`
2. Optionally set `PrimitiveID` to link to a RulePrimitive
3. Add entries to `RuleSet.csv` if creating new rule sets
4. Add associations to `RuleSetHavingRuleItem.csv`
5. Update the count validation in `V00.01.000040__Load_Rules_Data.sql`
6. Run Flyway migration

## Testing

Test files are located in: `Databases/BuildSets/tests/`

- `DataLoad.Tests.ps1` - Pester tests for data loading

## References

See also:
- `SolutionDocumentation/Rules Compendium.SQL.md` - SQL rule primitives
- `SolutionDocumentation/Rules Compendium.CSharp.md` - C# rule primitives
- `SolutionDocumentation/Rules Compendium.Powershell.md` - PowerShell rule primitives
- `SolutionDocumentation/Rules Compendium.MSBuild.md` - MSBuild rule primitives
