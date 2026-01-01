<#
.SYNOPSIS
Monitors ATAPUtilitiesETWProvider events in real-time.

.DESCRIPTION
Uses Get-WinEvent to tail ETW events from the ATAPUtilitiesETWProvider.
Displays events in the console with color-coding by event level.
Uses PSFramework for logging to align with repository standards.

.PARAMETER ProviderName
The name of the ETW provider to monitor. Defaults to 'ATAPUtilitiesETWProvider'.

.PARAMETER MaxEvents
Maximum number of events to retrieve when not following. Defaults to 100.

.PARAMETER Follow
When specified, monitors events in real-time (requires Administrator privileges).

.OUTPUTS
None
Displays formatted event information to the console.

.EXAMPLE
Watch-ETWEvents

Retrieves the last 100 events from ATAPUtilitiesETWProvider.

.EXAMPLE
Watch-ETWEvents -Follow

Monitors ETW events in real-time (requires Administrator).

.EXAMPLE
Watch-ETWEvents -MaxEvents 50

Retrieves the last 50 events.

.NOTES
AI assisted using repository coding instructions
Requires Administrator privileges to access ETW event log.
Uses PSFramework logging for consistency with repository standards.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Watch-ETWEvents {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([void])]
  param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ProviderName = 'ATAPUtilitiesETWProvider',

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10000)]
    [int]$MaxEvents = 100,

    [Parameter(Mandatory = $false)]
    [switch]$Follow
  )

  BEGIN {
    $fn = 'Watch-ETWEvents'
    $mn = 'ATAP.Utilities.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Monitoring ETW events from provider: $ProviderName"

    # Check if running as Administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
      $warningMessage = 'Not running as Administrator. Some ETW operations may fail.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message $warningMessage
      Write-Host $warningMessage -ForegroundColor Yellow
    }

    Write-Host "Monitoring ETW events from provider: $ProviderName" -ForegroundColor Cyan
    if ($Follow) {
      Write-Host "Real-time mode enabled. Press Ctrl+C to stop..." -ForegroundColor Yellow
    }
    Write-Host ""
  }

  PROCESS {
    try {
      if ($Follow) {
        if ($PSCmdlet.ShouldProcess($ProviderName, 'Start real-time ETW monitoring')) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Starting real-time ETW monitoring'

          # Real-time monitoring (requires elevated privileges)
          $query = @"
<QueryList>
  <Query Id="0" Path="Application">
    <Select Path="Application">*[System[Provider[@Name='$ProviderName']]]</Select>
  </Query>
</QueryList>
"@

          # Create watcher
          $watcher = New-Object System.Diagnostics.Eventing.Reader.EventLogWatcher $query

          # Event handler
          $action = {
            $event = $EventArgs.EventRecord
            $timestamp = $event.TimeCreated.ToString("HH:mm:ss.fff")
            $eventId = $event.Id
            $message = $event.FormatDescription()

            switch ($eventId) {
              1 { $color = 'White' }      # Information
              2 { $color = 'Green' }      # MethodBoundary
              3 { $color = 'Cyan' }       # MethodBoundaryFromAspect
              default { $color = 'Gray' }
            }

            Write-Host "[$timestamp] Event $eventId`: " -ForegroundColor $color -NoNewline
            Write-Host $message -ForegroundColor $color
          }

          # Register event
          Register-ObjectEvent -InputObject $watcher -EventName "EventRecordWritten" -Action $action | Out-Null

          # Enable the watcher
          $watcher.Enabled = $true

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Real-time ETW monitoring started'

          # Keep running
          try {
            while ($true) {
              Start-Sleep -Seconds 1
            }
          }
          finally {
            # Cleanup
            $watcher.Enabled = $false
            $watcher.Dispose()
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Stopped real-time ETW monitoring'
          }
        }
      }
      else {
        if ($PSCmdlet.ShouldProcess($ProviderName, "Retrieve last $MaxEvents events")) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Retrieving last $MaxEvents events"

          # Retrieve recent events
          $events = Get-WinEvent -ProviderName $ProviderName -MaxEvents $MaxEvents -ErrorAction Stop

          if ($null -eq $events -or $events.Count -eq 0) {
            $message = "No events found for provider '$ProviderName'"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message $message
            Write-Host $message -ForegroundColor Yellow
            return
          }

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Found $($events.Count) events"

          $events | Sort-Object TimeCreated | ForEach-Object {
            $timestamp = $_.TimeCreated.ToString("HH:mm:ss.fff")
            $eventId = $_.Id
            $message = $_.Message

            switch ($eventId) {
              1 { $color = 'White' }      # Information
              2 { $color = 'Green' }      # MethodBoundary
              3 { $color = 'Cyan' }       # MethodBoundaryFromAspect
              default { $color = 'Gray' }
            }

            Write-Host "[$timestamp] Event $eventId`: " -ForegroundColor $color -NoNewline
            Write-Host $message -ForegroundColor $color
          }

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Successfully retrieved and displayed $($events.Count) events"
        }
      }
    }
    catch [System.Diagnostics.Eventing.Reader.EventLogException] {
      $errorMessage = "ETW event log error: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -ErrorRecord $_
      Write-Host "Error: $errorMessage" -ForegroundColor Red
      Write-Host "Note: Verify the provider name '$ProviderName' is correct" -ForegroundColor Yellow
      Write-Host "Note: Ensure your application has written events to the log" -ForegroundColor Yellow
      throw
    }
    catch [System.UnauthorizedAccessException] {
      $errorMessage = "Access denied. Administrator privileges required."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -ErrorRecord $_
      Write-Host "Error: $errorMessage" -ForegroundColor Red
      Write-Host "Solution: Run PowerShell as Administrator" -ForegroundColor Yellow
      throw
    }
    catch {
      $errorMessage = "Failed to monitor ETW events. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -ErrorRecord $_
      Write-Host "Error: $errorMessage" -ForegroundColor Red
      Write-Host "Note: You may need to run as Administrator" -ForegroundColor Yellow
      Write-Host "Note: Make sure your application has written events first" -ForegroundColor Yellow
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
