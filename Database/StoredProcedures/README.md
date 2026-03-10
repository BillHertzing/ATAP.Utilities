# Database Stored Procedures

This folder contains reference copies of stored procedure definitions from the ATAPUtilities database.

## Purpose

This folder provides:

- **Quick reference**: Easy-to-find SP definitions without searching through migration files
- **API development**: Reference for developers building API endpoints
- **Documentation**: Clear view of what stored procedures exist and their signatures
- **Development**: Template for testing SP modifications before creating migrations

## Important Notes

⚠️ **THESE ARE REFERENCE COPIES**

- The actual stored procedures are created by Flyway migrations in `Database/Flyway/SQL/`
- Changes here do NOT automatically update the database
- To modify a stored procedure, create a new migration file

✅ **Workflow for Modifying Stored Procedures:**

1. **Edit** the reference copy in this folder (for development/testing)
2. **Test** the changes directly in SQL Server
3. **Create** a new Flyway migration (e.g., `V00.01.000400__Update_GetRuleByName.sql`)
4. **Update** this reference copy to match the new version
5. **Run** Flyway migration to apply to all environments

## File Organization

Each file should:

- Match the stored procedure name (e.g., `GetRuleByName.sql` for `dbo.GetRuleByName`)
- Include header comments indicating the migration that creates it
- Use `CREATE OR ALTER` for easy testing
- Include usage examples

## Usage Examples

### From PowerShell

```powershell
# Execute stored procedure
Invoke-DbaQuery -SqlInstance 'localhost' `
                -Database 'ATAPUtilities' `
                -CommandType StoredProcedure `
                -Query 'dbo.GetRuleByName' `
                -SqlParameter @{ RuleName = '<cs-source-file>'; LanguageKindName = 'CSharp' }
```

### From C# API

```csharp
// Call stored procedure via Dapper
var parameters = new { RuleName = "<cs-source-file>", LanguageKindName = "CSharp" };
using var multi = await connection.QueryMultipleAsync(
    "dbo.GetRuleByName",
    parameters,
    commandType: CommandType.StoredProcedure);

var ruleInfo = await multi.ReadFirstOrDefaultAsync<RuleInfo>();
var composition = await multi.ReadAsync<RuleComposition>();
```

### Direct Testing in SSMS

```sql
-- Copy from this folder, modify, and test
EXEC dbo.GetRuleByName
    @RuleName = '<cs-source-file>',
    @LanguageKindName = 'CSharp';
```

## Current Stored Procedures

- **GetRuleByName.sql**: Retrieves a Rule with all metadata by name
  - Created by: `V00.01.000300__Create_Stored_Procedure_GetRuleByName.sql`
  - Returns: Multiple result sets (Rule info, Composition, Additional IDs, Time Blocks)

## Related Folders

- `Database/Flyway/SQL/`: Contains the actual migration files that CREATE the stored procedures
- `Database/Queries/`: Ad-hoc queries and query templates
- `Database/Powershell/`: Scripts that may call these stored procedures

## Naming Conventions

- Use PascalCase for stored procedure names (e.g., `GetRuleByName`)
- Prefix with verb describing action: `Get`, `Insert`, `Update`, `Delete`, `Upsert`, `Calculate`
- Keep names clear and descriptive

## Version History

When a stored procedure is modified:

1. Update the reference copy here
2. Add a comment noting the version and migration file
3. Keep old version commented out if the changes are significant

Example:

```sql
-- Version 1 - Created by V00.01.000300
-- Version 2 - Modified by V00.01.000500 (added caching hints)
```

## Best Practices

- ✅ Keep reference copies in sync with migrations
- ✅ Include usage examples in comments
- ✅ Document all parameters and return values
- ✅ Use meaningful, descriptive names
- ⚠️ Remember: Changes here don't affect the database automatically
- ⚠️ Always create a migration for actual database changes
