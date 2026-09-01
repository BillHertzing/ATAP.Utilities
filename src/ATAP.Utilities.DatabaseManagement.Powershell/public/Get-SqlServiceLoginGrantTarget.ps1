#Requires -Modules PSFramework, dbatools

function Get-SqlServiceLoginGrantTarget {
  <#
    .SYNOPSIS
        Inventories user databases eligible for a host-local service-account grant.

    .DESCRIPTION
        Reads metadata from master.sys.databases on one explicitly allowed named SQL
        Server instance. The function validates that the SQL target is local to the
        expected host and that the service account is qualified by that same host.

        This function does not create or alter SQL logins, users, roles, databases, or
        permissions. System databases, snapshots, read-only databases, databases that
        are not ONLINE, and databases that are not MULTI_USER are returned with
        Include = false and an explicit ExclusionReason.

    .PARAMETER SqlInstance
        Named SQL Server instance in Server\Instance format. Server may be the expected
        host name, localhost, '.', or '(local)'. Remote targets fail closed.

    .PARAMETER ExpectedHostName
        NetBIOS/DNS-short host name that owns both the SQL instances and service account.

    .PARAMETER ServiceAccount
        Host-local Windows account in ExpectedHostName\Account format.

    .PARAMETER AllowedInstanceName
        Exact named-instance allow-list. The instance parsed from SqlInstance must match
        one entry. Generic instance name Experimental is always rejected.

    .PARAMETER Encrypt
        SqlClient Encrypt connection setting. Allowed values: Optional, Mandatory, Strict.

    .PARAMETER TrustServerCertificate
        Disables certificate-chain validation for this metadata query when specified.

    .OUTPUTS
        PSCustomObject rows with target identity, database state, Include, and
        ExclusionReason properties.

    .EXAMPLE
        Get-SqlServiceLoginGrantTarget -SqlInstance 'UTAT022\Production' `
          -ExpectedHostName 'UTAT022' -ServiceAccount 'UTAT022\SvcBuildMaster' `
          -AllowedInstanceName 'Production'

        Inventories current eligible databases without changing SQL security state.
  #>

  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $SqlInstance,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ExpectedHostName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ServiceAccount,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]] $AllowedInstanceName,

    [ValidateSet('Optional', 'Mandatory', 'Strict')]
    [string] $Encrypt = 'Optional',

    [switch] $TrustServerCertificate
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "[$fn] Starting SQL service-login grant-target inventory." -Tag 'SqlSecurityInventory'

    if ($SqlInstance -ne $SqlInstance.Trim() -or
      $ExpectedHostName -ne $ExpectedHostName.Trim() -or
      $ServiceAccount -ne $ServiceAccount.Trim()) {
      throw 'SqlInstance, ExpectedHostName, and ServiceAccount must not contain leading or trailing whitespace.'
    }

    $nonCanonicalAllowedInstanceNames = @($AllowedInstanceName | Where-Object {
        [string]::IsNullOrWhiteSpace($_) -or $_ -ne $_.Trim()
      })
    if ($nonCanonicalAllowedInstanceNames.Count -gt 0) {
      throw 'AllowedInstanceName entries must be non-empty and must not contain leading or trailing whitespace.'
    }
  }

  process {
    $instanceParts = $SqlInstance -split '\\', 2
    if ($instanceParts.Count -ne 2 -or
      [string]::IsNullOrWhiteSpace($instanceParts[0]) -or
      [string]::IsNullOrWhiteSpace($instanceParts[1])) {
      throw "SqlInstance '$SqlInstance' must use the explicit Server\Instance form."
    }

    $serverName = $instanceParts[0]
    $instanceName = $instanceParts[1]
    $localServerAliases = @($ExpectedHostName, 'localhost', '.', '(local)')
    if ($serverName -notin $localServerAliases) {
      throw "SqlInstance '$SqlInstance' is not local to expected host '$ExpectedHostName'."
    }

    $accountParts = $ServiceAccount -split '\\', 2
    if ($accountParts.Count -ne 2 -or
      -not $accountParts[0].Equals($ExpectedHostName, [System.StringComparison]::OrdinalIgnoreCase) -or
      [string]::IsNullOrWhiteSpace($accountParts[1])) {
      throw "ServiceAccount '$ServiceAccount' is not a host-local account for '$ExpectedHostName'."
    }

    if ($instanceName.Equals('Experimental', [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Generic SQL instance name 'Experimental' is not a canonical per-developer instance."
    }

    $allowed = @($AllowedInstanceName)
    if (-not ($allowed | Where-Object { $_.Equals($instanceName, [System.StringComparison]::OrdinalIgnoreCase) })) {
      throw "SQL instance name '$instanceName' is not present in the explicit allow-list."
    }

    if (-not $PSCmdlet.ShouldProcess($SqlInstance, 'Read master.sys.databases metadata')) {
      return [PSCustomObject]@{
        SqlInstance      = $SqlInstance
        InstanceName     = $instanceName
        ExpectedHostName = $ExpectedHostName
        ServiceAccount   = $ServiceAccount
        DatabaseName     = $null
        State            = $null
        UserAccess       = $null
        IsReadOnly       = $null
        Include          = $false
        ExclusionReason  = 'WhatIf'
      }
    }

    $query = @'
SELECT
    [name] AS [DatabaseName],
    [database_id] AS [DatabaseId],
    [state_desc] AS [State],
    [user_access_desc] AS [UserAccess],
    [is_read_only] AS [IsReadOnly],
    [source_database_id] AS [SourceDatabaseId]
FROM sys.databases
ORDER BY [name];
'@

    $appendConnectionStringParts = @("Integrated Security=True", "Encrypt=$Encrypt")
    if ($TrustServerCertificate) {
      $appendConnectionStringParts += 'Trust Server Certificate=True'
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "[$fn] Reading database grant-target metadata from '$SqlInstance'." -Tag 'SqlSecurityInventory'

    try {
      $databases = @(Invoke-DbaQuery -SqlInstance $SqlInstance -Database 'master' -Query $query `
          -AppendConnectionString ($appendConnectionStringParts -join ';') `
          -EnableException -ErrorAction Stop)
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
        -Message "[$fn] Failed to read database metadata from '$SqlInstance': $($_.Exception.Message)" `
        -Exception $_.Exception -Tag 'SqlSecurityInventory'
      throw
    }

    if ($databases.Count -eq 0) {
      throw "SQL instance '$SqlInstance' returned no sys.databases metadata rows."
    }

    foreach ($database in ($databases | Sort-Object -Property DatabaseName)) {
      $reason = $null
      if ([int] $database.DatabaseId -le 4) {
        $reason = 'SystemDatabase'
      }
      elseif ($null -ne $database.SourceDatabaseId -and $database.SourceDatabaseId -ne [DBNull]::Value) {
        $reason = 'DatabaseSnapshot'
      }
      elseif ([string] $database.State -ne 'ONLINE') {
        $reason = "State:$($database.State)"
      }
      elseif ([bool] $database.IsReadOnly) {
        $reason = 'ReadOnly'
      }
      elseif ([string] $database.UserAccess -ne 'MULTI_USER') {
        $reason = "UserAccess:$($database.UserAccess)"
      }

      [PSCustomObject]@{
        SqlInstance      = $SqlInstance
        InstanceName     = $instanceName
        ExpectedHostName = $ExpectedHostName
        ServiceAccount   = $ServiceAccount
        DatabaseName     = [string] $database.DatabaseName
        State            = [string] $database.State
        UserAccess       = [string] $database.UserAccess
        IsReadOnly       = [bool] $database.IsReadOnly
        Include          = [string]::IsNullOrEmpty($reason)
        ExclusionReason  = $reason
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "[$fn] Finished SQL service-login grant-target inventory." -Tag 'SqlSecurityInventory'
  }
}
