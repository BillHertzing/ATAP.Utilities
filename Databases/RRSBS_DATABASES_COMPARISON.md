# RRSBS Database Implementations - Quick Reference

## Overview

The ATAP.Utilities repository now has **two** database implementations of the Rules, Rule Sets, and Build Sets (RRSBS) system:

1. **BuildSets** - Standalone, focused database for RRSBS
2. **ATAPUtilities** - Consolidated database integrating RRSBS with code generation

## Database Comparison

| Feature | BuildSets Database | ATAPUtilities Database |
|---------|-------------------|------------------------|
| **Purpose** | Focused RRSBS implementation | Consolidated RRSBS + code generation |
| **Philote System** | ❌ Not included | ✅ Included |
| **Language Support** | 5 languages | 8 languages |
| **RulePrimitive Table** | ✅ Yes | ✅ Yes |
| **Rule Hierarchy** | ❌ No parent-child | ✅ Parent-child support |
| **Rule Relationships** | ❌ No typed relationships | ✅ Typed relationships |
| **Code Generation Tables** | ❌ Not included | ✅ Included (GStatement, etc.) |
| **Data Separation** | Slow/Swift migration split | Slow/Swift migration split |
| **Primary Use Case** | RRSBS-only scenarios | Full ATAP ecosystem |

## When to Use Which Database

### Use BuildSets Database When:
- You only need RRSBS functionality
- Simpler schema is preferred
- Deploying to environments that don't need code generation
- Testing RRSBS concepts in isolation
- Creating lightweight RRSBS microservices

### Use ATAPUtilities Database When:
- You need both RRSBS and code generation
- Philote identity system is required
- Complex rule hierarchies are needed
- Typed rule relationships are needed
- Full ATAP.Utilities ecosystem is deployed
- Centralized database for all ATAP functionality

## Schema Comparison

### BuildSets Tables
```
Language
RulePrimitive (with PhiloteID)
RuleSet
RuleItem (rules)
RuleSetHavingRuleItem
BuildSet
BuildSetHavingRuleSet
```

### ATAPUtilities Tables
```
[All BuildSets tables PLUS:]

Philote (identity system)
Rule (extended with PhiloteID, PrimitiveID, ParentID)
RuleRelationship (typed dependencies)
Map_RuleSet_Rule (many-to-many)

[Code Generation tables:]
GStatement
GComment
GBody
GArgument
GAssemblyUnit
GSolutionFile
AppTemplate
AppInstance
[and mapping tables]
```

## File Structure Comparison

### BuildSets
```
Databases/
  BuildSets/
    ├── SQL/
    │   ├── V00.01.000020__Create_BuildSets_Core_Schema.sql
    │   ├── V00.01.000030__Load_LanguagePrimitives_Data.sql
    │   ├── V00.01.000040__Load_Rules_Data.sql
    │   ├── V00.01.000100__AddBuildSet_Tables.sql
    │   ├── V00.01.000120__Load_BuildSets_Data.sql
    │   ├── R__Functions.sql
    │   └── R__VerifyRuleSets.sql
    ├── DATA/
    │   ├── Language.csv
    │   ├── RulePrimitive.csv
    │   ├── RuleSet.csv
    │   ├── RuleItem.csv
    │   ├── RuleSetHavingRuleItem.csv
    │   ├── BuildSet.csv
    │   └── BuildSetHavingRuleSet.csv
    ├── tests/
    ├── README.md
    └── REFACTORING_SUMMARY.md
```

### ATAPUtilities
```
Databases/
  ATAPUtilities/
    ├── Flyway/
    │   ├── sql/
    │   │   ├── V00.01.000000__FlywaySchemaHistory_Table.sql
    │   │   ├── V00.01.000010__UDF_IsNullOrEmpty.sql
    │   │   ├── V00.01.000100__BuildTables.sql
    │   │   ├── V00.01.000200__Add_RRSBS_Core_Schema.sql ⭐
    │   │   ├── V00.01.000210__Load_LanguagePrimitives_Data.sql ⭐
    │   │   └── V00.01.000220__Load_Rules_And_BuildSets_Data.sql ⭐
    │   └── DATA/
    │       ├── Philote.csv ⭐
    │       ├── Language.csv ⭐
    │       ├── RulePrimitive.csv ⭐
    │       ├── Rule.csv ⭐
    │       ├── RuleSet.csv ⭐
    │       ├── Map_RuleSet_Rule.csv ⭐
    │       ├── BuildSet.csv ⭐
    │       └── BuildSetHavingRuleSet.csv ⭐
    ├── Powershell/
    │   └── public/
    │       └── Rebuild-All.ps1
    ├── README.md
    └── REFACTORING_SUMMARY.md
```

⭐ = New files created in this refactoring

## Migration Numbering

### BuildSets
- **V00.01.000020** - Core schema (DDL only)
- **V00.01.000030** - Language primitives (slowly changing)
- **V00.01.000040** - Rules data (swiftly changing)
- **V00.01.000100** - BuildSet tables
- **V00.01.000120** - BuildSet data

### ATAPUtilities
- **V00.01.000000** - Flyway schema history
- **V00.01.000010** - Utility functions
- **V00.01.000100** - Original tables (code generation + basic RRSBS)
- **V00.01.000200** ⭐ - RRSBS core schema additions
- **V00.01.000210** ⭐ - Language primitives (slowly changing)
- **V00.01.000220** ⭐ - Rules and BuildSets (swiftly changing)

## Data Organization

Both databases follow the same philosophy:

### Slowly Changing Data
- **Languages**: SQL, CSharp, PowerShell, MSBuild, Ansible, TypeScript, JavaScript, Python
- **RulePrimitives**: BNF non-terminals from language grammars
- **Philote IDs** (ATAPUtilities only): Stable GUID identifiers
- **Update Frequency**: Quarterly or less

### Swiftly Changing Data
- **Rules/RuleItems**: Specific rule instances and configurations
- **RuleSets**: Collections of related rules
- **BuildSets**: Collections of RuleSets defining features/modules
- **Update Frequency**: Daily to weekly

## Key Differences in Implementation

### Rule Storage

**BuildSets:**
```sql
CREATE TABLE RuleItem (
  ID            int,
  ParentID      int NULL,           -- Simple hierarchy
  PeerSortOrder int NULL,
  SymbolicName  nvarchar(128),
  ItemText      nvarchar(200)
)
```

**ATAPUtilities:**
```sql
CREATE TABLE Rule (
  Id              int,
  PhiloteID       uniqueidentifier NULL,  -- Stable identity
  PrimitiveID     uniqueidentifier NULL,  -- Link to primitive
  ParentID        int NULL,               -- Hierarchy
  PeerSortOrder   int NULL,
  SymbolicName    nvarchar(128) NULL,
  -- Plus legacy fields: Name, Kind, Validity, etc.
  IsActive        bit
)
```

### Relationship Modeling

**BuildSets:**
- Parent-child relationships only via `ParentID`
- Simple tree structures

**ATAPUtilities:**
- Parent-child relationships via `ParentID`
- **PLUS** typed relationships via `RuleRelationship` table:
  - depends-on
  - executes-before
  - executes-after
  - conflicts-with
  - enhances
  - deprecates

### Identity Management

**BuildSets:**
- Auto-increment IDs only
- PhiloteID in CSV but not in database table

**ATAPUtilities:**
- Auto-increment IDs for Rules/RuleSets
- **PLUS** Philote table with GUID-based stable identifiers
- Links to Philote from RulePrimitive and optionally from Rule

## Rebuild Scripts

### BuildSets
Not yet implemented (database created via Flyway only)

### ATAPUtilities
```powershell
.\Databases\ATAPUtilities\Powershell\public\Rebuild-All.ps1
```

Features:
- Drops and recreates database
- Runs all Flyway migrations
- Loads all CSV data
- Validates data integrity
- Configurable environment (Experimental, Development, Production)

## Synchronization Strategy

If you need to keep both databases in sync:

1. **Master Source**: Use ATAPUtilities as the master
2. **Extract to BuildSets**: Export Rules from ATAPUtilities to BuildSets format
3. **Update Approach**: Update ATAPUtilities first, then regenerate BuildSets CSV files
4. **Version Control**: Both databases have their CSV files in git

## Migration Path

### From BuildSets to ATAPUtilities
1. Export BuildSets data to CSV
2. Transform RuleItem → Rule (add legacy columns with defaults)
3. Import into ATAPUtilities
4. Optionally create Philote IDs for rules needing stable identifiers

### From ATAPUtilities to BuildSets
1. Export Rule data to CSV
2. Transform Rule → RuleItem (drop extra columns)
3. Import into BuildSets
4. Note: Typed relationships will be lost

## Future Considerations

1. **Unification**: Consider whether both databases are needed long-term
2. **Synchronization Tools**: Build scripts to sync data between databases
3. **Deployment**: Define which environments use which database
4. **Testing**: Ensure tests work against both schemas
5. **Documentation**: Keep both READMEs in sync for common concepts

## Quick Start

### To Use BuildSets Database
```bash
cd Databases/BuildSets
# Configure flyway.toml with connection details
flyway migrate
```

### To Use ATAPUtilities Database
```powershell
cd Databases/ATAPUtilities/Powershell/public
.\Rebuild-All.ps1
```

## Documentation

### BuildSets
- [README.md](../BuildSets/README.md) - Full documentation
- [REFACTORING_SUMMARY.md](../BuildSets/REFACTORING_SUMMARY.md) - Change summary

### ATAPUtilities
- [README.md](../ATAPUtilities/README.md) - Full documentation
- [REFACTORING_SUMMARY.md](../ATAPUtilities/REFACTORING_SUMMARY.md) - Change summary

### Rules Compendium (Source for Primitives)
- [Rules Compendium.SQL.md](../../SolutionDocumentation/Rules%20Compendium.SQL.md)
- [Rules Compendium.CSharp.md](../../SolutionDocumentation/Rules%20Compendium.CSharp.md)
- [Rules Compendium.Powershell.md](../../SolutionDocumentation/Rules%20Compendium.Powershell.md)
- [Rules Compendium.MSBuild.md](../../SolutionDocumentation/Rules%20Compendium.MSBuild.md)
