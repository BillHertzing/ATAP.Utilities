#Requires -Modules PSFramework, dbatools

function Set-SqlDatabasePackageDeploymentPrincipal {
  <#
    .SYNOPSIS
        Audits, grants, or revokes BuildMaster database-package deployment access.

    .DESCRIPTION
        Reconciles db_owner only on an explicit list of admitted package-target
        databases. It requires a frozen host-local Windows SID, verifies current
        state through Get-SqlServiceLoginGrantTarget, supports -WhatIf, and emits
        a reversible per-database change record.

        Ensure Absent removes db_owner membership and preserves the mapped database
        user unless -RemoveDatabaseUser is explicitly supplied. The apply result
        records whether the user existed before so rollback can restore that boundary.
        The server login is always retained: dropping it while an excluded, offline,
        or restoring database may still map its SID is unsafe and remains separately
        reviewed.

    .PARAMETER SqlInstance
        Explicit local Server\Instance target.

    .PARAMETER ExpectedHostName
        Host that owns the SQL instance and service account.

    .PARAMETER ServiceAccount
        Exact host-local BuildMaster Windows account.

    .PARAMETER ExpectedAccountSid
        SID frozen from the local Windows account in the authorization packet.

    .PARAMETER AllowedInstanceName
        Exact named-instance allow-list.

    .PARAMETER ApprovedDatabaseName
        Exact package-target database allow-list.

    .PARAMETER Ensure
        Present grants login/user/db_owner access. Absent removes the database-local
        membership and mapped user while retaining the server login.

    .PARAMETER AuditOnly
        Returns current inventory without mutation.

    .PARAMETER RemoveDatabaseUser
        With Ensure Absent, also removes the SID-mapped database user. Use only when
        the preceding apply result says RollbackRemoveDatabaseUser=True.

    .PARAMETER Encrypt
        SqlClient Encrypt setting.

    .PARAMETER TrustServerCertificate
        Allows the SQL connection to trust the server certificate.

    .OUTPUTS
        PSCustomObject containing before-state, action, and rollback semantics.

    .EXAMPLE
        Set-SqlDatabasePackageDeploymentPrincipal -SqlInstance 'UTAT022\Production' `
          -ExpectedHostName 'UTAT022' -ServiceAccount 'UTAT022\SvcBuildMaster' `
          -ExpectedAccountSid 'S-1-5-21-1-2-3-1001' -AllowedInstanceName 'Production' `
          -ApprovedDatabaseName 'ATAPUtilities' -Ensure Present -WhatIf

    .NOTES
        Task 15.185.i. No server role or server-level permission is granted.

    .LINK
        Get-SqlServiceLoginGrantTarget
  #>

  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  param (
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $SqlInstance,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $ExpectedHostName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $ServiceAccount,
    [Parameter(Mandatory)][ValidatePattern('^S-1-\d+(?:-\d+)+$')][string] $ExpectedAccountSid,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string[]] $AllowedInstanceName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string[]] $ApprovedDatabaseName,
    [ValidateSet('Present', 'Absent')][string] $Ensure = 'Present',
    [switch] $AuditOnly,
    [switch] $RemoveDatabaseUser,
    [ValidateSet('Optional', 'Mandatory', 'Strict')][string] $Encrypt = 'Optional',
    [switch] $TrustServerCertificate
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "[$fn] Starting database-package deployment-principal reconciliation."
    if (-not (Get-Command -Name Get-SqlServiceLoginGrantTarget -CommandType Function -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot 'Get-SqlServiceLoginGrantTarget.ps1')
    }
  }

  process {
    if ($RemoveDatabaseUser -and ($Ensure -ne 'Absent' -or $AuditOnly)) {
      throw '-RemoveDatabaseUser is valid only with -Ensure Absent outside audit mode.'
    }
    $auditParameters = @{
      SqlInstance = $SqlInstance
      ExpectedHostName = $ExpectedHostName
      ServiceAccount = $ServiceAccount
      ExpectedAccountSid = $ExpectedAccountSid
      AllowedInstanceName = $AllowedInstanceName
      ApprovedDatabaseName = $ApprovedDatabaseName
      Encrypt = $Encrypt
      TrustServerCertificate = $TrustServerCertificate
    }
    $inventory = @(Get-SqlServiceLoginGrantTarget @auditParameters)
    $targets = @($inventory | Where-Object Include)
    if ($targets.Count -ne $ApprovedDatabaseName.Count) {
      throw "Eligible database count $($targets.Count) does not equal approved target count $($ApprovedDatabaseName.Count)."
    }
    if ($AuditOnly) { return $inventory }

    $appendParts = @("Integrated Security=True", "Encrypt=$Encrypt")
    if ($TrustServerCertificate) { $appendParts += 'Trust Server Certificate=True' }
    $connectionSuffix = $appendParts -join ';'
    $accountLiteral = $ServiceAccount.Replace("'", "''")
    $sid = [Security.Principal.SecurityIdentifier]::new($ExpectedAccountSid)
    $sidBytes = [byte[]]::new($sid.BinaryLength)
    $sid.GetBinaryForm($sidBytes, 0)
    $sidHexLiteral = '0x' + [Convert]::ToHexString($sidBytes)
    $machineLiteral = $ExpectedHostName.Replace("'", "''")

    foreach ($target in $targets) {
      $databaseName = [string]$target.DatabaseName
      $databaseIdentifier = $databaseName.Replace(']', ']]')
      $action = if ($Ensure -eq 'Present') {
        'Grant database-package db_owner access'
      }
      else {
        'Revoke database-package db_owner access'
      }
      $status = 'WhatIf'

      $ensurePresentBit = if ($Ensure -eq 'Present') { 1 } else { 0 }
      $removeDatabaseUserBit = if ($RemoveDatabaseUser) { 1 } else { 0 }
      $query = @"
SET XACT_ABORT ON;
DECLARE @expectedMachine sysname = N'$machineLiteral';
DECLARE @account sysname = N'$accountLiteral';
DECLARE @expectedSid varbinary(85) = CONVERT(varbinary(85), '$sidHexLiteral', 1);
DECLARE @ensurePresent bit = $ensurePresentBit;
DECLARE @removeDatabaseUser bit = $removeDatabaseUserBit;
IF UPPER(CONVERT(nvarchar(128), SERVERPROPERTY('MachineName'))) <> UPPER(@expectedMachine)
  THROW 60185, N'SQL machine-name gate failed.', 1;
IF SUSER_SID(@account) IS NULL OR SUSER_SNAME(SUSER_SID(@account)) IS NULL
  THROW 60186, N'Windows account SID could not be resolved.', 1;
IF SUSER_SID(@account) <> @expectedSid
  THROW 60187, N'Windows account SID does not match the frozen authorization SID.', 1;

BEGIN TRANSACTION;
BEGIN TRY
  IF @ensurePresent = 1
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE [name] = @account AND [type] IN ('U','G'))
      EXEC (N'CREATE LOGIN ' + QUOTENAME(@account) + N' FROM WINDOWS;');
    IF (SELECT [sid] FROM sys.server_principals WHERE [name] = @account AND [type] IN ('U','G')) <> SUSER_SID(@account)
      THROW 60188, N'Existing SQL login SID mismatch.', 1;
    USE [$databaseIdentifier];
    DECLARE @mappedUser sysname = (SELECT TOP (1) [name] FROM sys.database_principals WHERE [sid] = SUSER_SID(@account) AND [type] IN ('U','G') ORDER BY [principal_id]);
    IF @mappedUser IS NULL
    BEGIN
      SET @mappedUser = PARSENAME(REPLACE(@account, N'\', N'.'), 1);
      EXEC (N'CREATE USER ' + QUOTENAME(@mappedUser) + N' FOR LOGIN ' + QUOTENAME(@account) + N';');
    END;
    IF NOT EXISTS (
      SELECT 1 FROM sys.database_role_members drm
      JOIN sys.database_principals rp ON rp.[principal_id] = drm.[role_principal_id]
      JOIN sys.database_principals mp ON mp.[principal_id] = drm.[member_principal_id]
      WHERE rp.[name] = N'db_owner' AND mp.[name] = @mappedUser)
      EXEC (N'ALTER ROLE [db_owner] ADD MEMBER ' + QUOTENAME(@mappedUser) + N';');
  END
  ELSE
  BEGIN
    USE [$databaseIdentifier];
    DECLARE @revokeUser sysname = (SELECT TOP (1) [name] FROM sys.database_principals WHERE [sid] = SUSER_SID(@account) AND [type] IN ('U','G') ORDER BY [principal_id]);
    IF @revokeUser IS NOT NULL
    BEGIN
      IF IS_ROLEMEMBER(N'db_owner', @revokeUser) = 1
        EXEC (N'ALTER ROLE [db_owner] DROP MEMBER ' + QUOTENAME(@revokeUser) + N';');
      IF @removeDatabaseUser = 1
        EXEC (N'DROP USER ' + QUOTENAME(@revokeUser) + N';');
    END;
  END;
  COMMIT TRANSACTION;
END TRY
BEGIN CATCH
  IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
  THROW;
END CATCH;
"@
      $generatedSqlSha256 = [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($query)))
      if ($PSCmdlet.ShouldProcess("$SqlInstance/$databaseName/$ServiceAccount", $action)) {
        Invoke-DbaQuery -SqlInstance $SqlInstance -Database 'master' -Query $query `
          -AppendConnectionString $connectionSuffix -EnableException -ErrorAction Stop | Out-Null
        $status = 'Success'
      }

      [PSCustomObject]@{
        SqlInstance = $SqlInstance
        DatabaseName = $databaseName
        ServiceAccount = $ServiceAccount
        ExpectedAccountSid = $ExpectedAccountSid
        Ensure = $Ensure
        Status = $status
        GeneratedSqlSha256 = $generatedSqlSha256
        BeforeDriftReason = $target.DriftReason
        DatabaseUserExistedBefore = -not [string]::IsNullOrWhiteSpace([string]$target.DatabaseUserName)
        DbOwnerExistedBefore = [bool]$target.IsDbOwner
        RollbackRemoveDatabaseUser = [string]::IsNullOrWhiteSpace([string]$target.DatabaseUserName)
        Rollback = if ($Ensure -eq 'Present') {
          'Run Ensure Absent; pass RemoveDatabaseUser only when RollbackRemoveDatabaseUser is true. Server login retained.'
        }
        else {
          'Ensure Present recreates the mapped database user and db_owner membership.'
        }
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "[$fn] Finished database-package deployment-principal reconciliation."
  }
}
