<#
.SYNOPSIS
Loads Gmail data from a Google Takeout zip file into a SQL Server database.

.DESCRIPTION
This cmdlet extracts Gmail data from a Google Takeout archive and loads it into the configured
SQL Server database. It uses New-ConnectionStringBuilderFromDbaTools for connection string creation,
handles zip file extraction, and delegates the actual data processing to a private function.

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
The name of the database to load data into. Defaults to 'GMAIL'.

.PARAMETER ConnectionMethod
Protocol to use for connection: tcp, np (named pipes), lpc (shared memory), or default.

.PARAMETER CredentialsKey
Key to retrieve credentials from vault. The secret object may contain:
- UserName (required): SQL or Windows login
- Password (required): Login password
- HostName (optional): Overrides DatabaseHost parameter
- SqlInstance (optional): Named instance
- Port (optional): Non-default port

.PARAMETER TakeoutZipPath
Path to the Google Takeout zip file containing Gmail data.

.PARAMETER ExtractPath
Path to the directory where the zip file will be extracted. If not specified, creates a temp directory.

.PARAMETER SkipExtraction
Switch to skip extraction if the data has already been extracted to ExtractPath.

.PARAMETER BatchSize
Number of messages to insert per database transaction. Default is 100.
Larger batch sizes improve performance but use more memory.

.OUTPUTS
System.Object
Returns a summary object with the results of the load operation.

.EXAMPLE
Load-Gmail -DatabaseHost 'localhost' -Environment 'Development' -DatabaseName 'GMAIL' -IntegratedSecurity -TakeoutZipPath 'C:\Downloads\takeout.zip'
Loads Gmail data using Windows Integrated Authentication to the Development instance.

.EXAMPLE
Load-Gmail -Environment 'Experimental' -DatabaseName 'GMAIL' -CredentialsKey 'Gmail_Dev_Credentials' -TakeoutZipPath 'C:\Downloads\takeout.zip'
Loads Gmail data to Experimental environment (default instance) using vault credentials.

.EXAMPLE
Load-Gmail -DatabaseHost 'sqlserver01' -Environment 'Production' -DatabaseName 'GMAIL' -CredentialsKey 'Gmail_SQL_Creds' -ExtractPath 'C:\Temp\Gmail' -SkipExtraction
Uses vault credentials with Production environment, loads from already-extracted directory.

.EXAMPLE
Load-Gmail -DatabaseHost 'localhost' -SqlInstance 'CustomInstance' -DatabaseName 'GMAIL' -IntegratedSecurity -TakeoutZipPath 'C:\Downloads\takeout.zip'
Uses an explicitly specified SqlInstance, overriding the Environment-based value.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Uses New-ConnectionStringBuilderFromDbaTools for connection string creation.
Requires dbatools module for database operations.
Requires Bitwarden CLI (bw) for vault authentication.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Load-Gmail {
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

    [Parameter(Mandatory = $false, Position = 5, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, Position = 5, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [string]$TakeoutZipPath,

    [Parameter(Mandatory = $false, Position = 6, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, Position = 6, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [string]$ExtractPath,

    [Parameter(Mandatory = $false, Position = 7, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, Position = 7, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [switch]$SkipExtraction,

    [Parameter(Mandatory = $false, Position = 8, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, Position = 8, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [int]$BatchSize = 100
  )

  BEGIN {
    $fn = 'Load-Gmail'
    $mn = 'ATAP.Utilities.Gmail.Powershell'

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
    $privateFunction = Join-Path $PSScriptRoot '..\private\Import-GmailTakeoutData.ps1'
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
    $Environment = Get-PVal -ParameterName 'Environment' -originalPSBoundParameters $PSBoundParameters -dottedPath 'DatabasesCollection.Gmail.Environment' -DefaultValue 'Experimental' -AllowMissing:$true -ValidValues @('Development', 'Testing', 'Production', 'Experimental')
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Environment: $Environment"

    # Check and populate DatabaseHost parameter
    $DatabaseHost = Get-PVal -ParameterName 'DatabaseHost' -originalPSBoundParameters $PSBoundParameters -dottedPath "DatabasesCollection.Gmail.$Environment.DatabaseHost" -DefaultValue $DatabaseHost -AllowMissing:$true
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "DatabaseHost: $DatabaseHost"

    # Check and populate SqlInstance parameter
    # Per Database Design: SqlInstance matches Environment, except 'Experimental' uses default instance (blank)
    $sqlInstanceDefault = if ($Environment -eq 'Experimental') { $null } else { $Environment }
    $SqlInstance = Get-PVal -ParameterName 'SqlInstance' -originalPSBoundParameters $PSBoundParameters -dottedPath "DatabasesCollection.Gmail.$Environment.SqlInstance" -DefaultValue $sqlInstanceDefault -AllowMissing:$true
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "SqlInstance: $SqlInstance"

    # Check and populate DatabaseName parameter
    $DatabaseName = Get-PVal -ParameterName 'DatabaseName' -originalPSBoundParameters $PSBoundParameters -dottedPath 'DatabasesCollection.Gmail.DatabaseName' -DefaultValue 'GMAIL' -AllowMissing:$true
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "DatabaseName: $DatabaseName"

    # Check and populate ConnectionMethod parameter
    $ConnectionMethod = Get-PVal -ParameterName 'ConnectionMethod' -originalPSBoundParameters $PSBoundParameters -dottedPath 'DatabasesCollection.Gmail.ConnectionMethod' -DefaultValue 'default' -AllowMissing:$true -ValidValues @('tcp', 'np', 'lpc', 'default')
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "ConnectionMethod: $ConnectionMethod"

    # Check and populate CredentialsKey parameter (only for CredentialsFromVault parameter set)
    if ($PSCmdlet.ParameterSetName -eq 'CredentialsFromVault') {
      $CredentialsKey = Get-PVal -ParameterName 'CredentialsKey' -originalPSBoundParameters $PSBoundParameters -dottedPath "DatabasesCollection.Gmail.$Environment.CredentialsKey" -DefaultValue $CredentialsKey -AllowMissing:$false
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "CredentialsKey: $CredentialsKey"
    }

    # Check and populate TakeoutZipPath parameter
    $TakeoutZipPath = Get-PVal -ParameterName 'TakeoutZipPath' -originalPSBoundParameters $PSBoundParameters -dottedPath 'DatabasesCollection.Gmail.TakeoutZipPath' -DefaultValue $TakeoutZipPath -AllowMissing:$true
    # Validate TakeoutZipPath exists if provided and not skipping extraction
    if (-not $SkipExtraction) {
      if ([string]::IsNullOrWhiteSpace($TakeoutZipPath)) {
        throw "TakeoutZipPath is required unless SkipExtraction is specified"
      }
      if (-not (Test-Path $TakeoutZipPath -PathType Leaf)) {
        throw "TakeoutZipPath does not exist or is not a file: $TakeoutZipPath"
      }
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "TakeoutZipPath: $TakeoutZipPath"

    # Check and populate ExtractPath parameter
    $ExtractPath = Get-PVal -ParameterName 'ExtractPath' -originalPSBoundParameters $PSBoundParameters -dottedPath 'DatabasesCollection.Gmail.ExtractPath' -DefaultValue $ExtractPath -AllowMissing:$true
    # Validate ExtractPath is provided when SkipExtraction is specified
    if ($SkipExtraction -and [string]::IsNullOrWhiteSpace($ExtractPath)) {
      throw "ExtractPath is required when SkipExtraction is specified"
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "ExtractPath: $ExtractPath"

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "BatchSize: $BatchSize"

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "All parameters validated successfully"
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

      # Set up extraction path
      if ([string]::IsNullOrWhiteSpace($ExtractPath)) {
        $ExtractPath = Join-Path ([System.IO.Path]::GetTempPath()) "GmailTakeout_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Using temp extract path: $ExtractPath"
      }

      # Extract zip file if needed
      if (-not $SkipExtraction) {
        if ($PSCmdlet.ShouldProcess($TakeoutZipPath, "Extract to $ExtractPath")) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Extracting zip file: $TakeoutZipPath"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Extract destination: $ExtractPath"

          # Create extraction directory if it doesn't exist
          if (-not (Test-Path $ExtractPath)) {
            New-Item -Path $ExtractPath -ItemType Directory -Force | Out-Null
          }

          # Extract the zip file
          try {
            Expand-Archive -Path $TakeoutZipPath -DestinationPath $ExtractPath -Force
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Extraction completed successfully"
          }
          catch {
            $errorMessage = "Failed to extract zip file: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw
          }
        }
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Skipping extraction, using existing data at: $ExtractPath"
      }

      # Validate extraction path exists
      if (-not (Test-Path $ExtractPath)) {
        throw "Extract path does not exist: $ExtractPath"
      }

      # Call the private function to process the data, passing the open connection
      if ($PSCmdlet.ShouldProcess($DatabaseName, "Load Gmail data from $ExtractPath")) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Starting Gmail data import..."

        $result = Import-GmailTakeoutData -SqlConnection $sqlConnection -TakeoutDataPath $ExtractPath -BatchSize $BatchSize

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Gmail data import completed"

        return $result
      }
    }
    catch {
      $errorMessage = "Load-Gmail failed: $($_.Exception.Message)"
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
