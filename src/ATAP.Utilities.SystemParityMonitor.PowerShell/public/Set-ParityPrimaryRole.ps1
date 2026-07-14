function Set-ParityPrimaryRole {
<#
.SYNOPSIS
Writes the canonical Dropbox-synchronized DPOM primary-role marker.

.DESCRIPTION
Creates or replaces the one shared PrimaryRole.json record using the Task 12.59
schema. The function requires explicit human
authorization and a parity-journal entry ID, writes atomically, and is
idempotent for an identical marker.

.PARAMETER StatePath
Dropbox-synchronized ParityState folder that owns the single PrimaryRole.json
record shared by both hosts.

.PARAMETER PrimaryRole
Host authorized as the current primary and sole publisher.

.PARAMETER PlannedAbsenceHostName
Host expected to be absent. Omit this parameter for a normal-operation exit
marker.

.PARAMETER SinceUtc
UTC start time of the planned absence. Defaults to the current UTC instant.

.PARAMETER Reason
Secret-free reason for the role declaration.

.PARAMETER AuthorizedBy
Human operator who authorized the role declaration.

.PARAMETER JournalEntryId
Parity-journal entry that records the authorized role declaration.

.OUTPUTS
PSCustomObject describing the action, path, and canonical marker.

.EXAMPLE
Set-ParityPrimaryRole -PrimaryRole 'utat01' -PlannedAbsenceHostName 'utat022' -Reason 'first Class A test' -AuthorizedBy 'Bill Hertzing' -JournalEntryId '00000000-0000-0000-0000-000000000001'

.EXAMPLE
Set-ParityPrimaryRole -PrimaryRole 'utat022' -Reason 'DPOM exit' -AuthorizedBy 'Bill Hertzing' -JournalEntryId '00000000-0000-0000-0000-000000000002'

.NOTES
Run this function once on either host after journaling the human-authorized
entry or exit, then wait for Dropbox to report Up to date before relying on the
marker from the peer. Do not place credentials or secret values in the marker.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [string] $StatePath = 'C:\Dropbox\whertzing\ATAP\ParityState',

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $PrimaryRole,

    [ValidateNotNullOrEmpty()]
    [string] $PlannedAbsenceHostName,

    [DateTimeOffset] $SinceUtc = [DateTimeOffset]::UtcNow,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Reason,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $AuthorizedBy,

    [Parameter(Mandatory = $true)]
    [guid] $JournalEntryId
  )

  begin {
    $fn = 'Set-ParityPrimaryRole'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Starting primary-role marker write.'
  }

  process {
    try {
      $normalizedPrimaryRole = $PrimaryRole.Trim().ToLowerInvariant()
      $normalizedAbsenceHostName = if ($PSBoundParameters.ContainsKey('PlannedAbsenceHostName')) {
        $PlannedAbsenceHostName.Trim().ToLowerInvariant()
      } else {
        $null
      }

      if ($normalizedAbsenceHostName -and $normalizedPrimaryRole -eq $normalizedAbsenceHostName) {
        throw 'PrimaryRole and PlannedAbsenceHostName must identify different hosts.'
      }
      if ($JournalEntryId -eq [guid]::Empty) {
        throw 'JournalEntryId must not be an empty GUID.'
      }

      $plannedAbsence = if ($normalizedAbsenceHostName) {
        [pscustomobject] [ordered] @{
          HostName = $normalizedAbsenceHostName
          SinceUtc = $SinceUtc.ToUniversalTime().ToString('o', [Globalization.CultureInfo]::InvariantCulture)
          Reason = $Reason.Trim()
        }
      } else {
        $null
      }

      $marker = [pscustomobject] [ordered] @{
        SchemaVersion = 1
        PrimaryRole = $normalizedPrimaryRole
        PlannedAbsence = $plannedAbsence
        AuthorizedBy = $AuthorizedBy.Trim()
        JournalEntryId = $JournalEntryId.ToString()
      }
      $markerPath = Join-Path $StatePath 'PrimaryRole.json'
      $existingMarker = Get-ParityPrimaryRole -StatePath $StatePath
      $isIdentical = $null -ne $existingMarker -and
        ($existingMarker | ConvertTo-Json -Depth 8 -Compress) -ceq ($marker | ConvertTo-Json -Depth 8 -Compress)

      $action = if ($isIdentical) {
        'AlreadyCurrent'
      } elseif (Test-Path -LiteralPath $markerPath -PathType Leaf) {
        'Updated'
      } else {
        'Created'
      }

      $changed = $false
      if (-not $isIdentical -and $PSCmdlet.ShouldProcess($markerPath, "Write authorized primary role '$normalizedPrimaryRole'")) {
        Write-ParityJsonFile -Path $markerPath -InputObject $marker -Confirm:$false
        $changed = $true
      } elseif (-not $isIdentical) {
        $action = 'WhatIf'
      }

      [pscustomobject] @{
        Action = $action
        Changed = $changed
        Path = $markerPath
        Marker = $marker
      }
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to write primary-role marker. Exception: $($_.Exception.Message)"
      throw
    } finally {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving primary-role marker write.'
    }
  }

  end {
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed primary-role marker write.'
  }
}
