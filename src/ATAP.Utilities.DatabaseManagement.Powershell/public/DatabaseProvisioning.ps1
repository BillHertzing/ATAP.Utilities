function DatabaseProvisioning {

  <#
  .SYNOPSIS
  Creates (or recreates) the BuildSets database and associated login/user objects. The script must be run by a Windows
  user who has both administrative rights on the target SQL server\instance, and also write access to the DatabasePath.
  Once the database has been created, the script proceeds to optionally create either a windows integrated login or
  a SQL login, and database user, and optionally grants the login\user DBO access to the database and optionally BulkAdmin server role.
  Once this is done, the script populates the database with tables and structures needed by Flyway to manage database migrations.

  .DESCRIPTION
  Runs one or more SQL scripts (in a defined order) against a target SQL Server instance to provision
  a database. Each script is executed with structured logging and robust error handling.

  .PARAMETER DatabaseName
  Name of the database to create or update.

  .PARAMETER Environment
  Name of the environment, which influences the DatabaseHost, SqlInstance amd the DatabasePath. This is usually supplied by an environment variable or from the global settings. but can be overridden here.

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

  .PARAMETER ScriptDirectory
  Directory that contains the provisioning SQL scripts and contains the scripts executed by this function.
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.
  Defaults to the location where ATAP.Utilities.DatabaseManagement places its 'SharedSQL' subdirectory,

  .PARAMETER UseNamedLogin
  Boolean. if false, the database is created with integrated security, using the current Windows's user that is running this scrip.
    the current Windows's user that is running this script is granted datareader / datawriter access, and DBO  and BulkAdmin per the appropriate parameter.
  If true and LoginName is nonblank, then if the LoginName follows a Window's user's name pattern "contains '\' or \@\",
  That window's login is granted datareader / datawriter access, and DBO and BulkAdmin per the appropriate parameter.
  If the LoginName does not follow a Window's user's name pattern a SQL login is created or ensured as part of the provisioning.
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .PARAMETER LoginName
  The Windows or SQL Login name to create or ensure if UseNamedLogin is true.  If UseNamedLogin is false, this parameter is ignored.
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .PARAMETER LoginPasswordVaultKey
  The key used to retrieve the password for the login if UseNamedLogin is true and the LoginName is not a Windows' username pattern
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .Parameter GrantDatabaseOwner
  If true, grants the login DBO access to the database
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .PARAMETER GrantBulkAdmin
  If true, grants the login BulkAdmin server role
  This is usually supplied by an environment variable or from the global settings. but can be overridden here.

  .PARAMETER Force
  If supplied, allow dropping existing database and login, else this fails if the database already exists

  .EXAMPLE
   DatabaseProvisioning -DatabaseName BuildSets -Environment Development

  .EXAMPLE
   DatabaseProvisioning -DatabaseName BuildSets -Environment Production -UseNamedLogin -LoginName 'utat022\jenkinsAdmin'

  .EXAMPLE
  $Env:BuildSetsloginPassword='StrongP@ssw0rd!'; DatabaseProvisioning -DatabaseName BuildSets -SqlInstance '.\Testing' -LoginName 'LocalTestingBuildSetsOwner'

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines
  #>

  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet('Production', 'Testing', 'Development', 'Experimental')]
    [string]$Environment,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet('tcp', 'np', 'lpc')]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet('Production', 'Testing', 'Development', 'SQLEXPRESS')]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [bool]$UseNamedLogin = $false,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$LoginName ,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    #[Securestring]$LoginPasswordVaultKey,
    [string]$LoginPasswordVaultKey,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$DatabasePath,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$ScriptDirectory,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [bool]$GrantDatabaseOwner = $false,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [bool]$GrantBulkAdmin = $true,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [bool]$ProvisionForFlyway = $true,

    [switch]$Force
  )

  BEGIN {
    Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Debug -Message "Entering script DatabaseProvisioning"
    $errors = [System.Collections.Generic.List[string]]::new()
    $scriptsRun = [System.Collections.Generic.List[string]]::new()

    # ToDo maybe: Are there naming conventions for the database file names, if so enforce them here

    function Get-Env([string]$key) {
      [Environment]::GetEnvironmentVariable($key, 'Process')
    }

    function Test-Blank([string]$s) { [string]::IsNullOrWhiteSpace($s) }

    function Resolve-FromSettings([string]$db, [string]$env, [string]$leafKey) {
      if ($settings.ContainsKey($global:configRootKeys['DatabasesCollectionConfigRootKey'])) {
        $root = $settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']]
        if ($root.ContainsKey($db) -and $root[$db].ContainsKey($env) -and $root[$db][$env].ContainsKey($leafKey)) {
          $val = $root[$db][$env][$leafKey]
          if (-not (Test-Blank $val)) { return $val }
        }
      }
      return $null
    }

    function Is-WindowsLoginName([string]$name) {
      # "domain\user" OR "user@domain"
      return ($name -match '\\') -or ($name -match '@')
    }

    # --- Environment: param -> env -> $global:settings['Environment'] -> throw
    if (Test-Blank $Environment) {
      # Try environment variable first (e.g., via a configured key like 'EnvironmentConfigRootKey')
      $envVal = Get-Env $global:configRootKeys['EnvironmentConfigRootKey']
      if (Test-Blank $envVal) {
        # Then try global settings at the top level: $global:settings['Environment']
        $setVal = $null
        if ($null -ne $global:settings -and $global:settings.ContainsKey('Environment')) {
          $setVal = $global:settings['Environment']
        }

        if (Test-Blank $setVal) {
          $errorMessage = "Environment not found via parameter, env '$($global:configRootKeys['EnvironmentConfigRootKey'])', or global settings['Environment']."
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
        else {
          $Environment = $setVal
        }
      }
      else {
        $Environment = $envVal
      }
    }
    # Normalize to one of the allowed values (case-insensitive) and hard-validate
    $allowedEnvs = 'Production', 'Testing', 'Development', 'Experimental'
    $match = $allowedEnvs | Where-Object { $_.ToLowerInvariant() -eq $Environment.ToString().ToLowerInvariant() }

    if ($null -ne $match) {
      # Snap to canonical casing from $allowedEnvs
      $Environment = $match
    }
    else {
      $errorMessage = "Environment '$Environment' must be one of: $($allowedEnvs -join ', ')."
      Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
      throw $errorMessage
    }

    # --- DatabaseHost: param -> env -> settings -> throw
    if (Test-Blank $DatabaseHost) {
      $dbh = 'Database' + $DatabaseName + $Environment + 'DatabaseHostConfigRootKey'
      $envVal = Get-Env $global:configRootKeys[$dbh]
      if (Test-Blank $envVal) {
        $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey 'DatabaseHost'
        if (Test-Blank $setVal) {
          $errorMessage = "DatabaseHost not found via parameter, env '$($global:configRootKeys[$dbh])', or settings for '$DatabaseName'/'$Environment'."
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
        else { $DatabaseHost = $setVal }
      }
      else { $DatabaseHost = $envVal }
    }

    # --- ConnectionMethod: param -> env -> settings -> throw
    if (Test-Blank $ConnectionMethod) {
      $envVal = Get-Env $global:configRootKeys['ConnectionMethodConfigRootKey']
      if (Test-Blank $envVal) {
        $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey 'ConnectionMethod'
        if (Test-Blank $setVal) {
          $errorMessage = "ConnectionMethod not found via parameter, env '$($global:configRootKeys['ConnectionMethodConfigRootKey'])', or settings for '$DatabaseName'/'$Environment'."
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
        else { $ConnectionMethod = $setVal }
      }
      else { $ConnectionMethod = $envVal }
    }

    # Normalize and hard-validate (defensive; complements [ValidateSet()])
    $ConnectionMethod = $ConnectionMethod.ToString().ToLowerInvariant()
    if ('tcp', 'np', 'lpc' -notcontains $ConnectionMethod) {
      $errorMessage = "ConnectionMethod '$ConnectionMethod' must be one of: tcp, np, lpc."
      Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
      throw $errorMessage
    }

    # --- SqlInstance: param -> env -> settings -> throw
    if (Test-Blank $SqlInstance) {
      $envVal = Get-Env $global:configRootKeys['SqlInstanceConfigRootKey']
      if (Test-Blank $envVal) {
        $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey 'SqlInstance'
        if (Test-Blank $setVal) {
          $errorMessage = "SqlInstance not found via parameter, env '$($global:configRootKeys['SqlInstanceConfigRootKey'])', or settings for '$DatabaseName'/'$Environment'."
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
        else { $SqlInstance = $setVal }
      }
      else { $SqlInstance = $envVal }
    }

    if ($UseNamedLogin) {
      # LoginName: param -> env -> settings -> throw
      if (Test-Blank $LoginName) {
        $envVal = Get-Env $global:configRootKeys['LoginNameConfigRootKey']
        if (Test-Blank $envVal) {
          $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey 'LoginName'
          if (Test-Blank $setVal) {
            $errorMessage = "UseNamedLogin is true but LoginName is not provided and was not found via env '$($global:configRootKeys['LoginNameConfigRootKey'])' or settings."
            Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
            throw $errorMessage
          }
          else { $LoginName = $setVal }
        }
        else { $LoginName = $envVal }
      }

      # If SQL login, require LoginPasswordVaultKey; if Windows login, it's optional/ignored
      if (-not (Is-WindowsLoginName $LoginName)) {
        if (Test-Blank $LoginPasswordVaultKey) {
          $envVal = Get-Env $global:configRootKeys['LoginPasswordVaultKeyConfigRootKey']
          if (Test-Blank $envVal) {
            $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey 'LoginPasswordVaultKey'
            if (Test-Blank $setVal) {
              $errorMessage = "UseNamedLogin is true and LoginName '$LoginName' appears to be a SQL login, but LoginPasswordVaultKey was not provided and was not found via env '$($global:configRootKeys['LoginPasswordVaultKeyConfigRootKey'])' or settings."
              Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
              throw $errorMessage
            }
            else { $LoginPasswordVaultKey = $setVal }
          }
          else { $LoginPasswordVaultKey = $envVal }
        }
      }
      else {
        Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Verbose -Message "LoginName '$LoginName' detected as Windows principal; LoginPasswordVaultKey not required."
      }

      # Lookup LoginPassword (temporary clear text lookup)
      # [SecureString]$loginPassword = $null
      [string]$loginPassword = $null
      if (-not $global:VaultData.ContainsKey($LoginPasswordVaultKey)) {
        $errorMessage = "LoginPasswordVaultKey '$LoginPasswordVaultKey' not found in vault."
        Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
        throw $errorMessage
      }
      else {
        if (-not (Test-Blank $global:VaultData[$LoginPasswordVaultKey])) {
          # [SecureString]$loginPassword = $global:VaultData[$LoginPasswordVaultKey]
          $loginPassword = $global:VaultData[$LoginPasswordVaultKey]
        }
        else {
          $errorMessage = "LoginPasswordVaultKey '$LoginPasswordVaultKey' has blank value in vault."
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
      }
    }
    else {
      # If $UseNamedLogin is false, then LoginName and LoginPasswordVaultKey should not be present
      $LoginName = $null
      $LoginPasswordVaultKey = $null
    }

    # --- DatabasePath: param -> env -> settings -> throw
    if (Test-Blank $DatabasePath) {
      $envVal = Get-Env $global:configRootKeys['DatabasePathConfigRootKey']
      if (Test-Blank $envVal) {
        $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey 'DatabasePath'
        if (Test-Blank $setVal) {
          $errorMessage = "DatabasePath not found via parameter, env '$($global:configRootKeys['DatabasePathConfigRootKey'])', or settings for '$DatabaseName'/'$Environment'."
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
        else { $DatabasePath = $setVal }
      }
      else { $DatabasePath = $envVal }
    }

    # --- ScriptDirectory: param -> env -> settings -> throw
    if (Test-Blank $ScriptDirectory) {
      $envVal = Get-Env $global:configRootKeys['ScriptDirectoryConfigRootKey']
      if (Test-Blank $envVal) {
        $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey 'ScriptDirectory'
        if (Test-Blank $setVal) {
          $errorMessage = "ScriptDirectory not found via parameter, env '$($global:configRootKeys['ScriptDirectoryConfigRootKey'])', or settings for '$DatabaseName'/'$Environment'."
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
        else { $ScriptDirectory = $setVal }
      }
      else { $ScriptDirectory = $envVal }
    }

    # --- GrantDatabaseOwner: only if not explicitly bound; env -> settings -> keep default ($false)
    if (-not $PSBoundParameters.ContainsKey('GrantDatabaseOwner')) {
      $envVal = Get-Env $global:configRootKeys['GrantDatabaseOwnerConfigRootKey']
      if (-not (Test-Blank $envVal)) {
        try {
          $GrantDatabaseOwner = [System.Convert]::ToBoolean($envVal)
        }
        catch {
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Warning -Message "Invalid boolean in env '$($global:configRootKeys['GrantDatabaseOwnerConfigRootKey'])': '$envVal'. Keeping default: $GrantDatabaseOwner" -Tag 'Validation', 'Warning'
        }
      }
      else {
        $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey $global:configRootKeys['GrantDatabaseOwnerConfigRootKey']
        if (-not (Test-Blank $setVal)) {
          try {
            $GrantDatabaseOwner = [bool]$setVal
          }
          catch {
            Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Warning -Message "Invalid boolean in settings for '$($global:configRootKeys['GrantDatabaseOwnerConfigRootKey'])': '$setVal'. Keeping default: $GrantDatabaseOwner" -Tag 'Validation', 'Warning'
          }
        }
      }
    }

    # --- GrantBulkAdmin: only if not explicitly bound; env -> settings -> keep default ($true)
    if (-not $PSBoundParameters.ContainsKey('GrantBulkAdmin')) {
      $envVal = Get-Env $global:configRootKeys['GrantBulkAdminConfigRootKey']
      if (-not (Test-Blank $envVal)) {
        try {
          $GrantBulkAdmin = [System.Convert]::ToBoolean($envVal)
        }
        catch {
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Warning -Message "Invalid boolean in env '$($global:configRootKeys['GrantBulkAdminConfigRootKey'])': '$envVal'. Keeping default: $GrantBulkAdmin" -Tag 'Validation', 'Warning'
        }
      }
      else {
        $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey $global:configRootKeys['GrantBulkAdminConfigRootKey']
        if (-not (Test-Blank $setVal)) {
          try {
            $GrantBulkAdmin = [bool]$setVal
          }
          catch {
            Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Warning -Message "Invalid boolean in settings for '$($global:configRootKeys['GrantBulkAdminConfigRootKey'])': '$setVal'. Keeping default: $GrantBulkAdmin" -Tag 'Validation', 'Warning'
          }
        }
      }
    }

    # --- ProvisionForFlyway: only if not explicitly bound; env -> settings -> keep default
    if (-not $PSBoundParameters.ContainsKey('ProvisionForFlyway')) {
      $envVal = Get-Env $global:configRootKeys['ProvisionForFlywayConfigRootKey']
      if (-not (Test-Blank $envVal)) {
        $ProvisionForFlyway = [System.Convert]::ToBoolean($envVal)
      }
      else {
        $setVal = Resolve-FromSettings -db $DatabaseName -env $Environment -leafKey $global:configRootKeys['ProvisionForFlywayConfigRootKey']
        if (-not (Test-Blank $setVal)) {
          $ProvisionForFlyway = [bool]$setVal
        }
      }
    }


    $result = [ordered]@{
      DatabaseName          = $DatabaseName
      Environment           = $Environment
      DatabasePath          = $DatabasePath
      SqlInstance           = $SqlInstance
      UseNamedLogin         = $UseNamedLogin
      LoginName             = $LoginName
      # LoginPasswordVaultKey = $LoginPasswordVaultKey # SecureString?
      LoginPasswordVaultKey = $LoginPasswordVaultKey
      GrantDatabaseOwner    = $GrantDatabaseOwner
      ScriptsPlanned        = @()
      ScriptsExecuted       = @()
      Success               = $false
      Errors                = @()
      Force                 = [bool]$Force
      TimestampUTC          = (Get-Date).ToUniversalTime()
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
      $full = Join-Path -Path $ScriptDirectory -ChildPath $entry.Name
      if (-not (Test-Path $full)) {
        $msg = "Planned script not found: $full"
        Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $msg
        $errors.Add($msg) | Out-Null
      }
      else {
        $entry.FullPath = $full
        $result.ScriptsPlanned += $full
      }
    }

    if ($errors.Count -gt 0) {
      Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message 'Aborting before execution due to missing scripts.'
      throw 'Provisioning aborted; missing scripts.'
    }

    # Create the server portion of the connection string for Invoke-Sqlcmd
    $serverForConnect = "${ConnectionMethod}:$DatabaseHost"
    if (-not (Test-Blank $SqlInstance)) {
      $serverForConnect += "\$SqlInstance"
    } # else default instance: no suffixes

    # Test the connection to the SQL instance and check if the database already exists
    $dbExists = $false
    try {
      Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Debug -Message ("Checking for existing database '{0}' on instance '{1}'" -f $DatabaseName, $serverForConnect)

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
          $errorMessage = "Database '$DatabaseName' already exists on instance '$SqlInstance'. Use -Force to drop and recreate."
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
        else {
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Warning -Message "Database '$DatabaseName' already exists on '$SqlInstance'. It will be dropped and recreated because -Force is set." -Tag 'Validation', 'Warning'
        }
      }
      else {
        Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Debug -Message "Database '$DatabaseName' does not exist on '$SqlInstance'. Proceeding with creation." -Tag 'Validation', 'Info'
      }
    }
    catch {
      $errorMessage = "Failed checking database existence on '$SqlInstance': $($_.Exception.Message)"
      Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
      $errors.Add($errorMessage) | Out-Null
      throw
    }

    # if $dbExists and $force, drop the database
    if ($dbExists -and $Force) {
      try {
        Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Warning -Message ("Dropping existing database '{0}' on instance '{1}'" -f $DatabaseName, $serverForConnect) -Tag 'Validation', 'Warning'

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
        Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Warning -Message "Successfully dropped existing database '$DatabaseName' on '$SqlInstance'." -Tag 'Validation', 'Warning'
      }
      catch {
        $errorMessage = "Failed dropping existing database '$DatabaseName' on '$SqlInstance': $($_.Exception.Message)"
        Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
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
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Warning -Message "Deleted leftover database file '$file'." -Tag 'Validation', 'Warning'
        }
        catch {
          $errorMessage = "Failed to delete leftover database file '$file': $($_.Exception.Message)"
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          $errors.Add($errorMessage) | Out-Null
          throw
        }
      }
    }


    # Stash script metadata in script scope for PROCESS
    $script:PlannedScriptsMetadata = $plannedScripts
    $script:loginPasswordValue = $loginPassword
    $script:dbExists = $dbExists
  }

  PROCESS {

    foreach ($meta in $script:PlannedScriptsMetadata) {
      $scriptPath = $meta.FullPath
      $scriptLabel = $meta.Name
      $targetDb = $meta.RunDb

      if ($PSCmdlet.ShouldProcess("$SqlInstance / $targetDb", "Execute $scriptLabel")) {
        try {
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Verbose -Message "Starting script $scriptLabel"

          try {
            # ToDo: revisit and fix when trusted SSL certificates for DB server access is available
            $invokeParams = @{
              ServerInstance         = $serverForConnect
              InputFile              = $scriptPath
              ErrorAction            = 'Stop'
              Encrypt                = 'Optional' # or 'Mandatory' or 'Strict'
              TrustServerCertificate = $true # use only when using no SSL
            }
            if ($targetDb -and $targetDb -ne 'master') {
              $invokeParams.Database = $targetDb
            }

            #if ($meta.NeedsVars) {
            # These variable names must match those used in the SQL script:
            # $(loginPassword), $(DatabaseName), $(DatabasePath), $(LoginName)
            $invokeParams.Variable = @{
              DatabaseName       = $DatabaseName
              DatabasePath       = $DatabasePath
              DBExists           = $script:dbExists
              UseNamedLogin      = $UseNamedLogin
              LoginName          = $LoginName
              loginPassword      = $script:loginPasswordValue
              GrantDatabaseOwner = $GrantDatabaseOwner
              GrantBulkAdmin     = $GrantBulkAdmin
            }
            #}

            Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Debug -Message "Calling Invoke-Sqlcmd $scriptLabel (DB=$targetDb)"
            Invoke-Sqlcmd @invokeParams
            Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Debug -Message "Successfully returned from Invoke-Sqlcmd $scriptLabel"
            $scriptsRun.Add($scriptPath) | Out-Null
          }
          catch {
            $errorMessage = "Failure executing $scriptLabel. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message $errorMessage
            if ($_.Exception.StackTrace) {
              Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Debug -Message "StackTrace: $($_.Exception.StackTrace)"
            }
            $errors.Add($errorMessage) | Out-Null
            throw
          }
          finally {
            Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Debug -Message "Finished attempt for $scriptLabel"
          }
        }
        catch {
          continue
        }
      }
      else {
        Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Important -Message "Skipped script $scriptLabel due to ShouldProcess decision"
      }
    }
  }

  END {
    $result.ScriptsExecuted = $scriptsRun.ToArray()
    $result.Errors = $errors.ToArray()
    $result.Success = ($errors.Count -eq 0)
    Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Important -Message ("Provisioning {0}" -f ($(if ($result.Success) { 'succeeded' } else { 'failed' })))
    if ($errors.Count -gt 0) {
      Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Error -Message ("Errors:`n {0}" -f ($errors -join [Environment]::NewLine))
    }
    Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' -Level Debug -Message 'Leaving script DatabaseProvisioning'
    [PSCustomObject]$result
  }
}
