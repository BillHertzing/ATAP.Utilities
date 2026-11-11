BeforeDiscovery {
  $sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  $moduleName = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
  $promoted = [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
  $sourceManifest = Join-Path $sourceRoot ($moduleName + '.psd1')
  $manifest = if ($null -eq $promoted) { $sourceManifest } else { $promoted }
  if ([string]::IsNullOrWhiteSpace($manifest) -or -not [IO.Path]::IsPathFullyQualified($manifest) -or
      [Management.Automation.WildcardPattern]::ContainsWildcardCharacters($manifest) -or
      -not [string]::Equals([IO.Path]::GetFullPath($manifest), $manifest.Replace('/', '\'), [StringComparison]::OrdinalIgnoreCase)) { throw 'RecoveryTestManifestMustBeCanonical' }
  if ($null -ne $promoted -and [string]::Equals($manifest, $sourceManifest, [StringComparison]::OrdinalIgnoreCase)) { throw 'RecoveryPromotedManifestCannotBeSource' }
  for ($part = $manifest; $part; $part = [IO.Path]::GetDirectoryName($part)) {
    if ((Get-Item -LiteralPath $part -Force -ErrorAction Stop).LinkType) { throw 'RecoveryTestManifestCannotTraverseLinks' }
  }
  $item = Get-Item -LiteralPath $manifest -Force -ErrorAction Stop
  if ($item.PSIsContainer -or $item.Name -cne ($moduleName + '.psd1')) { throw 'RecoveryInvalidSelectedManifest' }
  $data = Import-PowerShellDataFile -LiteralPath $manifest
  $sourceVersion = (Import-PowerShellDataFile -LiteralPath $sourceManifest).ModuleVersion
  if ($data.RootModule -cne ($moduleName + '.psm1') -or $data.ModuleVersion -cne $sourceVersion) { throw 'RecoverySelectedModuleVersionMismatch' }
  $moduleBase = [IO.Path]::GetDirectoryName($manifest)
  $modulePath = Join-Path $moduleBase $data.RootModule
  $loaded = @(Get-Module -Name $moduleName -All)
  if ($loaded.Count -gt 1 -or @($loaded | Where-Object { $_.Path -ine $modulePath -or $_.Version -ne [version]$data.ModuleVersion }).Count) { throw 'RecoveryConflictingLoadedModule' }
  $selected = if ($loaded.Count) { $loaded[0] } else { Import-Module -Name $manifest -PassThru -ErrorAction Stop }
  if ($selected.Name -cne $moduleName -or $selected.Path -ine $modulePath -or $selected.ModuleBase -ine $moduleBase -or $selected.Version -ne [version]$data.ModuleVersion) { throw 'RecoverySelectedModuleIdentityMismatch' }
  & $selected {
    param($binding)
    $script:recoveryTestBinding = $binding
  } ([pscustomobject]@{ Module = $selected; ModuleBase = $moduleBase; ModulePath = $modulePath; Promoted = ($null -ne $promoted) })
  $script:recoveryTestModuleName = $moduleName
}

InModuleScope -ModuleName $script:recoveryTestModuleName {
Describe 'Filesystem recovery on disposable targets' -Tag 'Integration','CoordRestore' {
  BeforeAll {
    Import-Module PSFramework -RequiredVersion 1.14.457 -ErrorAction Stop
    $current = @(Get-Module -Name $script:recoveryTestBinding.Module.Name -All)
    if ($current.Count -ne 1 -or -not [object]::ReferenceEquals($current[0], $script:recoveryTestBinding.Module)) { throw 'RecoverySelectedModuleChanged' }
    $script:moduleRoot = $script:recoveryTestBinding.ModuleBase
    foreach ($name in 'Export-CoordState','Restore-CoordState','Submit-CoordRequest','Read-CoordRecoveryHistory','Write-CoordRecoveryHistory','Write-CoordRestoreImage','Assert-CoordOrdinaryPath','Test-CoordDescendant') {
      $command = Get-Command -Name $name -CommandType Function -ErrorAction Stop
      if ($null -eq $command.Module -or $command.Module.Path -ine $script:recoveryTestBinding.ModulePath -or
          -not [IO.Path]::GetFullPath($command.ScriptBlock.File).StartsWith($moduleRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
          ($script:recoveryTestBinding.Promoted -and $command.ScriptBlock.File -ine $script:recoveryTestBinding.ModulePath)) { throw 'RecoverySelectedFunctionIdentityMismatch' }
    }
    $script:sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $script:oldSettings = $global:settings
    $script:oldKeys = $global:configRootKeys
    $defaultFixtureRoot = switch ([Environment]::MachineName.ToUpperInvariant()) {
      'UTAT022' { 'D:/ATAPArtifacts/_generated/Sprint0017/stream-c-filesystem-recovery-module-20261110/SourceFixtures' }
      'UTAT01' { 'C:/ATAPArtifacts/_generated/Sprint0017/stream-c-filesystem-recovery-module-20261110/SourceFixtures' }
      default { throw 'Unknown recovery fixture host; an approved artifact mapping is required.' }
    }
    $fixtureRoot = if ([string]::IsNullOrWhiteSpace($env:COORD_RECOVERY_FIXTURE_ROOT)) { $defaultFixtureRoot } else { $env:COORD_RECOVERY_FIXTURE_ROOT }
    if (-not [IO.Path]::IsPathFullyQualified($fixtureRoot) -or $fixtureRoot.StartsWith('\\', [StringComparison]::Ordinal)) { throw 'RecoveryFixtureRequiresLocalAbsolutePath' }
    $script:fixtureBase = [IO.Path]::GetFullPath($fixtureRoot)
    $assignedRoot = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($defaultFixtureRoot))
    if ($fixtureBase -ine $assignedRoot -and -not (Test-CoordDescendant $fixtureBase $assignedRoot)) { throw 'RecoveryFixtureOutsideAssignedRoot' }
    # The existing helper rejects link targets and recognizes valid CloudFiles
    # placeholders; a CloudFiles reparse tag alone is not a refusal.
    $script:fixtureBase = Assert-CoordOrdinaryPath $fixtureBase
    function Protect-RecoveryFixture([string]$Path) {
      $acl = Get-Acl -LiteralPath $Path
      $acl.SetOwner([Security.Principal.SecurityIdentifier]::new($sid))
      $acl.SetAccessRuleProtection($true, $false)
      foreach ($rule in @($acl.GetAccessRules($true, $false, [Security.Principal.SecurityIdentifier]))) { $acl.RemoveAccessRuleSpecific($rule) }
      foreach ($who in $sid,'S-1-5-18','S-1-5-32-544') {
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($who),'FullControl','ContainerInherit,ObjectInherit','None','Allow'))
      }
      Set-Acl -LiteralPath $Path -AclObject $acl
    }
    function Write-RecoveryJson([string]$Path, $Value) {
      [IO.File]::WriteAllBytes($Path, (ConvertTo-CoordStateBytes (ConvertTo-CoordElement $Value)))
    }
    function New-RecoveryFixture {
      $script:root = Join-Path $fixtureBase ([guid]::NewGuid().ToString('N'))
      $script:fakeProgramData = Join-Path $root 'ProgramData'
      $script:stateRoot = Join-Path $fakeProgramData 'State'
      $script:custodyRoot = Join-Path $fakeProgramData 'Custody'
      $script:backupRoot = Join-Path $fakeProgramData 'Backup'
      $script:historyRoot = Join-Path $fakeProgramData 'RecoveryHistory'
      $script:boardRoot = Join-Path $root 'Board'
      foreach ($directory in $stateRoot,$custodyRoot,$backupRoot,$historyRoot,$boardRoot) {
        $null = [IO.Directory]::CreateDirectory($directory)
        Protect-RecoveryFixture $directory
      }
      $script:statePath = Join-Path $stateRoot 'state.json'
      $script:custodyPath = Join-Path $custodyRoot 'custody.json'
      $manifest = [ordered]@{}
      foreach ($slot in 'markdown','boardHtml','proceduralDetailsHtml','accomplishedHtml') {
        $path = Join-Path $boardRoot "$slot.bin"
        $bytes = [Text.Encoding]::UTF8.GetBytes("fixture $slot")
        [IO.File]::WriteAllBytes($path,$bytes)
        $manifest[$slot] = @{path=$path;digest=Get-CoordHash $bytes}
      }
      $lockPath = Join-Path $boardRoot 'board.lock'
      [IO.File]::WriteAllBytes($lockPath,[byte[]]@())
      $reference = @{reference='admitted-fixture';digest=('0'*64)}
      $request = [ordered]@{
        protocolVersion='Coordination-v1';resourceId='restore-fixture';sprintId='0017'
        requestId='original-request';category='Claim';taskId='17.31.c'
        scope=@(@{registeredRootId='fixture';path='work.ps1'})
        holder=@{holderId='Coordinator';sessionId='session-1'}
        authorizationReference='original-grant';generation='epoch-1';expectedRevision='head-1'
        predecessors=@();payload=@{}
      }
      $draft = [Text.Encoding]::UTF8.GetBytes((@{request=$request;digest=('0'*64)} | ConvertTo-Json -Depth 20 -Compress))
      $canonical = ConvertTo-CoordCanonicalRequest -EnvelopeBytes $draft -MaxRequestBytes 65536 -DeferDigestComparison
      $script:envelope = [Text.Encoding]::UTF8.GetBytes((@{request=$request;digest=$canonical.Digest} | ConvertTo-Json -Depth 20 -Compress))
      $script:state = [ordered]@{
        schemaVersion='Coordination-state-v1';resourceId='restore-fixture';lineageId='lineage-1'
        registeredRoots=@(@{registeredRootId='fixture';path=$boardRoot});generation='epoch-1'
        committedRevision='head-1';committedOutputManifest=$manifest;custodyEvidence=$reference
        compatibilityEvidence=$reference;admissionEvidence=@($reference)
        requests=@(@{request=$request;digest=$canonical.Digest;originalRequestJson=($request | ConvertTo-Json -Depth 20 -Compress)
          queueOrdinal='0';status='Pending';pendingEvidence=@{reason='Eligible'}})
        claims=@(@{claimId='retained-claim';resourceId='restore-fixture';taskId='17.31.c';scope=$request.scope
          holder=$request.holder;generation='epoch-1';claimRequestId='earlier-claim'})
        reservations=@(@{reservationId='retained-reservation';resourceId='restore-fixture';requestId='unpublished'
          taskId='17.31.c';scope=$request.scope;generation='epoch-1'})
        preparedOperations=@();commitReceipts=@()
        mutationAdmission=@{status='Admitted';reason='Disposable';observedOutputs=@()}
      }
      Write-RecoveryJson $statePath $state
      $pins = @(Get-ChildItem -LiteralPath $moduleRoot -File -Recurse | Where-Object {
        $_.Extension -in '.ps1','.psm1','.psd1','.json' -and -not (Test-CoordDescendant $_.FullName (Join-Path $moduleRoot 'tests'))
      } | ForEach-Object { @{path=[IO.Path]::GetRelativePath($moduleRoot,$_.FullName).Replace('\','/');digest=Get-CoordHash ([IO.File]::ReadAllBytes($_.FullName))} })
      $script:witness = [ordered]@{
        schemaVersion='Coordination-custody-v1';admissionMode='Established';custodianSid=$sid
        resourceId='restore-fixture';lineageId='lineage-1';generation='epoch-1';sprintId='0017'
        coordinatorId='Coordinator';statePath=$statePath;stateSha256=Get-CoordHash ([IO.File]::ReadAllBytes($statePath))
        pendingWrite=$null;boardLockPath=$lockPath;actors=@(@{holderId='Coordinator';sessionId='session-1';windowsSid=$sid;role='Coordinator'})
        authorizations=@();existingTasks=@(@{taskId='17.31.c';ancestorTaskIds=@()})
        package=@{moduleVersion=(Import-PowerShellDataFile (Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psd1')).ModuleVersion;files=$pins}
      }
      Write-RecoveryJson $custodyPath $witness
      $global:configRootKeys = @{}
      $global:settings = @{}
      $values = @{
        StateRootPath=$stateRoot;CustodyRecordPath=$custodyPath;ProtectedBackupRootPath=$backupRoot
        RecoveryHistoryRootPath=$historyRoot;SevenZipPath='C:/Program Files/7-Zip/7z.exe'
        SevenZipSha256='DC0493429FE28136FCB177A0E77C9875CBB3B0BFF5F2F8EEBA4DF302E98CEF76'
        MaxRequestBytes=65536;MaxBatchBytes=262144;MaxBatchRequests=8;MaxDrainRequests=16;MaxDrainBatches=8;MaxDrainMilliseconds=10000
      }
      foreach ($name in $values.Keys) {
        $key='Orchestration'+$name
        $global:configRootKeys[$key+'ConfigRootKey']=$key
        $global:settings[$key]=$values[$name]
      }
      $null = Write-CoordRecoveryHistory -Action Initialize -Confirm:$false
    }
    function Export-RecoveryFixture([switch]$NoCompression) {
      Export-CoordState -HolderId Coordinator -SessionId session-1 -DestinationPath (Join-Path $backupRoot ([guid]::NewGuid().ToString('N'))) -NoCompression:$NoCompression -Confirm:$false
    }
    function Restore-RecoveryFixture($Export) {
      Restore-CoordState -BundlePath $Export.Path -ExpectedSha256 $Export.Digest -ExpectedResourceId restore-fixture -ExpectedLineageId lineage-1 -ExpectedGeneration epoch-1 -ExpectedCommittedRevision head-1 -Confirm:$false
    }
    function Park-RecoveryImages {
      # Retain old physical images separately. Clean targets use the original
      # absolute names to preserve immutable request and prepared-plan bindings.
      $parked = Join-Path $root 'RetainedOldImages'
      $null = [IO.Directory]::CreateDirectory($parked)
      $paths = @($statePath,$custodyPath)+@($state.committedOutputManifest.Values | ForEach-Object path)
      foreach ($path in $paths) { [IO.File]::Move($path,(Join-Path $parked ([IO.Path]::GetFileName($path)))) }
    }
  }
  BeforeEach {
    New-RecoveryFixture
    Mock Get-CoordProgramDataPath { $script:fakeProgramData }
  }
  AfterAll {
    $global:settings=$script:oldSettings
    $global:configRootKeys=$script:oldKeys
  }
  It 'roundtrips raw and default 7-Zip bundles preserving claims, reservations and original-request retry' {
    foreach ($plain in $true,$false) {
      $export = Export-RecoveryFixture -NoCompression:$plain
      $export.Format | Should -BeExactly $(if ($plain) {'JSON'} else {'ZIP'})
      $before = Get-CoordHash ([IO.File]::ReadAllBytes($statePath))
      Park-RecoveryImages
      (Restore-RecoveryFixture $export).Status | Should -BeExactly 'RestoredHeld'
      (Get-CoordHash ([IO.File]::ReadAllBytes($statePath))) | Should -BeExactly $before
      (Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false).Decision | Should -BeExactly 'Retained'
      $loaded = [IO.File]::ReadAllText($statePath) | ConvertFrom-Json
      $loaded.claims.Count | Should -Be 1
      $loaded.reservations.Count | Should -Be 1
      $loaded.requests.Count | Should -Be 1
      New-RecoveryFixture
    }
  }
  It 'refuses a corrupt archive or bundle before destination writes' {
    $export = Export-RecoveryFixture
    Park-RecoveryImages
    $bytes = [IO.File]::ReadAllBytes($export.Path)
    $bytes[0] = 0
    [IO.File]::WriteAllBytes($export.Path,$bytes)
    { Restore-RecoveryFixture $export } | Should -Throw '*BundleDigestMismatch*'
    Test-Path -LiteralPath $statePath | Should -BeFalse
    $export.Digest = Get-CoordHash $bytes
    { Restore-RecoveryFixture $export } | Should -Throw
    Test-Path -LiteralPath $custodyPath | Should -BeFalse
  }
  It 'rejects escaping ZIP entries and bounded expansion' {
    $archive = Join-Path $backupRoot 'escape.zip'
    $memory=[IO.MemoryStream]::new()
    $zip=[IO.Compression.ZipArchive]::new($memory,'Create',$true)
    $entry=$zip.CreateEntry('../bundle.json')
    $writer=[IO.StreamWriter]::new($entry.Open())
    $writer.Write('{}');$writer.Dispose();$zip.Dispose()
    [IO.File]::WriteAllBytes($archive,$memory.ToArray());$memory.Dispose()
    { Read-CoordRecoveryBundle -Path $archive -ExpectedSha256 (Get-CoordHash ([IO.File]::ReadAllBytes($archive))) } | Should -Throw '*UnexpectedArchiveEntry*'
    $export=Export-RecoveryFixture
    { Read-CoordRecoveryBundle -Path $export.Path -ExpectedSha256 $export.Digest -MaxBundleBytes 8 } | Should -Throw '*BundleByteLimitExceeded*'
  }
  It 'detects old restored custody through the normal producer entry point' {
    $old=[IO.File]::ReadAllBytes($custodyPath)
    $text=[Text.Encoding]::UTF8.GetString($old).Replace('"session-1"','"session-2"')
    Write-CoordAtomicBytes $custodyPath $old ([Text.Encoding]::UTF8.GetBytes($text))
    [IO.File]::WriteAllBytes($custodyPath,$old)
    { Export-RecoveryFixture -NoCompression } | Should -Throw '*RecoveryHistoryDetectsRestoredOrExternalPair*'
    (Read-CoordRecoveryHistory $historyRoot).Ordinal | Should -Be 1
  }
  It 'holds interrupted history and resolves only the pinned observed pair' {
    $history=Read-CoordRecoveryHistory $historyRoot
    $after=[ordered]@{state=$history.Pair.state;custody=('a'*64)}
    $digest=New-CoordRecoveryRecord (Join-Path $historyRoot '000000000001.intent.json') ([ordered]@{
      ordinal=1;previousDigest=$history.Digest;before=$history.Pair;after=$after
    })
    { Assert-CoordRecoveryPair (Read-CoordRecoveryHistory $historyRoot) } | Should -Throw '*Interrupted*'
    { Write-CoordRecoveryHistory -Action Resolve -ExpectedIntentDigest ('b'*64) -Outcome Aborted -Confirm:$false } | Should -Throw '*BindingMismatch*'
    $resolved=Write-CoordRecoveryHistory -Action Resolve -ExpectedIntentDigest $digest -Outcome Aborted -Confirm:$false
    $resolved.Ordinal | Should -Be 1
    Assert-CoordRecoveryPair $resolved
  }
  It 'preserves a prepared plan and terminal result with exact retry identity' {
    $logical=[ordered]@{}
    foreach($field in 'schemaVersion','resourceId','lineageId','registeredRoots','generation','committedRevision',
        'committedOutputManifest','custodyEvidence','compatibilityEvidence','admissionEvidence','requests','claims','reservations','mutationAdmission') {
      $logical[$field]=$state[$field]
    }
    $logicalBytes=ConvertTo-CoordStateBytes (ConvertTo-CoordElement $logical)
    $images=[ordered]@{}
    foreach($slot in $state.committedOutputManifest.Keys) {
      $path=$state.committedOutputManifest[$slot].path
      $bytes=[IO.File]::ReadAllBytes($path)
      $images[$slot]=@{path=$path;digest=Get-CoordHash $bytes;bytesBase64=[Convert]::ToBase64String($bytes)}
    }
    $operation=@{
      operationId='retained-operation';resourceId='restore-fixture';status='Prepared'
      baseHead=@{generation='epoch-1';committedRevision='head-1';outputManifest=$state.committedOutputManifest}
      nextRevision='head-2';requestIds=@('original-request')
      beforeStateImage=@{bytesBase64=[Convert]::ToBase64String($logicalBytes);digest=Get-CoordHash $logicalBytes}
      afterStateImage=@{bytesBase64=[Convert]::ToBase64String($logicalBytes);digest=Get-CoordHash $logicalBytes}
      beforeOutputs=$images;afterOutputs=$images;outputManifest=$state.committedOutputManifest;reservations=@()
    }
    $state.preparedOperations=@($operation)
    $state.requests[0].Remove('pendingEvidence')
    $state.requests[0].status='Prepared'
    $state.requests[0].preparedOperationId='retained-operation'
    $terminalRequest=$state.requests[0].request | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
    $terminalRequest.requestId='old-rejection'
    $terminalJson=$terminalRequest | ConvertTo-Json -Depth 20 -Compress
    $terminalDraft=[Text.Encoding]::UTF8.GetBytes((@{request=$terminalRequest;digest=('0'*64)} | ConvertTo-Json -Depth 20 -Compress))
    $terminalDigest=(ConvertTo-CoordCanonicalRequest -EnvelopeBytes $terminalDraft -MaxRequestBytes 65536 -DeferDigestComparison).Digest
    $state.requests+=@{
      request=$terminalRequest;digest=$terminalDigest;originalRequestJson=$terminalJson;queueOrdinal='1';status='Rejected'
      terminalEvidence=@{resourceId='restore-fixture';requestId='old-rejection';digest=$terminalDigest;status='Rejected';reason='Retained'
        receipt=@{reference='retained-rejection';digest=('2'*64)}}
    }
    $before=[IO.File]::ReadAllBytes($statePath)
    $after=ConvertTo-CoordStateBytes (ConvertTo-CoordElement $state)
    Write-CoordAtomicBytes $statePath $before $after
    $witness.stateSha256=Get-CoordHash $after
    Write-CoordAtomicBytes $custodyPath ([IO.File]::ReadAllBytes($custodyPath)) (ConvertTo-CoordStateBytes (ConvertTo-CoordElement $witness))
    $export=Export-RecoveryFixture
    Park-RecoveryImages
    $null=Restore-RecoveryFixture $export
    (Get-CoordHash ([IO.File]::ReadAllBytes($statePath))) | Should -BeExactly (Get-CoordHash $after)
    $restored=[IO.File]::ReadAllText($statePath) | ConvertFrom-Json
    $restored.preparedOperations[0].status | Should -BeExactly Prepared
    $restored.requests[1].status | Should -BeExactly Rejected
    (Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false).Decision | Should -BeExactly Retained
  }
  It 'preserves a pending state journal exactly across export and restore' {
    $before=[IO.File]::ReadAllBytes($statePath)
    $script:state.mutationAdmission.reason='retained pending state'
    $after=ConvertTo-CoordStateBytes (ConvertTo-CoordElement $state)
    $witness.pendingWrite=@{kind='State';beforeDigest=Get-CoordHash $before;afterDigest=Get-CoordHash $after;afterBytesBase64=[Convert]::ToBase64String($after)}
    Write-CoordAtomicBytes $custodyPath ([IO.File]::ReadAllBytes($custodyPath)) (ConvertTo-CoordStateBytes (ConvertTo-CoordElement $witness))
    $export=Export-RecoveryFixture -NoCompression
    $pin=Get-CoordHash ([IO.File]::ReadAllBytes($custodyPath))
    Park-RecoveryImages
    $null=Restore-RecoveryFixture $export
    (Get-CoordHash ([IO.File]::ReadAllBytes($custodyPath))) | Should -BeExactly $pin
    ([IO.File]::ReadAllText($custodyPath) | ConvertFrom-Json).pendingWrite.kind | Should -BeExactly State
  }
  It 'rejects a replaced restore receipt without changing the restored pair' {
    $export=Export-RecoveryFixture -NoCompression
    Park-RecoveryImages
    $restored=Restore-RecoveryFixture $export
    $before=Get-CoordHash ([IO.File]::ReadAllBytes($statePath))
    [IO.File]::WriteAllText($restored.ReceiptPath,'{}')
    { Restore-RecoveryFixture $export } | Should -Throw '*RestoreReceiptMismatch*'
    (Get-CoordHash ([IO.File]::ReadAllBytes($statePath))) | Should -BeExactly $before
  }
  It 'reuses only the same restore intent and refuses destination drift' {
    $export=Export-RecoveryFixture -NoCompression
    Park-RecoveryImages
    $script:interruptRestore = $true
    $script:originalImageWriter = ${function:Write-CoordRestoreImage}
    Mock Write-CoordRestoreImage { & $script:originalImageWriter -Path $Path -Bytes $Bytes -Digest $Digest }
    Mock Write-CoordRestoreImage { throw 'SimulatedRestoreInterruption' } -ParameterFilter {
      $script:interruptRestore -and $Path -eq $script:custodyPath
    }
    { Restore-RecoveryFixture $export } | Should -Throw '*SimulatedRestoreInterruption*'
    Test-Path -LiteralPath $statePath | Should -BeTrue
    Test-Path -LiteralPath $custodyPath | Should -BeFalse
    $script:interruptRestore = $false
    (Restore-RecoveryFixture $export).Resumed | Should -BeTrue
    [IO.File]::WriteAllText($statePath,'wrong image')
    { Restore-RecoveryFixture $export } | Should -Throw '*RestoreDestinationNotClean*'
  }
}
}

