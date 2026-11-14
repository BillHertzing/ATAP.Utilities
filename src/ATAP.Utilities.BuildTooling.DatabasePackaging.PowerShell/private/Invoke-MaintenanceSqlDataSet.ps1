function Invoke-MaintenanceSqlDataSet {
  <#
  .SYNOPSIS
    Runs one SQL batch through the pinned .NET SqlClient and captures every result set.
  .DESCRIPTION
    Integrated Security only: no credential is read, built or written. The batch text is sent exactly
    as given (never through sqlcmd, which may rewrite line endings; Junior Dev #1, delta review 4.1).
    Parameters are bound by name: a byte[] binds as varbinary, everything else as nvarchar(4000) or
    its own type. A SqlException is not rethrown: it is returned as Status 'SqlFailed' with the first
    error's Number, State, Class and LineNumber and the per-error list. Result sets read before the
    error are kept. No retry.
  .PARAMETER SqlInstance
    Server\instance to connect to.
  .PARAMETER Database
    Initial catalog.
  .PARAMETER CommandText
    The exact batch text.
  .PARAMETER Parameters
    Ordered dictionary of parameter name (without '@') to value.
  .PARAMETER SqlClientPath
    Pinned Microsoft.Data.SqlClient.dll path.
  .PARAMETER ExpectedSqlClientSha256
    Its pinned SHA-256.
  .PARAMETER CommandTimeout
    Seconds (default 60).
  .PARAMETER ApplicationName
    Application Name on the connection, visible in sys.dm_exec_sessions.
  .OUTPUTS
    PSCustomObject with Status (Completed or SqlFailed), ResultSets, SqlErrorNumber, SqlState, SqlClass,
    SqlLineNumber, SqlErrors.
  .EXAMPLE
    Invoke-MaintenanceSqlDataSet -SqlInstance 'UTAT022\Devwhertzing' -Database master -CommandText $t -Parameters $p -SqlClientPath $dll -ExpectedSqlClientSha256 $h
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines. DB-Runner-S1-Foundation.
  .LINK
    ConvertFrom-MaintenanceWindowDataReader
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory)][string]$SqlInstance,
    [Parameter(Mandatory)][string]$Database,
    [Parameter(Mandatory)][string]$CommandText,
    [Collections.IDictionary]$Parameters = @{},
    [Parameter(Mandatory)][string]$SqlClientPath,
    [Parameter(Mandatory)][ValidatePattern('\A[0-9a-fA-F]{64}\z')][string]$ExpectedSqlClientSha256,
    [ValidateRange(1, 3600)][int]$CommandTimeout = 60,
    [string]$ApplicationName = 'ATAP.MaintenanceWindow'
  )
  begin {
    $fn = 'Invoke-MaintenanceSqlDataSet'
    $mn = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }
  process {
    $null = Import-MaintenanceWindowSqlClient -Path $SqlClientPath -ExpectedSha256 $ExpectedSqlClientSha256
    $sets = [System.Collections.Generic.List[object]]::new()
    $result = [ordered]@{ Status = 'NotRun'; ResultSets = $sets; SqlErrorNumber = $null; SqlState = $null; SqlClass = $null; SqlLineNumber = $null; SqlErrors = @() }
    $builder = [Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new()
    $builder.DataSource = $SqlInstance
    $builder.InitialCatalog = $Database
    $builder.IntegratedSecurity = $true
    $builder.Encrypt = [Microsoft.Data.SqlClient.SqlConnectionEncryptOption]::Mandatory
    $builder.TrustServerCertificate = $true
    $builder.ApplicationName = $ApplicationName
    $builder.Pooling = $false
    $connection = [Microsoft.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Opening $SqlInstance/$Database" -Tag 'SqlCall'
      $connection.Open()
      $command = $connection.CreateCommand()
      try {
        $command.CommandText = $CommandText
        $command.CommandTimeout = $CommandTimeout
        foreach ($key in $Parameters.Keys) {
          $value = $Parameters[$key]
          $p = $command.CreateParameter()
          $p.ParameterName = '@' + ([string]$key).TrimStart('@')
          if ($value -is [byte[]]) { $p.SqlDbType = [System.Data.SqlDbType]::VarBinary; $p.Size = 85 }
          elseif ($value -is [string]) { $p.SqlDbType = [System.Data.SqlDbType]::NVarChar; $p.Size = 4000 }
          $p.Value = if ($null -eq $value) { [DBNull]::Value } else { $value }
          $null = $command.Parameters.Add($p)
        }
        $reader = $command.ExecuteReader()
        try { ConvertFrom-MaintenanceWindowDataReader -Reader $reader -ResultSets $sets } finally { $reader.Dispose() }
        $result.Status = 'Completed'
      } finally { $command.Dispose() }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Returned from $SqlInstance/$Database" -Tag 'SqlCall'
    } catch {
      $ex = $_.Exception
      while ($null -ne $ex -and $ex.GetType().FullName -cne 'Microsoft.Data.SqlClient.SqlException' -and $null -ne $ex.InnerException) { $ex = $ex.InnerException }
      if ($null -eq $ex -or $ex.GetType().FullName -cne 'Microsoft.Data.SqlClient.SqlException') { throw }
      $result.Status = 'SqlFailed'
      $result.SqlErrorNumber = [int]$ex.Number
      $result.SqlState = [int]$ex.State
      $result.SqlClass = [int]$ex.Class
      $result.SqlLineNumber = [int]$ex.LineNumber
      $result.SqlErrors = @(foreach ($e in $ex.Errors) { [ordered]@{ Number = [int]$e.Number; State = [int]$e.State; Class = [int]$e.Class; LineNumber = [int]$e.LineNumber } })
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "SQL error $($result.SqlErrorNumber) at line $($result.SqlLineNumber)"
    } finally {
      $connection.Dispose()
    }
    [pscustomobject]$result
  }
  end {}
}
