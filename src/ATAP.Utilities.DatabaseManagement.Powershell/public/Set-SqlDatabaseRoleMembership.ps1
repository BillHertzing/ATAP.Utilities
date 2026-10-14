#Requires -Modules PSFramework, dbatools

function Set-SqlDatabaseRoleMembership {
  <#
    .SYNOPSIS
        Idempotently adds or removes a database principal's membership in a named
        application database role.

    .DESCRIPTION
        Flyway migrations in this repository create application roles and grant those
        roles their object permissions, but they deliberately never add members. A
        migration runs against every tier, while membership names a host-specific service
        account, so membership is an operator step applied per deployment. This function
        is that step, made repeatable and reversible.

        Distinct from Initialize-SqlServiceLogin, which grants the fixed db_owner role and
        creates the login and user if they are missing. This function grants a *named
        application role* only, and refuses when the principal or the role does not exist
        rather than creating either. A membership that silently created its own principal
        would hide exactly the misconfiguration it is meant to surface.

        -Ensure Absent removes the membership. Every grant made through this function is
        expected to be revoked eventually, so revocation is a first-class parameter rather
        than a separate script somebody has to write under time pressure.

        All dynamic identifier construction uses QUOTENAME() inside SQL EXEC() calls to
        prevent SQL-injection via principal or role names.

    .PARAMETER SqlConnection
        Existing open SQL connection. When supplied, this function uses the connection
        directly and leaves lifecycle ownership with the caller.

    .PARAMETER DBConnectionStringSecretName
        Bitwarden secret name whose notes field contains the SQL connection string.
        Alias: SecretName.

    .PARAMETER SqlInstance
        SQL Server instance in 'Server\Instance' or 'Server' format.

    .PARAMETER DatabaseName
        Database holding the role. The database and the role must already exist.

    .PARAMETER DatabasePrincipal
        The database principal to add or remove. Accepts either the database user name
        or the Windows account the user is mapped to ('DOMAIN\Account'); the account form
        is resolved through the login SID, so a user whose name differs from the account's
        short name is still found.

    .PARAMETER RoleName
        The application database role, for example 'AceAISupervisorCaptureExecutor'.

    .PARAMETER Ensure
        'Present' adds the membership, 'Absent' removes it. Default 'Present'.

    .PARAMETER Encrypt
        SqlClient Encrypt connection setting. Allowed values: Optional, Mandatory, Strict.
        Default: 'Optional'.

    .PARAMETER TrustServerCertificate
        Disables certificate chain validation for the SQL Server TLS certificate.

    .OUTPUTS
        PSCustomObject with fields:
          SqlInstance, DatabaseName, DatabasePrincipal, RoleName, Ensure, Status

    .EXAMPLE
        Set-SqlDatabaseRoleMembership -SqlInstance 'UTAT022\Exp' -DatabaseName 'ATAPUtilities' `
          -DatabasePrincipal 'UTAT022\SvcAceOutpost' -RoleName 'AceAISupervisorCaptureExecutor'

    .EXAMPLE
        # Revoke once AceOutpost persists through the AceCommander API instead.
        Set-SqlDatabaseRoleMembership -SqlInstance 'UTAT022\Exp' -DatabaseName 'ATAPUtilities' `
          -DatabasePrincipal 'UTAT022\SvcAceOutpost' -RoleName 'AceAISupervisorCaptureExecutor' `
          -Ensure Absent
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
    [Alias('ServiceAccount', 'PrincipalName')]
    [string] $DatabasePrincipal,

    [Parameter(Mandatory)]
    [string] $RoleName,

    [ValidateSet('Present', 'Absent')]
    [string] $Ensure = 'Present',

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

  if ($PSCmdlet.ParameterSetName -ne 'SqlInstance') {
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
    -Message "[$fn] Ensuring membership '$Ensure' for principal '$DatabasePrincipal' in role '$RoleName' on $SqlInstance/$DatabaseName"

  $result = [PSCustomObject]@{
    SqlInstance       = $SqlInstance
    DatabaseName      = $DatabaseName
    DatabasePrincipal = $DatabasePrincipal
    RoleName          = $RoleName
    Ensure            = $Ensure
    Status            = 'NotStarted'
  }

  $principalEscaped = $DatabasePrincipal -replace "'", "''"
  $roleEscaped = $RoleName -replace "'", "''"
  # ALTER ROLE ... ADD MEMBER and DROP MEMBER differ only in the verb, and both are
  # no-ops guarded by the same existence check, so one batch covers both directions.
  $membershipVerb = if ($Ensure -eq 'Present') { 'ADD' } else { 'DROP' }
  $membershipShouldExist = if ($Ensure -eq 'Present') { '1' } else { '0' }

  $membershipSql = @"
USE [$($DatabaseName.Replace(']', ']]'))];
DECLARE @principal NVARCHAR(256) = N'$principalEscaped';
DECLARE @role      NVARCHAR(128) = N'$roleEscaped';

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE [name] = @role AND [type] = 'R')
    THROW 60001, N'The database role does not exist. Deploy the migration that creates it first.', 1;

-- Accept either the database user name or the Windows account it maps to. A user whose
-- name differs from the account's short name is common once a login has been remapped,
-- and silently missing it would look like a permission defect much later.
DECLARE @mappedUser sysname = (
    SELECT TOP (1) [name]
    FROM   sys.database_principals
    WHERE  [name] = @principal
       OR  ([sid] = SUSER_SID(@principal) AND [type] IN ('U', 'G', 'S'))
    ORDER BY CASE WHEN [name] = @principal THEN 0 ELSE 1 END, [principal_id]
);
IF @mappedUser IS NULL
    THROW 60002, N'The database principal does not exist. Create the user before granting role membership.', 1;

DECLARE @isMember bit = CONVERT(bit, CASE WHEN EXISTS (
    SELECT 1
    FROM sys.database_role_members AS drm
    INNER JOIN sys.database_principals AS rolePrincipal
      ON rolePrincipal.[principal_id] = drm.[role_principal_id]
    INNER JOIN sys.database_principals AS memberPrincipal
      ON memberPrincipal.[principal_id] = drm.[member_principal_id]
    WHERE rolePrincipal.[name] = @role
      AND memberPrincipal.[name] = @mappedUser
) THEN 1 ELSE 0 END);

IF @isMember <> CONVERT(bit, $membershipShouldExist)
BEGIN
    DECLARE @sqlRole NVARCHAR(512) =
        N'ALTER ROLE ' + QUOTENAME(@role) + N' $membershipVerb MEMBER ' + QUOTENAME(@mappedUser) + N';';
    EXEC (@sqlRole);
END;
"@

  $appendConnectionStringParts = @("Integrated Security=True", "Encrypt=$Encrypt")
  if ($TrustServerCertificate) {
    $appendConnectionStringParts += 'Trust Server Certificate=True'
  }
  $appendConnectionString = $appendConnectionStringParts -join ';'

  try {
    if ($PSCmdlet.ShouldProcess("$SqlInstance / $DatabaseName", "$Ensure membership of '$DatabasePrincipal' in role '$RoleName'")) {
      if ($PSCmdlet.ParameterSetName -eq 'SqlInstance') {
        Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -Query $membershipSql -AppendConnectionString $appendConnectionString -EnableException -ErrorAction Stop | Out-Null
      }
      else {
        $membershipCommand = $openSQLConnection.CreateCommand()
        $membershipCommand.CommandText = $membershipSql
        [void] $membershipCommand.ExecuteNonQuery()
      }

      $result.Status = 'Success'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "[$fn] Role membership '$Ensure' applied for '$DatabasePrincipal' in '$RoleName'"
    }
    else {
      $result.Status = 'WhatIf'
    }
  }
  catch {
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
