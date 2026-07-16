function WatchFile {
  <#
  .SYNOPSIS
    Watches one file for filesystem changes until cancelled.
  .DESCRIPTION
    Registers FileSystemWatcher handlers, emits PSFramework log records for changes, and always unregisters and disposes resources.
  .PARAMETER Path
    Existing file to monitor.
  .OUTPUTS
    PSCustomObject change-event records.
  .EXAMPLE
    WatchFile -Path C:\Logs\application.log
  .NOTES
    Press Ctrl+C to stop. Moved from CurrentUserAllHostsV7CoreProfile.ps1 in Task 12.49.e.
  .LINK
    System.IO.FileSystemWatcher
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param([Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string] $Path)
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn"
  }
  process {
    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    if (-not $PSCmdlet.ShouldProcess($resolvedPath, 'Watch file until cancelled')) { return }
    $watcher = [IO.FileSystemWatcher]::new((Split-Path $resolvedPath -Parent), (Split-Path $resolvedPath -Leaf))
    $watcher.NotifyFilter = [IO.NotifyFilters]::LastWrite -bor [IO.NotifyFilters]::FileName
    $handlers = @()
    try {
      foreach ($eventName in @('Changed', 'Created', 'Deleted', 'Renamed')) {
        $handlers += Register-ObjectEvent -InputObject $watcher -EventName $eventName
      }
      $watcher.EnableRaisingEvents = $true
      while ($true) {
        $eventRecord = Wait-Event -Timeout 1
        if ($eventRecord) {
          $details = $eventRecord.SourceEventArgs
          $record = [PSCustomObject]@{ ChangeType = [string]$details.ChangeType; Name = $details.Name; FullPath = $details.FullPath; Timestamp = $eventRecord.TimeGenerated }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "$($record.ChangeType): $($record.FullPath)"
          $record
          Remove-Event -EventIdentifier $eventRecord.EventIdentifier -ErrorAction SilentlyContinue
        }
      }
    } finally {
      $watcher.EnableRaisingEvents = $false
      foreach ($handler in $handlers) { Unregister-Event -SourceIdentifier $handler.Name -ErrorAction SilentlyContinue; Remove-Job -Id $handler.Id -Force -ErrorAction SilentlyContinue }
      $watcher.Dispose()
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'File monitoring ended.'
    }
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" }
}
