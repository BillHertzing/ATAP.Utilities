# Database Queries

This folder contains ad-hoc SQL queries, query templates, and development/debugging scripts for the ATAPUtilities database.

## Purpose

- **Ad-hoc queries**: Standalone SQL queries for data exploration and analysis
- **Query templates**: Reusable query patterns for common operations
- **Development queries**: Scripts useful during development and debugging
- **API query references**: Queries that may be used by API endpoints

## Important Notes

⚠️ **DO NOT** place these files in `Database/Flyway/SQL/`

- Flyway expects only migration files (V##**Description.sql or R**Description.sql)
- This folder is separate to avoid Flyway validation errors

✅ **DO** use these queries:

- From PowerShell scripts via `Invoke-DbaQuery`
- From API code (ASP.NET, Node.js, etc.)
- Directly in SQL Server Management Studio (SSMS)
- For development and debugging

## Usage Examples

### From PowerShell

```powershell
# Execute a query from this folder
$queryPath = "C:\Dropbox\whertzing\GitHub\ATAP.Utilities-branch63\Database\Queries\Query_Rule_By_Name.sql"
$query = Get-Content $queryPath -Raw

Invoke-DbaQuery -SqlInstance 'localhost' `
                -Database 'ATAPUtilities' `
                -Query $query
```

### From C# API

```csharp
// Read query from file
var queryPath = Path.Combine(_hostEnvironment.ContentRootPath,
    "Database", "Queries", "Query_Rule_By_Name.sql");
var query = await File.ReadAllTextAsync(queryPath);

// Execute query
var results = await _dbContext.Database.ExecuteSqlRawAsync(query);
```

### From SSMS

Simply open the .sql file and execute it directly.

## File Organization

- **Query\_\*.sql**: Ad-hoc queries for data retrieval
- **Report\_\*.sql**: Queries that generate reports
- **Debug\_\*.sql**: Helpful queries for troubleshooting

## Related Folders

- `Database/StoredProcedures/`: Reference definitions of stored procedures
- `Database/Flyway/SQL/`: Database migration scripts (DO NOT PUT QUERIES HERE)
- `Database/Powershell/`: PowerShell scripts that may use these queries

## Adding New Queries

When adding new queries:

1. Use descriptive names: `Query_[WhatItDoes].sql`
2. Include comments explaining the query's purpose
3. Add example parameters if applicable
4. Document any special requirements or dependencies

## Version Control

These query files are version-controlled and should be committed to the repository for:

- Team collaboration
- Documentation
- Consistency across environments
- API integration reference
