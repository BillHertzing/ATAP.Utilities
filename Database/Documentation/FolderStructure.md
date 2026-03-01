# Database Folder Structure

This document describes the organization of the `Database` folder in the ATAP.Utilities repository.

**Last Updated:** February 27, 2026
**Branch:** 63-update-atap-utilities-database-scripts

---

## Overview

The Database folder contains all artifacts related to the ATAPUtilities database, including:

- Flyway migration scripts
- PowerShell management cmdlets
- SQL query templates and stored procedure references
- Data seed files
- Documentation

---

## Complete Folder Structure

```text
Database/
│
├── README_RuleExport.md                  # Main documentation for Rule export utilities
├── API_Specification_RuleExport.md       # REST API design specification
│
├── Documentation/                        # Additional documentation
│   ├── FolderStructure.md               # This file
│   ├── PROMOTION_SUMMARY.md             # Database promotion from OlderDBsForReference
│   ├── README.RRSBS.md                  # Rules, Rule Sets, Build Sets documentation
│   └── REFACTORING_SUMMARY.md           # Summary of refactoring work
│
├── Queries/                              # Ad-hoc queries and query templates
│   ├── README.md                         # Usage guide for queries
│   └── Query_Rule_By_Name.sql           # Standalone query to retrieve Rules
│
├── StoredProcedures/                     # Reference copies of stored procedures
│   ├── README.md                         # Usage guide for stored procedures
│   └── GetRuleByName.sql                # Reference definition of dbo.GetRuleByName
│
├── Flyway/                               # Flyway database migration management
│   ├── flyway.toml                       # Flyway configuration file
│   │
│   ├── Data/                             # Seed data files (CSV format)
│   │   ├── ATAPUtilities.SeedData.csv
│   │   ├── Philote_Primitives.csv       # 51 primitive Philote IDs
│   │   ├── Philote_Rules.csv            # 24 rule Philote IDs
│   │   ├── Rule.csv                     # 24 rule definitions
│   │   └── RulePrimitive.csv            # 51 primitive definitions
│   │
│   └── SQL/                              # Flyway migration scripts (ONLY)
│       ├── V00.01.000010__Create_ATAPUtilities_Core_Schema.sql
│       ├── V00.01.000020__Load_ATAPUtilities_Data_From_BCP.sql
│       └── V00.01.000300__Create_Stored_Procedure_GetRuleByName.sql
│
└── Powershell/                           # PowerShell management scripts
    └── public/                           # Public/exported cmdlets
        ├── Example-RuleExport.ps1                # Example usage of Export-RuleToTextFile
        ├── Export-RuleToTextFile.ps1             # Export Rules to formatted text files
        ├── Invoke-DatabaseFlywayMigrations.ps1   # Run Flyway migrations
        └── Rebuild-All.ps1                       # Complete database rebuild script
```

---

## Folder Purposes

### Root Level Files

| File                              | Purpose                                                              |
| --------------------------------- | -------------------------------------------------------------------- |
| `README_RuleExport.md`            | Comprehensive guide for Rule export utilities (SQL, PowerShell, API) |
| `API_Specification_RuleExport.md` | Complete REST API specification for future rule export endpoints     |

### Documentation/

Contains detailed documentation about database structure, migrations, and design decisions.

**Files:**

- `FolderStructure.md` - This document
- `PROMOTION_SUMMARY.md` - Documentation of database promotion process
- `README.RRSBS.md` - Rules, Rule Sets, and Build Sets architecture
- `REFACTORING_SUMMARY.md` - Summary of refactoring and restructuring

### Queries/

Ad-hoc SQL queries, query templates, and development/debugging scripts.

**Purpose:**

- Development and debugging
- Query templates for PowerShell scripts
- Reference queries for API development
- SSMS ad-hoc analysis

**Important:**

- ⚠️ Do NOT place migration files here
- ✅ DO use for standalone queries
- ✅ DO commit to version control

**Files:**

- `README.md` - Usage guide with PowerShell, C#, and SSMS examples
- `Query_Rule_By_Name.sql` - Standalone query to retrieve Rules with metadata

### StoredProcedures/

Reference copies of stored procedure definitions.

**Purpose:**

- Quick reference for developers
- API integration documentation
- Development and testing templates
- Version history tracking

**Important:**

- ⚠️ These are REFERENCE copies only
- ⚠️ Changes here do NOT update the database
- ✅ Actual SPs created by Flyway migrations
- ✅ Use CREATE OR ALTER for easy testing

**Files:**

- `README.md` - Usage guide with workflow for modifying SPs
- `GetRuleByName.sql` - Reference definition (created by V00.01.000300)

### Flyway/

Flyway database migration management system.

#### Flyway/Data/

CSV seed data files loaded by migrations.

**Files:**

- `ATAPUtilities.SeedData.csv` - General seed data
- `Philote_Primitives.csv` - 51 primitive Philote GUID identifiers
- `Philote_Rules.csv` - 24 rule Philote GUID identifiers
- `Rule.csv` - 24 rule definitions (CSharp, Powershell, SQL, MSBuild)
- `RulePrimitive.csv` - 51 language primitive definitions

**Referenced by:** `V00.01.000020__Load_ATAPUtilities_Data_From_BCP.sql`

#### Flyway/SQL/

Flyway migration scripts ONLY. Must follow naming conventions:

- `V##.##.######__Description.sql` - Versioned migrations
- `R__Description.sql` - Repeatable migrations

**Current Migrations:**

| Version       | File                                        | Purpose                                                           |
| ------------- | ------------------------------------------- | ----------------------------------------------------------------- |
| V00.01.000010 | `Create_ATAPUtilities_Core_Schema.sql`      | Creates Philote, RulePrimitive, Rule, RuleSet, and related tables |
| V00.01.000020 | `Load_ATAPUtilities_Data_From_BCP.sql`      | Loads seed data from CSV files in Flyway/Data/                    |
| V00.01.000300 | `Create_Stored_Procedure_GetRuleByName.sql` | Creates dbo.GetRuleByName stored procedure                        |

**Important:**

- ⚠️ ONLY Flyway migration files allowed here
- ⚠️ Must follow Flyway naming conventions
- ✅ Versioned migrations run once in order
- ✅ Repeatable migrations run on checksum change

### Powershell/public/

Public PowerShell cmdlets for database management and Rule operations.

**Files:**

| File                                  | Purpose                                                         |
| ------------------------------------- | --------------------------------------------------------------- |
| `Rebuild-All.ps1`                     | Complete database rebuild script - drops and recreates          |
| `Invoke-DatabaseFlywayMigrations.ps1` | Cmdlet to run Flyway migrations (migrate, info, validate, etc.) |
| `Export-RuleToTextFile.ps1`           | Cmdlet to export Rules from database to formatted text files    |
| `Example-RuleExport.ps1`              | Example script demonstrating Export-RuleToTextFile usage        |

**All cmdlets:**

- Follow PowerShell best practices
- Use PSFMessage for logging
- Support -WhatIf and -Confirm
- Include comprehensive help documentation
- Comply with `Powershell.instructions.md` guidelines

---

## Database Schema Overview

### Core Tables

| Table                      | Purpose                                              |
| -------------------------- | ---------------------------------------------------- |
| `Philote`                  | Stable GUID identity system for primitives and rules |
| `PhiloteAdditionalId`      | Secondary IDs for Philotes                           |
| `PhiloteTimeBlock`         | Time period tracking for Philotes                    |
| `PrimitiveLanguageKind`    | Lookup: CSharp, Powershell, SQL, MSBuild             |
| `RulePrimitive`            | Atomic BNF building blocks (51 primitives)           |
| `RulePrimitiveInput`       | Named inputs for each primitive                      |
| `Rule`                     | Named composition of primitives (24 rules)           |
| `RulePrimitiveComposition` | Ordered primitives within a rule                     |
| `RuleSet`                  | Collections of related rules                         |
| `RuleSetMember`            | Rules belonging to RuleSets                          |
| `RuleInstantiation`        | Specific renderings of rules                         |
| `RuleInstantiationBinding` | Input bindings for instantiations                    |

### Stored Procedures

| Procedure           | Purpose                                                          |
| ------------------- | ---------------------------------------------------------------- |
| `dbo.GetRuleByName` | Retrieves Rule with all metadata, composition, and relationships |

---

## Usage Patterns

### Running Migrations

```powershell
# Load the cmdlet
. "C:\...\Database\Powershell\public\Invoke-DatabaseFlywayMigrations.ps1"

# Run pending migrations
Invoke-DatabaseFlywayMigrations -FlywayCommand 'migrate'

# Check migration status
Invoke-DatabaseFlywayMigrations -FlywayCommand 'info'

# Validate migrations
Invoke-DatabaseFlywayMigrations -FlywayCommand 'validate'
```

### Exporting Rules

```powershell
# Load the cmdlet
. "C:\...\Database\Powershell\public\Export-RuleToTextFile.ps1"

# Export a rule
Export-RuleToTextFile -RuleName "<cs-source-file>" -LanguageKind "CSharp"

# Export with custom output path
Export-RuleToTextFile -RuleName "<using-directive>" `
                      -OutputPath "C:\Temp\MyRule.txt"
```

### Using Queries

```powershell
# Execute a query from Queries folder
$query = Get-Content "C:\...\Database\Queries\Query_Rule_By_Name.sql" -Raw
Invoke-DbaQuery -SqlInstance 'localhost' `
                -Database 'ATAPUtilities' `
                -Query $query
```

### Calling Stored Procedures

```powershell
# Call stored procedure
Invoke-DbaQuery -SqlInstance 'localhost' `
                -Database 'ATAPUtilities' `
                -CommandType StoredProcedure `
                -Query 'dbo.GetRuleByName' `
                -SqlParameter @{ RuleName = '<cs-source-file>'; LanguageKindName = 'CSharp' }
```

---

## File Naming Conventions

### Migration Files (Flyway/SQL/)

**Versioned:**

- Format: `V##.##.######__Description.sql`
- Example: `V00.01.000010__Create_ATAPUtilities_Core_Schema.sql`
- Run once in version order
- Never modify after deployment

**Repeatable:**

- Format: `R__Description.sql`
- Example: `R__Update_Statistics.sql`
- Run when checksum changes
- Executed after versioned migrations

### Query Files (Queries/)

- Prefix with `Query_`
- Describe what it does
- Example: `Query_Rule_By_Name.sql`, `Query_AllPrimitives.sql`

### Stored Procedure Files (StoredProcedures/)

- Match stored procedure name
- PascalCase
- Example: `GetRuleByName.sql`, `UpsertRulePrimitive.sql`

### PowerShell Files (Powershell/public/)

- Verb-Noun format
- Example: `Invoke-DatabaseFlywayMigrations.ps1`, `Export-RuleToTextFile.ps1`

---

## Development Workflow

### Adding a New Migration

1. Create new file in `Flyway/SQL/` with next version number
2. Follow naming convention: `V##.##.######__Description.sql`
3. Test locally first
4. Run `Invoke-DatabaseFlywayMigrations -FlywayCommand 'migrate'`
5. Commit to version control

### Adding a New Stored Procedure

1. Create migration file: `V##.##.######__Create_Stored_Procedure_[Name].sql`
2. Create reference copy in `StoredProcedures/[Name].sql`
3. Update `StoredProcedures/README.md` with new SP documentation
4. Run migration
5. Commit both files

### Adding a New Query

1. Create file in `Queries/` folder
2. Name: `Query_[WhatItDoes].sql`
3. Include comments explaining purpose and usage
4. Test the query
5. Commit to version control

### Modifying an Existing Stored Procedure

1. Edit reference copy in `StoredProcedures/` for development
2. Test changes in SSMS
3. Create new migration: `V##.##.######__Update_[ProcedureName].sql`
4. Update reference copy to match new version
5. Add version comment to reference copy
6. Run migration
7. Commit all changes

---

## Environment Variables

Flyway uses these environment variables (set by PowerShell scripts):

| Variable                 | Purpose                      |
| ------------------------ | ---------------------------- |
| `FLYWAY_DATA_DIR`        | Path to Flyway/Data folder   |
| `FLYWAY_PACKAGE_NAME`    | Package name for manifest    |
| `FLYWAY_PACKAGE_VERSION` | Package version              |
| `FLYWAY_GIT_TAG`         | Git tag for tracking         |
| `FLYWAY_GIT_COMMIT`      | Git commit hash              |
| `FLYWAY_MANIFEST_VALUES` | Manifest values for tracking |

---

## Related Documentation

- **Main README:** `README_RuleExport.md` - Rule export utility guide
- **API Spec:** `API_Specification_RuleExport.md` - REST API design
- **RRSBS:** `Documentation/README.RRSBS.md` - Rules architecture
- **Queries:** `Queries/README.md` - Query usage guide
- **SPs:** `StoredProcedures/README.md` - Stored procedure reference guide
- **PowerShell Guidelines:** `../../.github/instructions/Powershell.instructions.md`

---

## Version Control Notes

### Always Commit

- ✅ Migration files
- ✅ Query files
- ✅ Stored procedure reference copies
- ✅ PowerShell scripts
- ✅ Documentation
- ✅ Data seed files (CSV)

### Never Commit

- ❌ Database backup files (\*.bak)
- ❌ Log files
- ❌ Temporary files
- ❌ Local configuration overrides

---

## Troubleshooting

### "Invalid SQL filenames found" Error

**Problem:** Non-migration files in `Flyway/SQL/` folder
**Solution:** Move to `Queries/` or `StoredProcedures/` folder

### "Table does not exist" Error

**Problem:** Migrations haven't been run
**Solution:** Run `Invoke-DatabaseFlywayMigrations -FlywayCommand 'migrate'`

### Can't Find Query File

**Problem:** Looking in wrong folder
**Solution:** Check `Queries/` folder, not `Flyway/SQL/`

### Changes to StoredProcedures/ Don't Take Effect

**Problem:** These are reference copies only
**Solution:** Create a migration to update the actual procedure

---

## Maintenance

### Regular Tasks

- Review and update documentation quarterly
- Verify all migrations run successfully
- Test stored procedures after modifications
- Update API specification as endpoints are implemented
- Keep reference copies in sync with actual database objects

### Before Major Changes

1. Document current state
2. Create database backup
3. Test in development environment
4. Review with team
5. Plan rollback strategy

---

## Contact & Support

For questions about this structure or the database:

- See `README_RuleExport.md` for Rule export utilities
- See folder-specific README files for detailed usage
- Refer to `.github/instructions/Powershell.instructions.md` for coding guidelines

---

**Document Version:** 1.0
**Last Reviewed:** February 27, 2026
**Maintained By:** ATAP.Utilities Database Team
