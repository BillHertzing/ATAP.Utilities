function Initialize-ProGetSqlServiceLogin {
  # AI assisted using Powershell.instructions.md as guidelines
  <#
.SYNOPSIS
Creates and grants SQL Server access for the ProGet Windows service account.

.DESCRIPTION
Runs idempotent SQL statements to ensure a Windows login exists for the ProGet service account,
creates a database user in the target database, and grants membership in db_owner.

.PARAMETER SqlInstance
SQL Server instance name to connect to.

.PARAMETER DatabaseName
Database name to grant access to.

.PARAMETER ServiceAccount
Windows service account to grant access for.

.PARAMETER Encrypt
Encryption mode passed through the shared SQL connection resolver.

.PARAMETER TrustServerCertificate
When enabled, trusts the SQL Server certificate without validating its issuing CA.

.OUTPUTS
PSCustomObject

.EXAMPLE
# Call the autoloaded function with basic parameters and confirmation
Initialize-ProGetSqlServiceLogin -SqlInstance 'localhost\Production' -DatabaseName 'ProGet' -ServiceAccount 'NT SERVICE\INEDOPROGETSVC' -Confirm

.EXAMPLE
# Call the function with encryption settings
Initialize-ProGetSqlServiceLogin -SqlInstance 'localhost\Production' -DatabaseName 'ProGet' -ServiceAccount 'NT SERVICE\INEDOPROGETSVC' -Encrypt Optional -TrustServerCertificate

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://docs.inedo.com/docs/installation/configuration-files
#>
  [CmdletBinding(DefaultParameterSetName = 'ConnectionParts', SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlConnection')]
    [AllowNull()]
    [object]$SqlConnection,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'DBConnectionStringSecretName')]
    [Alias('DBConnectionStringSecret', 'SecretName', 'BitwardenSecretName', 'BitwardenSecret')]
    [string]$DBConnectionStringSecretName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [Alias('HostName', 'ServerInstance')]
    [string]$DatabaseHost = 'localhost',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$InstanceName = 'Production',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlConnection')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'DBConnectionStringSecretName')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$DatabaseName = 'ProGet',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$CredentialsKey,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$ApplicationName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [switch]$UseTrustedConnection,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [switch]$IntegratedSecurity,

    [Parameter(Mandatory = $false)]
    [hashtable]$Settings,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ServiceAccount = 'NT SERVICE\INEDOPROGETSVC',

    [Parameter()]
    [string]$Encrypt = 'Optional',

    [Parameter()]
    [switch]$TrustServerCertificate
  )

  $fn = 'Initialize-ProGetSqlServiceLogin'
  $mn = 'ATAP.IAC'

  $openSQLConnection = $null
  $isCallerOwnedConnection = $false

  try {
    if (-not (Get-Command -Name 'Resolve-BuildToolingDatabaseSqlConnection' -CommandType Function -ErrorAction SilentlyContinue) -or
      -not (Get-Command -Name 'Invoke-BuildToolingSqlQuery' -CommandType Function -ErrorAction SilentlyContinue)) {
      $helperPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'private\BuildToolingSql.Helpers.ps1'
      if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
        . $helperPath
      }
    }

    $resolution = Resolve-BuildToolingDatabaseSqlConnection `
      -OriginalPSBoundParameters $PSBoundParameters `
      -SqlConnection $SqlConnection `
      -DBConnectionStringSecretName $DBConnectionStringSecretName `
      -DatabaseHost $DatabaseHost `
      -SqlInstance $SqlInstance `
      -InstanceName $InstanceName `
      -DatabaseName 'master' `
      -ConnectionMethod $ConnectionMethod `
      -CredentialsKey $CredentialsKey `
      -ApplicationName $ApplicationName `
      -UseTrustedConnection:$UseTrustedConnection `
      -IntegratedSecurity:$IntegratedSecurity `
      -Settings $Settings `
      -DefaultDatabaseHost 'localhost' `
      -DefaultDatabaseName 'master'

    $openSQLConnection = $resolution.Connection
    $isCallerOwnedConnection = [bool]$resolution.IsCallerOwned

    $escapedServiceAccount = $ServiceAccount.Replace('''', '''''')
    $escapedDatabaseName = $DatabaseName.Replace('''', '''''')

    $sql = @"
SET NOCOUNT ON;

DECLARE @ServiceAccount sysname = N'$escapedServiceAccount';
DECLARE @DatabaseName sysname = N'$escapedDatabaseName';
DECLARE @CreateLoginSql nvarchar(max);
DECLARE @CreateUserSql nvarchar(max);
DECLARE @RoleSql nvarchar(max);

IF DB_ID(@DatabaseName) IS NULL
BEGIN
  THROW 50000, 'Target database was not found.', 1;
END;

IF NOT EXISTS (
  SELECT 1
  FROM sys.server_principals
  WHERE name = @ServiceAccount
)
BEGIN
  SET @CreateLoginSql = N'CREATE LOGIN ' + QUOTENAME(@ServiceAccount) + N' FROM WINDOWS;';
  EXEC(@CreateLoginSql);
END;

SET @CreateUserSql = N'
USE ' + QUOTENAME(@DatabaseName) + N';
IF NOT EXISTS (
  SELECT 1
  FROM sys.database_principals
  WHERE name = @ServiceAccount
)
BEGIN
  CREATE USER ' + QUOTENAME(@ServiceAccount) + N' FOR LOGIN ' + QUOTENAME(@ServiceAccount) + N';
END;';
EXEC sp_executesql @CreateUserSql, N'@ServiceAccount sysname', @ServiceAccount = @ServiceAccount;

SET @RoleSql = N'
USE ' + QUOTENAME(@DatabaseName) + N';
IF NOT EXISTS (
  SELECT 1
  FROM sys.database_role_members rm
  INNER JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
  INNER JOIN sys.database_principals u ON rm.member_principal_id = u.principal_id
  WHERE r.name = N''db_owner''
    AND u.name = @ServiceAccount
)
BEGIN
  ALTER ROLE [db_owner] ADD MEMBER ' + QUOTENAME(@ServiceAccount) + N';
END;';
EXEC sp_executesql @RoleSql, N'@ServiceAccount sysname', @ServiceAccount = @ServiceAccount;
"@

    $targetDescription = "$($openSQLConnection.DataSource)/$DatabaseName"
    if ($PSCmdlet.ShouldProcess($targetDescription, "Ensure SQL login, user, and db_owner membership for $ServiceAccount")) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Applying SQL principal grants on $targetDescription for account $ServiceAccount"

      Invoke-BuildToolingSqlQuery -SqlConnection $openSQLConnection -Query $sql -As NonQuery | Out-Null

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'SQL principal grants applied successfully'

      [PSCustomObject]@{
        SqlInstance    = $openSQLConnection.DataSource
        DatabaseName   = $DatabaseName
        ServiceAccount = $ServiceAccount
        Status         = 'Success'
      }
    }
  } catch {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to grant SQL access for ProGet service account. $($_.Exception.Message)"
    if ($null -ne $openSQLConnection) {
      try { $openSQLConnection.Close() } catch { }
      try { $openSQLConnection.Dispose() } catch { }
      $openSQLConnection = $null
    }
    throw
  } finally {
    if (-not $isCallerOwnedConnection -and $null -ne $openSQLConnection) {
      try { $openSQLConnection.Close() } catch { }
      try { $openSQLConnection.Dispose() } catch { }
      $openSQLConnection = $null
    }
  }
}
