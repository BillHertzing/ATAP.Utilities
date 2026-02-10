<#
.SYNOPSIS
Loads Tags data for an organization
.DESCRIPTION
Long description

Uses parameter sets to determine authentication method:
- IntegratedSecurity (default): Uses Windows Integrated Authentication
- CredentialsFromVault: Retrieves credentials from vault using CredentialsKey

.PARAMETER DatabaseHost
The SQL Server host. Can be overridden by vault secret if CredentialsKey returns a HostName. Alias: HostName

.PARAMETER Environment
The target environment: 'Development', 'Testing', 'Production', or 'Experimental'.
This parameter drives the value of SqlInstance:
- Development, Testing, Production: SqlInstance is set to match the Environment value
- Experimental: SqlInstance is left blank (uses default instance)

.PARAMETER SqlInstance
The SQL Server named instance.
Typically derived from the Environment parameter.
Can be explicitly specified to override the Environment-based value.

.PARAMETER DatabaseName
The name of the database to load data into. Defaults to 'Tags'.

.PARAMETER ConnectionMethod
Protocol to use for connection: tcp, np (named pipes), lpc (shared memory), or default.

.PARAMETER CredentialsKey
Key to retrieve credentials from vault. The secret object may contain:
- UserName (required): SQL or Windows login
- Password (required): Login password
- HostName (optional): Overrides DatabaseHost parameter
- SqlInstance (optional): Named instance
- Port (optional): Non-default port

.PARAMETER SourcePath
Path to the source data file or directory containing tag data to import.

.PARAMETER BatchSize
Number of records to process per database transaction. Default is 100.
Larger batch sizes improve performance but use more memory.


.OUTPUTS
System.Object
Returns a summary object with the results of the load operation.

.EXAMPLE
Load-Tags -DatabaseHost 'localhost' -Environment 'Development' -DatabaseName 'Tags' -IntegratedSecurity

.EXAMPLE
Load-Tags -DatabaseHost 'localhost' -Environment 'Development' -IntegratedSecurity -SourcePath 'C:\Data\tags.json' -BatchSize 50

.EXAMPLE
Load-Tags -Environment 'Production' -CredentialsKey 'TagsDB-Prod' -BatchSize 200

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Uses New-ConnectionStringBuilderFromDbaTools for connection string creation.
Requires dbatools module for database operations.
Requires Bitwarden CLI (bw) for vault authentication.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Load-Tags {
  [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'IntegratedSecurity')]
  param(
    [Parameter(Mandatory = $false, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [Alias('HostName')]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [string]$Environment,

    [Parameter(Mandatory = $false, Position = 2, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, Position = 2, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false, Position = 3, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, Position = 3, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [string]$DatabaseName,

    [Parameter(Mandatory = $false, Position = 4, ValueFromPipelineByPropertyName = $true)]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $true, ParameterSetName = 'IntegratedSecurity')]
    [switch]$IntegratedSecurity,

    [Parameter(Mandatory = $true, ParameterSetName = 'CredentialsFromVault')]
    [string]$CredentialsKey,

    [Parameter(Mandatory = $false, Position = 5, ValueFromPipelineByPropertyName = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $false, Position = 6, ValueFromPipelineByPropertyName = $true)]
    [int]$BatchSize = 100
  )

  BEGIN {
    $fn = 'Load-Tags'
    $mn = 'ATAP.Utilities.Tags.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Load required helper functions
    try {
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      }
      if (-not (Get-Command -Name 'New-ConnectionStringBuilderFromDbaTools' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\New-ConnectionStringBuilderFromDbaTools.ps1'
      }
    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    # Load private functions
    $privateFunction = Join-Path $PSScriptRoot '..\private\Import-Tags.ps1'
    if (Test-Path $privateFunction) {
      . $privateFunction
    }
    else {
      $errorMessage = "Private function not found at: $privateFunction"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    # Parameter validation using Get-PVal pattern (per Powershell.instructions.md)

    # Check and populate Environment parameter
    $Environment = Get-PVal -ParameterName 'Environment' -originalPSBoundParameters $PSBoundParameters -dottedPath 'DatabasesCollection.Tags.Environment' -DefaultValue 'Experimental' -AllowMissing:$true -ValidValues @('Development', 'Testing', 'Production', 'Experimental')
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Environment: $Environment"

    # Check and populate DatabaseHost parameter
    $DatabaseHost = Get-PVal -ParameterName 'DatabaseHost' -originalPSBoundParameters $PSBoundParameters -dottedPath "DatabasesCollection.Tags.$Environment.DatabaseHost" -DefaultValue $DatabaseHost -AllowMissing:$true
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "DatabaseHost: $DatabaseHost"

    # Check and populate SqlInstance parameter
    # Per Database Design: SqlInstance matches Environment, except 'Experimental' uses default instance (blank)
    $sqlInstanceDefault = if ($Environment -eq 'Experimental') { $null } else { $Environment }
    $SqlInstance = Get-PVal -ParameterName 'SqlInstance' -originalPSBoundParameters $PSBoundParameters -dottedPath "DatabasesCollection.Tags.$Environment.SqlInstance" -DefaultValue $sqlInstanceDefault -AllowMissing:$true
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "SqlInstance: $SqlInstance"

    # Check and populate DatabaseName parameter
    $DatabaseName = Get-PVal -ParameterName 'DatabaseName' -originalPSBoundParameters $PSBoundParameters -dottedPath 'DatabasesCollection.Tags.DatabaseName' -DefaultValue 'Tags' -AllowMissing:$true
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "DatabaseName: $DatabaseName"

    # Check and populate ConnectionMethod parameter
    $ConnectionMethod = Get-PVal -ParameterName 'ConnectionMethod' -originalPSBoundParameters $PSBoundParameters -dottedPath 'DatabasesCollection.Tags.ConnectionMethod' -DefaultValue 'default' -AllowMissing:$true -ValidValues @('tcp', 'np', 'lpc', 'default')
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "ConnectionMethod: $ConnectionMethod"

    # Check and populate CredentialsKey parameter (only for CredentialsFromVault parameter set)
    if ($PSCmdlet.ParameterSetName -eq 'CredentialsFromVault') {
      $CredentialsKey = Get-PVal -ParameterName 'CredentialsKey' -originalPSBoundParameters $PSBoundParameters -dottedPath "DatabasesCollection.Tags.$Environment.CredentialsKey" -DefaultValue $CredentialsKey -AllowMissing:$false
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "CredentialsKey: $CredentialsKey"
    }

    # Check and populate SourcePath parameter
    # ToDo: there may be more than one way to load data, so we may want to allow for multiple source paths (e.g. one for tags, one for related data). If so, we should consider a more flexible parameter structure that allows for multiple named source paths rather than hardcoding 'SourcePath'. For now, we'll keep it simple with a single SourcePath parameter.
    $SourcePath = Get-PVal -ParameterName 'SourcePath' -originalPSBoundParameters $PSBoundParameters -dottedPath 'DatabasesCollection.Tags.SourcePath' -DefaultValue $SourcePath -AllowMissing:$true
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "SourcePath: $SourcePath"

    # Check and populate BatchSize parameter
    $BatchSize = Get-PVal -ParameterName 'BatchSize' -originalPSBoundParameters $PSBoundParameters -dottedPath 'DatabasesCollection.Tags.BatchSize' -DefaultValue 100 -AllowMissing:$true
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "BatchSize: $BatchSize"

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'All parameters validated successfully'
  }

  PROCESS {
    $sqlConnection = $null

    try {
      # Build connection string using New-ConnectionStringBuilderFromDbaTools
      $connBuilderParams = @{
        DatabaseName     = $DatabaseName
        ConnectionMethod = $ConnectionMethod
      }

      # Add DatabaseHost if specified
      if (-not [string]::IsNullOrWhiteSpace($DatabaseHost)) {
        $connBuilderParams['DatabaseHost'] = $DatabaseHost
      }

      # Add SqlInstance if specified
      if (-not [string]::IsNullOrWhiteSpace($SqlInstance)) {
        $connBuilderParams['SqlInstance'] = $SqlInstance
      }

      # Set authentication method based on parameter set
      # ToDo: this is not quite right
      # After populating connBuilderParams from parameters using Get-PVal, if a credentials Key is provided
      #  (either directly or via configuration), use that to override Host, Instance, authentication method, user if present,
      #   and password rather than relying solely on the parameter set.
      #  The presence of a specific property in a retrieved credentials should take precedence over the
      #  parameters.
      if ($PSCmdlet.ParameterSetName -eq 'IntegratedSecurity') {
        $connBuilderParams['IntegratedSecurity'] = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Using Windows Integrated Authentication'
      }
      else {
        $connBuilderParams['CredentialsKey'] = $CredentialsKey
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Using vault credentials with key: $CredentialsKey"
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Database: $DatabaseName"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "ConnectionMethod: $ConnectionMethod"

      # Create the connection string builder
      $connectionStringBuilder = New-ConnectionStringBuilderFromDbaTools @connBuilderParams

      # Get the connection string by calling ToString()
      $connectionString = $connectionStringBuilder.ToString()

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "DataSource: $($connectionStringBuilder.DataSource)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Connection string built successfully'

      # Open database connection
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Opening database connection...'
      $sqlConnection = New-Object Microsoft.Data.SqlClient.SqlConnection($connectionString)
      $sqlConnection.Open()
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Database connection opened successfully'

      # Verify database exists by checking the connection's database property
      if ($sqlConnection.Database -ne $DatabaseName) {
        throw "Connected to unexpected database '$($sqlConnection.Database)' instead of '$DatabaseName'"
      }

      # Verify database is accessible by running a simple query
      $checkCmd = $sqlConnection.CreateCommand()
      $checkCmd.CommandText = 'SELECT DB_NAME() AS CurrentDatabase'
      try {
        $dbResult = $checkCmd.ExecuteScalar()
        if ($dbResult -ne $DatabaseName) {
          throw "Database verification failed. Expected '$DatabaseName', got '$dbResult'"
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Database '$DatabaseName' verified and accessible"
      }
      finally {
        $checkCmd.Dispose()
      }

      # Call the private function to process the data, passing the open connection
      if ($PSCmdlet.ShouldProcess($DatabaseName, 'Load tag data')) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Starting data import...'

        # Build parameters for private function
        $importParams = @{
          SqlConnection = $sqlConnection
          BatchSize     = $BatchSize
        }

        # Add optional parameters if provided
        if ($PSBoundParameters.ContainsKey('SourcePath')) {
          $importParams['SourcePath'] = $SourcePath
        }

        $result = Import-Tags @importParams

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Data import completed'

        return $result
      }
    }
    catch {
      $errorMessage = "Load-Tags failed: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
      throw
    }
    finally {
      # Close and dispose the database connection
      if ($sqlConnection) {
        if ($sqlConnection.State -eq [System.Data.ConnectionState]::Open) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Closing database connection'
          $sqlConnection.Close()
        }
        $sqlConnection.Dispose()
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Database connection disposed'
      }
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
