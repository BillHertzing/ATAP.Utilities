function Add-ParityChangeEntry {
<#
.SYNOPSIS
Appends a declared machine-state change to this host's parity journal.

.DESCRIPTION
Creates a schema-versioned JSONL entry in ChangeJournal.<host>.jsonl. The entry
captures the changed category/item, old and new values, and the peer action that
should be reviewed or applied on the other host.

.PARAMETER StatePath
Local ParityState folder that owns this host's journal.

.PARAMETER HostName
Host name whose journal receives the entry. Defaults to COMPUTERNAME.

.PARAMETER Category
Change category, such as Packages, Services, OS, SQL, or Runbook.

.PARAMETER Item
Specific changed item within the category.

.PARAMETER OldValue
Previous value or state.

.PARAMETER NewValue
New value or state.

.PARAMETER PeerHostName
Peer host expected to read and act on the entry.

.PARAMETER PeerActionKind
Type of peer action required.

.PARAMETER PeerAction
Human-readable peer action instruction or guarded command text.

.PARAMETER Reason
Reason for the local change.

.OUTPUTS
PSCustomObject.

.EXAMPLE
Add-ParityChangeEntry -Category Packages -Item git -OldValue 2.45 -NewValue 2.46 -PeerHostName utat01 -PeerActionKind Manual -PeerAction 'Review package parity'

.NOTES
Secret values must never be placed in journal entries.
#>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [string] $StatePath = 'C:\ProgramData\ATAP\ParityState',

    [string] $HostName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $true)]
    [ValidateSet('OS', 'Packages', 'PowerShellModules', 'WindowsFeatures', 'Services', 'Registry', 'Files', 'Shares', 'Firewall', 'SQL', 'Runbook', 'Other')]
    [string] $Category,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Item,

    [AllowNull()]
    [string] $OldValue,

    [AllowNull()]
    [string] $NewValue,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $PeerHostName,

    [ValidateSet('None', 'Manual', 'Command', 'Document', 'InstallPackage', 'ConfigureService')]
    [string] $PeerActionKind = 'Manual',

    [string] $PeerAction,

    [string] $Reason
  )

  begin {
    $fn = 'Add-ParityChangeEntry'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Starting parity change entry append.'
  }

  process {
    try {
      New-ParityDirectory -Path $StatePath
      $timestampUtc = (Get-Date).ToUniversalTime()
      $entry = [pscustomobject] @{
        SchemaVersion = 1
        Id = [guid]::NewGuid().ToString()
        RecordedAtUtc = $timestampUtc.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
        SourceHostName = $HostName.ToLowerInvariant()
        PeerHostName = $PeerHostName.ToLowerInvariant()
        Category = $Category
        Item = $Item
        OldValue = $OldValue
        NewValue = $NewValue
        PeerActionKind = $PeerActionKind
        PeerAction = $PeerAction
        Reason = $Reason
        Status = 'Recorded'
      }

      $journalPath = Get-ParityJournalPath -StatePath $StatePath -HostName $HostName
      if ($PSCmdlet.ShouldProcess($journalPath, "Append parity change entry '$($entry.Id)'")) {
        Write-ParityJsonLine -Path $journalPath -InputObject $entry
      }

      $entry
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to append parity change entry. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed parity change entry append.'
  }
}
