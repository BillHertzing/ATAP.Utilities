#Requires -Version 7.0
function Test-DatabaseSeedIdempotency {
  <#
.SYNOPSIS
    Verifies that database seed/loader scripts are idempotent by running each
    script twice and comparing row counts and content hashes.

.DESCRIPTION
    For each seed or loader SQL file listed in the `seeds` or `loaders` arrays
    of a database change package manifest, this cmdlet:

      1. Executes the script once and captures per-table row counts and
         SHA-256 content hashes for every table the script touches.
      2. Executes the script a second time.
      3. Compares the before-second-run and after-second-run snapshots.

    Row counts and hashes must be identical after the second run for the
    seed to be considered idempotent.  Any mismatch is recorded in the
    `Mismatches` list.

    The `AffectedTables` parameter names the tables to snapshot.  When omitted
    the cmdlet uses the table names from the `expectedRowCounts` map in the
    manifest.

.PARAMETER PackagePath
    Path to an expanded database change package folder containing
    `db-release-unit-manifest.json` and the seed SQL files.

.PARAMETER AffectedTables
    Optional list of table names to snapshot (overrides `expectedRowCounts`
    keys in the manifest).

.PARAMETER SqlConnection
    An open Microsoft.Data.SqlClient.SqlConnection.
    Mandatory for the SqlConnection parameter set.

.PARAMETER DBConnectionStringSecretName
    Bitwarden secure-note name whose password is a SQL connection string.
    Mandatory for the DBConnectionStringSecretName parameter set.

.PARAMETER DatabaseHost
    SQL Server host.  Used with ConnectionParts parameter set.

.PARAMETER SqlInstance
    SQL Server named instance.  Used with ConnectionParts parameter set.

.PARAMETER DatabaseName
    Target database name.  Used with ConnectionParts parameter set.

.PARAMETER ConnectionMethod
    Connection protocol: tcp, np, lpc, or default.

.PARAMETER CredentialsKey
    Bitwarden credentials key for SQL login.

.PARAMETER IntegratedSecurity
    Use Windows Integrated Authentication.

.OUTPUTS
    [PSCustomObject] @{
        IsIdempotent = [bool]
        Mismatches   = [PSCustomObject[]]   # @{ Table; FirstRunCount; SecondRunCount; FirstRunHash; SecondRunHash }
    }

.EXAMPLE
    Test-DatabaseSeedIdempotency -PackagePath 'C:\pkg\ATAPUtilities.Database.1.5.0' `
        -DatabaseHost localhost -SqlInstance SQLEXPRESS `
        -DatabaseName ATAPUtilities -IntegratedSecurity

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Task: TASKS_V4-DBA1.md DBA1-T04 / V4-E07.
#>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialsKey',
    Justification = 'CredentialsKey is a vault lookup key name, not a credential')]
  [CmdletBinding(DefaultParameterSetName = 'ConnectionParts')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$PackagePath,

    [Parameter(Mandatory = $false)]
    [string[]]$AffectedTables,

    [Parameter(Mandatory = $true, ParameterSetName = 'SqlConnection', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [object]$SqlConnection,

    [Parameter(Mandatory = $true, ParameterSetName = 'DBConnectionStringSecretName', ValueFromPipelineByPropertyName = $true)]
    [Alias('DBConnectionStringSecret', 'SecretName', 'BitwardenSecretName', 'BitwardenSecret')]
    [string]$DBConnectionStringSecretName,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParts', ValueFromPipelineByPropertyName = $true)]
    [Alias('HostName', 'ServerInstance')]
    [string]$DatabaseHost = 'localhost',

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParts', ValueFromPipelineByPropertyName = $true)]
    [Alias('InstanceName')]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$DatabaseName,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParts', ValueFromPipelineByPropertyName = $true)]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParts', ValueFromPipelineByPropertyName = $true)]
    [string]$CredentialsKey,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParts')]
    [switch]$IntegratedSecurity
  )

  begin {
    $fn = 'Test-DatabaseSeedIdempotency'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'
  }

  process {
    # Helper: snapshot row counts + SHA-256 of ordered content for a list of tables
    function Get-TableSnapshot {
      param([object]$Conn, [string[]]$Tables)
      $snap = @{}
      foreach ($table in $Tables) {
        $cmd = $Conn.CreateCommand()
        try {
          # Row count
          $cmd.CommandText = "SELECT COUNT(*) FROM [$table];"
          $rowCount = [int]$cmd.ExecuteScalar()

          # Content hash (concatenated ordered rows as CSV)
          $cmd.CommandText = "SELECT * FROM [$table] ORDER BY (SELECT NULL);"
          $reader = $cmd.ExecuteReader()
          $sb = [System.Text.StringBuilder]::new()
          try {
            while ($reader.Read()) {
              for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                [void]$sb.Append($reader.GetValue($i))
                [void]$sb.Append(',')
              }
              [void]$sb.AppendLine()
            }
          } finally {
            $reader.Dispose()
          }
          $bytes  = [System.Text.Encoding]::UTF8.GetBytes($sb.ToString())
          $sha256 = [System.Security.Cryptography.SHA256]::Create()
          $hash   = ($sha256.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
          $sha256.Dispose()

          $snap[$table] = [PSCustomObject]@{ RowCount = $rowCount; Hash = $hash }
        } finally {
          $cmd.Dispose()
        }
      }
      return $snap
    }

    # Helper: execute a SQL file against the connection
    function Invoke-SqlFile {
      param([object]$Conn, [string]$FilePath)
      $sql = Get-Content -LiteralPath $FilePath -Raw
      $cmd = $Conn.CreateCommand()
      try {
        $cmd.CommandText = $sql
        [void]$cmd.ExecuteNonQuery()
      } finally {
        $cmd.Dispose()
      }
    }

    $resolution = Resolve-DatabaseSqlConnection `
      -OriginalPSBoundParameters $PSBoundParameters `
      -SqlConnection $SqlConnection `
      -DBConnectionStringSecretName $DBConnectionStringSecretName `
      -DatabaseHost $DatabaseHost `
      -InstanceName $SqlInstance `
      -DatabaseName $DatabaseName `
      -ConnectionMethod $ConnectionMethod `
      -CredentialsKey $CredentialsKey `
      -IntegratedSecurity:$IntegratedSecurity

    $resolvedConnection = $resolution.Connection
    $resolvedConnectionOwnedByFunction = -not [bool]$resolution.IsCallerOwned

    $manifest = Get-DatabasePackageManifest -PackagePath $PackagePath

    # Collect tables to snapshot
    $tables = @()
    if ($AffectedTables -and $AffectedTables.Count -gt 0) {
      $tables = $AffectedTables
    } elseif ($manifest.PSObject.Properties.Name -contains 'expectedRowCounts' -and $null -ne $manifest.expectedRowCounts) {
      $tables = @($manifest.expectedRowCounts.PSObject.Properties.Name)
    }

    # Collect seed + loader SQL files from the package
    $seedFiles = [System.Collections.Generic.List[string]]::new()
    foreach ($kind in @('seeds', 'loaders')) {
      if ($manifest.PSObject.Properties.Name -contains $kind -and $null -ne $manifest.$kind) {
        foreach ($entry in @($manifest.$kind)) {
          $filePath = Join-Path $PackagePath $entry
          if (Test-Path $filePath) { $seedFiles.Add($filePath) }
        }
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Seed files: $($seedFiles.Count)  Tables to snapshot: $($tables.Count)" -Tag 'Idempotency'

    $mismatches = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($seedFile in $seedFiles) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Running seed file once: '$seedFile'" -Tag 'Idempotency'
      Invoke-SqlFile -Conn $resolvedConnection -FilePath $seedFile

      $snapBefore = Get-TableSnapshot -Conn $resolvedConnection -Tables $tables

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Running seed file second time: '$seedFile'" -Tag 'Idempotency'
      Invoke-SqlFile -Conn $resolvedConnection -FilePath $seedFile

      $snapAfter = Get-TableSnapshot -Conn $resolvedConnection -Tables $tables

      foreach ($table in $tables) {
        $before = $snapBefore[$table]
        $after  = $snapAfter[$table]
        if ($null -eq $before -or $null -eq $after) { continue }
        if ($before.RowCount -ne $after.RowCount -or $before.Hash -ne $after.Hash) {
          $mismatches.Add([PSCustomObject]@{
              SeedFile       = $seedFile
              Table          = $table
              FirstRunCount  = $before.RowCount
              SecondRunCount = $after.RowCount
              FirstRunHash   = $before.Hash
              SecondRunHash  = $after.Hash
            })
        }
      }
    }

    $isIdempotent = ($mismatches.Count -eq 0)
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "IsIdempotent=$isIdempotent  Mismatches=$($mismatches.Count)" -Tag 'Idempotency'

    Write-Output ([PSCustomObject]@{
        IsIdempotent = $isIdempotent
        Mismatches   = $mismatches.ToArray()
      })
  }

  end {
    if ($resolvedConnectionOwnedByFunction -and $null -ne $resolvedConnection) {
      try { $resolvedConnection.Close() } catch { $null = $_ }
      try { $resolvedConnection.Dispose() } catch { $null = $_ }
      $resolvedConnection = $null
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
  }
}
