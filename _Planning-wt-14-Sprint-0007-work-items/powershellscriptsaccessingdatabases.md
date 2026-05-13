# PowerShell Scripts with Database Connection Parameters

Below is a review of the PowerShell scripts and functions in the specified folders that contain database connection parameters (e.g., ServerInstance, DatabaseName, ConnectionString) or invoke `sqlcmd`. It also lists the corresponding `.test.ps1` files where available.

### ATAP.Utilities.DatabaseManagement.Powershell (Public)

| PowerShell Script / Function                  | Associated Test File (`*.test.ps1` or `*.Tests.ps1`)                                                           |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `Resolve-DbInstanceName.ps1`                  | `tests\Unit\Resolve-DbInstanceName.Tests.ps1`                                                                  |
| `Resolve-DatabaseSqlConnection.ps1`           | `tests\Unit\Resolve-DatabaseSqlConnection.Tests.ps1`                                                           |
| `Remove-FeatureSharedDb.ps1`                  | `tests\Unit\Remove-FeatureSharedDb.Tests.ps1`                                                                  |
| `Remove-DeveloperScratchDb.ps1`               | `tests\Unit\Remove-DeveloperScratchDb.Tests.ps1`                                                               |
| `New-FeatureSharedDb.ps1`                     | `tests\Unit\New-FeatureSharedDb.Tests.ps1`                                                                     |
| `New-DeveloperScratchDb.ps1`                  | `tests\Unit\New-DeveloperScratchDb.Tests.ps1`                                                                  |
| `New-ConnectionStringBuilderFromDbaTools.ps1` | _No corresponding test file found_                                                                             |
| `New-CobianSqlJobs.ps1`                       | _No corresponding test file found_                                                                             |
| `Invoke-SqlServerBackup.ps1`                  | _No corresponding test file found_                                                                             |
| `Invoke-FlywayRehearsal.ps1`                  | `tests\Unit\Invoke-FlywayRehearsal.Tests.ps1` `tests\Integration\Invoke-FlywayRehearsal.Integration.Tests.ps1` |
| `Invoke-Flyway.ps1`                           | _No corresponding test file found_                                                                             |
| `Install-SqlServerInstance.ps1`               | _No corresponding test file found_                                                                             |
| `Get-DatabaseCredentialsKey.ps1`              | _No corresponding test file found_                                                                             |
| `Export-RuleToTextFile.ps1`                   | _No corresponding test file found_                                                                             |
| `Example-RuleExport.ps1`                      | _No corresponding test file found_                                                                             |
| `DatabaseProvisioning.ps1`                    | _No corresponding test file found_                                                                             |
| `DatabaseBuildAndMigrateTasks.ps1`            | _No corresponding test file found_                                                                             |
| `Build-DatabaseWithFlyway.ps1`                | _No corresponding test file found_                                                                             |

### ATAP.Utilities.DatabaseManagement.Powershell (Public/Obsolete)

| PowerShell Script / Function                       | Associated Test File (`*.test.ps1` or `*.Tests.ps1`) |
| -------------------------------------------------- | ---------------------------------------------------- |
| `Remove-DeveloperDatabaseInstances.ps1`            | _No corresponding test file found_                   |
| `New-DeveloperDatabaseInstances.ps1`               | _No corresponding test file found_                   |
| `Invoke-DatabaseRebuild.ps1`                       | _No corresponding test file found_                   |
| `ATAPUtilities_Database_BulkDataOut.ps1`           | _No corresponding test file found_                   |
| `ATAPUtilities_Database_BackupDropAndRecreate.ps1` | _No corresponding test file found_                   |
| `afterVersioned__ImportData.ps1`                   | _No corresponding test file found_                   |

### ATAP.Utilities.BuildTooling.PowerShell (Public)

| PowerShell Script / Function           | Associated Test File (`*.test.ps1` or `*.Tests.ps1`)   |
| -------------------------------------- | ------------------------------------------------------ |
| `Initialize-ProGetSqlServiceLogin.ps1` | _No corresponding test file found_                     |
| `New-OverviewSprintWorkspace.ps1`      | `tests\Unit\New-OverviewSprintWorkspace.Tests.ps1`     |
| `New-SprintBitwardenSecrets.ps1`       | _No corresponding test file found_                     |
| `New-SprintStage2.ps1`                 | _No corresponding test file found_                     |
| `Read-SourceAndCreateRules.ps1`        | _No corresponding test file found_                     |
| `Remove-SprintBitwardenSecrets.ps1`    | `tests\Unit\Remove-SprintBitwardenSecrets.Tests.ps1`   |
| `Remove-SprintSqlServerInstances.ps1`  | `tests\Unit\Remove-SprintSqlServerInstances.Tests.ps1` |
| `Set-BuildMasterStableVariables.ps1`   | _No corresponding test file found_                     |
| `Sync-RulesToCSV.ps1`                  | _No corresponding test file found_                     |
| `New-SprintSqlServerInstances.ps1`     | `tests\Unit\New-SprintSqlServerInstances.Tests.ps1`    |
| `New-PermanentBitwardenSecrets.ps1`    | _No corresponding test file found_                     |

### ATAP.Utilities.BuildTooling.PowerShell (Private)

| PowerShell Script / Function               | Associated Test File (`*.test.ps1` or `*.Tests.ps1`) |
| ------------------------------------------ | ---------------------------------------------------- |
| `New-SprintDatabaseInstances.ps1`          | _No corresponding test file found_                   |
| `New-SprintBitwardenConnectionStrings.ps1` | _No corresponding test file found_                   |
| `Find-SqlServerSetupExe.ps1`               | _No corresponding test file found_                   |

### Database\Powershell (Public)

| PowerShell Script / Function   | Associated Test File (`*.test.ps1` or `*.Tests.ps1`) |
| ------------------------------ | ---------------------------------------------------- |
| `Rebuild-All.ps1`              | _No corresponding test file found_                   |
| `Rebuild-All-AllInstances.ps1` | _No corresponding test file found_                   |

## SampleParameterBlock

All PowerShell functions that access a SQL database should support three mutually exclusive connection-selection parameter sets:

- `SqlConnection`: an already-open `Microsoft.Data.SqlClient.SqlConnection`.
- `BitwardenSecretName`: a Bitwarden secret name whose value is a complete SQL connection string.
- `ConnectionParts`: the existing database host/name/instance/authentication parameters, resolved through `Get-ParameterValueFromNeoConfigurationRoot` / `Get-PVal`.

```powershell
[CmdletBinding(DefaultParameterSetName = 'ConnectionParts')]
param(
  [Parameter(
    Mandatory = $true,
    ValueFromPipeline = $true,
    ValueFromPipelineByPropertyName = $true,
    ParameterSetName = 'SqlConnection')]
  [Microsoft.Data.SqlClient.SqlConnection] $SqlConnection,

  [Parameter(
    Mandatory = $true,
    ValueFromPipelineByPropertyName = $true,
    ParameterSetName = 'BitwardenSecretName')]
  [Alias('BitwardenSecret', 'SecretName')]
  [string] $BitwardenSecretName,

  [Parameter(
    Mandatory = $false,
    ValueFromPipelineByPropertyName = $true,
    ParameterSetName = 'ConnectionParts')]
  [Alias('HostName', 'ServerInstance')]
  [string] $DatabaseHost,

  [Parameter(
    Mandatory = $false,
    ValueFromPipelineByPropertyName = $true,
    ParameterSetName = 'ConnectionParts')]
  [Alias('SqlInstance')]
  [string] $InstanceName,

  [Parameter(
    Mandatory = $false,
    ValueFromPipelineByPropertyName = $true,
    ParameterSetName = 'ConnectionParts')]
  [string] $DatabaseName,

  [Parameter(
    Mandatory = $false,
    ValueFromPipelineByPropertyName = $true,
    ParameterSetName = 'ConnectionParts')]
  [string] $ConnectionMethod,

  [Parameter(
    Mandatory = $false,
    ValueFromPipelineByPropertyName = $true,
    ParameterSetName = 'ConnectionParts')]
  [string] $CredentialsKey,

  [Parameter(
    Mandatory = $false,
    ValueFromPipelineByPropertyName = $true,
    ParameterSetName = 'ConnectionParts')]
  [string] $ApplicationName,

  [Parameter(
    Mandatory = $false,
    ValueFromPipelineByPropertyName = $true,
    ParameterSetName = 'ConnectionParts')]
  [switch] $UseTrustedConnection,

  [Parameter(
    Mandatory = $false,
    ValueFromPipelineByPropertyName = $true,
    ParameterSetName = 'ConnectionParts')]
  [switch] $IntegratedSecurity,

  [Parameter(Mandatory = $false)]
  [hashtable] $Settings

  # Add cmdlet-specific parameters here. If they must be valid for all
  # connection methods, leave off ParameterSetName or repeat them across
  # all three parameter sets.
)
```

Do not add `ValidateScript`, `ValidateSet`, `ValidateNotNull`, or similar parameter-block validation to these connection parameters. Validate them in the `begin` block instead.

If a pipeline object can contain more than one connection selector property, `SqlConnection` wins over `BitwardenSecretName`, and both win over `ConnectionParts`. Direct parameter use normally lets PowerShell select the parameter set. Pipeline property binding happens after `begin`, so functions that accept pipeline input should call the shared resolver from `process` for each pipeline object.

## SampleBeginBlockValidation

The shared validation implementation lives in `src\ATAP.Utilities.DatabaseManagement.Powershell\public\Resolve-DatabaseSqlConnection.ps1`. The function returns one open `Microsoft.Data.SqlClient.SqlConnection` object and uses private helpers for Bitwarden lookup, connection-string opening, `Get-PVal` resolution, and `New-ConnectionStringBuilderFromDbaTools` integration.

For functions that do not process pipeline input, the `begin` block should reduce to a single resolver call:

```powershell
begin {
  $resolvedSqlConnection = Resolve-DatabaseSqlConnection `
    -OriginalPSBoundParameters $PSBoundParameters `
    -SqlConnection $SqlConnection `
    -BitwardenSecretName $BitwardenSecretName `
    -DatabaseHost $DatabaseHost `
    -InstanceName $InstanceName `
    -DatabaseName $DatabaseName `
    -ConnectionMethod $ConnectionMethod `
    -CredentialsKey $CredentialsKey `
    -ApplicationName $ApplicationName `
    -UseTrustedConnection:$UseTrustedConnection `
    -IntegratedSecurity:$IntegratedSecurity `
    -Settings $Settings
}
```

For functions that accept pipeline input by property name, use the same resolver in `begin` for direct parameter calls and in `process` for pipeline-bound values:

```powershell
begin {
  $resolvedSqlConnection = $null
  $connectionResolvedInBegin = $false

  if (-not $MyInvocation.ExpectingInput -or
      $PSBoundParameters.ContainsKey('SqlConnection') -or
      $PSBoundParameters.ContainsKey('BitwardenSecretName')) {
    $resolvedSqlConnection = Resolve-DatabaseSqlConnection `
      -OriginalPSBoundParameters $PSBoundParameters `
      -SqlConnection $SqlConnection `
      -BitwardenSecretName $BitwardenSecretName `
      -DatabaseHost $DatabaseHost `
      -InstanceName $InstanceName `
      -DatabaseName $DatabaseName `
      -ConnectionMethod $ConnectionMethod `
      -CredentialsKey $CredentialsKey `
      -ApplicationName $ApplicationName `
      -UseTrustedConnection:$UseTrustedConnection `
      -IntegratedSecurity:$IntegratedSecurity `
      -Settings $Settings

    $connectionResolvedInBegin = $true
  }
}

process {
  if (-not $connectionResolvedInBegin) {
    $resolvedSqlConnection = Resolve-DatabaseSqlConnection `
      -OriginalPSBoundParameters $PSBoundParameters `
      -SqlConnection $SqlConnection `
      -BitwardenSecretName $BitwardenSecretName `
      -DatabaseHost $DatabaseHost `
      -InstanceName $InstanceName `
      -DatabaseName $DatabaseName `
      -ConnectionMethod $ConnectionMethod `
      -CredentialsKey $CredentialsKey `
      -ApplicationName $ApplicationName `
      -UseTrustedConnection:$UseTrustedConnection `
      -IntegratedSecurity:$IntegratedSecurity `
      -Settings $Settings
  }

  # Use $resolvedSqlConnection for all database work in this function.
}
```

If a function stores its connection settings below a custom configuration root, pass the resolver's dotted-path parameters, for example `-DatabaseHostDottedPath "RulesManagement.$Environment.DatabaseHost"` and `-InstanceNameDottedPath "RulesManagement.$Environment.InstanceName"`.
