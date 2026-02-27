# ATAPUtilities Database Refactoring Summary

## Date: February 26, 2026

## Overview

Refactored the ATAPUtilities database to integrate the **Rules, Rule Sets, and Build Sets (RRSBS)** system with existing code generation functionality. The refactoring separates data into **slowly changing** (language primitives) and **swiftly changing** (rules) categories, adds a **Philote identity system**, and supports **parent-child rule hierarchies** and **typed rule relationships**.

This refactoring consolidates functionality from the standalone BuildSets database into the main ATAPUtilities database while preserving all existing code generation capabilities.

## Changes Made

### 1. Schema Additions (V00.01.000200__Add_RRSBS_Core_Schema.sql)

#### New Tables Created:

**Philote** - Stable GUID-based identity system:
- `PhiloteID` (uniqueidentifier, PK) - Unique identifier
- `EntityType` (nvarchar(50)) - Type of entity ('RulePrimitive', 'Rule')
- `EntityKey` (nvarchar(128)) - Optional symbolic reference
- `CreatedDate` (datetime2)
- `Description` (nvarchar(500))

**Language** - Defines programming/markup languages:
- `ID` (int IDENTITY, PK)
- `Name` (nvarchar(50), unique)
- `Description` (nvarchar(500))
- `IsActive` (bit)
- `CreatedDate` (datetime2)

**RulePrimitive** - Language construct primitives with Philote IDs:
- `PhiloteID` (uniqueidentifier, PK, FK to Philote)
- `LanguageID` (int, FK to Language)
- `SymbolicName` (nvarchar(128)) - e.g., "<sql-script-file>"
- `Description` (nvarchar(1000))
- `BNFDefinition` (nvarchar(max)) - BNF grammar definition
- `Attribution` (nvarchar(max)) - Source references
- `IsActive` (bit)
- `CreatedDate` (datetime2)
- `ModifiedDate` (datetime2)

**BuildSet** - Feature/module definitions:
- `ID` (int IDENTITY, PK)
- `Name` (nvarchar(100), unique)
- `Description` (nvarchar(500))
- `IsActive` (bit)
- `CreatedDate` (datetime2)
- `ModifiedDate` (datetime2)

**BuildSetHavingRuleSet** - Many-to-many BuildSet-RuleSet associations:
- `BuildSetID` (int, PK, FK to BuildSet)
- `RuleSetID` (int, PK, FK to RuleSet)
- `SortOrder` (int)

**RuleRelationship** - Typed relationships between rules:
- `ID` (int IDENTITY, PK)
- `SourceRuleID` (int, FK to Rule)
- `TargetRuleID` (int, FK to Rule)
- `RelationshipType` (nvarchar(50)) - 'depends-on', 'executes-before', etc.
- `Description` (nvarchar(500))
- `IsActive` (bit)
- `CreatedDate` (datetime2)

#### Existing Table Extended:

**Rule** - Added columns to support RRSBS:
- `PhiloteID` (uniqueidentifier, nullable, FK to Philote) - Optional stable identifier
- `PrimitiveID` (uniqueidentifier, nullable, FK to RulePrimitive) - Links to language primitive
- `ParentID` (int, nullable, FK to Rule) - Self-reference for hierarchy
- `PeerSortOrder` (int, nullable) - Sort order among siblings
- `SymbolicName` (nvarchar(128), nullable) - Symbolic name for reference
- `IsActive` (bit, default 1) - Active flag

#### Indexes Added:

**Philote:**
- `PK_Philote` (Clustered on PhiloteID)
- `UQ_Philote_EntityType_EntityKey` (Unique)
- `IX_Philote_EntityType`

**Language:**
- `PK_Language` (Clustered on ID)
- `UQ_Language_Name` (Unique)

**RulePrimitive:**
- `PK_RulePrimitive` (Clustered on PhiloteID)
- `FK_RulePrimitive_Language`
- `FK_RulePrimitive_Philote`
- `UQ_RulePrimitive_Language_Name` (Unique)
- `IX_RulePrimitive_Language`
- `IX_RulePrimitive_SymbolicName`

**Rule (new indexes):**
- `FK_Rule_Philote`
- `FK_Rule_Primitive`
- `FK_Rule_Parent`
- `IX_Rule_Philote`
- `IX_Rule_Primitive`
- `IX_Rule_Parent`
- `IX_Rule_Parent_PeerSort`

**BuildSet:**
- `PK_BuildSet` (Clustered on ID)
- `UQ_BuildSet_Name` (Unique)

**BuildSetHavingRuleSet:**
- `PK_BuildSetHavingRuleSet` (Clustered)
- `FK_BuildSetHavingRuleSet_BuildSet`
- `FK_BuildSetHavingRuleSet_RuleSet`
- `IX_BuildSetHavingRuleSet_RuleSet`

**RuleRelationship:**
- `PK_RuleRelationship` (Clustered on ID)
- `FK_RuleRelationship_Source`
- `FK_RuleRelationship_Target`
- `UQ_RuleRelationship_Source_Target_Type` (Unique)
- `IX_RuleRelationship_Source`
- `IX_RuleRelationship_Target`
- `IX_RuleRelationship_Type`

### 2. Data Migration Files Created

#### V00.01.000210__Load_LanguagePrimitives_Data.sql
**Purpose:** Load SLOWLY CHANGING reference data
**Loads:**
- Philote identifiers (9 initial entries)
- Languages (8 languages: SQL, CSharp, PowerShell, MSBuild, Ansible, TypeScript, JavaScript, Python)
- Rule Primitives (8 initial primitives from Rules Compendium)

**Validation:**
- Minimum 3 languages
- Minimum 5 primitives
- Referential integrity checks
- Philote linkage verification

**Change Frequency:** Rarely - only when adding new languages or core grammar constructs

#### V00.01.000220__Load_Rules_And_BuildSets_Data.sql
**Purpose:** Load SWIFTLY CHANGING configuration data
**Loads:**
- Rules (5 sample rules with hierarchy)
- RuleSets (3 sample rule sets)
- Map_RuleSet_Rule associations (5 mappings)
- BuildSets (3 sample build sets)
- BuildSetHavingRuleSet associations (3 mappings)

**Validation:**
- Minimum 1 rule loaded
- Minimum 1 ruleset loaded
- PrimitiveID referential integrity
- PhiloteID referential integrity
- ParentID referential integrity (parent-child validation)

**Change Frequency:** Frequently - as rules and features evolve

### 3. CSV Data Files Created

#### Slowly Changing Data:

**Philote.csv** - Philote identifiers:
```csv
PhiloteID,EntityType,EntityKey,Description
a3f2e1d0-1b2c-4a5b-8c9d-0e1f2a3b4c5d,RulePrimitive,<sql-script-file>,...
```
9 Philote entries for initial primitives

**Language.csv** - 8 supported languages:
```csv
ID,Name,Description
1,SQL,Structured Query Language...
2,CSharp,C# programming language...
3,PowerShell,PowerShell scripting...
4,MSBuild,Microsoft Build Engine...
5,Ansible,Ansible YAML playbooks...
6,TypeScript,TypeScript programming...
7,JavaScript,JavaScript programming...
8,Python,Python programming...
```

**RulePrimitive.csv** - 8 language construct primitives:
```csv
PhiloteID,LanguageID,SymbolicName,Description,BNFDefinition,Attribution
a3f2e1d0-...,1,<sql-script-file>,Top-level container...,...
```

#### Swiftly Changing Data:

**Rule.csv** - 5 sample rules with parent-child hierarchy:
```csv
Id,PhiloteID,PrimitiveID,ParentID,PeerSortOrder,SymbolicName,Name,Kind,Validity,DisplayOrder,DisplayAction,InputAction,Value,Dirty,IsActive
1,,,,,Rule_UseDatabase,Use ATAPUtilities Database,...
4,,,1,1,Rule_CreateTable_Columns,Define Table Columns,...
```

**RuleSet.csv** - 3 sample rule sets:
```csv
Id,Name,Validity
1,SQL Table Creation Rules,2026-01-01
2,SQL Script Structure Rules,2026-01-01
3,CSharp Class Generation Rules,2026-01-01
```

**Map_RuleSet_Rule.csv** - 5 rule-to-ruleset mappings

**BuildSet.csv** - 3 sample build sets:
```csv
ID,Name,Description
1,Database Schema Management,...
2,Code Generation Framework,...
3,ATAP Utilities Core,...
```

**BuildSetHavingRuleSet.csv** - 3 buildset-to-ruleset mappings

### 4. Documentation Created

#### README.md (Comprehensive)
Sections:
- Overview and database purpose
- Core concepts (Philote, Language hierarchy, change frequency)
- Complete schema structure with all tables and columns
- Migration file sequence and purpose
- Data organization philosophy
- CSV file locations and formats
- Key relationships diagram
- Usage examples
- Rebuild script instructions
- Testing guidance
- References to Rules Compendium
- Future enhancements

#### REFACTORING_SUMMARY.md (This file)
Complete summary of all changes made

## Migration Sequence

The new Flyway migration order for ATAPUtilities:

1. **V00.01.000000** - FlywaySchemaHistory_Table
2. **V00.01.000010** - UDF_IsNullOrEmpty (utility function)
3. **V00.01.000100** - BuildTables (original code generation + Rule/RuleSet tables)
4. **V00.01.000200** ⭐ **NEW** - Add_RRSBS_Core_Schema (RRSBS integration)
5. **V00.01.000210** ⭐ **NEW** - Load_LanguagePrimitives_Data (slowly changing)
6. **V00.01.000220** ⭐ **NEW** - Load_Rules_And_BuildSets_Data (swiftly changing)

## Design Philosophy

### Slowly Changing Data (Languages & Primitives)
- Represents stable language constructs
- Maps to BNF non-terminals in language grammars
- Uses Philote GUID identifiers for stability
- Loaded once, rarely updated
- Changes require coordinated updates across systems
- **Examples:** Adding new language, adding BNF primitives
- **Update Frequency:** Quarterly or less

### Swiftly Changing Data (Rules & BuildSets)
- Represents configuration and business logic
- Built from primitives or custom specifications
- Updated frequently as features evolve
- Can change independently without affecting primitives
- **Examples:** New rules, modified configurations, updated rule sets
- **Update Frequency:** Daily to weekly

### Parent-Child Rule Hierarchies
Rules can now form trees via `ParentID`:
- Parent rule at root (ParentID = NULL)
- Child rules reference parent (ParentID = parent.Id)
- Siblings ordered by `PeerSortOrder`
- Enables complex rule compositions

### Typed Rule Relationships
Beyond parent-child, rules can have typed relationships:
- **depends-on**: Target must execute before source
- **executes-before**: Source must execute before target
- **executes-after**: Source must execute after target
- **conflicts-with**: Cannot both be active
- **enhances**: Source enhances/extends target
- **deprecates**: Source deprecates target

## Benefits

1. **Unified Database**: Consolidates code generation and RRSBS in one database
2. **Stable Identifiers**: Philote GUIDs ensure referential integrity across evolution
3. **Multi-Language Support**: Single schema supports SQL, C#, PowerShell, MSBuild, Ansible, TypeScript, JavaScript, Python
4. **Flexible Rule Definition**: Rules can reference primitives, be standalone, or form hierarchies
5. **Clear Separation**: Language constructs separate from configurations
6. **Better Change Management**: Different update frequencies for different data types
7. **Traceability**: Rules traced back to primitives for governance
8. **Relationship Modeling**: Typed relationships enable complex rule dependencies
9. **Backward Compatible**: All original code generation tables preserved
10. **Extensible**: Easy to add new languages, primitives, or relationship types

## Relationship Diagram

```
┌──────────┐
│ Philote  │ (Stable GUID Identity)
└────┬─────┘
     │
     ├──────────────────────────────┐
     │                              │
     ↓                              ↓
┌────────────┐ 1             ┌─────────┐
│  Language  │───────M───────│  Rule   │ (existing, extended)
└──────┬─────┘               └────┬────┘
       │                          │
       │ M                        │ (self-ref)
       ↓                          │ ParentID
┌──────────────────┐              │
│  RulePrimitive   │              │
│  (BNF terminals) │              │
└────────┬─────────┘              │
         │                        │
         │ (optional link)        │
         └────────────────────────┤
                                  │
                            M ┌───┴──────┐ M      ┌───────────┐
                              │ RuleSet  │────────│ BuildSet  │
                              └──────────┘        └───────────┘
                                    │
                                    │ M
                                    ↓
                              ┌──────────────────────┐
                              │  RuleRelationship    │
                              │  (typed dependencies)│
                              └──────────────────────┘

[Original Code Generation Tables Preserved]
┌──────────────┐  ┌───────────┐  ┌────────┐
│ GStatement   │  │ GComment  │  │ GBody  │
│ GArgument    │  │ GSolution │  │ etc.   │
└──────────────┘  └───────────┘  └────────┘
```

## Integration Points

### With Rules Compendium
The Rules Compendium documents (SQL.md, CSharp.md, etc.) define Rule Primitives that are loaded into the `RulePrimitive` table. Each primitive:
- Has a unique Philote GUID
- Maps to a BNF non-terminal
- Links to its Language
- Includes BNF definition and attribution

### With Code Generation
The existing code generation tables (`GStatement`, `GComment`, `GBody`, etc.) are preserved and can be enhanced with Rules:
- Generated code can be defined by Rules
- Rules can reference generation templates
- BuildSets can orchestrate code generation workflows

### With BuildSets Database
The standalone BuildSets database provided the model:
- ATAPUtilities now includes all BuildSets functionality
- Can be used as the primary RRSBS database
- BuildSets database remains for specialized use cases

## Files Created

### SQL Migration Scripts:
- `Flyway/sql/V00.01.000200__Add_RRSBS_Core_Schema.sql` (264 lines)
- `Flyway/sql/V00.01.000210__Load_LanguagePrimitives_Data.sql` (155 lines)
- `Flyway/sql/V00.01.000220__Load_Rules_And_BuildSets_Data.sql` (227 lines)

### CSV Data Files:
- `Flyway/DATA/Philote.csv` (9 entries)
- `Flyway/DATA/Language.csv` (8 languages)
- `Flyway/DATA/RulePrimitive.csv` (8 primitives)
- `Flyway/DATA/Rule.csv` (5 sample rules)
- `Flyway/DATA/RuleSet.csv` (3 sample rule sets)
- `Flyway/DATA/Map_RuleSet_Rule.csv` (5 mappings)
- `Flyway/DATA/BuildSet.csv` (3 sample build sets)
- `Flyway/DATA/BuildSetHavingRuleSet.csv` (3 mappings)

### Documentation:
- `README.md` (comprehensive database documentation)
- `REFACTORING_SUMMARY.md` (this file)

## Files Modified

### No Existing Files Modified
All changes are additive:
- New migration files
- New data files
- New documentation
- No changes to existing migrations or data
- Preserves backward compatibility

## Next Steps

1. **Extract Primitives**: Extract remaining primitives from Rules Compendium documents and add to RulePrimitive.csv
2. **Link Rules to Primitives**: Update Rule.csv to set PrimitiveID where rules implement primitives
3. **Create Rule Hierarchies**: Design and implement complex rule hierarchies for features
4. **Define Relationships**: Create RuleRelationship entries for rule dependencies
5. **Testing**: Create Pester tests for schema and data integrity
6. **Validation**: Execute Rebuild-All.ps1 and verify all migrations work correctly
7. **Populate Data**: Add real rules from ATAP.Utilities codebase
8. **Build Automation**: Create scripts to generate code from BuildSets
9. **Documentation**: Add examples of using the RRSBS system
10. **Performance Tuning**: Monitor and optimize based on query patterns

## Testing Checklist

- [ ] Run Rebuild-All.ps1 successfully
- [ ] Verify all tables created
- [ ] Verify all data loaded
- [ ] Test Philote uniqueness
- [ ] Test Language-Primitive relationships
- [ ] Test Primitive-Rule relationships
- [ ] Test Rule parent-child hierarchies
- [ ] Test Rule-RuleSet mappings
- [ ] Test RuleSet-BuildSet mappings
- [ ] Test RuleRelationship constraints
- [ ] Verify all indexes created
- [ ] Test referential integrity
- [ ] Verify data counts match expectations
- [ ] Test data quality guardrails

## References

### Comparison with BuildSets Database
This refactoring brings the concepts from:
- `Databases/BuildSets/` - Standalone BuildSets database
Into the consolidated ATAPUtilities database.

Key differences:
- ATAPUtilities adds Philote identity system
- ATAPUtilities adds parent-child rule hierarchies
- ATAPUtilities adds typed rule relationships
- ATAPUtilities integrates with code generation tables
- ATAPUtilities supports 8 languages vs 5 in BuildSets

### Rules Compendium Documentation
- [Rules Compendium.SQL.md](../../SolutionDocumentation/Rules%20Compendium.SQL.md)
- [Rules Compendium.CSharp.md](../../SolutionDocumentation/Rules%20Compendium.CSharp.md)
- [Rules Compendium.Powershell.md](../../SolutionDocumentation/Rules%20Compendium.Powershell.md)
- [Rules Compendium.MSBuild.md](../../SolutionDocumentation/Rules%20Compendium.MSBuild.md)

### Related Databases
- [BuildSets Database README](../BuildSets/README.md)
- [BuildSets Refactoring Summary](../BuildSets/REFACTORING_SUMMARY.md)
