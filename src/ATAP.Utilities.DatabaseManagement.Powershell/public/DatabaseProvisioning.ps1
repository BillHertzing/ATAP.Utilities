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
  This parameter belongs to the 'SqlConnection' parameter set.

  .PARAMETER Environment
  Name of the environment, which influences the DatabaseHost, SqlInstance and the DatabasePath.
  This parameter belongs to the 'ConnectionParts' parameter set.

  .PARAMETER DatabaseHost
  Computer (host) name of the machine that hosts the database server instance.
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .PARAMETER ConnectionMethod
  How to connect to the SQL instance: 'tcp' (default), 'np' (named pipes), or 'lpc' (shared memory).
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .PARAMETER SqlInstance
  SQL Server instance (local or remote) to target (e.g. '<hostname>\Production').
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
  If supplied, allow dropping an existing database and removing an existing
  database file folder before provisioning. Without -Force, an existing database
  or database file folder fails fast.

  .EXAMPLE
  # Using existing connection
  $conn = Resolve-DatabaseSqlConnection -DatabaseHost UTAT01 -DatabaseName master -IntegratedSecurity
  DatabaseProvisioning -DatabaseName PCMSC -SqlConnection $conn -DatabasePath "C:\Data" -ProvisioningScriptsPath "C:\Scripts" -Force

  .EXAMPLE
  # Using connection parameters (legacy mode)
  DatabaseProvisioning -DatabaseName BuildSets -Environment Development

  #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialsKey',
    Justification = 'CredentialsKey is a vault lookup key name, not a credential')]
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ConnectionParts')]
  param(
    # region Database connection parameters
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
    [string]$DatabaseName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$Environment,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [Alias('HostName')]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [Alias('InstanceName')]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [int]$Port,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParts')]
    [Parameter(Mandatory = $false, ParameterSetName = 'DBConnectionStringSecretName')]
    [switch]$IntegratedSecurity,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$CredentialsKey,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$ApplicationName,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParts')]
    [switch]$UseTrustedConnection,

    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlConnection')]
    [Microsoft.Data.SqlClient.SqlConnection]$SqlConnection,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'DBConnectionStringSecretName')]
    [Alias('DBConnectionStringSecret', 'SecretName', 'BitwardenSecretName', 'BitwardenSecret')]
    [string]$DBConnectionStringSecretName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [Alias('DBConnectionStringMasterSecret', 'MasterSecretName', 'DBMasterConnectionStringSecretName')]
    [string]$DBConnectionStringMasterSecretName,

    [Parameter(Mandatory = $false)]
    [hashtable]$Settings,
    # endregion Database connection parameters

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$DatabasePath,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$ProvisioningScriptsPath,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [bool]$GrantDatabaseOwner = $true,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [bool]$GrantBulkAdmin = $true,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [bool]$ProvisionForFlyway = $true,

    [switch]$Force
  )

  begin {
    $fn = 'DatbaseProvisioning'
    $mn = 'ATAP.Utilities.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn (ParameterSet: $($PSCmdlet.ParameterSetName))"

    # Load required helper functions
    try {
      $repositoryRoot = Get-RepositoryRoot
      if (-not (Get-Command -Name 'Resolve-DatabaseSqlConnection' -CommandType Function -ErrorAction SilentlyContinue)) {
        . (Join-Path $repositoryRoot 'src\ATAP.Utilities.DatabaseManagement.Powershell\public\Resolve-DatabaseSqlConnection.ps1')
      }
      if (-not (Get-Command -Name 'Invoke-DatabaseSqlNonQuery' -CommandType Function -ErrorAction SilentlyContinue)) {
        . (Join-Path $repositoryRoot 'src\ATAP.Utilities.DatabaseManagement.Powershell\private\DatabaseSqlCommand.Helpers.ps1')
      }
    } catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    function ConvertTo-DatabaseProvisioningSqlText {
      param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptText,

        [Parameter(Mandatory = $true)]
        [hashtable]$Variables
      )

      $expandedText = $ScriptText
      foreach ($key in $Variables.Keys) {
        $expandedText = $expandedText.Replace('$(' + $key + ')', [string]$Variables[$key])
      }

      return $expandedText
    }

    function Split-DatabaseProvisioningSqlBatch {
      param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptText
      )

      [regex]::Split($ScriptText, '(?im)^\s*GO\s*(?:--.*)?$') |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }

    function Format-DatabaseProvisioningSqlIdentifier {
      param(
        [Parameter(Mandatory = $true)]
        [string]$Identifier
      )

      '[' + ($Identifier -replace ']', ']]') + ']'
    }

    function Invoke-DatabaseProvisioningSqlFile {
      param(
        [Parameter(Mandatory = $true)]
        [object]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$TargetDatabase,

        [Parameter(Mandatory = $true)]
        [hashtable]$Variables
      )

      $scriptText = Get-Content -LiteralPath $Path -Raw
      $expandedText = ConvertTo-DatabaseProvisioningSqlText -ScriptText $scriptText -Variables $Variables
      $databasePrefix = if ([string]::IsNullOrWhiteSpace($TargetDatabase) -or $TargetDatabase -eq 'master') {
        ''
      }
      else {
        'USE ' + (Format-DatabaseProvisioningSqlIdentifier -Identifier $TargetDatabase) + ';' + [Environment]::NewLine
      }

      foreach ($batch in (Split-DatabaseProvisioningSqlBatch -ScriptText $expandedText)) {
        [void](Invoke-DatabaseSqlNonQuery `
            -SqlConnection $Connection `
            -CommandText ($databasePrefix + $batch) `
            -CommandTimeout 0)
      }
    }

    # Validate the parameters that do not depend on the database connection first, so that we can fail fast if there are issues with them

    $databasesCollection = if ($Settings) {
      $Settings
    }
    elseif ($global:settings -and $global:configRootKeys -and $global:configRootKeys['DatabasesCollectionConfigRootKey']) {
      $global:settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']]
    }
    elseif ($global:settings -is [System.Collections.IDictionary] -and $global:settings.Contains('DatabasesCollection')) {
      $global:settings['DatabasesCollection']
    }
    elseif ($global:settings -and $global:settings.PSObject.Properties['DatabasesCollection']) {
      $global:settings.DatabasesCollection
    }
    else {
      $null
    }

    $Environment = Get-PVal -ParameterName 'Environment' -originalPSBoundParameters $PSBoundParameters -DefaultValue $Environment -ValidValues @('Production', 'QA', 'Integration', 'Development', 'Experimental') -AllowMissing
    $DBConnectionStringSecretName = Get-PVal -ParameterName 'DBConnectionStringSecretName' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.DBConnectionStringSecretName" -Settings $databasesCollection -DefaultValue $DBConnectionStringSecretName -AllowMissing
    $DBConnectionStringMasterSecretName = Get-PVal -ParameterName 'DBConnectionStringMasterSecretName' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.DBConnectionStringMasterSecretName" -Settings $databasesCollection -DefaultValue $DBConnectionStringMasterSecretName -AllowMissing
    if ([string]::IsNullOrWhiteSpace($DBConnectionStringMasterSecretName)) {
      $DBConnectionStringMasterSecretName = $DBConnectionStringSecretName
    }
    $ProvisioningScriptsPath = Get-PVal -ParameterName 'ProvisioningScriptsPath' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.ProvisioningScriptsPath" -Settings $databasesCollection -DefaultValue $ProvisioningScriptsPath -AllowMissing
    $DatabasePath = Get-PVal -ParameterName 'DatabasePath' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.DatabasePath" -Settings $databasesCollection -DefaultValue $DatabasePath -AllowMissing

    if ([string]::IsNullOrWhiteSpace($ProvisioningScriptsPath)) {
      $ProvisioningScriptsPath = Join-Path $repositoryRoot 'src\ATAP.Utilities.DatabaseManagement\SharedSQL'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "ProvisioningScriptsPath was empty; defaulting to '$ProvisioningScriptsPath'"
    }

    if (-not [string]::IsNullOrWhiteSpace($DatabasePath)) {
      $DatabasePath = [System.IO.Path]::GetFullPath($DatabasePath)
    } else {
      $databaseRootPath = 'C:\LocalDBs'
      $DatabasePath = [System.IO.Path]::GetFullPath((Join-Path $databaseRootPath $DatabaseName))
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "DatabasePath was empty; defaulting to '$DatabasePath'"
    }

    $requiredProvisioningScripts = @(
      'DropAndCreateDatabase.sql',
      'CreateLoginAndUser.sql',
      'AddFlywaySchemaHistoryTable.sql'
    )
    $missingScripts = @($requiredProvisioningScripts | Where-Object {
        -not (Test-Path (Join-Path $ProvisioningScriptsPath $_))
      })
    if ($missingScripts.Count -gt 0) {
      $fallbackProvisioningScriptsPath = Join-Path $repositoryRoot 'src\ATAP.Utilities.DatabaseManagement\SharedSQL'
      if ($fallbackProvisioningScriptsPath -ne $ProvisioningScriptsPath) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "ProvisioningScriptsPath '$ProvisioningScriptsPath' is missing required scripts ($($missingScripts -join ', ')). Falling back to '$fallbackProvisioningScriptsPath'."
        $ProvisioningScriptsPath = $fallbackProvisioningScriptsPath
      }
    }
    # Check and populate optional parameter
    $GrantDatabaseOwner = Get-PVal -ParameterName 'GrantDatabaseOwner' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.GrantDatabaseOwner" -Settings $databasesCollection -DefaultValue $GrantDatabaseOwner -AsType ([bool]) -AllowMissing
    $GrantBulkAdmin = Get-PVal -ParameterName 'GrantBulkAdmin' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.GrantBulkAdmin" -Settings $databasesCollection -DefaultValue $GrantBulkAdmin -AsType ([bool]) -AllowMissing
    $ProvisionForFlyway = Get-PVal -ParameterName 'ProvisionForFlyway' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.ProvisionForFlyway" -Settings $databasesCollection -DefaultValue $ProvisionForFlyway -AsType ([bool]) -AllowMissing


    $errors = [System.Collections.Generic.List[string]]::new()
    $scriptsRun = [System.Collections.Generic.List[string]]::new()
    $resolverBoundParameters = @{}
    foreach ($key in $PSBoundParameters.Keys) {
      $resolverBoundParameters[$key] = $PSBoundParameters[$key]
    }
    $resolverBoundParameters['DatabaseName'] = 'master'

    $resolution = Resolve-DatabaseSqlConnection `
      -OriginalPSBoundParameters $resolverBoundParameters `
      -SqlConnection $SqlConnection `
      -DBConnectionStringSecretName $DBConnectionStringSecretName `
      -DBConnectionStringMasterSecretName $DBConnectionStringMasterSecretName `
      -DatabaseHost $DatabaseHost `
      -InstanceName $SqlInstance `
      -DatabaseName 'master' `
      -ConnectionMethod $ConnectionMethod `
      -CredentialsKey $CredentialsKey `
      -ApplicationName $ApplicationName `
      -UseTrustedConnection:$UseTrustedConnection `
      -IntegratedSecurity:$IntegratedSecurity `
      -Settings $databasesCollection `
      -DatabaseHostDottedPath "$databaseName.$Environment.DatabaseHost" `
      -DBConnectionStringSecretNameDottedPath "$databaseName.$Environment.DBConnectionStringSecretName" `
      -DBConnectionStringMasterSecretNameDottedPath "$databaseName.$Environment.DBConnectionStringMasterSecretName" `
      -InstanceNameDottedPath "$databaseName.$Environment.SqlInstance" `
      -ConnectionMethodDottedPath "$databaseName.$Environment.ConnectionMethod" `
      -CredentialsKeyDottedPath "$databaseName.$Environment.CredentialsKey" `
      -ApplicationNameDottedPath "$databaseName.$Environment.ApplicationName"

    $openSQLConnection = $resolution.Connection
    $isCallerOwnedConnection = [bool]$resolution.IsCallerOwned

    $connectionStringBuilder = [Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new($openSQLConnection.ConnectionString)
    $serverForConnect = $openSQLConnection.DataSource
    $useIntegratedSecurity = [bool]($connectionStringBuilder.IntegratedSecurity -or $IntegratedSecurity -or $UseTrustedConnection)
    $usingExistingConnection = $PSCmdlet.ParameterSetName -eq 'SqlConnection'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Using resolved SQL connection for server: $serverForConnect"

    # Initialize results tracking
    $result = [ordered]@{
      DatabaseName            = $DatabaseName
      Environment             = $Environment
      DatabasePath            = $DatabasePath
      SqlInstance             = $serverForConnect
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

    if ([string]::IsNullOrWhiteSpace($ProvisioningScriptsPath)) {
      $msg = 'ProvisioningScriptsPath is empty after normalization; cannot locate SQL provisioning scripts.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    foreach ($entry in $plannedScripts) {
      $full = Join-Path -Path $ProvisioningScriptsPath -ChildPath $entry.Name
      if (-not (Test-Path $full)) {
        $msg = "Planned script not found: $full"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        $errors.Add($msg) | Out-Null
      } else {
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
  SELECT CAST(0 AS int) AS ExistsFlag;
ELSE
  SELECT CAST(1 AS int) AS ExistsFlag;
"@

      $dbExists = [bool](Invoke-DatabaseSqlScalar `
          -SqlConnection $openSQLConnection `
          -CommandText $existsQuery `
          -CommandTimeout 30)

      if ($dbExists) {
        if (-not $Force) {
          $errorMessage = "Database '$DatabaseName' already exists on '$serverForConnect'. Use -Force to drop and recreate."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        } else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Database '$DatabaseName' already exists on '$serverForConnect'. It will be dropped and recreated because -Force is set." -Tag 'Validation', 'Warning'
        }
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Database '$DatabaseName' does not exist on '$serverForConnect'. Proceeding with creation." -Tag 'Validation', 'Info'
      }
    } catch {
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

        [void](Invoke-DatabaseSqlNonQuery `
            -SqlConnection $openSQLConnection `
            -CommandText $dropQuery `
            -CommandTimeout 0)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Successfully dropped existing database '$DatabaseName' on '$serverForConnect'." -Tag 'Validation', 'Warning'
      } catch {
        $errorMessage = "Failed dropping existing database '$DatabaseName' on '$serverForConnect': $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
        $errors.Add($errorMessage) | Out-Null
        throw
      }
    }

    # Ensure a stale database file folder never reaches DropAndCreateDatabase.sql.
    # SQL Server xp_create_subdir reports error 183 when the folder already exists.
    if (Test-Path -LiteralPath $DatabasePath -PathType Container) {
      if (-not $Force) {
        $errorMessage = "Database folder '$DatabasePath' already exists. Use -Force to remove it before provisioning."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
        $errors.Add($errorMessage) | Out-Null
        throw $errorMessage
      }

      try {
        Remove-Item -LiteralPath $DatabasePath -Recurse -Force -ErrorAction Stop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Deleted existing database folder '$DatabasePath' because -Force is set." -Tag 'Validation', 'Warning'
      } catch {
        $errorMessage = "Failed to delete existing database folder '$DatabasePath': $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
        $errors.Add($errorMessage) | Out-Null
        throw
      }
    }
    elseif (Test-Path -LiteralPath $DatabasePath -PathType Leaf) {
      $errorMessage = "Database path '$DatabasePath' exists as a file, not a folder."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
      $errors.Add($errorMessage) | Out-Null
      throw $errorMessage
    }

    try {
      if (-not (Test-Path -LiteralPath $DatabasePath -PathType Container)) {
        New-Item -ItemType Directory -Path $DatabasePath -Force -ErrorAction Stop | Out-Null
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Created database folder '$DatabasePath'."
      }
    } catch {
      $errorMessage = "Failed to create database folder '$DatabasePath': $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
      $errors.Add($errorMessage) | Out-Null
      throw
    }

    # Ensure any leftover files are deleted. The folder cleanup above should
    # normally remove these; keep the file-level cleanup as a precise fallback.
    $mdf = Join-Path -Path $DatabasePath -ChildPath ($DatabaseName + '.mdf')
    $ldf = Join-Path -Path $DatabasePath -ChildPath ($DatabaseName + '_log.ldf')
    $filesToCheck = @($mdf, $ldf)
    foreach ($file in $filesToCheck) {
      if (Test-Path $file) {
        try {
          Remove-Item -Path $file -Force -ErrorAction Stop
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Deleted leftover database file '$file'." -Tag 'Validation', 'Warning'
        } catch {
          $errorMessage = "Failed to delete leftover database file '$file': $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          $errors.Add($errorMessage) | Out-Null
          throw
        }
      }
    }


    # Stash script metadata for PROCESS block
    $PlannedScriptsMetadata = $plannedScripts
    $dbExists = $dbExists
    $ServerForConnect = $serverForConnect
    $ResolvedConnectionStringBuilder = $connectionStringBuilder
  }

  process {

    foreach ($meta in $PlannedScriptsMetadata) {
      $scriptPath = $meta.FullPath
      $scriptLabel = $meta.Name
      $targetDb = $meta.RunDb

      if ($PSCmdlet.ShouldProcess("$($ServerForConnect) / $targetDb", "Execute $scriptLabel")) {
        try {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting script $scriptLabel"

          try {
            # These variable names must match those used in the SQL script:
            # $(loginPassword), $(DatabaseName), $(DatabasePath), $(LoginName)

            # Determine LoginName and loginPassword from the validated connection string.
            $loginName = ''
            $loginPassword = ''
            if (-not $ResolvedConnectionStringBuilder.IntegratedSecurity) {
              $loginName = $ResolvedConnectionStringBuilder.UserID
              $loginPassword = $ResolvedConnectionStringBuilder.Password
            }

            $sqlVariables = @{
              DatabaseName       = $DatabaseName
              DatabasePath       = $DatabasePath
              LoginName          = $loginName
              loginPassword      = $loginPassword
              DBExists           = [int]$dbExists
              GrantDatabaseOwner = [int][bool]$GrantDatabaseOwner
              GrantBulkAdmin     = [int][bool]$GrantBulkAdmin
            }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Executing provisioning SQL $scriptLabel (DB=$targetDb)"
            Invoke-DatabaseProvisioningSqlFile `
              -Connection $openSQLConnection `
              -Path $scriptPath `
              -TargetDatabase $targetDb `
              -Variables $sqlVariables
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully executed provisioning SQL $scriptLabel"
            $scriptsRun.Add($scriptPath) | Out-Null
          } catch {
            $errorMessage = "Failure executing $scriptLabel. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            if ($_.Exception.StackTrace) {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "StackTrace: $($_.Exception.StackTrace)"
            }
            $errors.Add($errorMessage) | Out-Null
            throw
          } finally {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished attempt for $scriptLabel"
          }
        } catch {
          continue
        }
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Skipped script $scriptLabel due to ShouldProcess decision"
      }
    }
  }

  end {
    $result.ScriptsExecuted = $scriptsRun.ToArray()
    $result.Errors = $errors.ToArray()
    $result.Success = ($errors.Count -eq 0)
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message ('Provisioning {0}' -f ($(if ($result.Success) { 'succeeded' } else { 'failed' })))
    if ($errors.Count -gt 0) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message ("Errors:`n {0}" -f ($errors -join [Environment]::NewLine))
    }
    if (-not $isCallerOwnedConnection -and $null -ne $openSQLConnection) {
      try { $openSQLConnection.Close() } catch { $null = $_ }
      try { $openSQLConnection.Dispose() } catch { $null = $_ }
      $openSQLConnection = $null
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving script DatabaseProvisioning'
    [PSCustomObject]$result
  }
}
