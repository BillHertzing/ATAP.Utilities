function Grant-ParityScheduledTaskStartRight {
  <#
  .SYNOPSIS
    Grants one identity start-only rights on one registered scheduled task.

  .DESCRIPTION
    Edits only the named task's security descriptor through Task Scheduler COM, using the same
    approach as ATAP.Utilities.BuildTooling.ProGet.PowerShell Grant-ElevationBrokerStartRights:
    the prior SDDL is written to BackupDirectory before any change, so the grant is reversible,
    and an identical existing grant is a no-op. The task folder ACL is never touched.

  .PARAMETER TaskPath
    Task folder, for example '\ATAP\'.

  .PARAMETER TaskName
    Registered task name.

  .PARAMETER Sid
    String SID of the identity that may start the task.

  .PARAMETER BackupDirectory
    Directory that receives the pre-change SDDL.

  .OUTPUTS
    PSCustomObject with Task, Sid, Changed, BackupPath.
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)] [string] $TaskPath,
    [Parameter(Mandatory = $true)] [string] $TaskName,
    [Parameter(Mandatory = $true)] [string] $Sid,
    [Parameter(Mandatory = $true)] [string] $BackupDirectory
  )

  begin {
    $fn = 'Grant-ParityScheduledTaskStartRight'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting start-right grant on '$TaskPath$TaskName'."
  }

  process {
    $folderPath = $TaskPath.TrimEnd('\')
    if ([string]::IsNullOrWhiteSpace($folderPath)) { $folderPath = '\' }
    try {
      $scheduler = New-Object -ComObject 'Schedule.Service'
      $scheduler.Connect()
      $task = $scheduler.GetFolder($folderPath).GetTask($TaskName)
      $currentSddl = [string]$task.GetSecurityDescriptor(0x4) # DACL_SECURITY_INFORMATION
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Could not read the security descriptor of '$TaskPath$TaskName': $($_.Exception.Message)"
      throw
    }

    $computed = Get-ParityTaskStartRightSddl -Sddl $currentSddl -Sid $Sid
    if (-not $computed.Changed) {
      return [pscustomobject]@{ Task = "$TaskPath$TaskName"; Sid = $Sid; Changed = $false; BackupPath = $null }
    }

    if (-not $PSCmdlet.ShouldProcess("$TaskPath$TaskName", "grant start-only rights to $Sid")) {
      return [pscustomobject]@{ Task = "$TaskPath$TaskName"; Sid = $Sid; Changed = $false; BackupPath = $null }
    }

    New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    $backupPath = Join-Path $BackupDirectory ('{0}-sddl-{1}.txt' -f $TaskName, [DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssZ'))
    Set-Content -LiteralPath $backupPath -Value $currentSddl -Encoding utf8NoBOM -ErrorAction Stop
    try {
      $task.SetSecurityDescriptor($computed.Sddl, 0)
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Task Scheduler refused the security descriptor update for '$TaskPath$TaskName': $($_.Exception.Message). Prior SDDL saved at '$backupPath'."
      throw
    }
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Granted start-only rights on '$TaskPath$TaskName' to $Sid. Prior SDDL saved at '$backupPath'."
    [pscustomobject]@{ Task = "$TaskPath$TaskName"; Sid = $Sid; Changed = $true; BackupPath = $backupPath }
  }

  end {
  }
}
