<#
.SYNOPSIS
  Stops non-game processes to free resources before gaming sessions.
.DESCRIPTION
  Iterates all running processes and stops any whose name matches a predefined
  list of background/non-game process patterns. Supports -WhatIf and -Confirm.
.OUTPUTS
  None
.EXAMPLE
  Stop-NonGameProcesses
  Stops all matching non-game processes.
.EXAMPLE
  Stop-NonGameProcesses -WhatIf
  Shows which processes would be stopped without actually stopping them.
.NOTES
  AI assisted using ./claude/Rules/Powershell.md as guidelines
.LINK
  https://github.com/BillHertzing/ATAP.Utilities
#>
function Stop-NonGameProcesses {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([void])]
  param ()

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = $MyInvocation.MyCommand.ModuleName
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    $nonGameProcessNamesToStop = @(
      '.*buildmaster.*',
      '.*chrome.*',
      '.*claude.*',
      'Code',
      'Codex',
      '.*cobian.*',
      'discord',
      '.*docfetcher.*',
      'everything',
      '.*headroom.*',
      'GoProDeviceDetection',
      'Microsoft.*Teams',
      '.*node.js.*',
      '.*perplexity.*',
      '.*phone.*link.*',
      'Plex Update Service',
      '.*proget.*',
      '.*pushbullet.*',
      '.*python.*',
      '.*search.*indexer.*',
      '.*SQL Server.*',
      'sqlceip',
      'sqlservr',
      '.*VisualStudioCode.*',
      '.*WhatsApp.*',
      'YourPhoneAppProxy'
    )
    $processNamesRegExpr = $nonGameProcessNamesToStop -join '|'
  }

  process {
    # Try-Catch-Finally
    try {
      $initialProcesses = Get-Process
      foreach ($process in $initialProcesses) {
        if ($process.Name -match $processNamesRegExpr) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Stopping process: $($process.Name) (PID: $($process.Id))"
          if ($PSCmdlet.ShouldProcess($process.Name, 'Stop-Process')) {
            Stop-Process -InputObject $process -Force -ErrorAction Stop
          }
        }
      }
    } catch {
      $errorMessage = "Failed to stop process. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      # ToDo: accumulate the errors; potentially add to 'Problems'
      # ToDo: flesh out logging the stacktrace
      throw # the unadorned throw will throw the $_ exception and keep the stack trace intact
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
