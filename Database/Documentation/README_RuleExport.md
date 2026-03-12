# Rule Export Utility

This folder contains code for reading Rules from the ATAPUtilities database and exporting them to text files.

## Overview

The Rule export utility consists of three main components:

1. **SQL Stored Procedure** - `V00.01.000300__Create_Stored_Procedure_GetRuleByName.sql`
2. **PowerShell Function** - `Export-RuleToTextFile.ps1`
3. **Standalone SQL Query** - `Query_Rule_By_Name.sql`

## SQL Stored Procedure

### Location

`Database/Flyway/SQL/V00.01.000300__Create_Stored_Procedure_GetRuleByName.sql`

### Description

Creates the stored procedure `dbo.GetRuleByName` which retrieves all metadata for a Rule including:

- PhiloteID (the stable GUID identifier)
- Rule Name
- Purpose
- Language Kind (CSharp, Powershell, SQL, MSBuild)
- Source File Reference
- Created timestamp
- Associated Rule Primitives in composition order
- Additional Philote IDs
- Time Blocks

### Installation

This stored procedure will be automatically created when you run Flyway migrations. Alternatively, you can execute the SQL script directly.

```sql
-- Deploy via Flyway (recommended)
flyway migrate

-- Or execute directly in SSMS
```

### Usage

```sql
-- Get a specific rule
EXEC dbo.GetRuleByName @RuleName = '<cs-source-file>', @LanguageKindName = 'CSharp';

-- Get a rule without language filter
EXEC dbo.GetRuleByName @RuleName = 'MyRuleName';
```

## PowerShell Function

### Location

`Database/Powershell/public/Export-RuleToTextFile.ps1`

### Description

PowerShell function that queries the database using the stored procedure and exports the Rule to a formatted text file. The output includes all Rule metadata in a human-readable format.

### Prerequisites

- PowerShell 5.1 or higher
- `dbatools` module (automatically checks and prompts for installation)

### Installation

```powershell
if (-not (Get-Command -Name 'Get-RepositoryRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
  . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-RepositoryRoot.ps1'
}
$repositoryRoot = Get-RepositoryRoot
# Dot-source the script to load the function
. (Join-Path $repositoryRoot "Database\Powershell\public\Export-RuleToTextFile.ps1")
```

### Usage Examples

#### Basic Usage

```powershell
# Export a C# rule to default location (current directory)
Export-RuleToTextFile -RuleName "<cs-source-file>" -LanguageKind "CSharp"
```

#### Specify Output Path

```powershell
# Export to a specific file
Export-RuleToTextFile -RuleName "<cs-source-file>" `
                      -OutputPath "C:\Temp\CsSourceFileRule.txt" `
                      -LanguageKind "CSharp"
```

#### Remote SQL Server

```powershell
# Connect to a remote SQL Server instance
Export-RuleToTextFile -RuleName "MyRule" `
                      -SqlInstance "SQLSERVER01" `
                      -DatabaseName "ATAPUtilities"
```

#### SQL Authentication

```powershell
# Use SQL Server authentication instead of Windows auth
$securePassword = ConvertTo-SecureString "YourPassword" -AsPlainText -Force
Export-RuleToTextFile -RuleName "MyRule" `
                      -UseIntegratedSecurity $false `
                      -Username "sqluser" `
                      -Password $securePassword
```

### Function Parameters

| Parameter             | Type         | Required | Default         | Description                                                  |
| --------------------- | ------------ | -------- | --------------- | ------------------------------------------------------------ |
| RuleName              | string       | Yes      | -               | Name of the Rule to export                                   |
| LanguageKind          | string       | No       | -               | Filter by language: 'CSharp', 'Powershell', 'SQL', 'MSBuild' |
| OutputPath            | string       | No       | Auto-generated  | Full path to output text file                                |
| DatabaseName          | string       | No       | 'ATAPUtilities' | Database name                                                |
| SqlInstance           | string       | No       | 'localhost'     | SQL Server instance                                          |
| UseIntegratedSecurity | bool         | No       | $true           | Use Windows authentication                                   |
| Username              | string       | No       | -               | SQL Server username (if not using Windows auth)              |
| Password              | SecureString | No       | -               | SQL Server password (if not using Windows auth)              |

### Output Format

The exported text file contains:

```
================================================================================
Rule Export from ATAPUtilities Database
Generated: 2026-02-27 14:30:00
================================================================================

RULE INFORMATION
--------------------------------------------------------------------------------
PhiloteID:            4f6dbde9-52f2-4d3f-82a1-7b9f3a6c4d85
Rule Name:            <cs-source-file>
Language Kind:        CSharp
Created At:           2026-01-15 10:00:00

PURPOSE
--------------------------------------------------------------------------------
Top-level container for a .cs file...

RULE COMPOSITION
--------------------------------------------------------------------------------

[1] <file-element-list>

  Description:
    Sequence of file elements...

  BNF Definition:
    <file-element-list> ::= <file-element>
                          | <file-element-list> <file-element>

  ...

================================================================================
End of Rule Export
================================================================================
```

## Standalone SQL Query

### Location

`Database/Flyway/SQL/Query_Rule_By_Name.sql`

### Description

A standalone SQL script that can be executed directly in SQL Server Management Studio (SSMS) or any SQL client. This is useful for quick queries without needing PowerShell or the stored procedure.

### Usage

1. Open the file in SSMS or your preferred SQL client
2. Update the configuration parameters at the top:
   ```sql
   DECLARE @RuleName NVARCHAR(200) = N'<cs-source-file>';  -- Your rule name
   DECLARE @LanguageKind NVARCHAR(50) = N'CSharp';          -- Or NULL for all
   ```
3. Execute the script

The script outputs:

- Rule basic information
- Rule composition with primitives
- Additional Philote IDs
- Time blocks
- Rule Sets containing the rule

## Future API Integration

These scripts are designed to eventually be called from a REST API. The stored procedure provides a stable interface that can be wrapped in an API endpoint:

### Sample API Endpoint Design

```
GET /api/rules/{ruleName}?languageKind={languageKind}

Response:
{
  "philoteId": "4f6dbde9-52f2-4d3f-82a1-7b9f3a6c4d85",
  "ruleName": "<cs-source-file>",
  "languageKind": "CSharp",
  "purpose": "...",
  "composition": [...]
}
```

## Troubleshooting

### Connection Issues

If you encounter connection errors:

```powershell
# Verify SQL Server is running
Get-DbaService -ComputerName localhost

# Test connection
Test-DbaConnection -SqlInstance localhost
```

### Missing dbatools Module

```powershell
# Install dbatools
Install-Module -Name dbatools -Scope CurrentUser -Force
```

### Stored Procedure Not Found

Ensure the stored procedure has been deployed:

```sql
-- Check if stored procedure exists
SELECT * FROM sys.procedures WHERE name = 'GetRuleByName';

-- If not, run the migration script
```

### No Rules Found

Verify the Rule exists in the database:

```sql
-- List all rules
SELECT Name, PrimitiveLanguageKindId FROM dbo.[Rule];

-- Check exact name (case-sensitive)
SELECT * FROM dbo.[Rule] WHERE Name = N'<cs-source-file>';
```

## Development Notes

- The stored procedure uses four result sets to return related data efficiently
- The PowerShell function uses `dbatools` for robust SQL Server connectivity
- All queries join through the Philote table to maintain referential integrity
- The text output format is designed to be both human-readable and parseable for future automation

## Contributing

When extending this functionality:

1. Update the stored procedure first for any schema changes
2. Update the PowerShell function to handle new data fields
3. Update this README with new examples
4. Test with various Rule types across all language kinds

## Version History

- **v1.0.0** (2026-02-27)
  - Initial release
  - SQL stored procedure for Rule retrieval
  - PowerShell export function
  - Standalone SQL query script
  - Comprehensive documentation
