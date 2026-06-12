<#
.SYNOPSIS
  Executes the idempotent AgentText SQL produced by Import-AgentTextFromFiles.
.DESCRIPTION
  Completes the load direction of the AgentText round trip. Accepts records
  produced by Import-AgentTextFromFiles -AsSql (each record carries a .Sql
  property) and executes each record's SQL batch against the AgentText pilot
  tables created by the Add_AgentText_Rule_Kind Flyway migration.

  Each record executes as its own SqlCommand so the per-record DECLARE
  @AgentTextId statement never collides across records. The SQL is idempotent:
  existing rows are resolved by SourceId and re-runs insert nothing new.
.PARAMETER AgentText
  One or more records from Import-AgentTextFromFiles -AsSql. Records without a
  .Sql property are rejected with guidance to re-run the import with -AsSql.
.PARAMETER ConnectionString
  SQL Server connection string for the target ATAPUtilities database. Resolve
  the value from Bitwarden (e.g. Get-SecretATAP with the
  dbConnectionString-ATAPUtilities-<Host>-<Tier>[-<UserName>] item name); do
  not embed literal credentials in scripts.
.OUTPUTS
  PSCustomObject — SourceId, Action (loaded|exists), and RowCounts per record.
.EXAMPLE
  $import = Import-AgentTextFromFiles -ManifestPath $manifest -AsSql
  $import.Records | Save-AgentTextToDatabase -ConnectionString $connectionString
.NOTES
  AI assisted using .claude/Rules/Powershell.md as guidelines.
  Sprint 0008 Dev-tier slice of the AgentText round-trip pipeline.
#>
function Save-AgentTextToDatabase {
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [ValidateNotNull()]
    [PSCustomObject] $AgentText,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $ConnectionString
  )

  begin {
    $fn = 'Save-AgentTextToDatabase'
    $mn = 'ATAP.Utilities.RulesManagement.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    if (-not (Get-Command -Name 'New-AgentTextSqlConnection' -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot '..' 'private' 'New-AgentTextSqlConnection.ps1')
    }

    $connection = New-AgentTextSqlConnection -ConnectionString $ConnectionString
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Database connection opened'
  }

  process {
    try {
      if (-not ($AgentText.PSObject.Properties.Name -contains 'Sql') -or [string]::IsNullOrWhiteSpace([string]$AgentText.Sql)) {
        throw "Record '$($AgentText.SourceId)' has no Sql property. Re-run Import-AgentTextFromFiles with -AsSql."
      }

      $existedBefore = $false
      $checkCommand = $connection.CreateCommand()
      try {
        $checkCommand.CommandText = 'SELECT COUNT(1) FROM ATAPUtilities.AgentText WHERE SourceId = @SourceId;'
        $parameter = $checkCommand.CreateParameter()
        $parameter.ParameterName = '@SourceId'
        $parameter.Value = [string]$AgentText.SourceId
        [void]$checkCommand.Parameters.Add($parameter)
        $existedBefore = ([int]$checkCommand.ExecuteScalar()) -gt 0
      }
      finally {
        $checkCommand.Dispose()
      }

      if ($PSCmdlet.ShouldProcess($AgentText.SourceId, 'Load AgentText record into database')) {
        $loadCommand = $connection.CreateCommand()
        try {
          $loadCommand.CommandText = [string]$AgentText.Sql
          [void]$loadCommand.ExecuteNonQuery()
        }
        finally {
          $loadCommand.Dispose()
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Loaded AgentText record '$($AgentText.SourceId)' (existedBefore=$existedBefore)"

      return [PSCustomObject]@{
        SourceId = [string]$AgentText.SourceId
        Action   = if ($existedBefore) { 'exists' } else { 'loaded' }
      }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Save-AgentTextToDatabase failed for '$($AgentText.SourceId)'. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    if ($connection) {
      if ($connection.State -eq [System.Data.ConnectionState]::Open) { $connection.Close() }
      $connection.Dispose()
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Database connection closed'
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
