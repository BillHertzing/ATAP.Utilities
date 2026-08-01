function Write-ParityScheduledTaskEvent {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Error', 'Warning', 'Information')]
    [string] $EntryType,

    [Parameter(Mandatory = $true)]
    [int] $EventId,

    [Parameter(Mandatory = $true)]
    [string] $Message,

    [Parameter(Mandatory = $false)]
    [string] $LogName = 'Application',

    [Parameter(Mandatory = $false)]
    [string] $Source = 'ATAP.SystemParityMonitor'
  )

  $fn = 'Write-ParityScheduledTaskEvent'
  $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'

  try {
    if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) {
      New-EventLog -LogName $LogName -Source $Source -ErrorAction Stop
    }

    Write-EventLog -LogName $LogName -Source $Source -EntryType $EntryType -EventId $EventId -Message $Message -ErrorAction Stop
    [pscustomobject]@{
      Success = $true
      LogName = $LogName
      Source = $Source
      EventId = $EventId
      EntryType = $EntryType
      Error = $null
    }
  } catch {
    [pscustomobject]@{
      Success = $false
      LogName = $LogName
      Source = $Source
      EventId = $EventId
      EntryType = $EntryType
      Error = $_.Exception.Message
    }
  }
}
