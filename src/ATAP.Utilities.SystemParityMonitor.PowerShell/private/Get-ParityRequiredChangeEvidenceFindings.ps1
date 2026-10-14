function Get-ParityRequiredChangeEvidenceFindings {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object[]] $RequiredChanges,

    [Parameter(Mandatory = $true)]
    [string] $LeftStatePath,

    [Parameter(Mandatory = $true)]
    [string] $RightStatePath,

    [Parameter(Mandatory = $true)]
    [string] $LeftHostName,

    [Parameter(Mandatory = $true)]
    [string] $RightHostName
  )

  begin {
    $fn = 'Get-ParityRequiredChangeEvidenceFindings'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Validating required parity journal and acknowledgement evidence.'
  }

  process {
    $statePaths = @{
      $LeftHostName.ToLowerInvariant() = $LeftStatePath
      $RightHostName.ToLowerInvariant() = $RightStatePath
    }
    $ackRanks = @{ Applied = 1; Verified = 2; Waived = 3 }
    $logicalIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $findings = [System.Collections.Generic.List[object]]::new()

    foreach ($requiredChange in @($RequiredChanges)) {
      $logicalChangeId = ([string]$requiredChange.LogicalChangeId).Trim()
      $entryId = ([string]$requiredChange.EntryId).Trim()
      $journalHostName = ([string]$requiredChange.JournalHostName).Trim().ToLowerInvariant()
      $ackHostName = ([string]$requiredChange.AckHostName).Trim().ToLowerInvariant()
      $category = ([string]$requiredChange.Category).Trim()
      $item = ([string]$requiredChange.Item).Trim()
      $minimumAckStatus = if ($requiredChange.PSObject.Properties['MinimumAckStatus']) { [string]$requiredChange.MinimumAckStatus } else { 'Verified' }

      if ([string]::IsNullOrWhiteSpace($logicalChangeId) -or [string]::IsNullOrWhiteSpace($entryId) -or
        [string]::IsNullOrWhiteSpace($journalHostName) -or [string]::IsNullOrWhiteSpace($ackHostName) -or
        [string]::IsNullOrWhiteSpace($category) -or [string]::IsNullOrWhiteSpace($item)) {
        throw 'Every required parity change must specify LogicalChangeId, EntryId, JournalHostName, AckHostName, Category, and Item.'
      }
      if (-not $logicalIds.Add($logicalChangeId)) { throw "Required parity LogicalChangeId '$logicalChangeId' is configured more than once." }
      if (-not $statePaths.ContainsKey($journalHostName) -or -not $statePaths.ContainsKey($ackHostName)) {
        throw "Required parity change '$logicalChangeId' names a host outside the compared pair."
      }
      if (-not $ackRanks.ContainsKey($minimumAckStatus)) {
        throw "Required parity change '$logicalChangeId' has unsupported MinimumAckStatus '$minimumAckStatus'."
      }

      $journalPath = Get-ParityJournalPath -StatePath $statePaths[$journalHostName] -HostName $journalHostName
      $journalMatches = @(Read-ParityJsonLines -Path $journalPath | Where-Object { [string]$_.Id -eq $entryId })
      if ($journalMatches.Count -ne 1) {
        $findings.Add([pscustomobject]@{
            LogicalChangeId = $logicalChangeId
            Classification = 'JournalMissingOrDuplicate'
            EntryId = $entryId
            HostName = $journalHostName
            Expected = "$category/$item"
            Actual = "Count=$($journalMatches.Count)"
          })
        continue
      }
      $journal = $journalMatches[0]
      if ([string]$journal.SourceHostName -ine $journalHostName -or [string]$journal.PeerHostName -ine $ackHostName -or
        [string]$journal.Category -ine $category -or [string]$journal.Item -ine $item) {
        $findings.Add([pscustomobject]@{
            LogicalChangeId = $logicalChangeId
            Classification = 'JournalContractMismatch'
            EntryId = $entryId
            HostName = $journalHostName
            Expected = "$journalHostName->$ackHostName;$category/$item"
            Actual = "$($journal.SourceHostName)->$($journal.PeerHostName);$($journal.Category)/$($journal.Item)"
          })
        continue
      }

      $ackPath = Get-ParityAckPath -StatePath $statePaths[$ackHostName] -HostName $ackHostName
      $ackMatches = @(Read-ParityJsonLines -Path $ackPath | Where-Object {
          [string]$_.JournalEntryId -eq $entryId -and
          [string]$_.AckHostName -ieq $ackHostName -and
          [string]$_.JournalHostName -ieq $journalHostName
        } | Sort-Object RecordedAtUtc)
      if ($ackMatches.Count -eq 0) {
        $findings.Add([pscustomobject]@{
            LogicalChangeId = $logicalChangeId
            Classification = 'AcknowledgementMissing'
            EntryId = $entryId
            HostName = $ackHostName
            Expected = $minimumAckStatus
            Actual = '<missing>'
          })
        continue
      }
      $latestAck = $ackMatches[-1]
      if (-not $ackRanks.ContainsKey([string]$latestAck.Status) -or $ackRanks[[string]$latestAck.Status] -lt $ackRanks[$minimumAckStatus]) {
        $findings.Add([pscustomobject]@{
            LogicalChangeId = $logicalChangeId
            Classification = 'AcknowledgementInsufficient'
            EntryId = $entryId
            HostName = $ackHostName
            Expected = $minimumAckStatus
            Actual = [string]$latestAck.Status
          })
      }
    }

    @($findings)
  }

  end {
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed required parity change evidence validation.'
  }
}
