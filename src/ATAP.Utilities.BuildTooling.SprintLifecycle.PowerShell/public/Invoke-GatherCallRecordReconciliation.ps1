function Invoke-GatherCallRecordReconciliation {
  <#
  .SYNOPSIS
  Reconciles staged gather-call record segments against explicit closure boundaries.

  .DESCRIPTION
  Provides the public command surface for gather-call record staging reconciliation.
  The command delegates discovery, boundary evaluation, validation, sealing, hashing,
  movement, and quarantine behavior to Invoke-GatherCallRecordStagingReconciliation.
  Explicit roots are passed through as supplied; omitted roots remain omitted so the
  private reconciler can resolve the exact configured keys.

  .PARAMETER CorpusGatherRecordsStagingPath
  Optional absolute staging root. When omitted, the private reconciler resolves
  CorpusGatherRecordsStagingPath through Get-PVal.

  .PARAMETER CorpusGatherRecordsPath
  Optional absolute durable corpus root. When omitted, the private reconciler resolves
  CorpusGatherRecordsPath through Get-PVal.

  .PARAMETER SprintNumber
  The four-digit sprint number used for durable partition placement.

  .PARAMETER ClosedSessionId
  Session identifiers whose staged segments are eligible for sealing.

  .PARAMETER MaximumSegmentAge
  The maximum age of a staged JSONL segment before it becomes eligible for sealing.

  .PARAMETER MaximumSegmentBytes
  The maximum staged JSONL byte count before it becomes eligible for sealing.

  .PARAMETER AbandonedRemnantAge
  The minimum age at which a partial remnant becomes eligible for quarantine.

  .PARAMETER NowUtc
  The UTC boundary instant. Defaults to the current UTC time and can be injected for
  deterministic callers and tests.

  .OUTPUTS
  System.Management.Automation.PSCustomObject. Returns the private reconciler result
  without transformation.

  .EXAMPLE
  Invoke-GatherCallRecordReconciliation -SprintNumber '0015' `
    -MaximumSegmentAge ([timespan]::FromMinutes(15)) -MaximumSegmentBytes 1048576 `
    -AbandonedRemnantAge ([timespan]::FromHours(1))

  Reconciles the configured staging root using the current UTC time.

  .EXAMPLE
  Invoke-GatherCallRecordReconciliation -CorpusGatherRecordsStagingPath 'C:\CorpusStaging' `
    -CorpusGatherRecordsPath 'C:\Corpus' -SprintNumber '0015' -ClosedSessionId 'session-a' `
    -MaximumSegmentAge ([timespan]::FromMinutes(15)) -MaximumSegmentBytes 1048576 `
    -AbandonedRemnantAge ([timespan]::FromHours(1)) -WhatIf

  Validates and reports the planned reconciliation without moving staged files.

  .NOTES
  This function intentionally contains no discovery, parsing, sealing, hashing,
  movement, or quarantine implementation.

  .LINK
  Invoke-GatherCallRecordStagingReconciliation
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$CorpusGatherRecordsStagingPath,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$CorpusGatherRecordsPath,

    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$SprintNumber,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string[]]$ClosedSessionId = @(),

    [Parameter(Mandatory = $true)]
    [timespan]$MaximumSegmentAge,

    [Parameter(Mandatory = $true)]
    [long]$MaximumSegmentBytes,

    [Parameter(Mandatory = $true)]
    [timespan]$AbandonedRemnantAge,

    [Parameter(Mandatory = $false)]
    [datetime]$NowUtc = [datetime]::UtcNow
  )

  begin {
    $fn = 'Invoke-GatherCallRecordReconciliation'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message 'Beginning public gather-call record reconciliation.' -Tag 'GatherCallRecord'
  }

  process {
    $arguments = @{
      SprintNumber = $SprintNumber
      ClosedSessionId = $ClosedSessionId
      MaximumSegmentAge = $MaximumSegmentAge
      MaximumSegmentBytes = $MaximumSegmentBytes
      AbandonedRemnantAge = $AbandonedRemnantAge
      NowUtc = $NowUtc
      WhatIf = [bool]$WhatIfPreference
      Confirm = $false
    }
    if ($PSBoundParameters.ContainsKey('CorpusGatherRecordsStagingPath')) {
      $arguments.CorpusGatherRecordsStagingPath = $CorpusGatherRecordsStagingPath
    }
    if ($PSBoundParameters.ContainsKey('CorpusGatherRecordsPath')) {
      $arguments.CorpusGatherRecordsPath = $CorpusGatherRecordsPath
    }

    $approved = $PSCmdlet.ShouldProcess(
      'gather-call record staging',
      'reconcile eligible segments and abandoned remnants')
    if (-not $approved -and -not $WhatIfPreference) {
      return
    }

    Invoke-GatherCallRecordStagingReconciliation @arguments
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message 'Finished public gather-call record reconciliation.' -Tag 'GatherCallRecord'
  }
}
