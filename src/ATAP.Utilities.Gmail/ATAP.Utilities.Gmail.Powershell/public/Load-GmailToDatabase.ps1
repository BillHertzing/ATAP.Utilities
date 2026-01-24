<#
.SYNOPSIS
Loads Gmail data from a Google Takeout zip file into a SQL Server database.

.DESCRIPTION
This cmdlet extracts Gmail data from a Google Takeout archive and loads it into the configured
SQL Server database. It handles connection string creation, zip file extraction, and delegates
the actual data processing to a private function.

Uses parameter sets to determine authentication method:
- IntegratedAuth (default): Uses Windows Integrated Authentication
- SqlAuth: Uses SQL Server authentication with credentials from Bitwarden Secret Store

.PARAMETER SqlInstance
The SQL Server instance to connect to. If not specified, uses the value from environment or global settings.

.PARAMETER DatabaseName
The name of the database to load data into. Defaults to 'GMAIL'.

.PARAMETER SqlDatabaseLoginKey
The Bitwarden secret key for SQL Server login credentials. When specified, uses SQL authentication
with username and password retrieved from Bitwarden. If not specified, uses Windows Integrated Authentication.

.PARAMETER TakeoutZipPath
Path to the Google Takeout zip file containing Gmail data.

.PARAMETER ExtractPath
Path to the directory where the zip file will be extracted. If not specified, creates a temp directory.

.PARAMETER SkipExtraction
Switch to skip extraction if the data has already been extracted to ExtractPath.

.PARAMETER TrustServerCertificate
Switch to trust the server certificate (useful for development environments with self-signed certs).

.OUTPUTS
System.Object
Returns a summary object with the results of the load operation.

.EXAMPLE
Load-GmailToDatabase -SqlInstance 'UTAT01' -TakeoutZipPath 'C:\Downloads\takeout.zip'
Loads Gmail data using Windows Integrated Authentication to the default GMAIL database.

.EXAMPLE
Load-GmailToDatabase -SqlInstance 'UTAT01' -SqlDatabaseLoginKey 'gmail-sql-login' -TakeoutZipPath 'C:\Downloads\takeout.zip'
Loads Gmail data using SQL authentication with credentials from Bitwarden secret 'gmail-sql-login'.

.EXAMPLE
Load-GmailToDatabase -SqlInstance 'UTAT01' -ExtractPath 'C:\Temp\Gmail' -SkipExtraction
Loads Gmail data from an already-extracted directory using Windows Integrated Authentication.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Requires SqlServer module for database operations.
Requires Bitwarden CLI (bw) for SQL authentication.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Load-GmailToDatabase {
  [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'IntegratedAuth')]
  param(
    [Parameter(Mandatory = $false, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedAuth')]
    [Parameter(Mandatory = $false, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlAuth')]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedAuth')]
    [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlAuth')]
    [string]$DatabaseName = 'GMAIL',

    [Parameter(Mandatory = $true, Position = 2, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlAuth')]
    [string]$SqlDatabaseLoginKey,

    [Parameter(Mandatory = $false, Position = 3, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedAuth')]
    [Parameter(Mandatory = $false, Position = 3, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlAuth')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$TakeoutZipPath,

    [Parameter(Mandatory = $false, Position = 4, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedAuth')]
    [Parameter(Mandatory = $false, Position = 4, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlAuth')]
    [string]$ExtractPath,

    [Parameter(Mandatory = $false, Position = 5, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedAuth')]
    [Parameter(Mandatory = $false, Position = 5, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlAuth')]
    [switch]$SkipExtraction,

    [Parameter(Mandatory = $false, Position = 6, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedAuth')]
    [Parameter(Mandatory = $false, Position = 6, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlAuth')]
    [switch]$TrustServerCertificate
  )

  BEGIN {
    $fn = 'Load-GmailToDatabase'
    $mn = 'ATAP.Utilities.Gmail.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Load required helper functions
    try {
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      }
      if (-not (Get-Command -Name 'Resolve-ParameterValueToList' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Resolve-ParameterValueToList.ps1'
      }
      if (-not (Get-Command -Name 'Get-BitWardenCredential' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\Get-BitWardenCredential.ps1'
      }
      if (-not (Get-Module -Name SqlServer -ListAvailable)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "SqlServer module not found. Installing..."
        Install-Module -Name SqlServer -Scope CurrentUser -Force -AllowClobber
      }
      Import-Module SqlServer -ErrorAction Stop

    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    # Load private function
    $privateFunction = Join-Path $PSScriptRoot '..\private\Import-GmailTakeoutData.ps1'
    if (Test-Path $privateFunction) {
      . $privateFunction
    }
    else {
      $errorMessage = "Private function not found at: $privateFunction"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    # Determine if using SQL authentication based on parameter set
    $useIntegratedSecurity = ($PSCmdlet.ParameterSetName -eq 'IntegratedAuth')

    # If using SQL authentication, retrieve credentials using Get-BitWardenCredential
    $sqlUsername = $null
    $sqlPassword = $null

    # Validate parameters - TakeoutZipPath and ExtractPath interdependency
    if (-not $SkipExtraction -and [string]::IsNullOrWhiteSpace($TakeoutZipPath)) {
      throw "TakeoutZipPath is required unless SkipExtraction is specified"
    }

    if ($SkipExtraction -and [string]::IsNullOrWhiteSpace($ExtractPath)) {
      throw "ExtractPath is required when SkipExtraction is specified"
    }

    # Resolve SqlInstance using Get-PVal (alias for Get-ParameterValueFromNeoConfigurationRoot)
    $SqlInstance = Get-PVal -ParameterName 'SqlInstance' -originalPSBoundParameters $PSBoundParameters -dottedPath 'DatabasesCollection.Gmail.Experimental.ServerInstance' -DefaultValue $SqlInstance -AllowMissing:$false

    if ([string]::IsNullOrWhiteSpace($SqlInstance)) {
      throw "SqlInstance is required. Provide it as a parameter or configure in global settings at 'DatabasesCollection.Gmail.Experimental.ServerInstance'."
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Resolved SqlInstance: $SqlInstance"

    if (-not $useIntegratedSecurity) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "SQL Authentication requested. Retrieving credentials from Bitwarden..."

      try {
        # Use Get-BitWardenCredential to retrieve the SQL login credentials
        # The SqlDatabaseLoginKey is used to identify the credential in the credential store
        $credentials = Get-BitWardenCredential

        if (-not $credentials -or -not $credentials.LoginCredential) {
          $errorMessage = "Failed to retrieve BitWarden credentials. Ensure credentials are configured."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw $errorMessage
        }

        # Extract username and password from the credential
        $sqlUsername = $credentials.LoginCredential.UserName
        $sqlPassword = $credentials.LoginCredential.GetNetworkCredential().Password

        if ([string]::IsNullOrWhiteSpace($sqlUsername) -or [string]::IsNullOrWhiteSpace($sqlPassword)) {
          $errorMessage = "Could not extract username and/or password from BitWarden credentials."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw $errorMessage
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Successfully retrieved SQL credentials for user: $sqlUsername"
      }
      catch {
        $errorMessage = "Error retrieving credentials from BitWarden: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw
      }
    }
  }

  PROCESS {
    try {

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "SQL Server Instance: $SqlInstance"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Database: $DatabaseName"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Authentication: $(if ($useIntegratedSecurity) { 'Windows Integrated' } else { 'SQL Server' })"

      # Build connection string
      $connectionStringBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
      $connectionStringBuilder["Server"] = $SqlInstance
      $connectionStringBuilder["Database"] = $DatabaseName

      if ($useIntegratedSecurity) {
        $connectionStringBuilder["Integrated Security"] = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Using Windows Integrated Authentication"
      }
      else {
        $connectionStringBuilder["User ID"] = $sqlUsername
        $connectionStringBuilder["Password"] = $sqlPassword
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Using SQL Authentication with user: $sqlUsername"
      }

      if ($TrustServerCertificate) {
        $connectionStringBuilder["TrustServerCertificate"] = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "TrustServerCertificate enabled"
      }

      $connectionStringBuilder["Connection Timeout"] = 30

      $connectionString = $connectionStringBuilder.ConnectionString
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Connection string built successfully"

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

      # Call the private function to process the data
      if ($PSCmdlet.ShouldProcess($DatabaseName, "Load Gmail data from $ExtractPath")) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Starting Gmail data import..."

        $result = Import-GmailTakeoutData -ConnectionString $connectionString -TakeoutDataPath $ExtractPath

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Gmail data import completed"

        return $result
      }
    }
    catch {
      $errorMessage = "Load-GmailToDatabase failed: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
      throw
    }
  }

  END {
    # Clear sensitive variables
    if ($sqlPassword) {
      $sqlPassword = $null
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
