<#
.SYNOPSIS
Runs Flyway migrations for the Database folder structure.

.DESCRIPTION
This cmdlet applies Flyway migrations from the Database\Flyway\SQL folder that have not yet been applied
to the ATAPUtilities database. It uses the Invoke-Flyway function to execute the migrations and supports
both Windows Integrated Security and SQL Server authentication.

The cmdlet will:
1. Validate the migration folder path exists
2. Configure database connection parameters
3. Execute pending Flyway migrations
4. Report on the migration status

.PARAMETER DatabaseName
The name of the database to migrate. Default: 'ATAPUtilities'.

.PARAMETER DatabaseHost
The SQL Server host to connect to. Default: 'localhost'.

.PARAMETER SqlInstance
Optional SQL Server named instance.

.PARAMETER Environment
The target environment: 'Development', 'Testing', 'Production', or 'Experimental'.
Default: 'Experimental'.

.PARAMETER ConnectionMethod
Protocol to use for connection: tcp, np (named pipes), lpc (shared memory), or default.
Default: 'tcp'.

.PARAMETER IntegratedSecurity
Use Windows Integrated Authentication. Default: $true.

.PARAMETER CredentialsKey
Key to retrieve credentials from vault. Use this instead of IntegratedSecurity for SQL Server authentication.

.PARAMETER FlywayCommand
The Flyway command to run: validate, migrate, check, repair, info, baseline, clean, or undo.
Default: 'migrate'.

.PARAMETER MigrationsPath
Path to the folder containing SQL migration files.
Default: 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-branch63\Database\Flyway\SQL'.

.PARAMETER FlywayBasePath
Base path for Flyway configuration.
Default: 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-branch63\Database\Flyway'.

.PARAMETER FlywayConfigPath
Path to the Flyway configuration file.
Default: 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-branch63\Database\Flyway\flyway.toml'.

.PARAMETER WhatIf
Shows what would happen if the cmdlet runs. The cmdlet is not run.

.PARAMETER Confirm
Prompts you for confirmation before running the cmdlet.

.OUTPUTS
PSCustomObject containing the migration execution results and status.

.EXAMPLE
Invoke-DatabaseFlywayMigrations

Runs pending migrations using default settings (localhost, Integrated Security, migrate command).

.EXAMPLE
Invoke-DatabaseFlywayMigrations -FlywayCommand 'info'

Shows information about pending migrations without applying them.

.EXAMPLE
Invoke-DatabaseFlywayMigrations -DatabaseHost 'SQLSERVER01' -CredentialsKey 'ATAPUtilities-Credential'

Runs migrations against a remote SQL Server using credentials from vault.

.EXAMPLE
Invoke-DatabaseFlywayMigrations -FlywayCommand 'validate' -Verbose

Validates the migration scripts without applying them, with verbose output.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Requires Invoke-Flyway function from ATAP.Utilities.DatabaseManagement.Powershell module.
Requires dbatools PowerShell module for database operations.

.LINK
https://flywaydb.org/documentation/usage/commandline/

#>
function Invoke-DatabaseFlywayMigrations {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param (
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$DatabaseName = 'ATAPUtilities',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$DatabaseHost = 'localhost',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet('Development', 'Testing', 'Production', 'Experimental')]
    [string]$Environment = 'Experimental',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet('tcp', 'np', 'lpc', 'default')]
    [string]$ConnectionMethod = 'tcp',

    [Parameter(Mandatory = $false)]
    [switch]$IntegratedSecurity = $true,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$CredentialsKey,

    [Parameter(Mandatory = $false)]
    [ValidateSet('validate', 'migrate', 'check', 'repair', 'info', 'baseline', 'clean', 'undo')]
    [string]$FlywayCommand = 'migrate',

    [Parameter(Mandatory = $false)]
    [string]$MigrationsPath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-branch63\Database\Flyway\SQL',

    [Parameter(Mandatory = $false)]
    [string]$FlywayBasePath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-branch63\Database\Flyway',

    [Parameter(Mandatory = $false)]
    [string]$FlywayConfigPath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-branch63\Database\Flyway\flyway.toml'
  )

  BEGIN {
    # Snippet: Set function and module names for logging
    $fn = 'Invoke-DatabaseFlywayMigrations'
    $mn = 'ATAP.Utilities.Database.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # Load required helper functions
    # Snippet: Try-Catch-Finally for loading dependencies
    try {
      # Import dbatools module for database operations
      if (-not (Get-Module -Name dbatools -ListAvailable)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "dbatools module not found. Installing..."
        Install-Module -Name dbatools -Scope CurrentUser -Force -AllowClobber
      }
      Import-Module dbatools -ErrorAction Stop

      # Load Invoke-Flyway function
      if (-not (Get-Command -Name 'Invoke-Flyway' -CommandType Function -ErrorAction SilentlyContinue)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Loading Invoke-Flyway function"
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Invoke-Flyway.ps1'
      }

      # Load Get-ParameterValueFromNeoConfigurationRoot if available
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        $paramHelperPath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
        if (Test-Path $paramHelperPath) {
          . $paramHelperPath
        }
      }
    }
    catch {
      # Snippet: ThrowMessage
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    # Validate migrations path exists
    if (-not (Test-Path -Path $MigrationsPath -PathType Container)) {
      $errorMessage = "Migrations path not found: $MigrationsPath"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    # Validate Flyway base path exists
    if (-not (Test-Path -Path $FlywayBasePath -PathType Container)) {
      $errorMessage = "Flyway base path not found: $FlywayBasePath"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    # Validate Flyway config file exists (optional - Flyway can run without it)
    if ($FlywayConfigPath -and -not (Test-Path -Path $FlywayConfigPath -PathType Leaf)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Flyway config file not found: $FlywayConfigPath. Continuing without it."
      $FlywayConfigPath = $null
    }

    # Configure dbatools SSL/encryption settings
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Configuring dbatools to trust server certificates"
    Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -PassThru | Register-DbatoolsConfig
    Set-DbatoolsConfig -FullName sql.connection.encrypt -Value $false -PassThru | Register-DbatoolsConfig

    # Log configuration
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "=== Flyway Migration Configuration ==="
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Database: $DatabaseName"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Database host: $DatabaseHost"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Environment: $Environment"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Connection method: $ConnectionMethod"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Flyway command: $FlywayCommand"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Migrations path: $MigrationsPath"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Flyway base path: $FlywayBasePath"
    if ($FlywayConfigPath) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Flyway config path: $FlywayConfigPath"
    }

    # Check for pending migrations (if command is migrate)
    if ($FlywayCommand -eq 'migrate') {
      $sqlFiles = Get-ChildItem -Path $MigrationsPath -Filter "*.sql" -File | Where-Object { $_.Name -match '^V\d+' }
      if ($sqlFiles.Count -eq 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "No migration files found in $MigrationsPath"
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Found $($sqlFiles.Count) migration file(s) in folder"
      }
    }
  }

  PROCESS {
    try {
      # Build parameters for Invoke-Flyway
      $flywayParams = @{
        DatabaseName            = $DatabaseName
        DatabaseHost            = $DatabaseHost
        Environment             = $Environment
        ConnectionMethod        = $ConnectionMethod
        FlywayCommand           = $FlywayCommand
        flywaySqlMigrationsPath = $MigrationsPath
        FlywayBasePath          = $FlywayBasePath
      }

      # Add optional parameters if provided
      if ($SqlInstance) {
        $flywayParams['SqlInstance'] = $SqlInstance
      }

      if ($FlywayConfigPath) {
        $flywayParams['FlywayTomlPath'] = $FlywayConfigPath
      }

      # Handle authentication
      if ($CredentialsKey) {
        $flywayParams['CredentialsKey'] = $CredentialsKey
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using credentials from vault: $CredentialsKey"
      }
      elseif ($IntegratedSecurity) {
        $flywayParams['IntegratedSecurity'] = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using Windows Integrated Security"
      }

      # ShouldProcess check
      $target = "$DatabaseHost\$DatabaseName"
      $action = "Run Flyway $FlywayCommand command"

      if ($PSCmdlet.ShouldProcess($target, $action)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Executing Flyway $FlywayCommand..."

        # Snippet: Log before Invoke-Command style call
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling Invoke-Flyway with command: $FlywayCommand" -Tag 'InvokeFlywayCall'

        # Execute Flyway migrations
        $result = Invoke-Flyway @flywayParams

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from Invoke-Flyway" -Tag 'InvokeFlywayCall'

        # Check result
        if ($result.Success) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Flyway $FlywayCommand completed successfully"
        }
        else {
          $errorMessage = "Flyway $FlywayCommand failed. Errors: $($result.Errors -join '; ')"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw $errorMessage
        }

        # Return result
        return $result
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "WhatIf: Would execute Flyway $FlywayCommand against $target"
        return [PSCustomObject]@{
          Success = $true
          WhatIf  = $true
          Target  = $target
          Command = $FlywayCommand
          Message = "WhatIf mode - no changes made"
        }
      }
    }
    catch {
      # Snippet: ThrowMessage
      $errorMessage = "Flyway migration execution failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
      throw
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}

# Export the function
Export-ModuleMember -Function Invoke-DatabaseFlywayMigrations
