function BuildSetsDatabaseProvisioning {

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

.PARAMETER AdminUsername
Administrative (SQL/Login) user to provision (login & database user).

.PARAMETER ScriptDirectory
Directory that contains the provisioning SQL scripts. Defaults to the directory of this script.

.PARAMETER Force
If supplied, allows recreation steps (e.g., dropping existing database) inside scripts if they perform such logic.

.EXAMPLE
.\BuildSetsDatabaseProvisioning.ps1 -DatabaseName BuildSets -SqlInstance '.\SQLEXPRESS' -AdminUsername BuildSetsDBAdminName -WhatIf

.EXAMPLE
.\BuildSetsDatabaseProvisioning.ps1 -DatabaseName BuildSets -SqlInstance '.\SQLEXPRESS' -AdminUsername BuildSetsDBAdminName -Confirm

.OUTPUTS
System.Object
Returns a PSCustomObject summarizing provisioning results (Success flag, ScriptsExecuted, Errors).

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
    [ValidateNotNullOrEmpty()]
    [string]$AdminUsername = 'FlywayAsBuildSetsDBOwner',

    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ })]
    [string]$ScriptDirectory = $PSScriptRoot,

    [switch]$Force
  )

  BEGIN {
    Write-PSFMessage -FunctionName 'BuildSetsDatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message "Entering script BuildSetsDatabaseProvisioning"
    $errors = [System.Collections.Generic.List[string]]::new()
    $scriptsRun = [System.Collections.Generic.List[string]]::new()
    $result = [ordered]@{
      DatabaseName    = $DatabaseName
      SqlInstance     = $SqlInstance
      AdminUsername   = $AdminUsername
      ScriptsPlanned  = @()
      ScriptsExecuted = @()
      Success         = $false
      Errors          = @()
      Force           = [bool]$Force
      TimestampUTC    = (Get-Date).ToUniversalTime()
    }

    # Collect script files in desired order
    $plannedScripts = @{
      'DropAndCreateBuildSetsDatabase.sql' = @{
        ConnectionString = "Server=$SqlInstance;Integrated Security=True;Trusted_Connection=True;Encrypt=False"
        InputFile        = $scriptPath
        ErrorAction      = 'Stop'
      }
      'CreateBuildSetsLoginAndUser.sql'    = @{
        ConnectionString = "Server=$SqlInstance;Initial Catalog=BuildSets;Integrated Security=True;Trusted_Connection=True;Encrypt=False"
        InputFile        = $scriptPath
        ErrorAction      = 'Stop'
      }
    }

    foreach ($s in $plannedScripts.keys) {
      $full = Join-Path -Path $ScriptDirectory -ChildPath $s
      if (-not (Test-Path $full)) {
        $msg = "Planned script not found: $full"
        Write-PSFMessage -FunctionName 'BuildSetsDatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Error -Message $msg
        $errors.Add($msg) | Out-Null
      }
      else {
        $result.ScriptsPlanned += $full
      }
    }

    if ($errors.Count -gt 0) {
      Write-PSFMessage -FunctionName 'BuildSetsDatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Error -Message "Aborting before execution due to missing scripts."
      throw "Provisioning aborted; missing scripts."
    }
  }

  PROCESS {
    foreach ($scriptPath in $result.ScriptsPlanned) {
      $scriptLabel = [IO.Path]::GetFileName($scriptPath)
      if ($PSCmdlet.ShouldProcess("$SqlInstance / $DatabaseName", "Execute $scriptLabel")) {
        try {
          Write-PSFMessage -FunctionName 'BuildSetsDatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Verbose -Message "Starting script $scriptLabel"
          # Try-Catch-Finally snippet (adapted)
          try {
            # change SQLCMD variables as needed
            $invokeParams = $plannedScripts[$scriptLabel]
            $invokeParams['InputFile'] = $scriptPath
            Write-PSFMessage -FunctionName 'BuildSetsDatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message "Calling Invoke-Sqlcmd $scriptLabel"
            Invoke-Sqlcmd @invokeParams
            Write-PSFMessage -FunctionName 'BuildSetsDatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message "Successfully returned from Invoke-Sqlcmd $scriptLabel"
            $scriptsRun.Add($scriptPath) | Out-Null
          }
          catch {
            $errorMessage = "Failure executing $scriptLabel. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName 'BuildSetsDatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Error -Message $errorMessage
            if ($_.Exception.StackTrace) {
              Write-PSFMessage -FunctionName 'BuildSetsDatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message "StackTrace: $($_.Exception.StackTrace)"
            }
            $errors.Add($errorMessage) | Out-Null
            throw
          }
          finally {
            Write-PSFMessage -FunctionName 'BuildSetsDatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message "Finished attempt for $scriptLabel"
          }
        }
        catch {
          # Continue to next script after logging
          continue
        }
      }
      else {
        Write-PSFMessage -FunctionName 'BuildSetsDatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Important -Message "Skipped script $scriptLabel due to ShouldProcess decision"
      }
    }
  }

  END {
    $result.ScriptsExecuted = $scriptsRun.ToArray()
    $result.Errors = $errors.ToArray()
    $result.Success = ($errors.Count -eq 0)
    Write-PSFMessage -FunctionName 'BuildSetsDatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Important -Message ("Provisioning {0}" -f ($(if ($result.Success) { 'succeeded' } else { 'failed' })))
    if ($errors.Count -gt 0) {
      Write-PSFMessage -FunctionName 'BuildSetsDatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Error -Message ("Errors:`n{0}" -f ($errors -join [Environment]::NewLine))
    }
    Write-PSFMessage -FunctionName 'BuildSetsDatabaseProvisioning' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message "Leaving script BuildSetsDatabaseProvisioning"
    [PSCustomObject]$result
  }
}
