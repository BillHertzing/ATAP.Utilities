function Test-ParityJournalCorrelation {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyCollection()]
    [object[]] $JournalEntries,

    [Parameter(Mandatory = $true)]
    [string] $Category,

    [Parameter(Mandatory = $true)]
    [string] $Item
  )

  begin {
    $fn = 'Test-ParityJournalCorrelation'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Checking journal correlation for '$Category/$Item'."
  }

  process {
    foreach ($entry in $JournalEntries) {
      if ($entry.Category -ne $Category -or $entry.Item -ne $Item) {
        continue
      }

      if ($entry.Status -in @('Recorded', 'Applied')) {
        return $entry
      }
    }
  }

  end {
  }
}
