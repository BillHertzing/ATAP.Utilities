#Requires -Modules PSFramework, dbatools

function Initialize-SqlServiceLogin {
  <#
    .SYNOPSIS
        Idempotently creates a Windows login, database user, and db_owner role grant
        on a SQL Server instance for a specified service account.

    .DESCRIPTION
        Runs two idempotent T-SQL batches against a SQL Server instance:

        Batch 1 (master): Creates a Windows server-level login if one does not already
          exist, using CREATE LOGIN ... FROM WINDOWS.

        Batch 2 (target database): Creates a database user mapped to that login if
          absent, then adds the user to the db_owner fixed database role using
          ALTER ROLE [db_owner] ADD MEMBER.

        All dynamic identifier construction uses QUOTENAME() inside SQL EXEC() calls
        to prevent SQL-injection via account or database names.

        This is a generic replacement / generalization of Initialize-ProGetSqlServiceLogin
        in ATAP.Utilities.BuildTooling.PowerShell.  Use that function when the service
        account is the NT Service virtual account created by ProGet; use this function
        when the account is a real local Windows user such as SvcProGet or SvcBuildmaster.

    .PARAMETER SqlConnection
        Existing open SQL connection. When supplied, this function uses the connection
        directly and leaves lifecycle ownership with the caller.

    .PARAMETER DBConnectionStringSecretName
        Bitwarden secret name whose notes field contains the SQL connection string.
        Alias: SecretName.

    .PARAMETER SqlInstance
        SQL Server instance in 'Server\Instance' or 'Server' format.
        Example: 'localhost\Production'

    .PARAMETER DatabaseName
        Name of the application database that the service account needs db_owner access to.
        The database must already exist (created by the application installer).
        Examples: 'ProGet', 'BuildMaster'

    .PARAMETER ServiceAccount
        Windows account in 'DOMAIN\Account' or 'COMPUTERNAME\Account' format.
        This is the account that will be granted access.
        Examples: 'UTAT022\SvcProGet', 'UTAT022\SvcBuildmaster'

    .PARAMETER Encrypt
        SqlClient Encrypt connection setting.  Allowed values: Optional, Mandatory, Strict.
        Default: 'Optional'.

    .PARAMETER TrustServerCertificate
        When specified, disables certificate chain validation for the SQL Server TLS
        certificate.  Useful in development / new-computer setup before a proper cert
        is deployed.

    .OUTPUTS
        PSCustomObject with fields:
          SqlInstance, DatabaseName, ServiceAccount, Status

    .EXAMPLE
        Initialize-SqlServiceLogin `
            -SqlInstance     'localhost\Production' `
            -DatabaseName    'ProGet' `
            -ServiceAccount  "$env:COMPUTERNAME\SvcProGet" `
            -Encrypt          Optional `
            -TrustServerCertificate

        Creates / verifies the Windows login and grants db_owner on the ProGet database.

    .EXAMPLE
        Initialize-SqlServiceLogin `
            -SqlInstance     'localhost\Production' `
            -DatabaseName    'BuildMaster' `
            -ServiceAccount  "UTAT022\SvcBuildmaster" `
            -Encrypt          Optional `
            -TrustServerCertificate `
            -WhatIf

        Shows what would be executed without making changes.

    .NOTES
        Requires the dbatools PowerShell module (Invoke-DbaQuery).
        The caller must have a SQL Server login with sysadmin or securityadmin + alter any
        login permissions.  Running as the host administrator under Integrated Security is
        the typical approach on a new-computer setup.
    #>

  [CmdletBinding(DefaultParameterSetName = 'SqlInstance', SupportsShouldProcess, ConfirmImpact = 'Medium')]
  param (
    [Parameter(Mandatory, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlConnection')]
    [AllowNull()]
    [object] $SqlConnection,

    [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'DBConnectionStringSecretName')]
    [Alias('DBConnectionStringSecret', 'SecretName', 'BitwardenSecretName', 'BitwardenSecret')]
    [string] $DBConnectionStringSecretName,

    [Parameter(Mandatory, ParameterSetName = 'SqlInstance')]
    [string] $SqlInstance,

    [Parameter(Mandatory)]
    [string] $DatabaseName,

    [Parameter(Mandatory)]
    [string] $ServiceAccount,

    [ValidateSet('Optional', 'Mandatory', 'Strict')]
    [string] $Encrypt = 'Optional',

    [switch] $TrustServerCertificate
  )

  $fn = $MyInvocation.MyCommand.Name
  $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'

  if (-not (Get-Command -Name 'Resolve-DatabaseSqlConnection' -CommandType Function -ErrorAction SilentlyContinue)) {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Resolve-DatabaseSqlConnection.ps1')
  }

  $openSQLConnection = $null
  $isCallerOwnedConnection = $false

  if ($PSCmdlet.ParameterSetName -eq 'SqlInstance') {
    $connectionStringBuilder = [Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new()
    $connectionStringBuilder.DataSource = $SqlInstance
    $connectionStringBuilder.InitialCatalog = 'master'
    $connectionStringBuilder.IntegratedSecurity = $true
    $connectionStringBuilder.Encrypt = $Encrypt
    $connectionStringBuilder.TrustServerCertificate = [bool] $TrustServerCertificate
    $openSQLConnection = [Microsoft.Data.SqlClient.SqlConnection]::new($connectionStringBuilder.ConnectionString)
    $openSQLConnection.Open()
  }
  else {
    $resolution = Resolve-DatabaseSqlConnection `
      -OriginalPSBoundParameters $PSBoundParameters `
      -SqlConnection $SqlConnection `
      -DBConnectionStringSecretName $DBConnectionStringSecretName `
      -DatabaseName $DatabaseName
    $openSQLConnection = $resolution.Connection
    $isCallerOwnedConnection = [bool] $resolution.IsCallerOwned
    if (-not [string]::IsNullOrWhiteSpace($DBConnectionStringSecretName)) {
      $SqlInstance = $openSQLConnection.DataSource
    }
  }

  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
    -Message "[$fn] Applying SQL principal grants on $SqlInstance for database '$DatabaseName' and account '$ServiceAccount'"

  $result = [PSCustomObject]@{
    SqlInstance    = $SqlInstance
    DatabaseName   = $DatabaseName
    ServiceAccount = $ServiceAccount
    Status         = 'NotStarted'
  }

  # Escape single quotes in all values used as NVARCHAR literals in DECLARE statements.
  # QUOTENAME() in the dynamic EXEC calls protects identifier injection;
  # the single-quote doubling here protects the DECLARE string assignments.
  $loginEscaped = $ServiceAccount -replace "'", "''"
  $userEscaped = ($ServiceAccount -split '\\')[-1] -replace "'", "''"

  # Batch 1: create the server-level Windows login (run against master)
  $loginSql = @"
USE [master];
DECLARE @login NVARCHAR(256) = N'$loginEscaped';
IF NOT EXISTS (
    SELECT 1
    FROM   sys.server_principals
    WHERE  [name] = @login
      AND  [type] IN ('U', 'G')
)
BEGIN
    DECLARE @sql NVARCHAR(512) = N'CREATE LOGIN ' + QUOTENAME(@login) + N' FROM WINDOWS;';
    EXEC (@sql);
END;
"@

  # Batch 2: create the DB user and grant db_owner (run against the target database)
  $userSql = @"
USE [$($DatabaseName.Replace(']', ']]'))];
DECLARE @login NVARCHAR(256) = N'$loginEscaped';
DECLARE @user  NVARCHAR(128) = N'$userEscaped';
IF NOT EXISTS (
    SELECT 1
    FROM   sys.database_principals
    WHERE  [name] = @user
      AND  [type] IN ('U', 'G')
)
BEGIN
    DECLARE @sqlUser NVARCHAR(512) = N'CREATE USER ' + QUOTENAME(@user) + N' FOR LOGIN ' + QUOTENAME(@login) + N';';
    EXEC (@sqlUser);
END;
IF IS_ROLEMEMBER(N'db_owner', @user) = 0
BEGIN
    DECLARE @sqlRole NVARCHAR(512) = N'ALTER ROLE [db_owner] ADD MEMBER ' + QUOTENAME(@user) + N';';
    EXEC (@sqlRole);
END;
"@

  try {
    if ($PSCmdlet.ShouldProcess("$SqlInstance / $DatabaseName", "Grant db_owner to '$ServiceAccount'")) {

      # Step 1: server login
      $loginCommand = $openSQLConnection.CreateCommand()
      $loginCommand.CommandText = $loginSql
      [void] $loginCommand.ExecuteNonQuery()
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "[$fn] Server login step completed"

      # Step 2: DB user + role membership
      $userCommand = $openSQLConnection.CreateCommand()
      $userCommand.CommandText = $userSql
      [void] $userCommand.ExecuteNonQuery()
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "[$fn] Database user/role step completed in '$DatabaseName'"

      $result.Status = 'Success'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "[$fn] SQL principal grants applied successfully"
    } else {
      $result.Status = 'WhatIf'
    }
  } catch {
    $result.Status = "Error: $($_.Exception.Message)"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
      -Message "[$fn] $($_.Exception.Message)" -Exception $_.Exception
    throw
  }
  finally {
    if ($null -ne $openSQLConnection -and -not $isCallerOwnedConnection) {
      try { $openSQLConnection.Close() } catch { }
      try { $openSQLConnection.Dispose() } catch { }
    }
  }

  $result
}
