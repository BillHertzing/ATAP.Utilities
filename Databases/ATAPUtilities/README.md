# ATAPUtilities Database - RRSBS Integration

## Overview

The ATAPUtilities database is the consolidated database for the ATAP.Utilities repository. It integrates the **Rules, Rule Sets, and Build Sets (RRSBS)** system with existing code generation and application management functionality.

## Database Purpose

The ATAPUtilities database serves as the central repository for:

- **Code Generation**: Tables for generating C# classes, methods, and assemblies
- **Rules System**: Rules, Rule Sets, and Build Sets that define all aspects of applications and libraries
- **Identity Management**: Philote-based stable identity system
- **Language Primitives**: Core language constructs for SQL, C#, PowerShell, and other languages
- **Application Management**: Templates and instances for application lifecycle

## Core Concepts

### Philote Identity System

**Philote** provides stable GUID-based identifiers for entities across the system:

- Each RulePrimitive has a unique Philote GUID
- Rules can optionally have Philote GUIDs for stable references
- Philote IDs never change once allocated, ensuring referential integrity

### Language Hierarchy

```
Language
  ├── RulePrimitive (BNF non-terminals)
  │     └── Rule (instances/configurations)
  │           └── RuleSet
  │                 └── BuildSet
```

### Data Change Frequency

| Data Type            | Change Frequency     | Examples                                |
| -------------------- | -------------------- | --------------------------------------- |
| **Slowly Changing**  | Rarely               | Languages, RulePrimitives               |
| **Swiftly Changing** | Frequently           | Rules, RuleSets, BuildSets              |
| **Static**           | Never after creation | Philote IDs, Code generation structures |

## Schema Structure

### Identity & Reference Tables

#### Philote

Stable GUID-based identity system for entities.

| Column      | Type                | Description                              |
| ----------- | ------------------- | ---------------------------------------- |
| PhiloteID   | uniqueidentifier PK | Unique identifier                        |
| EntityType  | nvarchar(50)        | Type of entity ('RulePrimitive', 'Rule') |
| EntityKey   | nvarchar(128)       | Optional symbolic reference              |
| CreatedDate | datetime2           | Creation timestamp                       |
| Description | nvarchar(500)       | Optional description                     |

**Indexes:**

- `PK_Philote` (Clustered on PhiloteID)
- `UQ_Philote_EntityType_EntityKey` (Unique on EntityType, EntityKey)
- `IX_Philote_EntityType` (Non-clustered on EntityType)

#### Language

Defines supported programming/markup languages.

| Column      | Type                 | Description                             |
| ----------- | -------------------- | --------------------------------------- |
| ID          | int IDENTITY(1,1) PK | Auto-incrementing ID                    |
| Name        | nvarchar(50)         | Language name (SQL, CSharp, etc.)       |
| Description | nvarchar(500)        | Language description                    |
| IsActive    | bit                  | Whether language is currently supported |
| CreatedDate | datetime2            | Creation timestamp                      |

**Supported Languages:**

- SQL - Structured Query Language
- CSharp - C# programming language
- PowerShell - Scripting and automation
- MSBuild - Build engine project files
- Ansible - Infrastructure as Code
- TypeScript - Web applications
- JavaScript - Web scripting
- Python - General purpose programming

#### RulePrimitive

Language construct primitives (BNF non-terminals) with Philote IDs.

| Column        | Type                | Description                 |
| ------------- | ------------------- | --------------------------- |
| PhiloteID     | uniqueidentifier PK | Stable GUID identifier      |
| LanguageID    | int FK              | Reference to Language       |
| SymbolicName  | nvarchar(128)       | e.g., `<sql-script-file>`   |
| Description   | nvarchar(1000)      | Primitive description       |
| BNFDefinition | nvarchar(max)       | BNF grammar definition      |
| Attribution   | nvarchar(max)       | Source references/links     |
| IsActive      | bit                 | Whether primitive is active |
| CreatedDate   | datetime2           | Creation timestamp          |
| ModifiedDate  | datetime2           | Last modification timestamp |

**Indexes:**

- `PK_RulePrimitive` (Clustered on PhiloteID)
- `FK_RulePrimitive_Language` (LanguageID → Language.ID)
- `FK_RulePrimitive_Philote` (PhiloteID → Philote.PhiloteID)
- `UQ_RulePrimitive_Language_Name` (Unique on LanguageID, SymbolicName)
- `IX_RulePrimitive_Language` (Non-clustered on LanguageID)
- `IX_RulePrimitive_SymbolicName` (Non-clustered on SymbolicName)

### Rules Tables

#### Rule (Extended)

Specific rule instances/configurations. **Extended** from original table to support RRSBS.

**Original Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Id | int IDENTITY(1,1) PK | Auto-incrementing ID |
| Name | nvarchar(512) | Rule name |
| Kind | nvarchar(512) | Rule type/kind |
| Validity | datetime | Validity date |
| DisplayOrder | nvarchar(512) | Display ordering |
| DisplayAction | nvarchar(512) | Display action |
| InputAction | nvarchar(512) | Input action |
| Value | nvarchar(512) | Rule value |
| Dirty | bit | Dirty flag |

**New Columns Added:**
| Column | Type | Description |
|--------|------|-------------|
| PhiloteID | uniqueidentifier FK | Optional Philote identifier |
| PrimitiveID | uniqueidentifier FK | Links to RulePrimitive |
| ParentID | int FK | Self-reference for hierarchy |
| PeerSortOrder | int | Sort order among siblings |
| SymbolicName | nvarchar(128) | Symbolic name for reference |
| IsActive | bit | Whether rule is active |

**New Indexes:**

- `FK_Rule_Philote` (PhiloteID → Philote.PhiloteID)
- `FK_Rule_Primitive` (PrimitiveID → RulePrimitive.PhiloteID)
- `FK_Rule_Parent` (ParentID → Rule.Id)
- `IX_Rule_Philote` (Non-clustered on PhiloteID)
- `IX_Rule_Primitive` (Non-clustered on PrimitiveID)
- `IX_Rule_Parent` (Non-clustered on ParentID)
- `IX_Rule_Parent_PeerSort` (Non-clustered on ParentID, PeerSortOrder)

#### RuleSet (Original)

Groups of related rules.

| Column   | Type                 | Description          |
| -------- | -------------------- | -------------------- |
| Id       | int IDENTITY(1,1) PK | Auto-incrementing ID |
| Name     | nvarchar(512)        | RuleSet name         |
| Validity | datetime             | Validity date        |

#### Map_RuleSet_Rule (Original)

Many-to-many relationship between RuleSets and Rules.

| Column     | Type                 | Description          |
| ---------- | -------------------- | -------------------- |
| Id         | int IDENTITY(1,1) PK | Auto-incrementing ID |
| FK_RuleSet | int FK               | Reference to RuleSet |
| FK_Rule    | int FK               | Reference to Rule    |
| SortOrder  | int                  | Sort order in set    |

#### BuildSet (New)

Collections of RuleSets that define complete features/modules.

| Column       | Type                 | Description                 |
| ------------ | -------------------- | --------------------------- |
| ID           | int IDENTITY(1,1) PK | Auto-incrementing ID        |
| Name         | nvarchar(100)        | BuildSet name               |
| Description  | nvarchar(500)        | BuildSet description        |
| IsActive     | bit                  | Whether BuildSet is active  |
| CreatedDate  | datetime2            | Creation timestamp          |
| ModifiedDate | datetime2            | Last modification timestamp |

#### BuildSetHavingRuleSet (New)

Many-to-many relationship between BuildSets and RuleSets.

| Column     | Type   | Description            |
| ---------- | ------ | ---------------------- |
| BuildSetID | int PK | Reference to BuildSet  |
| RuleSetID  | int PK | Reference to RuleSet   |
| SortOrder  | int    | Sort order in BuildSet |

**Indexes:**

- `PK_BuildSetHavingRuleSet` (Clustered on BuildSetID, RuleSetID)
- `FK_BuildSetHavingRuleSet_BuildSet` (BuildSetID → BuildSet.ID)
- `FK_BuildSetHavingRuleSet_RuleSet` (RuleSetID → RuleSet.Id)
- `IX_BuildSetHavingRuleSet_RuleSet` (Non-clustered on RuleSetID)

#### RuleRelationship (New)

Defines typed relationships between rules beyond parent-child.

| Column           | Type                 | Description                                 |
| ---------------- | -------------------- | ------------------------------------------- |
| ID               | int IDENTITY(1,1) PK | Auto-incrementing ID                        |
| SourceRuleID     | int FK               | Source rule                                 |
| TargetRuleID     | int FK               | Target rule                                 |
| RelationshipType | nvarchar(50)         | Type: 'depends-on', 'executes-before', etc. |
| Description      | nvarchar(500)        | Relationship description                    |
| IsActive         | bit                  | Whether relationship is active              |
| CreatedDate      | datetime2            | Creation timestamp                          |

**Relationship Types:**

- `depends-on` - Target must be executed before source
- `executes-before` - Source must execute before target
- `executes-after` - Source must execute after target
- `conflicts-with` - Source and target cannot both be active
- `enhances` - Source enhances/extends target
- `deprecates` - Source deprecates target

**Indexes:**

- `PK_RuleRelationship` (Clustered on ID)
- `FK_RuleRelationship_Source` (SourceRuleID → Rule.Id)
- `FK_RuleRelationship_Target` (TargetRuleID → Rule.Id)
- `UQ_RuleRelationship_Source_Target_Type` (Unique on SourceRuleID, TargetRuleID, RelationshipType)
- `IX_RuleRelationship_Source` (Non-clustered on SourceRuleID)
- `IX_RuleRelationship_Target` (Non-clustered on TargetRuleID)
- `IX_RuleRelationship_Type` (Non-clustered on RelationshipType)

### Code Generation Tables (Original)

These tables remain unchanged from the original schema:

- `GPatternReplacement` - Pattern replacement definitions
- `GStatement` - Statement definitions
- `GComment` - Comment definitions
- `GBody` - Body definitions
- `GArgument` - Argument definitions
- `GAssemblyUnit` - Assembly unit definitions
- `GSolutionFile` - Solution file metadata
- `AppTemplate` - Application templates
- `AppInstance` - Application instances
- `Map_GComment_GStatement` - Comment-Statement mappings
- `Map_GBody_GStatement` - Body-Statement mappings

## Migration Files

### Flyway Migration Sequence

#### V00.01.000000 - FlywaySchemaHistory Table

Creates Flyway's schema history tracking table.

#### V00.01.000010 - UDF_IsNullOrEmpty

User-defined function for null/empty checking.

#### V00.01.000100 - BuildTables

Original table creation:

- Code generation tables (GStatement, GComment, GBody, etc.)
- Original Rule and RuleSet tables
- AppTemplate and AppInstance tables
- Mapping tables

#### V00.01.000200 - Add_RRSBS_Core_Schema ⭐ **NEW**

**Purpose:** Adds RRSBS core schema to ATAPUtilities
**Tables Created:**

- `Philote` - Stable identity system
- `Language` - Language definitions
- `RulePrimitive` - Language construct primitives
- `BuildSet` - Feature/module definitions
- `BuildSetHavingRuleSet` - BuildSet-RuleSet associations
- `RuleRelationship` - Typed rule relationships

**Tables Extended:**

- `Rule` - Added PhiloteID, PrimitiveID, ParentID, PeerSortOrder, SymbolicName, IsActive

#### V00.01.000210 - Load_LanguagePrimitives_Data ⭐ **NEW**

**Purpose:** Load SLOWLY CHANGING reference data
**Data Loaded:**

- Philote identifiers
- Languages (8 languages)
- Rule Primitives (language constructs)

**CSV Files:**

- `Philote.csv`
- `Language.csv`
- `RulePrimitive.csv`

**Validation:**

- Minimum 3 languages
- Minimum 5 primitives
- Referential integrity checks
- Philote linkage verification

#### V00.01.000220 - Load_Rules_And_BuildSets_Data ⭐ **NEW**

**Purpose:** Load SWIFTLY CHANGING configuration data
**Data Loaded:**

- Rules with hierarchy support
- RuleSets
- Map_RuleSet_Rule associations
- BuildSets
- BuildSetHavingRuleSet associations

**CSV Files:**

- `Rule.csv`
- `RuleSet.csv`
- `Map_RuleSet_Rule.csv`
- `BuildSet.csv`
- `BuildSetHavingRuleSet.csv`

**Validation:**

- Minimum 1 rule loaded
- Minimum 1 ruleset loaded
- Referential integrity for PrimitiveID
- Philote linkage verification
- Parent-child relationship validation

## Data Organization Philosophy

### Slowly Changing Data (Languages & Primitives)

**Characteristics:**

- Represents stable language constructs
- Maps to BNF non-terminals in language grammars
- Uses Philote GUID identifiers for stability
- Loaded once, rarely updated
- Changes require coordinated updates across systems

**Examples:**

- Adding a new supported language
- Adding new BNF non-terminal primitives
- Updating primitive definitions

**Update Frequency:** Quarterly or less

### Swiftly Changing Data (Rules & BuildSets)

**Characteristics:**

- Represents configuration and business logic
- Built from primitives or custom specifications
- Updated frequently as features evolve
- Can change independently without affecting primitives

**Examples:**

- Creating new rules for features
- Modifying rule configurations
- Updating rule sets
- Adding/removing rules from BuildSets

**Update Frequency:** Daily to weekly

## CSV File Locations

All CSV files are located in: `Databases/ATAPUtilities/Flyway/DATA/`

### Slowly Changing Data Files

- `Philote.csv` - Philote identifiers
- `Language.csv` - Language definitions (8 languages)
- `RulePrimitive.csv` - Language primitives with Philote IDs

### Swiftly Changing Data Files

- `Rule.csv` - Rule instances
- `RuleSet.csv` - Rule set definitions
- `Map_RuleSet_Rule.csv` - Rule-to-RuleSet mappings
- `BuildSet.csv` - BuildSet definitions
- `BuildSetHavingRuleSet.csv` - BuildSet-to-RuleSet mappings

## Key Relationships

```
┌──────────┐
│ Philote  │
└────┬─────┘
     │
     ├──────────────────────┐
     │                      │
     ↓                      ↓
┌────────────┐         ┌────────┐
│  Language  │ 1       │  Rule  │
└──────┬─────┘         └───┬────┘
       │                   │
       │ M                 │ (self-ref)
       ↓                   │ ParentID
┌──────────────────┐       │
│  RulePrimitive   │       │
└────────┬─────────┘       │
         │                 │
         │ (optional)      │
         └─────────────────┤
                           │
                      M ┌──┴──────┐ M      ┌───────────┐
                        │ RuleSet │────────│ BuildSet  │
                        └─────────┘        └───────────┘
                             │
                             │ M
                             ↓
                        ┌──────────────────────┐
                        │ RuleRelationship     │
                        │ (depends-on, etc.)   │
                        └──────────────────────┘
```

## Usage Examples

### Creating a New Rule Primitive

1. Generate a new Philote GUID
2. Add entry to `Philote.csv`
3. Add entry to `RulePrimitive.csv` with the Philote GUID and LanguageID
4. Run Flyway migration

### Creating a New Rule

1. Optionally generate Philote GUID for stable reference
2. Add entry to `Rule.csv`
3. Set ParentID if rule is part of hierarchy
4. Set PrimitiveID if rule implements a primitive
5. Add to RuleSet via `Map_RuleSet_Rule.csv`
6. Run Flyway migration

### Creating a BuildSet

1. Add entry to `BuildSet.csv`
2. Link required RuleSets via `BuildSetHavingRuleSet.csv`
3. Run Flyway migration

## Rebuild Script

Location: `Databases/ATAPUtilities/Powershell/public/Rebuild-All.ps1`

**Usage:**

```powershell
cd C:\Dropbox\whertzing\GitHub\ATAP.Utilities\Databases\ATAPUtilities\Powershell\public
.\Rebuild-All.ps1
```

**What it does:**

1. Drops database if exists (when Force=$true)
2. Creates new database
3. Runs Flyway migrations in order
4. Loads all data from CSV files
5. Validates data integrity

## Testing

Pester tests should be added to validate:

- Schema integrity
- Data loading
- Referential integrity
- Philote uniqueness
- Parent-child hierarchies
- Rule relationships

## References

### Rules Compendium Documentation

- [Rules Compendium.SQL.md](../../SolutionDocumentation/Rules%20Compendium.SQL.md) - SQL primitives
- [Rules Compendium.CSharp.md](../../SolutionDocumentation/Rules%20Compendium.CSharp.md) - C# primitives
- [Rules Compendium.Powershell.md](../../SolutionDocumentation/Rules%20Compendium.Powershell.md) - PowerShell primitives
- [Rules Compendium.MSBuild.md](../../SolutionDocumentation/Rules%20Compendium.MSBuild.md) - MSBuild primitives

### Related Databases

- [BuildSets Database](../BuildSets/README.md) - Standalone BuildSets database
- Tags Database - Hierarchical tagging system
- Philote Database - Philote identity management

## Future Enhancements

1. **Versioning**: Add version tracking to Rules and RuleSets
2. **Audit Trail**: Track changes to rules over time
3. **Rule Validation**: Stored procedures to validate rule configurations
4. **Rule Execution**: Framework for executing rules in sequence
5. **Rule Testing**: Test harness for rule validation
6. **Performance**: Optimize indexes based on query patterns
7. **Security**: Row-level security for multi-tenant scenarios
