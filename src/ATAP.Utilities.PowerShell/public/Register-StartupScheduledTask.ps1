<#
.SYNOPSIS
Registers a scheduled task that runs a PowerShell script at system startup.

.DESCRIPTION
Creates and registers a Windows Scheduled Task configured with an AtStartup trigger.
The task runs the provided script path using `pwsh.exe` with execution policy bypass.
If a credential is supplied, the task is registered using that user context. If no
credential is supplied, the task is registered to run as the SYSTEM service account.

.PARAMETER TaskName
The name of the scheduled task to register.

.PARAMETER ScriptPath
The full path to the PowerShell script file that should execute at startup.

.PARAMETER Description
The description assigned to the scheduled task.

.PARAMETER Credential
Optional credential used to register and run the task as a specific user account.
Use `Get-Credential` to provide this value.

.PARAMETER LogonType
The scheduled task logon type. Valid values are `Password`, `S4U`, `Interactive`, and
`ServiceAccount`.

.PARAMETER RunLevel
The privilege level for the scheduled task. Valid values are `Highest` and `Limited`.

.OUTPUTS
[void]

.EXAMPLE
$credential = Get-Credential
Register-StartupScheduledTask -TaskName 'ATAPLoginScript' -ScriptPath 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-branch071\src\ATAP.Utilities.PowerShell\Profiles\LoginScript.ps1' -Description 'Run ATAP login script at startup' -Credential $credential -RunLevel Highest

Registers a startup task named `ATAPLoginScript` that runs `LoginScript.ps1` with the
credential captured from `Get-Credential`.

.EXAMPLE
Register-StartupScheduledTask -TaskName 'ATAPStartupSystemTask' -ScriptPath 'C:\Scripts\StartupScript.ps1' -Description 'Run startup script as SYSTEM' -RunLevel Highest

Registers a startup task to run as SYSTEM when no credential is supplied.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://learn.microsoft.com/powershell/module/scheduledtasks/register-scheduledtask
#>
function Register-StartupScheduledTask {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory = $true)]
    [string]$TaskName,

    [Parameter(Mandatory = $true)]
    [string]$ScriptPath,

    [Parameter(Mandatory = $true)]
    [string]$Description,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Password', 'S4U', 'Interactive', 'ServiceAccount')]
    [string]$LogonType = 'Password',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Highest', 'Limited')]
    [string]$RunLevel = 'Highest'
  )

  BEGIN {
    $fn = 'Register-StartupScheduledTask'
    $mn = 'ATAP.Utilities.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Verify running on Windows
    if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
      $errorMessage = 'This function requires Windows and the ScheduledTasks module'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    # Import ScheduledTasks module with compatibility fix for PowerShell 7+
    try {
      # For PowerShell 7+, use Windows PowerShell compatibility
      if ($PSVersionTable.PSVersion.Major -ge 7) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'PowerShell 7+ detected, using Windows PowerShell compatibility mode'

        # Use Windows PowerShell module path
        Import-Module -Name ScheduledTasks -UseWindowsPowerShell -ErrorAction Stop -WarningAction SilentlyContinue
      }
      else {
        # PowerShell 5.1 - normal import
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Importing ScheduledTasks module'
        Import-Module -Name ScheduledTasks -ErrorAction Stop
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'ScheduledTasks module imported successfully'
    }
    catch {
      $errorMessage = "Failed to import ScheduledTasks module. Exception: $($_.Exception.Message). Note: This function requires Administrator privileges."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
  }

  PROCESS {
    try {
      if (-not (Test-Path -Path $ScriptPath -PathType Leaf)) {
        $errorMessage = "The specified script path '$ScriptPath' does not exist or is not a file."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Creating ScheduledTaskAction'
      $action = New-ScheduledTaskAction -Execute 'pwsh.exe' `
        -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`""

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Creating ScheduledTaskTrigger for AtStartup'
      $trigger = New-ScheduledTaskTrigger -AtStartup

      if ($PSCmdlet.ShouldProcess("Scheduled Task '$TaskName'", 'Register')) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Registering scheduled task '$TaskName'"

        $registerParams = @{
          TaskName    = $TaskName
          Action      = $action
          Trigger     = $trigger
          Description = $Description
        }

        # Choose parameter set based on whether credential is provided
        if ($Credential) {
          # Use -User/-Password parameter set for regular users
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using User/Password parameter set for user $($Credential.UserName)"
          $registerParams['User'] = $Credential.UserName
          $registerParams['Password'] = $Credential.GetNetworkCredential().Password
          $registerParams['RunLevel'] = $RunLevel
        }
        else {
          # Use -Principal parameter set for service accounts
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using Principal parameter set for SYSTEM account"
          $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' `
            -LogonType ServiceAccount -RunLevel $RunLevel
          $registerParams['Principal'] = $principal
        }

        Register-ScheduledTask @registerParams

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Scheduled task '$TaskName' registered successfully"
      }
    }
    catch {
      $errorMessage = "Failed to register scheduled task '$TaskName'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
