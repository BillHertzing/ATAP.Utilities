<#
.SYNOPSIS
  Reads AgentText records back out of the pilot tables.
.DESCRIPTION
  Completes the read direction of the AgentText round trip. Queries
  ATAPUtilities.AgentText plus its child tables (AgentToolSurface,
  AgentAdapterTarget, AgentTextRoundTrip) and returns records shaped exactly
  like the records produced by Import-AgentTextFromFiles, so the output can be
  piped straight into Export-AgentTextToFiles to instantiate adapter files
  from database content.
.PARAMETER ConnectionString
  SQL Server connection string for the source ATAPUtilities database. Resolve
  the value from Bitwarden (e.g. Get-SecretATAP with the
  dbConnectionString-ATAPUtilities-<Host>-<Tier>[-<UserName>] item name); do
  not embed literal credentials in scripts.
.PARAMETER SourceId
  Optional. When supplied, only the record with this manifest SourceId is
  returned; otherwise every AgentText row is returned.
.OUTPUTS
  PSCustomObject[] — each record: AgentTextId, SourceId, Kind, DisplayName,
  SourcePath, BodyFormat, BodySha256, BodyText, ToolSurface, AdapterTargets,
  RoundTripPolicy.
.EXAMPLE
  Get-AgentTextFromDatabase -ConnectionString $connectionString -SourceId 'ai.agent.claude.version-control-commit.v1' |
    Export-AgentTextToFiles -TargetRoot $targetRoot
.NOTES
  AI assisted using .claude/Rules/Powershell.md as guidelines.
  Sprint 0008 Dev-tier slice of the AgentText round-trip pipeline.
#>
function Get-AgentTextFromDatabase {
  [CmdletBinding()]
  [OutputType([PSCustomObject[]])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $ConnectionString,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $SourceId
  )

  begin {
    $fn = 'Get-AgentTextFromDatabase'
    $mn = 'ATAP.Utilities.RulesManagement.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    if (-not (Get-Command -Name 'New-AgentTextSqlConnection' -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot '..' 'private' 'New-AgentTextSqlConnection.ps1')
    }

    function Read-AgentTextChildRows {
      param(
        [Parameter(Mandatory = $true)][object] $Connection,
        [Parameter(Mandatory = $true)][string] $CommandText,
        [Parameter(Mandatory = $true)][guid] $AgentTextId,
        [Parameter(Mandatory = $true)][scriptblock] $RowMapper
      )

      $command = $Connection.CreateCommand()
      $reader = $null
      try {
        $command.CommandText = $CommandText
        $parameter = $command.CreateParameter()
        $parameter.ParameterName = '@AgentTextId'
        $parameter.Value = $AgentTextId
        [void]$command.Parameters.Add($parameter)
        $reader = $command.ExecuteReader()
        $rows = [System.Collections.Generic.List[object]]::new()
        while ($reader.Read()) {
          $rows.Add((& $RowMapper $reader))
        }
        return $rows
      }
      finally {
        if ($reader) { $reader.Dispose() }
        $command.Dispose()
      }
    }
  }

  process {
    $connection = $null
    try {
      $connection = New-AgentTextSqlConnection -ConnectionString $ConnectionString
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Database connection opened'

      $headRows = [System.Collections.Generic.List[object]]::new()
      $headCommand = $connection.CreateCommand()
      $headReader = $null
      try {
        $headCommand.CommandText = @'
SELECT a.AgentTextId, a.SourceId, a.Kind, a.DisplayName, a.SourcePath, a.BodyFormat, a.BodySha256, a.BodyText,
       rt.RoundTripPolicy
FROM ATAPUtilities.AgentText AS a
LEFT JOIN ATAPUtilities.AgentTextRoundTrip AS rt ON rt.AgentTextId = a.AgentTextId
'@
        if ($PSBoundParameters.ContainsKey('SourceId')) {
          $headCommand.CommandText += [System.Environment]::NewLine + 'WHERE a.SourceId = @SourceId'
          $parameter = $headCommand.CreateParameter()
          $parameter.ParameterName = '@SourceId'
          $parameter.Value = $SourceId
          [void]$headCommand.Parameters.Add($parameter)
        }
        $headCommand.CommandText += [System.Environment]::NewLine + 'ORDER BY a.SourceId;'

        $headReader = $headCommand.ExecuteReader()
        while ($headReader.Read()) {
          $headRows.Add([PSCustomObject]@{
            AgentTextId     = [guid]$headReader['AgentTextId']
            SourceId        = [string]$headReader['SourceId']
            Kind            = [string]$headReader['Kind']
            DisplayName     = if ($headReader['DisplayName'] -is [System.DBNull]) { $null } else { [string]$headReader['DisplayName'] }
            SourcePath      = [string]$headReader['SourcePath']
            BodyFormat      = [string]$headReader['BodyFormat']
            BodySha256      = [string]$headReader['BodySha256']
            BodyText        = [string]$headReader['BodyText']
            RoundTripPolicy = if ($headReader['RoundTripPolicy'] -is [System.DBNull]) { 'semantic' } else { [string]$headReader['RoundTripPolicy'] }
          })
        }
      }
      finally {
        if ($headReader) { $headReader.Dispose() }
        $headCommand.Dispose()
      }

      if ($PSBoundParameters.ContainsKey('SourceId') -and $headRows.Count -eq 0) {
        throw "No AgentText record found with SourceId '$SourceId'."
      }

      $records = [System.Collections.Generic.List[object]]::new()
      foreach ($head in $headRows) {
        $toolSurface = Read-AgentTextChildRows -Connection $connection -AgentTextId $head.AgentTextId `
          -CommandText 'SELECT ToolName FROM ATAPUtilities.AgentToolSurface WHERE AgentTextId = @AgentTextId ORDER BY AgentToolSurfaceId;' `
          -RowMapper { param($reader) [string]$reader['ToolName'] }

        $targets = Read-AgentTextChildRows -Connection $connection -AgentTextId $head.AgentTextId `
          -CommandText 'SELECT ToolName, TargetPath, Materialization, RenderedSha256, RenderedBytes FROM ATAPUtilities.AgentAdapterTarget WHERE AgentTextId = @AgentTextId ORDER BY AgentAdapterTargetId;' `
          -RowMapper {
            param($reader)
            [PSCustomObject]@{
              Tool            = [string]$reader['ToolName']
              Path            = [string]$reader['TargetPath']
              Materialization = [string]$reader['Materialization']
              RenderedSha256  = if ($reader['RenderedSha256'] -is [System.DBNull]) { $null } else { [string]$reader['RenderedSha256'] }
              RenderedBytes   = if ($reader['RenderedBytes'] -is [System.DBNull]) { $null } else { [int]$reader['RenderedBytes'] }
            }
          }

        $records.Add([PSCustomObject]@{
          AgentTextId     = $head.AgentTextId
          SourceId        = $head.SourceId
          Kind            = $head.Kind
          DisplayName     = $head.DisplayName
          SourcePath      = $head.SourcePath
          BodyFormat      = $head.BodyFormat
          BodySha256      = $head.BodySha256
          BodyBytes       = [System.Text.Encoding]::UTF8.GetByteCount($head.BodyText)
          BodyText        = $head.BodyText
          ToolSurface     = @($toolSurface)
          AdapterTargets  = @($targets)
          RoundTripPolicy = $head.RoundTripPolicy
        })
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Read $($records.Count) AgentText record(s) from database"
      return $records.ToArray()
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Get-AgentTextFromDatabase failed. Exception: $($_.Exception.Message)"
      throw
    }
    finally {
      if ($connection) {
        if ($connection.State -eq [System.Data.ConnectionState]::Open) { $connection.Close() }
        $connection.Dispose()
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
