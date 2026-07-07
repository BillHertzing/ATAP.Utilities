function Confirm-ParityChangeApplied {
<#
.SYNOPSIS
Records this host's acknowledgement for a peer journal entry.

.DESCRIPTION
Appends a schema-versioned acknowledgement to ChangeAck.<host>.jsonl. The ack
records that a peer journal entry was applied, verified, or waived by this host.

.PARAMETER StatePath
Local ParityState folder that owns this host's ack file.

.PARAMETER LocalHostName
Host name writing the acknowledgement.

.PARAMETER PeerHostName
Host that owns the original journal entry.

.PARAMETER EntryId
Peer journal entry identifier.

.PARAMETER Status
Acknowledgement lifecycle status.

.PARAMETER Note
Optional human-readable note.

.OUTPUTS
PSCustomObject.

.EXAMPLE
Confirm-ParityChangeApplied -PeerHostName utat022 -EntryId '<guid>' -Status Applied
#>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [string] $StatePath = 'C:\ProgramData\ATAP\ParityState',

    [string] $LocalHostName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $PeerHostName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $EntryId,

    [ValidateSet('Applied', 'Verified', 'Waived')]
    [string] $Status = 'Applied',

    [string] $Note
  )

  begin {
    $fn = 'Confirm-ParityChangeApplied'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Starting parity change acknowledgement.'
  }

  process {
    try {
      New-ParityDirectory -Path $StatePath
      $ack = [pscustomobject] @{
        SchemaVersion = 1
        JournalEntryId = $EntryId
        AckHostName = $LocalHostName.ToLowerInvariant()
        JournalHostName = $PeerHostName.ToLowerInvariant()
        Status = $Status
        Note = $Note
        RecordedAtUtc = (Get-Date).ToUniversalTime().ToString('o', [Globalization.CultureInfo]::InvariantCulture)
      }

      $ackPath = Get-ParityAckPath -StatePath $StatePath -HostName $LocalHostName
      if ($PSCmdlet.ShouldProcess($ackPath, "Append parity acknowledgement for '$EntryId'")) {
        Write-ParityJsonLine -Path $ackPath -InputObject $ack
      }

      $ack
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to acknowledge parity change. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed parity change acknowledgement.'
  }
}
