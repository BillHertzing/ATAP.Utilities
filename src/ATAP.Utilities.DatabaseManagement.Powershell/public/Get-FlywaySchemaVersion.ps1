#Requires -Version 7.0
function Get-FlywaySchemaVersion {
  <#
.SYNOPSIS
    Returns the current Flyway schema version history from a target database.

.DESCRIPTION
    Queries `flyway_schema_history` on the specified database and returns each
    row as a [PSCustomObject].  The most-recently applied migration is first.
    Uses Resolve-DatabaseSqlConnection for connection resolution, accepting the
    same three connection methods as all other ATAP database cmdlets:
    an open SqlConnection object, a Bitwarden secret name, or structured
    connection-part parameters (DatabaseHost / SqlInstance / DatabaseName / etc.).

.PARAMETER SqlConnection
    An open Microsoft.Data.SqlClient.SqlConnection object.
    Mandatory for the SqlConnection parameter set.

.PARAMETER BitwardenSecretName
    Name of a Bitwarden secure note whose password is a complete SQL connection
    string.  Mandatory for the BitwardenSecretName parameter set.

.PARAMETER DatabaseHost
    SQL Server host name.  Used with the ConnectionParts parameter set.

.PARAMETER SqlInstance
    SQL Server named instance.  Used with the ConnectionParts parameter set.

.PARAMETER DatabaseName
    Database to query.  Used with the ConnectionParts parameter set.

.PARAMETER ConnectionMethod
    Connection protocol: tcp, np, lpc, or default.

.PARAMETER CredentialsKey
    Bitwarden credentials key for SQL authentication.  Used with ConnectionParts.

.PARAMETER IntegratedSecurity
    Use Windows Integrated Authentication with ConnectionParts.

.OUTPUTS
    [PSCustomObject[]] with properties:
      InstalledRank, Version, Description, Type, Script,
      Checksum, InstalledBy, InstalledOn, ExecutionTime, Success

.EXAMPLE
    Get-FlywaySchemaVersion -DatabaseHost localhost -SqlInstance SQLEXPRESS `
        -DatabaseName ATAPUtilities -IntegratedSecurity

.EXAMPLE
    $conn = New-Object Microsoft.Data.SqlClient.SqlConnection $connStr
    $conn.Open()
    Get-FlywaySchemaVersion -SqlConnection $conn

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Task: TASKS_V4-DBA1.md DBA1-T04 / V4-E07.
#>
  [CmdletBinding(DefaultParameterSetName = 'ConnectionParts')]
  [OutputType([PSCustomObject[]])]
  param(
    [Parameter(Mandatory = $true, ParameterSetName = 'SqlConnection', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [object]$SqlConnection,

    [Parameter(Mandatory = $true, ParameterSetName = 'BitwardenSecretName', ValueFromPipelineByPropertyName = $true)]
    [Alias('BitwardenSecret', 'SecretName')]
    [string]$BitwardenSecretName,

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
    $fn = 'Get-FlywaySchemaVersion'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'
  }

  process {
    # Resolve connection
    $resolvedConnection = Resolve-DatabaseSqlConnection `
      -OriginalPSBoundParameters $PSBoundParameters `
      -SqlConnection $SqlConnection `
      -BitwardenSecretName $BitwardenSecretName `
      -DatabaseHost $DatabaseHost `
      -InstanceName $SqlInstance `
      -DatabaseName $DatabaseName `
      -ConnectionMethod $ConnectionMethod `
      -CredentialsKey $CredentialsKey `
      -IntegratedSecurity:$IntegratedSecurity

    $query = @'
SELECT
    installed_rank  AS InstalledRank,
    version         AS Version,
    description     AS Description,
    type            AS Type,
    script          AS Script,
    checksum        AS Checksum,
    installed_by    AS InstalledBy,
    installed_on    AS InstalledOn,
    execution_time  AS ExecutionTime,
    success         AS Success
FROM flyway_schema_history
ORDER BY installed_rank DESC;
'@

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Querying flyway_schema_history on database '$DatabaseName'" -Tag 'Flyway'

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $cmd = $resolvedConnection.CreateCommand()
    try {
      $cmd.CommandText = $query
      $reader = $cmd.ExecuteReader()
      try {
        while ($reader.Read()) {
          $results.Add([PSCustomObject]@{
              InstalledRank = $reader['InstalledRank']
              Version       = $reader['Version']
              Description   = $reader['Description']
              Type          = $reader['Type']
              Script        = $reader['Script']
              Checksum      = $reader['Checksum']
              InstalledBy   = $reader['InstalledBy']
              InstalledOn   = $reader['InstalledOn']
              ExecutionTime = $reader['ExecutionTime']
              Success       = $reader['Success']
            })
        }
      } finally {
        $reader.Dispose()
      }
    } finally {
      $cmd.Dispose()
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Returned $($results.Count) flyway_schema_history rows" -Tag 'Flyway'

    Write-Output $results.ToArray()
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
  }
}
