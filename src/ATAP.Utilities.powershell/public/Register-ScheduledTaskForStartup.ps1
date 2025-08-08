function Register-StartupScheduledTask {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory)]
    [string]$TaskName,

    [Parameter(Mandatory)]
    [string]$ScriptPath,

    [Parameter(Mandatory)]
    [string]$Description,

    [Parameter(Mandatory)]
    [System.Management.Automation.PSCredential]$Credential
  )

  Write-PSFMessage -Level Verbose -Message 'Entering function: Register-StartupScheduledTask'
  Write-PSFMessage -Level Information -Message "TaskName: $TaskName | ScriptPath: $ScriptPath | Description: $Description | User: $($Credential.UserName)"

  try {
    if (-not (Test-Path -Path $ScriptPath -PathType Leaf)) {
      $msg = "The specified script path '$ScriptPath' does not exist or is not a file."
      Write-PSFMessage -Level Error -Message $msg
      throw $msg
    }

    $action = New-ScheduledTaskAction -Execute 'pwsh.exe' `
      -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`""
    Write-PSFMessage -Level Verbose -Message 'ScheduledTaskAction created successfully.'

    $trigger = New-ScheduledTaskTrigger -AtStartup
    Write-PSFMessage -Level Verbose -Message 'ScheduledTaskTrigger created for AtStartup.'

    $principal = New-ScheduledTaskPrincipal -UserId $Credential.UserName `
      -LogonType Password -RunLevel Highest
    Write-PSFMessage -Level Verbose -Message "ScheduledTaskPrincipal created for user $($Credential.UserName)."

    if ($PSCmdlet.ShouldProcess("Scheduled Task '$TaskName'", 'Register')) {
      Register-ScheduledTask -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Description $description `
        -User $Credential.UserName `
        -Password $Credential.GetNetworkCredential().Password

      Write-PSFMessage -Level Information -Message "Scheduled task '$TaskName' registered successfully."
    }
  }
  catch {
    $errorMessage = "Failed to register scheduled task '$TaskName'. Exception: $($_.Exception.Message)"
    Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
    throw $_
  }
  finally {
    Write-PSFMessage -Level Verbose -Message 'Exiting function: Register-StartupScheduledTask'
  }
}
