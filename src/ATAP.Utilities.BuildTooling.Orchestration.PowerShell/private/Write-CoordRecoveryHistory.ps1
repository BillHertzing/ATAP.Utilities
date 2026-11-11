function New-CoordRecoveryRecord {
  param([string]$Path, [System.Collections.IDictionary]$Record)
  $bytes = ConvertTo-CoordStateBytes (ConvertTo-CoordElement $Record)
  $stream = [IO.File]::Open($Path, 'CreateNew', 'Write', 'None')
  try { $stream.Write($bytes); $stream.Flush($true) } finally { $stream.Dispose() }
  if ((Get-CoordHash ([IO.File]::ReadAllBytes($Path))) -cne (Get-CoordHash $bytes)) { throw 'RecoveryHistoryReadbackFailed' }
  Get-CoordHash $bytes
}

function Write-CoordRecoveryHistory {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)][ValidateSet('Initialize','Resolve')][string]$Action,
    [ValidatePattern('\A[0-9a-f]{64}\z')][string]$ExpectedIntentDigest,
    [ValidateSet('Committed','Aborted')][string]$Outcome = 'Committed'
  )
  $root = Get-CoordRecoveryHistoryRoot
  if (-not $root) { throw 'RecoveryHistoryNotConfigured' }
  if (-not $PSCmdlet.ShouldProcess($root, "$Action retained recovery history")) { return }
  $lease = [IO.File]::Open((Join-Path $root 'history.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
  try {
    if ($Action -ceq 'Initialize') {
      if (@(Get-ChildItem -LiteralPath $root -Force | Where-Object Name -ne 'history.lock').Count) {
        throw 'RecoveryHistoryAlreadyExists'
      }
      $statePath = Join-Path (Get-CoordSetting 'OrchestrationStateRootPath') 'state.json'
      $custodyPath = Get-CoordSetting 'OrchestrationCustodyRecordPath'
      $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
      foreach ($path in $statePath, $custodyPath) { Assert-CoordProtection $path $sid }
      $state = [IO.File]::ReadAllBytes($statePath)
      $custody = [IO.File]::ReadAllBytes($custodyPath)
      $witness = Read-CoordJsonBytes $custody
      $record = Read-CoordJsonBytes $state
      if ($witness.GetProperty('custodianSid').GetString() -cne $sid -or
          $witness.GetProperty('stateSha256').GetString() -cne (Get-CoordHash $state) -or
          $witness.GetProperty('pendingWrite').ValueKind -ne [Text.Json.JsonValueKind]::Null) { throw 'RecoveryHistoryInitializationRequiresCoherentPair' }
      foreach ($key in 'resourceId','lineageId','generation') {
        if ($record.GetProperty($key).GetString() -cne $witness.GetProperty($key).GetString()) { throw 'RecoveryHistoryBindingMismatch' }
      }
      $binding = [ordered]@{
        kind = 'Coordination-recovery-history-v1'; host = [Environment]::MachineName; sid = $sid
        resourceId = $record.GetProperty('resourceId').GetString(); lineageId = $record.GetProperty('lineageId').GetString()
        statePath = [IO.Path]::GetFullPath($statePath); custodyPath = [IO.Path]::GetFullPath($custodyPath)
        pair = [ordered]@{ state = Get-CoordHash $state; custody = Get-CoordHash $custody }
      }
      $null = New-CoordRecoveryRecord (Join-Path $root 'binding.json') $binding
    } else {
      $history = Read-CoordRecoveryHistory $root
      if (-not $history.Pending -or $ExpectedIntentDigest -cne $history.Pending.Digest) { throw 'RecoveryHistoryResolutionBindingMismatch' }
      $pair = if ($Outcome -ceq 'Committed') { $history.Pending.Record.after } else { $history.Pending.Record.before }
      if ((Get-CoordHash ([IO.File]::ReadAllBytes($history.Binding.statePath))) -cne $pair.state -or
          (Get-CoordHash ([IO.File]::ReadAllBytes($history.Binding.custodyPath))) -cne $pair.custody) { throw 'RecoveryHistoryResolutionPairMismatch' }
      $name = '{0:D12}.receipt.json' -f [long]$history.Pending.Record.ordinal
      $null = New-CoordRecoveryRecord (Join-Path $root $name) ([ordered]@{
        intentDigest = $ExpectedIntentDigest; outcome = $Outcome
      })
    }
    Read-CoordRecoveryHistory $root
  } finally { $lease.Dispose() }
}

function Invoke-CoordHistoryReplace {
  param([string]$Path, [string]$StagePath)
  $root = Get-CoordRecoveryHistoryRoot
  if (-not $root) {
    [IO.File]::Replace($StagePath, $Path, [NullString]::Value)
    return
  }
  $statePath = Join-Path (Get-CoordSetting 'OrchestrationStateRootPath') 'state.json'
  $custodyPath = Get-CoordSetting 'OrchestrationCustodyRecordPath'
  if (-not $root -or ([IO.Path]::GetFullPath($Path) -ine $statePath -and
      [IO.Path]::GetFullPath($Path) -ine $custodyPath)) {
    [IO.File]::Replace($StagePath, $Path, [NullString]::Value)
    return
  }
  $lease = [IO.File]::Open((Join-Path $root 'history.lock'), 'Open', 'ReadWrite', 'None')
  try {
    $history = Read-CoordRecoveryHistory $root
    Assert-CoordRecoveryPair $history
    $after = [ordered]@{ state = $history.Pair.state; custody = $history.Pair.custody }
    $slot = if ([IO.Path]::GetFullPath($Path) -ieq $statePath) { 'state' } else { 'custody' }
    $after[$slot] = Get-CoordHash ([IO.File]::ReadAllBytes($StagePath))
    $ordinal = [long]$history.Ordinal + 1
    $intentDigest = New-CoordRecoveryRecord (Join-Path $root ('{0:D12}.intent.json' -f $ordinal)) ([ordered]@{
      ordinal = $ordinal; previousDigest = $history.Digest; before = $history.Pair; after = $after
    })
    [IO.File]::Replace($StagePath, $Path, [NullString]::Value)
    if ((Get-CoordHash ([IO.File]::ReadAllBytes($history.Binding.statePath))) -cne $after.state -or
        (Get-CoordHash ([IO.File]::ReadAllBytes($history.Binding.custodyPath))) -cne $after.custody) { throw 'RecoveryHistoryPairReadbackFailed' }
    $null = New-CoordRecoveryRecord (Join-Path $root ('{0:D12}.receipt.json' -f $ordinal)) ([ordered]@{
      intentDigest = $intentDigest; outcome = 'Committed'
    })
  } finally { $lease.Dispose() }
}

