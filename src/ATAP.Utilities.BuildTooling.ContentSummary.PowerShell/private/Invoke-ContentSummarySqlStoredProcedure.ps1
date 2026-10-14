function Invoke-ContentSummarySqlStoredProcedure {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object] $SqlConnection,

    [Parameter(Mandatory = $true)]
    [ValidateSet(
      'ATAPUtilities.CaptureContentSummaryObservationV1',
      'ATAPUtilities.ProvisionContentSummaryRepositoryV1',
      'ATAPUtilities.AssignContentSummaryVersionTagV1',
      'ATAPUtilities.AuthorizeContentSummaryDatabasePrincipalRepositoryV1'
    )]
    [string] $ProcedureName,

    [Parameter(Mandatory = $true)]
    [System.Collections.Specialized.OrderedDictionary] $Parameters,

    [Parameter(Mandatory = $true)]
    [string[]] $ResultPropertyOrder,

    [Parameter(Mandatory = $true)]
    [string[]] $AllowedStatusCodes,

    [string] $StatusPropertyName = 'StatusCode',

    [string] $ErrorPropertyName = 'ErrorCode',

    [ValidateRange(1, 300)]
    [int] $CommandTimeoutSeconds = 30
  )

  begin {
    $fn = 'Invoke-ContentSummarySqlStoredProcedure'
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'
  }

  process {
    if ($null -eq $SqlConnection -or
      -not [string]::Equals($SqlConnection.GetType().FullName, 'Microsoft.Data.SqlClient.SqlConnection', [StringComparison]::Ordinal)) {
      throw 'CS-SQL-001: an open Microsoft.Data.SqlClient.SqlConnection is required.'
    }
    if ([string]$SqlConnection.State -ne 'Open') {
      throw 'CS-SQL-001: SqlConnection must already be open.'
    }

    $command = $null
    $reader = $null
    try {
      $command = $SqlConnection.CreateCommand()
      $command.CommandText = "[$($ProcedureName.Replace('.', '].['))]"
      $command.CommandType = [System.Data.CommandType]::StoredProcedure
      $command.CommandTimeout = $CommandTimeoutSeconds

      foreach ($entry in $Parameters.GetEnumerator()) {
        $definition = $entry.Value
        $parameter = $command.CreateParameter()
        $parameter.ParameterName = "@$($entry.Key)"
        $parameter.SqlDbType = [System.Data.SqlDbType]::$($definition.SqlDbType)
        if ($null -ne $definition.Size) {
          $parameter.Size = [int]$definition.Size
        }
        if ($null -ne $definition.TypeName) {
          $parameter.TypeName = [string]$definition.TypeName
        }
        [void](Set-ContentSummarySqlParameterValue -Parameter $parameter -Value $definition.Value)
        [void]$command.Parameters.Add($parameter)
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling controlled procedure $ProcedureName with $($Parameters.Count) parameters." -Tag 'Database'
      $reader = $command.ExecuteReader()
      if (-not $reader.Read()) {
        throw 'CS-SQL-002: controlled procedure returned no acknowledgement row.'
      }
      $row = [ordered]@{}
      for ($index = 0; $index -lt $reader.FieldCount; $index++) {
        $value = $reader.GetValue($index)
        $row[$reader.GetName($index)] = if ($value -is [DBNull]) { $null } else { $value }
      }
      if ($reader.Read()) {
        throw 'CS-SQL-002: controlled procedure returned more than one acknowledgement row.'
      }
      if (($row.Keys -join ',') -ne ($ResultPropertyOrder -join ',')) {
        throw 'CS-SQL-002: controlled procedure returned an unexpected result shape.'
      }
      if ([string]$row[$StatusPropertyName] -notin $AllowedStatusCodes) {
        throw 'CS-SQL-002: controlled procedure returned an unexpected status code.'
      }
      if ($null -ne $row[$ErrorPropertyName] -and -not [string]::IsNullOrWhiteSpace([string]$row[$ErrorPropertyName])) {
        throw "CS-SQL-003: controlled procedure rejected the request with code $([string]$row[$ErrorPropertyName])."
      }
      [pscustomobject]$row
    }
    catch {
      $exceptionType = $_.Exception.GetType().FullName
      $safeCode = [regex]::Match($_.Exception.Message, 'CS-[A-Z]+-[0-9]{3}').Value
      if ([string]::IsNullOrWhiteSpace($safeCode)) { $safeCode = 'CS-SQL-004' }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Controlled procedure $ProcedureName failed with exception type $exceptionType and safe code $safeCode." -Tag 'Database'
      throw "$safeCode`: controlled procedure execution failed."
    }
    finally {
      if ($null -ne $reader -and $reader -is [IDisposable]) { $reader.Dispose() }
      if ($null -ne $command -and $command -is [IDisposable]) { $command.Dispose() }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}
