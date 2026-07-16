function Get-PeerPendingChanges {
<#
.SYNOPSIS
Returns peer journal entries not yet acknowledged by this host.

.DESCRIPTION
Reads ChangeJournal.<peer>.jsonl from the peer ParityState path and
ChangeAck.<local>.jsonl from this host. Entries with Applied, Verified, or
Waived acknowledgements are filtered out.

.PARAMETER LocalStatePath
Local ParityState folder containing this host's acknowledgement file.

.PARAMETER PeerStatePath
Peer ParityState folder containing the peer journal.

.PARAMETER LocalHostName
This host's name.

.PARAMETER PeerHostName
Peer host's name.

.OUTPUTS
PSCustomObject[].

.EXAMPLE
Get-PeerPendingChanges -PeerStatePath '\\utat022\ParityState' -PeerHostName utat022
#>
  [CmdletBinding()]
  param(
    [string] $LocalStatePath = 'C:\ProgramData\ATAP\ParityState',

    [Parameter(Mandatory = $true)]
    [string] $PeerStatePath,

    [string] $LocalHostName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $true)]
    [string] $PeerHostName
  )

  begin {
    $fn = 'Get-PeerPendingChanges'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Starting peer pending change read.'
  }

  process {
    try {
      $peerJournalPath = Get-ParityJournalPath -StatePath $PeerStatePath -HostName $PeerHostName
      $localAckPath = Get-ParityAckPath -StatePath $LocalStatePath -HostName $LocalHostName
      $journalEntries = Read-ParityJsonLines -Path $peerJournalPath
      $acks = Read-ParityJsonLines -Path $localAckPath
      $closedAckIds = @{}

      foreach ($ack in $acks) {
        if ($ack.JournalHostName -ieq $PeerHostName -and $ack.Status -in @('Applied', 'Verified', 'Waived')) {
          $closedAckIds[[string] $ack.JournalEntryId] = $true
        }
      }

      $pending = foreach ($entry in $journalEntries) {
        if ($entry.PeerHostName -and $entry.PeerHostName -ine $LocalHostName) {
          continue
        }

        if ($closedAckIds.ContainsKey([string] $entry.Id)) {
          continue
        }

        $entry
      }

      @($pending)
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to read peer pending changes. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed peer pending change read.'
  }
}
