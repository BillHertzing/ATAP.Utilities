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
  Name of the environment variable holding the password for the login. Its value is injected via the sqlcmd variable $(BuildSetsLoginPwd).

  .PARAMETER Force
  If supplied, allows recreation steps (e.g., dropping existing database) inside scripts if they perform such logic.

  .EXAMPLE
  $Env:BuildSetsLoginPwd='StrongP@ssw0rd!'; DatabaseProvisioning -DatabaseName BuildSets -SqlInstance '.\SQLEXPRESS' -LoginName 'FlywayAsBuildSetsDBOwner'

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines
  #>

  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName = 'BuildSets',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$SqlInstance = 'utat022\SQLEXPRESS',

    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ })]
    [string]$ScriptDirectory = $PSScriptRoot,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$LoginName = 'FlywayAsBuildSetsDBOwner',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$LoginPasswordEnvVar = 'BuildSetsLoginPwd',

    [switch]$Force
  )

  BEGIN {
    Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message "Entering script DatabaseProvisioning"
    $errors = [System.Collections.Generic.List[string]]::new()
    $scriptsRun = [System.Collections.Generic.List[string]]::new()
    $loginPwd = (Get-Item -Path Env:$LoginPasswordEnvVar -ErrorAction SilentlyContinue).Value

    if (-not $loginPwd) {
      $msg = "Environment variable '$LoginPasswordEnvVar' not found or empty. Cannot continue."
      Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Error -Message $msg
      throw $msg
    }

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
        Name      = 'DropAndCreateBuildSetsDatabase.sql'
        RunDb     = 'master'              # run against master (creates DB)
        NeedsVars = $false
      },
      @{
        Name      = 'CreateBuildSetsLoginAndUser.sql'
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
    $script:LoginPwdValue = $loginPwd
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
              # $(BuildSetsLoginPwd), $(DbName), $(LoginName)
              $invokeParams.Variable = @{
                BuildSetsLoginPwd = $script:LoginPwdValue
                DbName            = $DatabaseName
                LoginName         = $LoginName
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
    Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Important -Message ("Provisioning {0}" -f ($(if ($result.Success) { 'succeeded' } else { 'failed' })))
    if ($errors.Count -gt 0) {
      Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Error -Message ("Errors:`n{0}" -f ($errors -join [Environment]::NewLine))
    }
    Write-PSFMessage -FunctionName 'DatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message 'Leaving script DatabaseProvisioning'
    [PSCustomObject]$result
  }
}
