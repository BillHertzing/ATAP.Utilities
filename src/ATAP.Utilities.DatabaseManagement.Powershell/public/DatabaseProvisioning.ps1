````powershell
// filepath: c:\Dropbox\whertzing\GitHub\ATAP.Utilities\Databases\BuildSets\DatabaseProvisioning.ps1
function DatabaseProvisioning {

  <#
  .SYNOPSIS
  Creates (or recreates) the BuildSets database and associated login/user objects.

  .DESCRIPTION
  Runs one or more SQL scripts (in a defined order) against a target SQL Server instance to provision
  the BuildSets database artifacts. Each script is executed with structured logging and robust error handling.

  .PARAMETER DatabaseName
  Name of the database to create or update.

  .PARAMETER SqlInstance
  SQL Server instance (local or remote) to target (e.g. '.\SQLEXPRESS').

  .PARAMETER ScriptDirectory
  Directory that contains the provisioning SQL scripts. Defaults to the directory of this script.

  .PARAMETER LoginName
  The SQL/Login name to create or ensure (passed to the CreateBuildSetsLoginAndUser.sql script via sqlcmd variables).

  .PARAMETER LoginPasswordEnvVar
  Name of the environment variable holding the password for the login. Its value is injected via the sqlcmd variable $(BuildSetsloginPassword).

  .PARAMETER Force
  If supplied, allows recreation steps (e.g., dropping existing database) inside scripts if they perform such logic.

  .EXAMPLE
  $Env:BuildSetsloginPassword='StrongP@ssw0rd!'; DatabaseProvisioning -DatabaseName BuildSets -SqlInstance '.\SQLEXPRESS' -LoginName 'FlywayAsBuildSetsDBOwner'

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines
  #>

  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Production', 'Testing', 'Development')]
    [string]$Environment,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$SqlInstance = 'utat022\SQLEXPRESS',

    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ })]
    # ToDo: get default from a global:settings value
    [string]$ScriptDirectory = "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement\SharedSQL",

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    # ToDo: get default from a global:settings value, lookup by databaseName and environment
    [string]$LoginName ,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    # ToDo: get from a vault, lookup by databaseName and environment
    [Securestring]$LoginPasswordVaultKey ,

    [switch]$Force
  )

  BEGIN {
    Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message "Entering script DatabaseProvisioning"
    $errors = [System.Collections.Generic.List[string]]::new()
    $scriptsRun = [System.Collections.Generic.List[string]]::new()
    # ToDo: if a value was passed, use it, else get from environment variable else get from global variable
    # ToDo: add error checking to ensure it exists and is non-empty
    $loginName = $global:DatabaseProperties[$environment][$databaseName].LoginName
    # ToDo: if a value was passed, use it, else get from environment variable else get from global variable
    # ToDo: add error checking to ensure it exists and is non-empty
    $loginPasswordVaultKey = $global:DatabaseProperties[$environment][$databaseName].LoginPasswordVaultKey
    # Lookup LoginPassword from environment variable
    # ToDo: change this to lookup from a secure vault
    # ToDo: add error checking to ensure it exists and is non-empty
    [SecureString]$loginPassword = $global:DatabaseVaultPasswords[$environment][$databaseName].LoginPassword


    $result = [ordered]@{
      DatabaseName     = $DatabaseName
      SqlInstance      = $SqlInstance
      LoginName        = $LoginName
      LoginPasswordVar = $LoginPasswordEnvVar
      ScriptsPlanned   = @()
      ScriptsExecuted  = @()
      Success          = $false
      Errors           = @()
      Force            = [bool]$Force
      TimestampUTC     = (Get-Date).ToUniversalTime()
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
      }
    )

    foreach ($entry in $plannedScripts) {
      $full = Join-Path -Path $ScriptDirectory -ChildPath $entry.Name
      if (-not (Test-Path $full)) {
        $msg = "Planned script not found: $full"
        Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Error -Message $msg
        $errors.Add($msg) | Out-Null
      }
      else {
        $entry.FullPath = $full
        $result.ScriptsPlanned += $full
      }
    }

    if ($errors.Count -gt 0) {
      Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Error -Message 'Aborting before execution due to missing scripts.'
      throw 'Provisioning aborted; missing scripts.'
    }

    # Stash script metadata in script scope for PROCESS
    $script:PlannedScriptsMetadata = $plannedScripts
    $script:loginPasswordValue = $loginPassword
  }

  PROCESS {
    foreach ($meta in $script:PlannedScriptsMetadata) {
      $scriptPath = $meta.FullPath
      $scriptLabel = $meta.Name
      $targetDb = $meta.RunDb

      if ($PSCmdlet.ShouldProcess("$SqlInstance / $targetDb", "Execute $scriptLabel")) {
        try {
          Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Verbose -Message "Starting script $scriptLabel"

          try {
            $invokeParams = @{
              ServerInstance = $SqlInstance
              InputFile      = $scriptPath
              ErrorAction    = 'Stop'
            }
            if ($targetDb -and $targetDb -ne 'master') {
              $invokeParams.Database = $targetDb
            }

            if ($meta.NeedsVars) {
              # These variable names must match those used in the SQL script:
              # $(loginPassword), $(DbName), $(LoginName)
              $invokeParams.Variable = @{
                loginPassword = $script:loginPasswordValue
                DbName        = $DatabaseName
                LoginName     = $LoginName
              }
            }

            Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message "Calling Invoke-Sqlcmd $scriptLabel (DB=$targetDb)"
            Invoke-Sqlcmd @invokeParams
            Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message "Successfully returned from Invoke-Sqlcmd $scriptLabel"
            $scriptsRun.Add($scriptPath) | Out-Null
          }
          catch {
            $errorMessage = "Failure executing $scriptLabel. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Error -Message $errorMessage
            if ($_.Exception.StackTrace) {
              Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message "StackTrace: $($_.Exception.StackTrace)"
            }
            $errors.Add($errorMessage) | Out-Null
            throw
          }
          finally {
            Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message "Finished attempt for $scriptLabel"
          }
        }
        catch {
          continue
        }
      }
      else {
        Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Important -Message "Skipped script $scriptLabel due to ShouldProcess decision"
      }
    }
  }

  END {
    $result.ScriptsExecuted = $scriptsRun.ToArray()
    $result.Errors = $errors.ToArray()
    $result.Success = ($errors.Count -eq 0)
    Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Important -Message ("Provisioning { 0 }" -f ($(if ($result.Success) { 'succeeded' } else { 'failed' })))
    if ($errors.Count -gt 0) {
      Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Error -Message ("Errors:`n { 0 }" -f ($errors -join [Environment]::NewLine))
    }
    Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message 'Leaving script DatabaseProvisioning'
    [PSCustomObject]$result
  }
}
