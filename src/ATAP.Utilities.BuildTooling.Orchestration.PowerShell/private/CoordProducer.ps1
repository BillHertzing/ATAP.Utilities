function Get-CoordProgramDataPath {
  [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData)
}

function Get-CoordSetting {
  param([Parameter(Mandatory)][string]$Name)
  $key = $global:configRootKeys[$Name + 'ConfigRootKey']
  if ([string]::IsNullOrWhiteSpace($key) -or -not $global:settings.ContainsKey($key) -or $null -eq $global:settings[$key]) {
    throw "Missing coordination setting: $Name"
  }
  $global:settings[$key]
}

function Assert-CoordOrdinaryPath {
  param([Parameter(Mandatory)][string]$Path, [switch]$MustExist)
  $full = [IO.Path]::GetFullPath($Path)
  if ($full.StartsWith('\\', [StringComparison]::Ordinal)) { throw 'LocalPathRequired' }
  $part = $full
  while ($part) {
    if ($null -ne [IO.FileInfo]::new($part).LinkTarget) { throw 'RedirectedPath' }
    try {
      $attributes = [IO.File]::GetAttributes($part)
      if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { Assert-CoordCloudPlaceholder $part }
    } catch [IO.FileNotFoundException] {
      if ($MustExist -and $part -ceq $full) { throw 'MissingEstablishedState' }
    } catch [IO.DirectoryNotFoundException] {
      if ($MustExist -and $part -ceq $full) { throw 'MissingEstablishedState' }
    }
    $next = [IO.Path]::GetDirectoryName($part)
    if ($next -eq $part) { break }
    $part = $next
  }
  $full
}

function Test-CoordDescendant {
  param([string]$Path, [string]$Root)
  $p = [IO.Path]::GetFullPath($Path)
  $r = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
  $p.StartsWith($r + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-CoordCloudPlaceholder {
  # Same fixed read-only cloud-tag rule already used by Read-CoordBoard.
  param([Parameter(Mandatory)][string]$Path)
  if (-not $IsWindows) { throw 'RedirectedPath' }
  $command = Get-Command (Join-Path ([Environment]::SystemDirectory) 'fsutil.exe') -CommandType Application -ErrorAction Stop
  $lines = @(& $command reparsepoint query $Path 2>$null)
  if ($LASTEXITCODE -ne 0) { throw 'UnverifiedReparseMetadata' }
  $tags = @(foreach ($line in $lines) {
    $match = [regex]::Match([string]$line, '^\s*Reparse Tag Value\s*:\s*0x(?<tag>[0-9a-fA-F]{8})\s*$')
    if ($match.Success) { $match.Groups['tag'].Value }
  })
  if ($tags.Count -ne 1) { throw 'UnverifiedReparseMetadata' }
  $tag = [Convert]::ToUInt32($tags[0], 16)
  if (($tag -band [Convert]::ToUInt32('20000000', 16)) -ne 0 -or
      ($tag -band [Convert]::ToUInt32('FFFF0FFF', 16)) -ne [Convert]::ToUInt32('9000001A', 16)) { throw 'RedirectedPath' }
}

function Assert-CoordProtection {
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$CustodianSid)
  $null = Assert-CoordOrdinaryPath -Path $Path -MustExist
  $acl = Microsoft.PowerShell.Security\Get-Acl -LiteralPath $Path -ErrorAction Stop
  $allowed = @($CustodianSid, 'S-1-5-18', 'S-1-5-32-544')
  if ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -notin $allowed -or
      ([IO.Directory]::Exists($Path) -and -not $acl.AreAccessRulesProtected)) {
    throw 'UnprotectedCustody'
  }
  # Files may inherit from their verified protected parent; check their actual writers too.
  foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
    if ($rule.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and
        ($rule.FileSystemRights -band [Security.AccessControl.FileSystemRights]'Write,Delete,DeleteSubdirectoriesAndFiles,ChangePermissions,TakeOwnership') -ne 0 -and
        $rule.IdentityReference.Value -notin $allowed) { throw 'UnprotectedCustody' }
  }
}

function Read-CoordProducerContext {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$HolderId, [Parameter(Mandatory)][string]$SessionId,
    [ValidateSet('Submit', 'Clerk', 'Export')][string]$Role = 'Submit', [switch]$AllowPending)
  $ErrorActionPreference = 'Stop'
  $lease = $null; $boardLease = $null
  try {
    $stateRoot = [IO.Path]::GetFullPath((Get-CoordSetting 'OrchestrationStateRootPath'))
    $recordPath = [IO.Path]::GetFullPath((Get-CoordSetting 'OrchestrationCustodyRecordPath'))
    $programData = Get-CoordProgramDataPath
    if (-not (Test-CoordDescendant $stateRoot $programData) -or
        -not (Test-CoordDescendant $recordPath $programData) -or
        (Test-CoordDescendant $recordPath $stateRoot)) { throw 'CustodyLocationConflict' }
    $null = Assert-CoordOrdinaryPath $stateRoot -MustExist
    $null = Assert-CoordOrdinaryPath $recordPath -MustExist
    # The lease is outside replaceable state, under the protected witness parent.
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $recordDirectory = [IO.Path]::GetDirectoryName($recordPath)
    Assert-CoordProtection $recordDirectory $sid
    Assert-CoordProtection $recordPath $sid
    Assert-CoordProtection $stateRoot $sid
    $lease = Enter-CoordResourceLease -StateDirectory $recordDirectory
    $recordBytes = [IO.File]::ReadAllBytes($recordPath)
    $record = Read-CoordJsonBytes $recordBytes
    $r = ConvertFrom-CoordElement $record
    if ($r.schemaVersion -cne 'Coordination-custody-v1' -or $r.admissionMode -cne 'Established' -or $r.custodianSid -cne $sid) {
      throw 'CustodyNotEstablished'
    }
    $actors = @($r.actors | Where-Object { $_.holderId -ceq $HolderId -and $_.sessionId -ceq $SessionId -and $_.windowsSid -ceq $sid })
    if ($actors.Count -ne 1 -or $actors[0].role -cnotin @('Coordinator', 'Worker') -or
        ($Role -ne 'Submit' -and $actors[0].role -cne 'Coordinator')) { throw 'ActorNotAuthorized' }
    $statePath = [IO.Path]::GetFullPath($r.statePath)
    if ([IO.Path]::GetDirectoryName($statePath) -ine $stateRoot) { throw 'StateRootConflict' }
    $null = Assert-CoordOrdinaryPath $statePath -MustExist
    Assert-CoordProtection $statePath $sid
    $moduleRoot = if ((Split-Path $PSScriptRoot -Leaf) -ieq 'private') { Split-Path $PSScriptRoot -Parent } else { $PSScriptRoot }
    $manifest = Import-PowerShellDataFile (Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psd1')
    if ($r.package.moduleVersion -cne $manifest.ModuleVersion) { throw 'IncompatiblePackage' }
    $required = @(Get-ChildItem -LiteralPath $moduleRoot -File -Recurse | Where-Object {
      $_.Extension -in @('.ps1', '.psm1', '.psd1', '.json') -and -not (Test-CoordDescendant $_.FullName (Join-Path $moduleRoot 'tests')) })
    foreach ($file in $required) {
      $relative = [IO.Path]::GetRelativePath($moduleRoot, $file.FullName).Replace('\', '/')
      $pins = @($r.package.files | Where-Object { $_.path -ceq $relative })
      if ($pins.Count -ne 1 -or (Get-CoordHash ([IO.File]::ReadAllBytes($file.FullName))) -cne $pins[0].digest) { throw 'IncompatiblePackage' }
    }
    if ($r.pendingWrite -and -not $AllowPending) { throw 'NeedsRecovery' }
    $raw = [IO.File]::ReadAllBytes($statePath)
    if (-not $r.pendingWrite -and (Get-CoordHash $raw) -cne $r.stateSha256) { throw 'StateLossOrExternalReplacement' }
    $state = Read-CoordJsonBytes $raw
    if (-not (Test-Json -Json $state.GetRawText() -SchemaFile (Join-Path $moduleRoot 'schemas/state-v1.schema.json') -ErrorAction SilentlyContinue)) { throw 'InvalidState' }
    foreach ($name in @('resourceId', 'lineageId', 'generation')) {
      if ($state.GetProperty($name).GetString() -cne $r[$name]) { throw 'CustodyBindingConflict' }
    }
    $boardLockPath = [IO.Path]::GetFullPath($r.boardLockPath)
    $null = Assert-CoordOrdinaryPath $boardLockPath -MustExist
    $boardLease = [IO.File]::Open($boardLockPath, 'Open', 'ReadWrite', 'None')
    $limits = @{}
    foreach ($name in @('MaxRequestBytes', 'MaxBatchBytes', 'MaxBatchRequests', 'MaxDrainRequests', 'MaxDrainBatches', 'MaxDrainMilliseconds')) {
      $value = Get-CoordSetting ('Orchestration' + $name)
      if ($value -isnot [int] -and $value -isnot [long]) { throw 'InvalidCoordinationLimit' }
      if ([long]$value -le 0) { throw 'InvalidCoordinationLimit' }
      $limits[$name] = [long]$value
    }
    [pscustomobject]@{ Record = $r; RecordBytes = $recordBytes; RecordPath = $recordPath
      State = $state; StateBytes = $raw; StatePath = $statePath; Lease = $lease; BoardLease = $boardLease
      Actor = $actors[0]; Limits = $limits; ModuleRoot = $moduleRoot }
  } catch {
    if ($boardLease) { $boardLease.Dispose() }
    if ($lease) { $lease.Dispose() }
    throw
  }
}

function Write-CoordAtomicBytes {
  param([string]$Path, [byte[]]$ExpectedBytes, [byte[]]$Bytes)
  if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($Path)) -cne [Convert]::ToBase64String($ExpectedBytes)) { throw 'SnapshotMismatch' }
  $stage = $Path + '.stage-' + [guid]::NewGuid().ToString('N')
  $f = [IO.File]::Open($stage, 'CreateNew', 'Write', 'None')
  try { $f.Write($Bytes, 0, $Bytes.Length); $f.Flush($true) } finally { $f.Dispose() }
  [IO.File]::Replace($stage, $Path, [Management.Automation.Language.NullString]::Value)
  if ((Get-CoordHash ([IO.File]::ReadAllBytes($Path))) -cne (Get-CoordHash $Bytes)) { throw 'PersistenceFailed' }
}

function Save-CoordProducerState {
  # Protected pending image supports forward recovery of interrupted state writes.
  param($Context, [Text.Json.JsonElement]$State)
  $bytes = ConvertTo-CoordStateBytes $State
  if (-not (Test-Json -Json $State.GetRawText() -SchemaFile (Join-Path $Context.ModuleRoot 'schemas/state-v1.schema.json') -ErrorAction SilentlyContinue)) { throw 'InvalidState' }
  $Context.Record.pendingWrite = [ordered]@{ kind = 'State'; beforeDigest = Get-CoordHash $Context.StateBytes
    afterDigest = Get-CoordHash $bytes; afterBytesBase64 = [Convert]::ToBase64String($bytes) }
  $recordBytes = ConvertTo-CoordStateBytes (ConvertTo-CoordElement $Context.Record)
  Write-CoordAtomicBytes $Context.RecordPath $Context.RecordBytes $recordBytes
  $Context.RecordBytes = $recordBytes
  Write-CoordAtomicBytes $Context.StatePath $Context.StateBytes $bytes
  $Context.Record.stateSha256 = Get-CoordHash $bytes
  $Context.Record.pendingWrite = $null
  $final = ConvertTo-CoordStateBytes (ConvertTo-CoordElement $Context.Record)
  Write-CoordAtomicBytes $Context.RecordPath $Context.RecordBytes $final
  $Context.RecordBytes = $final; $Context.StateBytes = $bytes; $Context.State = $State.Clone()
}

function Get-CoordRequestGrant {
  param($Context, [Text.Json.JsonElement]$Request, [string]$Digest)
  $holder = $Request.GetProperty('holder')
  $registeredHolder = @($Context.Record.actors | Where-Object {
    $_.holderId -ceq $holder.GetProperty('holderId').GetString() -and
    $_.sessionId -ceq $holder.GetProperty('sessionId').GetString() -and $_.windowsSid -ceq $Context.Record.custodianSid })
  if ($registeredHolder.Count -ne 1) { throw 'AuthorityConflict' }
  $grant = @($Context.Record.authorizations | Where-Object {
    $_.reference -ceq $Request.GetProperty('authorizationReference').GetString() -and
    $_.requestId -ceq $Request.GetProperty('requestId').GetString() -and $_.digest -ceq $Digest })
  if ($grant.Count -ne 1 -or ($Request.GetProperty('category').GetString() -in @('Claim', 'AcceptChange') -and
      $Context.Actor.role -cne 'Coordinator')) { throw 'AuthorityConflict' }
  $grant[0]
}

function Assert-CoordPublishedHead {
  param($Context)
  if ($Context.State.GetProperty('mutationAdmission').GetProperty('status').GetString() -cne 'Admitted') { throw 'ResourceHeld' }
  foreach ($slot in @('markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml')) {
    $image = $Context.State.GetProperty('committedOutputManifest').GetProperty($slot)
    $path = $image.GetProperty('path').GetString()
    $null = Assert-CoordOrdinaryPath $path -MustExist
    if ((Get-CoordHash ([IO.File]::ReadAllBytes($path))) -cne $image.GetProperty('digest').GetString()) { throw 'ExternalBoardChange' }
  }
}
function Resolve-CoordScopeBindings {
  param([Text.Json.JsonElement]$State, [Text.Json.JsonElement]$Scope)
  $bindings = @()
  foreach ($entry in $Scope.EnumerateArray()) {
    $id = $entry.GetProperty('registeredRootId').GetString()
    $relative = $entry.GetProperty('path').GetString()
    $roots = @($State.GetProperty('registeredRoots').EnumerateArray() | Where-Object { $_.GetProperty('registeredRootId').GetString() -ceq $id })
    if ($roots.Count -ne 1 -or [IO.Path]::IsPathRooted($relative) -or $relative.Contains(':') -or $relative.Contains('~')) { throw 'ScopeConflict' }
    $root = Assert-CoordOrdinaryPath $roots[0].GetProperty('path').GetString() -MustExist
    $full = Assert-CoordOrdinaryPath ([IO.Path]::Combine($root, $relative))
    if (-not (Test-CoordDescendant $full $root) -and $full -ine $root) { throw 'ScopeEscape' }
    $volume = [IO.Path]::GetPathRoot($full)
    $bindings += [ordered]@{ registeredRootId = $id; path = $relative; registeredRootPath = $root
      identityDomain = $volume.ToUpperInvariant()
      segments = @($full.Substring($volume.Length).Split([char[]]@('\', '/'), [StringSplitOptions]::RemoveEmptyEntries))
      comparison = 'OrdinalIgnoreCase' }
  }
  return ,$bindings
}
