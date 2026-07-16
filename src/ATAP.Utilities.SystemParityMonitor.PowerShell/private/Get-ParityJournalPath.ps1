function Get-ParityJournalPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $StatePath,

    [Parameter(Mandatory = $true)]
    [string] $HostName
  )

  begin {
    $fn = 'Get-ParityJournalPath'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolving journal path for host '$HostName'."
  }

  process {
    Join-Path $StatePath "ChangeJournal.$($HostName.ToLowerInvariant()).jsonl"
  }

  end {
  }
}
