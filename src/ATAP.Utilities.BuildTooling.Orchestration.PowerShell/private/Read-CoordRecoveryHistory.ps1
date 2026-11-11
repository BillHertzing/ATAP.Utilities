function Get-CoordRecoveryHistoryRoot {
  # Opt-in for existing installations. The logon-task configuration must bind this
  # setting before recovery protection or restore can be accepted.
  $keys = Get-Variable configRootKeys -Scope Global -ValueOnly -ErrorAction SilentlyContinue
  $values = Get-Variable settings -Scope Global -ValueOnly -ErrorAction SilentlyContinue
  if ($null -eq $keys -or $null -eq $values) { return }
  $key = $keys['OrchestrationRecoveryHistoryRootPathConfigRootKey']
  if (-not $key -or -not $values.ContainsKey($key)) { return }
  $root = [IO.Path]::GetFullPath((Get-CoordSetting 'OrchestrationRecoveryHistoryRootPath'))
  for ($part = $root; $part; $part = [IO.Path]::GetDirectoryName($part)) {
    if ([IO.FileInfo]::new($part).LinkTarget -or
        ([uint32][IO.File]::GetAttributes($part) -band 0x00441400)) { throw 'RecoveryHistoryMustBeLocalResident' }
  }
  if ($root.StartsWith('\\', [StringComparison]::Ordinal)) { throw 'RecoveryHistoryMustBeLocalResident' }
  $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  Assert-CoordProtection $root $sid
  $stateRoot = [IO.Path]::GetFullPath((Get-CoordSetting 'OrchestrationStateRootPath'))
  $custodyRoot = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath((Get-CoordSetting 'OrchestrationCustodyRecordPath')))
  foreach ($protected in $stateRoot, $custodyRoot) {
    if ($root -ieq $protected -or (Test-CoordDescendant $root $protected) -or
        (Test-CoordDescendant $protected $root)) { throw 'RecoveryHistoryRestoreScopeConflict' }
  }
  $root
}

function Read-CoordRecoveryHistory {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Root)
  $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  Assert-CoordProtection $Root $sid
  $bindingPath = Join-Path $Root 'binding.json'
  Assert-CoordProtection $bindingPath $sid
  $bindingBytes = [IO.File]::ReadAllBytes($bindingPath)
  $binding = ConvertFrom-CoordElement (Read-CoordJsonBytes $bindingBytes)
  if ($binding.kind -cne 'Coordination-recovery-history-v1' -or $binding.sid -cne $sid -or
      $binding.host -ine [Environment]::MachineName -or
      $binding.statePath -ine (Join-Path (Get-CoordSetting 'OrchestrationStateRootPath') 'state.json') -or
      $binding.custodyPath -ine (Get-CoordSetting 'OrchestrationCustodyRecordPath')) { throw 'RecoveryHistoryBindingMismatch' }
  $head = $binding.pair
  $previous = Get-CoordHash $bindingBytes
  $ordinal = 0L
  $pending = $null
  $files = @(Get-ChildItem -LiteralPath $Root -File -Force | Where-Object Name -notin 'binding.json','history.lock' | Sort-Object Name)
  if ($files.Count -gt 200000) { throw 'RecoveryHistoryLimitExceeded' }
  foreach ($file in $files) {
    Assert-CoordProtection $file.FullName $sid
    if ($file.Name -cnotmatch '\A(?<ordinal>[0-9]{12})\.(?<type>intent|receipt)\.json\z') { throw 'RecoveryHistoryUnexpectedFile' }
    $number = [long]$Matches.ordinal
    $type = $Matches.type
    $bytes = [IO.File]::ReadAllBytes($file.FullName)
    $record = ConvertFrom-CoordElement (Read-CoordJsonBytes $bytes)
    if ($type -ceq 'intent') {
      if ($pending -or $number -ne $ordinal + 1 -or $record.ordinal -ne $number -or
          $record.previousDigest -cne $previous -or
          ($record.before | ConvertTo-Json -Compress) -cne ($head | ConvertTo-Json -Compress)) { throw 'RecoveryHistoryChainMismatch' }
      $pending = [pscustomobject]@{ Record = $record; Digest = Get-CoordHash $bytes }
    } else {
      if (-not $pending -or $number -ne $pending.Record.ordinal -or $record.intentDigest -cne $pending.Digest -or
          $record.outcome -cnotin 'Committed','Aborted') { throw 'RecoveryHistoryChainMismatch' }
      $head = if ($record.outcome -ceq 'Committed') { $pending.Record.after } else { $pending.Record.before }
      $previous = Get-CoordHash $bytes
      $ordinal = $number
      $pending = $null
    }
  }
  [pscustomobject]@{ Root = $Root; Binding = $binding; Pair = $head
    Ordinal = $ordinal; Digest = $previous; Pending = $pending }
}

function Assert-CoordRecoveryPair {
  param([Parameter(Mandatory)]$History)
  if ($History.Pending) { throw 'RecoveryHistoryInterruptedRequiresCustodian' }
  foreach ($entry in @(
      @{ Path = $History.Binding.statePath; Digest = $History.Pair.state },
      @{ Path = $History.Binding.custodyPath; Digest = $History.Pair.custody })) {
    $null = Assert-CoordOrdinaryPath $entry.Path -MustExist
    if ((Get-CoordHash ([IO.File]::ReadAllBytes($entry.Path))) -cne $entry.Digest) {
      throw 'RecoveryHistoryDetectsRestoredOrExternalPair'
    }
  }
}

