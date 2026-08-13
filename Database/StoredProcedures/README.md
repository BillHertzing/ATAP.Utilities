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

✅ **Workflow for Adding or Modifying Stored Procedures:**

1. **Design** the contract and obtain the required architecture approval.
2. **Create** a new Flyway migration in the active package source.
3. **Add or update** a reference copy in this folder when useful.
4. **Run** the required static, rehearsal, and deployment gates.

## File Organization

Each file should:

- Match the stored procedure name and schema.
- Include header comments indicating the migration that creates it
- Use `CREATE OR ALTER` for easy testing
- Include usage examples

## Current Stored Procedures

There are no supported stored-procedure reference copies in this folder. The
pre-V3 Rule Export procedure reference was retired on 2026-08-09. Its migration
remains under `Database/Flyway/Archive/RPRRSBSI-PreV3/SQL/` as historical
evidence only. See `Database/Documentation/RuleExport-Retirement.md`.

## Related Folders

- `Database/Flyway/SQL/`: Contains the actual migration files that CREATE the stored procedures
- `Database/Queries/`: Ad-hoc queries and query templates
- `Database/Powershell/`: Scripts that may call these stored procedures

## Naming Conventions

- Use PascalCase for stored procedure names.
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
