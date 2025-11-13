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
