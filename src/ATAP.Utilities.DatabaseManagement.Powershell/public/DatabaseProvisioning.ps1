function DatabaseProvisioning {

  <#
  .SYNOPSIS
  Creates (or recreates) the BuildSets database and associated login/user objects.

  .DESCRIPTION
  Runs one or more SQL scripts (in a defined order) against a target SQL Server instance to provision
  a database. Each script is executed with structured logging and robust error handling.

  Supports two modes of operation:
  1. Connection Parameters: Build connection from individual parameters (DatabaseHost, SqlInstance, etc.)
  2. Existing Connection: Use a pre-existing SQL connection object

  .PARAMETER DatabaseName
  Name of the database to create or update.

  .PARAMETER SqlConnection
  An existing SQL connection object to use. When provided, DatabaseHost, SqlInstance, ConnectionMethod,
  and authentication parameters are ignored. The connection will be tested before use.
  This parameter belongs to the 'ExistingConnection' parameter set.

  .PARAMETER Environment
  Name of the environment, which influences the DatabaseHost, SqlInstance and the DatabasePath.
  This parameter belongs to the 'ConnectionParameters' parameter set.

  .PARAMETER DatabaseHost
  Computer (host) name of the machine that hosts the database server instance.
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .PARAMETER ConnectionMethod
  How to connect to the SQL instance: 'tcp' (default), 'np' (named pipes), or 'lpc' (shared memory).
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .PARAMETER SqlInstance
  SQL Server instance (local or remote) to target (e.g. '<hostname>\PRODUCTION').
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.
  If there exists a database with the same name as the database in the DatabaseHost\SqlInstance path, the operation is aborted unless force is true.
  If force is true, the existing database is deleted.

  .PARAMETER DatabasePath
  Path where the database files are to be created.
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.
  If there exists files with the same name as the database in this path, the operation is aborted unless force is true
  If force is true, the existing files are deleted.

  .PARAMETER ProvisioningScriptsPath
  Directory that contains the provisioning SQL scripts and contains the scripts executed by this function.
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .PARAMETER CredentialsKey
  The key used to retrieve the credentials from the vault for a SQL authenticated connection. If not supplied, Windows Integrated Security is used.

  .Parameter GrantDatabaseOwner
  If true, grants the login DBO access to the database
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .PARAMETER GrantBulkAdmin
  If true, grants the login BulkAdmin server role
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .PARAMETER Force
  If supplied, allow dropping existing database and login, else this fails if the database already exists

  .EXAMPLE
  # Using existing connection
  $conn = New-Object System.Data.SqlClient.SqlConnection("Server=UTAT01;Database=master;Integrated Security=true")
  $conn.Open()
  DatabaseProvisioning -DatabaseName PCMSC -SqlConnection $conn -DatabasePath "C:\Data" -ProvisioningScriptsPath "C:\Scripts" -Force

  .EXAMPLE
  # Using connection parameters (legacy mode)
  DatabaseProvisioning -DatabaseName BuildSets -Environment Development

  #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialsKey',
    Justification = 'CredentialsKey is a vault lookup key name, not a credential')]
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ConnectionParameters')]
  param(
    # region Database connection parameters
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [string]$Environment,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [Alias('HostName')]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [int]$Port,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ParameterSetName = 'ExistingConnection')]
    [switch]$IntegratedSecurity,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [string]$CredentialsKey,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [ValidateNotNull()]
    [Microsoft.Data.SqlClient.SqlConnection]$SqlConnection,
    # endregion Database connection parameters

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [string]$DatabasePath,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [string]$ProvisioningScriptsPath,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [bool]$GrantDatabaseOwner = $true,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [bool]$GrantBulkAdmin = $true,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [bool]$ProvisionForFlyway = $true,

    [switch]$Force
  )

  BEGIN {
    $fn = 'DatbaseProvisioning'
    $mn = 'ATAP.Utilities.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn (ParameterSet: $($PSCmdlet.ParameterSetName))"

    # Load required helper functions
    try {
      # Load utility functions
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      }
      if (-not (Get-Command -Name 'New-DbaConnectionStringBuilder' -CommandType Function -ErrorAction SilentlyContinue)) {
        install-module dbatools -Scope CurrentUser -Force -ErrorAction Stop
      }
    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    $errors = [System.Collections.Generic.List[string]]::new()
    $scriptsRun = [System.Collections.Generic.List[string]]::new()
    if (-not $CredentialsKey -and -not $IntegratedSecurity) {
      $IntegratedSecurity = $true
    }
    $useIntegratedSecurity = $IntegratedSecurity

    # Handle connection based on parameter set
    if ($PSCmdlet.ParameterSetName -eq 'ExistingConnection') {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Using existing SQL connection object"

      try {
        if (-not ($SqlConnection.PSObject.Properties['State'] -and $SqlConnection.PSObject.Methods['Open'])) {
          throw "Provided SqlConnection object does not appear to be a valid SQL connection (missing State property or Open method)"
        }

        if ($SqlConnection.State -ne [System.Data.ConnectionState]::Open) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Opening provided SQL connection"
          $SqlConnection.Open()
        }

        $testCmd = $SqlConnection.CreateCommand()
        $testCmd.CommandText = "SELECT @@VERSION AS Version, DB_NAME() AS CurrentDatabase"
        $testCmd.CommandTimeout = 30

        $testReader = $testCmd.ExecuteReader()
        if ($testReader.Read()) {
          $version = $testReader["Version"]
          $currentDb = $testReader["CurrentDatabase"]
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "SQL Connection verified - Server: $version, Current DB: $currentDb"
        }
        $testReader.Close()
        $testCmd.Dispose()

        $ConnectionString = $SqlConnection.ConnectionString
        $serverForConnect = $SqlConnection.DataSource
        $useIntegratedSecurity = ([Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new($SqlConnection.ConnectionString)).IntegratedSecurity
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Using server: $serverForConnect"

        if ([string]::IsNullOrWhiteSpace($DatabasePath)) {
          throw "DatabasePath is required when using SqlConnection parameter"
        }
        if ([string]::IsNullOrWhiteSpace($ProvisioningScriptsPath)) {
          throw "ProvisioningScriptsPath is required when using SqlConnection parameter"
        }
      }
      catch {
        $errorMessage = "Failed to validate or use provided SQL connection: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw
      }
    }
    else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Building SQL connection from parameters"

      # region Database connection parameter validation
      $databasesCollection = $global:settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']]
      $Environment = Get-PVal -ParameterName 'Environment' -originalPSBoundParameters $PSBoundParameters -DefaultValue $Environment -ValidValues @('Production', 'Testing', 'Development', 'Experimental')
      $SqlInstance = Get-PVal -ParameterName "SqlInstance" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.SqlInstance" -Settings $databasesCollection -DefaultValue $SqlInstance
      $DatabaseHost = Get-PVal -ParameterName "DatabaseHost" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.DatabaseHost" -Settings $databasesCollection -DefaultValue $DatabaseHost
      $ConnectionMethod = Get-PVal -ParameterName "ConnectionMethod" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.ConnectionMethod" -Settings $databasesCollection -DefaultValue $ConnectionMethod -ValidValues @('tcp', 'np', 'lpc')
      $Port = Get-PVal -ParameterName "Port" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.Port" -Settings $databasesCollection -DefaultValue $Port -AllowMissing
      $DatabasePath = Get-PVal -ParameterName "DatabasePath" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.DatabasePath" -Settings $databasesCollection -DefaultValue $DatabasePath
      $CredentialsKey = Get-PVal -ParameterName "CredentialsKey" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.CredentialsKey" -Settings $databasesCollection -DefaultValue $CredentialsKey
      # endregion Database connection parameters validation

      $ProvisioningScriptsPath = Get-PVal -ParameterName "ProvisioningScriptsPath" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.ProvisioningScriptsPath" -Settings $databasesCollection -DefaultValue $ProvisioningScriptsPath

      # Check and populate optional parameter
      $GrantDatabaseOwner = Get-PVal -ParameterName "GrantDatabaseOwner" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.GrantDatabaseOwner" -Settings $databasesCollection -DefaultValue $GrantDatabaseOwner -AsType ([bool]) -AllowMissing
      $GrantBulkAdmin = Get-PVal -ParameterName "GrantBulkAdmin" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.GrantBulkAdmin" -Settings $databasesCollection -DefaultValue $GrantBulkAdmin -AsType ([bool]) -AllowMissing
      $ProvisionForFlyway = Get-PVal -ParameterName "ProvisionForFlyway" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.ProvisionForFlyway" -Settings $databasesCollection -DefaultValue $ProvisionForFlyway -AsType ([bool]) -AllowMissing

      # Build up the connection string
      $connBuilderParams = @{
        DatabaseHost     = $DatabaseHost
        DatabaseName     = $DatabaseName
        ConnectionMethod = $ConnectionMethod
        SqlInstance      = $SqlInstance
      }

      if ($Port) { $connBuilderParams['Port'] = $Port }
      if ($CredentialsKey) { $connBuilderParams['CredentialsKey'] = $CredentialsKey }
      elseif ($IntegratedSecurity) { $connBuilderParams['IntegratedSecurity'] = $true }
      else { $connBuilderParams['IntegratedSecurity'] = $true }

      $connStrBuilder = New-DBAConnStrBuilder @connBuilderParams
      $ConnectionString = $connStrBuilder.ToString()
      $useIntegratedSecurity = $connStrBuilder.UseIntegratedSecurity
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "IntegratedSecurity (from builder): $useIntegratedSecurity"

      # Create the server portion of the connection string for Invoke-Sqlcmd
      $serverForConnect = "${ConnectionMethod}:$DatabaseHost"
      if (-not ([string]::IsNullOrWhiteSpace($SqlInstance) )) {
        $serverForConnect += "\$SqlInstance"
      }
    }

    # Initialize results tracking
    $result = [ordered]@{
      DatabaseName            = $DatabaseName
      Environment             = $Environment
      DatabasePath            = $DatabasePath
      SqlInstance             = $(if ($usingExistingConnection) { $SqlConnection.DataSource } else { $SqlInstance })
      CredentialsKey          = $CredentialsKey
      GrantDatabaseOwner      = $GrantDatabaseOwner
      UsingExistingConnection = $usingExistingConnection
      UseIntegratedSecurity   = $useIntegratedSecurity
      ScriptsPlanned          = @()
      ScriptsExecuted         = @()
      Success                 = $false
      Errors                  = @()
      Force                   = [bool]$Force
      TimestampUTC            = (Get-Date).ToUniversalTime()
    }

    # Ordered list of scripts with metadata
    $plannedScripts = @(
      @{
        Name      = 'DropAndCreateDatabase.sql'
        RunDb     = 'master'              # run against master (creates DB)
        NeedsVars = $false
      },
      @{
        Name      = 'CreateLoginAndUser.sql'
        RunDb     = $DatabaseName         # run inside target DB
        NeedsVars = $true                 # pass sqlcmd variables
      },
      @{
        Name      = 'AddFlywaySchemaHistoryTable.sql'
        RunDb     = $DatabaseName         # run inside target DB if ProvisionForFlyway is $true
        NeedsVars = $false                # pass sqlcmd variables
      }

    )

    foreach ($entry in $plannedScripts) {
      $full = Join-Path -Path $ProvisioningScriptsPath -ChildPath $entry.Name
      if (-not (Test-Path $full)) {
        $msg = "Planned script not found: $full"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        $errors.Add($msg) | Out-Null
      }
      else {
        $entry.FullPath = $full
        $result.ScriptsPlanned += $full
      }
    }

    if ($errors.Count -gt 0) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Aborting before execution due to missing scripts.'
      throw 'Provisioning aborted; missing scripts.'
    }

    # Test the connection to the SQL instance and check if the database already exists
    $dbExists = $false
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message ("Checking for existing database '{0}' on instance '{1}'" -f $DatabaseName, $serverForConnect)

      $safeDbName = $DatabaseName -replace "'", "''"
      $existsQuery = @"
IF DB_ID(N'$safeDbName') IS NULL
  SELECT CAST(0 AS bit) AS ExistsFlag;
ELSE
  SELECT CAST(1 AS bit) AS ExistsFlag;
"@

      $invokeCheck = @{
        ServerInstance         = $serverForConnect
        Database               = 'master'
        Query                  = $existsQuery
        ErrorAction            = 'Stop'
        Encrypt                = 'Optional'             # align with script execution params
        TrustServerCertificate = $true                  # temporary until trusted certs are available
      }

      $res = Invoke-Sqlcmd @invokeCheck
      $dbExists = ($res | Select-Object -First 1 -ExpandProperty ExistsFlag)

      if ($dbExists) {
        if (-not $Force) {
          $errorMessage = "Database '$DatabaseName' already exists on '$serverForConnect'. Use -Force to drop and recreate."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
        else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Database '$DatabaseName' already exists on '$serverForConnect'. It will be dropped and recreated because -Force is set." -Tag 'Validation', 'Warning'
        }
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Database '$DatabaseName' does not exist on '$serverForConnect'. Proceeding with creation." -Tag 'Validation', 'Info'
      }
    }
    catch {
      $errorMessage = "Failed checking database existence on '$serverForConnect': $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
      $errors.Add($errorMessage) | Out-Null
      throw
    }

    # if $dbExists and $force, drop the database
    if ($dbExists -and $Force) {
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message ("Dropping existing database '{0}' on instance '{1}'" -f $DatabaseName, $serverForConnect) -Tag 'Validation', 'Warning'

        $safeDbName = $DatabaseName -replace "'", "''"
        $dropQuery = @"
IF DB_ID(N'$safeDbName') IS NOT NULL
BEGIN
  ALTER DATABASE [$DatabaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE [$DatabaseName];
END
"@

        $invokeDrop = @{
          ServerInstance         = $serverForConnect
          Database               = 'master'
          Query                  = $dropQuery
          ErrorAction            = 'Stop'
          Encrypt                = 'Optional'             # align with script execution params
          TrustServerCertificate = $true                  # temporary until trusted certs are available
        }

        Invoke-Sqlcmd @invokeDrop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Successfully dropped existing database '$DatabaseName' on '$serverForConnect'." -Tag 'Validation', 'Warning'
      }
      catch {
        $errorMessage = "Failed dropping existing database '$DatabaseName' on '$serverForConnect': $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
        $errors.Add($errorMessage) | Out-Null
        throw
      }
    }

    # ensure any leftover files are deleted
    # prior we dropped the database and that should have dropped the database files
    # If the database files are still present, report that and delete them
    # ToDo: more sophisticated database files
    $mdf = Join-Path -Path $DatabasePath -ChildPath ($DatabaseName + '.mdf')
    $ldf = Join-Path -Path $DatabasePath -ChildPath ($DatabaseName + '_log.ldf')
    $filesToCheck = @($mdf, $ldf)
    foreach ($file in $filesToCheck) {
      if (Test-Path $file) {
        try {
          Remove-Item -Path $file -Force -ErrorAction Stop
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Deleted leftover database file '$file'." -Tag 'Validation', 'Warning'
        }
        catch {
          $errorMessage = "Failed to delete leftover database file '$file': $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          $errors.Add($errorMessage) | Out-Null
          throw
        }
      }
    }


    # Stash script metadata for PROCESS block
    $PlannedScriptsMetadata = $plannedScripts
    $loginPasswordValue = $loginPassword
    $dbExists = $dbExists
    $ServerForConnect = $serverForConnect
    $UsingExistingConnection = $usingExistingConnection
    $ProvidedSqlConnection = $SqlConnection
  }

  PROCESS {

    foreach ($meta in $PlannedScriptsMetadata) {
      $scriptPath = $meta.FullPath
      $scriptLabel = $meta.Name
      $targetDb = $meta.RunDb

      if ($PSCmdlet.ShouldProcess("$($ServerForConnect) / $targetDb", "Execute $scriptLabel")) {
        try {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting script $scriptLabel"

          try {
            $invokeParams = @{
              ServerInstance         = $ServerForConnect
              InputFile              = $scriptPath
              ErrorAction            = 'Stop'
              Encrypt                = 'Optional'
              TrustServerCertificate = $true
            }

            # If using existing connection, we can optionally pass it to Invoke-Sqlcmd
            # Note: Invoke-Sqlcmd doesn't directly accept a connection object, but we've validated connectivity

            if ($targetDb -and $targetDb -ne 'master') {
              $invokeParams.Database = $targetDb
            }

            # These variable names must match those used in the SQL script:
            # $(loginPassword), $(DatabaseName), $(DatabasePath), $(LoginName)

            # Determine LoginName and loginPassword based on authentication method
            $loginName = ''
            $loginPassword = ''
            if ($CredentialsKey) {
              # Retrieve credentials from vault
              if (-not (Get-Command -Name 'Get-BitWardenSecret' -CommandType Function -ErrorAction SilentlyContinue)) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message 'Get-BitWardenSecret function not found. Loading from known location.'
                . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\Get-BitWardenSecret.ps1'
              }
              $secret = Get-BitWardenSecret -SecretName $CredentialsKey
              $loginName = $secret.UserName
              $loginPassword = $secret.Password
            }

            $invokeParams.Variable = @{
              DatabaseName       = $DatabaseName
              DatabasePath       = $DatabasePath
              LoginName          = $loginName
              loginPassword      = $loginPassword
              DBExists           = $dbExists
              GrantDatabaseOwner = $GrantDatabaseOwner
              GrantBulkAdmin     = $GrantBulkAdmin
            }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling Invoke-Sqlcmd $scriptLabel (DB=$targetDb)"
            Invoke-Sqlcmd @invokeParams
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from Invoke-Sqlcmd $scriptLabel"
            $scriptsRun.Add($scriptPath) | Out-Null
          }
          catch {
            $errorMessage = "Failure executing $scriptLabel. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            if ($_.Exception.StackTrace) {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "StackTrace: $($_.Exception.StackTrace)"
            }
            $errors.Add($errorMessage) | Out-Null
            throw
          }
          finally {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished attempt for $scriptLabel"
          }
        }
        catch {
          continue
        }
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Skipped script $scriptLabel due to ShouldProcess decision"
      }
    }
  }

  END {
    $result.ScriptsExecuted = $scriptsRun.ToArray()
    $result.Errors = $errors.ToArray()
    $result.Success = ($errors.Count -eq 0)
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message ("Provisioning {0}" -f ($(if ($result.Success) { 'succeeded' } else { 'failed' })))
    if ($errors.Count -gt 0) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message ("Errors:`n {0}" -f ($errors -join [Environment]::NewLine))
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving script DatabaseProvisioning'
    [PSCustomObject]$result
  }
}
