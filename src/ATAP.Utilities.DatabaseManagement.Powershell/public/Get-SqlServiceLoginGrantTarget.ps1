#Requires -Modules PSFramework, dbatools

function Get-SqlServiceLoginGrantTarget {
  <#
    .SYNOPSIS
        Audits explicitly admitted database-package deployment targets.

    .DESCRIPTION
        Reads metadata from one explicitly allowed local named SQL Server instance.
        Only names supplied through ApprovedDatabaseName can be included. The audit
        verifies the SQL machine name, the Windows SID resolved by SQL Server, any
        existing login SID, and database-user/db_owner state. It never mutates SQL.

    .PARAMETER SqlInstance
        Explicit Server\Instance target.

    .PARAMETER ExpectedHostName
        Host that owns the SQL instance and service account.

    .PARAMETER ServiceAccount
        Host-local Windows account in ExpectedHostName\Account form.

    .PARAMETER ExpectedAccountSid
        Optional SID frozen from the local Windows account by an authorization packet.

    .PARAMETER AllowedInstanceName
        Exact named-instance allow-list. Generic Experimental is prohibited.

    .PARAMETER ApprovedDatabaseName
        Exact database-package targets admitted by policy.

    .PARAMETER Encrypt
        SqlClient Encrypt setting.

    .PARAMETER TrustServerCertificate
        Allows the inventory connection to trust the server certificate.

    .OUTPUTS
        PSCustomObject rows describing topology, SID, eligibility, and grant drift.

    .EXAMPLE
        Get-SqlServiceLoginGrantTarget -SqlInstance 'UTAT022\Production' `
          -ExpectedHostName 'UTAT022' -ServiceAccount 'UTAT022\SvcBuildMaster' `
          -ExpectedAccountSid 'S-1-5-21-1-2-3-1001' `
          -AllowedInstanceName 'Production' -ApprovedDatabaseName 'ATAPUtilities'

    .NOTES
        Task 15.185.i. Unknown databases are evidence, not implicit authority.

    .LINK
        Set-SqlDatabasePackageDeploymentPrincipal
  #>

  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
  param (
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $SqlInstance,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $ExpectedHostName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $ServiceAccount,
    [ValidatePattern('^S-1-\d+(?:-\d+)+$')][string] $ExpectedAccountSid,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string[]] $AllowedInstanceName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string[]] $ApprovedDatabaseName,
    [ValidateSet('Optional', 'Mandatory', 'Strict')][string] $Encrypt = 'Optional',
    [switch] $TrustServerCertificate
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "[$fn] Starting SQL deployment-principal inventory." -Tag 'SqlSecurityInventory'

    foreach ($value in @($SqlInstance, $ExpectedHostName, $ServiceAccount)) {
      if ($value -ne $value.Trim()) {
        throw 'SqlInstance, ExpectedHostName, and ServiceAccount must not contain leading or trailing whitespace.'
      }
    }
    foreach ($collection in @($AllowedInstanceName, $ApprovedDatabaseName)) {
      if (@($collection | Where-Object { [string]::IsNullOrWhiteSpace($_) -or $_ -ne $_.Trim() }).Count -gt 0) {
        throw 'Allow-list entries must be non-empty and must not contain leading or trailing whitespace.'
      }
      $normalized = @($collection | ForEach-Object { $_.ToUpperInvariant() })
      if (@($normalized | Select-Object -Unique).Count -ne $normalized.Count) {
        throw 'Allow-list entries must be unique without regard to case.'
      }
    }
  }

  process {
    $instanceParts = $SqlInstance -split '\\', 2
    if ($instanceParts.Count -ne 2 -or [string]::IsNullOrWhiteSpace($instanceParts[0]) -or
      [string]::IsNullOrWhiteSpace($instanceParts[1])) {
      throw "SqlInstance '$SqlInstance' must use the explicit Server\Instance form."
    }
    $serverName = $instanceParts[0]
    $instanceName = $instanceParts[1]
    if ($serverName -notin @($ExpectedHostName, 'localhost', '.', '(local)')) {
      throw "SqlInstance '$SqlInstance' is not local to expected host '$ExpectedHostName'."
    }
    $accountParts = $ServiceAccount -split '\\', 2
    if ($accountParts.Count -ne 2 -or
      -not $accountParts[0].Equals($ExpectedHostName, [StringComparison]::OrdinalIgnoreCase) -or
      [string]::IsNullOrWhiteSpace($accountParts[1])) {
      throw "ServiceAccount '$ServiceAccount' is not a host-local account for '$ExpectedHostName'."
    }
    if ($instanceName.Equals('Experimental', [StringComparison]::OrdinalIgnoreCase)) {
      throw "Generic SQL instance name 'Experimental' is not a canonical per-developer instance."
    }
    if (-not ($AllowedInstanceName | Where-Object { $_.Equals($instanceName, [StringComparison]::OrdinalIgnoreCase) })) {
      throw "SQL instance name '$instanceName' is not present in the explicit allow-list."
    }

    if (-not $PSCmdlet.ShouldProcess($SqlInstance, 'Read SQL deployment-principal metadata')) {
      return [PSCustomObject]@{
        SqlInstance = $SqlInstance; InstanceName = $instanceName; ExpectedHostName = $ExpectedHostName
        ServiceAccount = $ServiceAccount; ExpectedAccountSid = $ExpectedAccountSid
        ResolvedAccountSid = $null; ServerLoginSid = $null; DatabaseName = $null
        State = $null; UserAccess = $null; IsReadOnly = $null; Include = $false
        ExclusionReason = 'WhatIf'; DatabaseUserName = $null; DatabaseUserSid = $null
        IsDbOwner = $false; IsCompliant = $false; DriftReason = 'NotAudited'
      }
    }

    $accountLiteral = $ServiceAccount.Replace("'", "''")
    $inventoryQuery = @"
DECLARE @account sysname = N'$accountLiteral';
SELECT CAST(SERVERPROPERTY('MachineName') AS nvarchar(128)) AS [MachineName],
  CONVERT(varchar(184), SUSER_SID(@account), 1) AS [ResolvedAccountSidHex],
  CONVERT(varchar(184), sp.[sid], 1) AS [ServerLoginSidHex],
  d.[name] AS [DatabaseName], d.[database_id] AS [DatabaseId],
  d.[state_desc] AS [State], d.[user_access_desc] AS [UserAccess],
  d.[is_read_only] AS [IsReadOnly], d.[source_database_id] AS [SourceDatabaseId]
FROM sys.databases AS d
LEFT JOIN sys.server_principals AS sp ON sp.[name] = @account AND sp.[type] IN ('U', 'G')
ORDER BY d.[name];
"@
    $appendParts = @("Integrated Security=True", "Encrypt=$Encrypt")
    if ($TrustServerCertificate) { $appendParts += 'Trust Server Certificate=True' }
    $connectionSuffix = $appendParts -join ';'
    try {
      $databases = @(Invoke-DbaQuery -SqlInstance $SqlInstance -Database 'master' -Query $inventoryQuery `
          -AppendConnectionString $connectionSuffix -EnableException -ErrorAction Stop)
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
        -Message "[$fn] SQL metadata inventory failed: $($_.Exception.Message)" `
        -Exception $_.Exception -Tag 'SqlSecurityInventory'
      throw
    }
    if ($databases.Count -eq 0) { throw "SQL instance '$SqlInstance' returned no sys.databases metadata rows." }

    $machineNames = @($databases.MachineName | Select-Object -Unique)
    if ($machineNames.Count -ne 1 -or
      -not ([string]$machineNames[0]).Equals($ExpectedHostName, [StringComparison]::OrdinalIgnoreCase)) {
      throw "SQL instance '$SqlInstance' reports machine '$($machineNames -join ',')', not expected host '$ExpectedHostName'."
    }
    $resolvedSidHex = [string]$databases[0].ResolvedAccountSidHex
    if ([string]::IsNullOrWhiteSpace($resolvedSidHex)) {
      throw "SQL Server could not resolve Windows account '$ServiceAccount' to a SID."
    }
    $resolvedSid = ([Security.Principal.SecurityIdentifier]::new(
        ([Convert]::FromHexString($resolvedSidHex.Substring(2))), 0)).Value
    if ($ExpectedAccountSid -and $resolvedSid -ne $ExpectedAccountSid) {
      throw "Windows SID mismatch for '$ServiceAccount': expected '$ExpectedAccountSid', SQL Server resolved '$resolvedSid'."
    }
    $serverLoginSidHex = [string]$databases[0].ServerLoginSidHex
    $serverLoginSid = if ($serverLoginSidHex) {
      ([Security.Principal.SecurityIdentifier]::new(
          ([Convert]::FromHexString($serverLoginSidHex.Substring(2))), 0)).Value
    }
    else { $null }
    if ($serverLoginSidHex -and $serverLoginSidHex -ne $resolvedSidHex) {
      throw "Existing SQL login SID for '$ServiceAccount' does not match the Windows account SID."
    }

    $approvedLookup = @{}
    foreach ($name in $ApprovedDatabaseName) { $approvedLookup[$name.ToUpperInvariant()] = $true }
    $foundApproved = @{}
    foreach ($database in ($databases | Sort-Object DatabaseName)) {
      $databaseName = [string]$database.DatabaseName
      $reason = $null
      if ([int]$database.DatabaseId -le 4) { $reason = 'SystemDatabase' }
      elseif ($null -ne $database.SourceDatabaseId -and $database.SourceDatabaseId -ne [DBNull]::Value) { $reason = 'DatabaseSnapshot' }
      elseif (-not $approvedLookup.ContainsKey($databaseName.ToUpperInvariant())) { $reason = 'NotApproved' }
      elseif ([string]$database.State -ne 'ONLINE') { $reason = "State:$($database.State)" }
      elseif ([bool]$database.IsReadOnly) { $reason = 'ReadOnly' }
      elseif ([string]$database.UserAccess -ne 'MULTI_USER') { $reason = "UserAccess:$($database.UserAccess)" }

      $databaseUserName = $null
      $databaseUserSidHex = $null
      $databaseUserSid = $null
      $isDbOwner = $false
      $driftReason = $reason
      if ([string]::IsNullOrEmpty($reason)) {
        $foundApproved[$databaseName.ToUpperInvariant()] = $true
        $databaseIdentifier = $databaseName.Replace(']', ']]')
        $auditQuery = @"
USE [$databaseIdentifier];
DECLARE @account sysname = N'$accountLiteral';
SELECT TOP (1) dp.[name] AS [DatabaseUserName],
  CONVERT(varchar(184), dp.[sid], 1) AS [DatabaseUserSidHex],
  CONVERT(bit, CASE WHEN rp.[name] = N'db_owner' THEN 1 ELSE 0 END) AS [IsDbOwner]
FROM (SELECT 1 AS anchor) AS a
LEFT JOIN sys.database_principals AS dp ON dp.[sid] = SUSER_SID(@account) AND dp.[type] IN ('U', 'G')
LEFT JOIN sys.database_role_members AS drm ON drm.[member_principal_id] = dp.[principal_id]
LEFT JOIN sys.database_principals AS rp ON rp.[principal_id] = drm.[role_principal_id]
ORDER BY CASE WHEN rp.[name] = N'db_owner' THEN 0 ELSE 1 END, dp.[principal_id];
"@
        $audit = @(Invoke-DbaQuery -SqlInstance $SqlInstance -Database $databaseName -Query $auditQuery `
            -AppendConnectionString $connectionSuffix -EnableException -ErrorAction Stop)
        if ($audit.Count -ne 1) { throw "Database '$databaseName' returned $($audit.Count) principal audit rows; expected one." }
        $databaseUserName = [string]$audit[0].DatabaseUserName
        $databaseUserSidHex = [string]$audit[0].DatabaseUserSidHex
        $databaseUserSid = if ($databaseUserSidHex) {
          ([Security.Principal.SecurityIdentifier]::new(
              ([Convert]::FromHexString($databaseUserSidHex.Substring(2))), 0)).Value
        }
        else { $null }
        $isDbOwner = [bool]$audit[0].IsDbOwner
        if (-not $serverLoginSidHex) { $driftReason = 'MissingServerLogin' }
        elseif (-not $databaseUserName) { $driftReason = 'MissingDatabaseUser' }
        elseif ($databaseUserSidHex -ne $resolvedSidHex) { $driftReason = 'DatabaseUserSidMismatch' }
        elseif (-not $isDbOwner) { $driftReason = 'MissingDbOwnerMembership' }
        else { $driftReason = $null }
      }

      [PSCustomObject]@{
        SqlInstance = $SqlInstance; InstanceName = $instanceName; ExpectedHostName = $ExpectedHostName
        ServiceAccount = $ServiceAccount; ExpectedAccountSid = $ExpectedAccountSid
        ResolvedAccountSid = $resolvedSid; ServerLoginSid = $serverLoginSid
        DatabaseName = $databaseName; State = [string]$database.State; UserAccess = [string]$database.UserAccess
        IsReadOnly = [bool]$database.IsReadOnly; Include = [string]::IsNullOrEmpty($reason)
        ExclusionReason = $reason; DatabaseUserName = $databaseUserName
        DatabaseUserSid = $databaseUserSid
        IsDbOwner = $isDbOwner; IsCompliant = [string]::IsNullOrEmpty($driftReason)
        DriftReason = $driftReason
      }
    }
    $missing = @($ApprovedDatabaseName | Where-Object { -not $foundApproved.ContainsKey($_.ToUpperInvariant()) })
    if ($missing.Count -gt 0) {
      throw "Approved database targets were not returned by '$SqlInstance': $($missing -join ', ')."
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "[$fn] Finished SQL deployment-principal inventory." -Tag 'SqlSecurityInventory'
  }
}
