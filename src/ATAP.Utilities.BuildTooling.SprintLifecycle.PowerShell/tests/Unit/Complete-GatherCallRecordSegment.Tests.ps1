#Requires -Version 7.0

<#
  Focused regression suite for Task 15.191.c.sealing.

  Every fixture is disposable and beneath $TestDrive. The suite does not create or
  inspect live corpus roots, mutate volumes, or discover aged remnants. ACL checks are
  limited to disposable files beneath $TestDrive.
#>

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param(
        [string]$FunctionName,
        [string]$ModuleName,
        [string]$Level,
        [string]$Message,
        [string]$Tag
      )
    }
    $script:CreatedWritePsfTestDouble = $true
  }

  if (-not (Get-Command Get-PVal -ErrorAction SilentlyContinue)) {
    function global:Get-PVal { throw 'Get-PVal test double was not configured.' }
    $script:CreatedGetPValTestDouble = $true
  }

  $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:helperPath = Join-Path $script:moduleRoot 'private\Set-CorpusFileSystemAcl.ps1'
  $script:functionPath = Join-Path $script:moduleRoot 'public\Complete-GatherCallRecordSegment.ps1'
  . $script:helperPath
  . $script:functionPath
  $script:captureSid = 'S-1-5-19'
  $script:expirySid = 'S-1-5-20'

  function New-SealingFixture {
    param([string]$Name)
    $root = Join-Path $TestDrive "$Name-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $staging = Join-Path $root 'CorpusGatherRecordsStaging'
    $corpus = Join-Path $root 'CorpusGatherRecords'
    New-Item -ItemType Directory -Path $staging, $corpus -Force | Out-Null
    [pscustomobject]@{ Root = $root; Staging = $staging; Corpus = $corpus }
  }

  function New-GatherRecord {
    param(
      [string]$InvocationId = ([guid]::NewGuid().ToString().ToLowerInvariant()),
      [string]$RecordVersion = '1.0.0'
    )
    [ordered]@{
      recordVersion = $RecordVersion
      invocationId = $InvocationId
      requestResponsePairId = $null
      ordinal = 1
      ordinalScope = 'file'
      timestampUtc = '2026-09-12T20:15:10.482Z'
      agentName = 'junior-dev-coder-sh'
      agentModel = $null
      sessionId = $null
      taskId = '15.191.c'
      worktreePath = 'C:/fixture/worktree'
      repositoryName = 'ATAP.Utilities'
      conversationId = $null
      conversationTitle = $null
    }
  }

  function Write-TestSegment {
    param(
      [string]$Path,
      [object[]]$Records = @((New-GatherRecord)),
      [switch]$NoFinalNewline,
      [switch]$Bom
    )
    $lines = @($Records | ForEach-Object {
        if ($_ -is [string]) { $_ } else { $_ | ConvertTo-Json -Compress -Depth 8 }
      })
    $text = $lines -join "`n"
    if (-not $NoFinalNewline) { $text += "`n" }
    $encoding = [System.Text.UTF8Encoding]::new([bool]$Bom)
    [System.IO.File]::WriteAllText($Path, $text, $encoding)
  }

  function Invoke-Sealer {
    param(
      [string]$Source,
      [string]$Staging,
      [object]$Corpus,
      [switch]$Quarantine,
      [switch]$WhatIf
    )
    $arguments = @{
      StagingFilePath = $Source
      CorpusGatherRecordsStagingPath = $Staging
      CorpusGatherRecordsPath = $Corpus
      SprintNumber = '0015'
      QuarantineInvalidRemnant = $Quarantine
      CaptureIdentity = $script:captureSid
      ExpiryIdentity = $script:expirySid
    }
    if ($WhatIf) { $arguments.WhatIf = $true }
    Complete-GatherCallRecordSegment @arguments
  }
}

AfterAll {
  if ($script:CreatedGetPValTestDouble) {
    Remove-Item -LiteralPath 'Function:\Get-PVal' -ErrorAction SilentlyContinue
  }
  if ($script:CreatedWritePsfTestDouble) {
    Remove-Item -LiteralPath 'Function:\Write-PSFMessage' -ErrorAction SilentlyContinue
  }
}

Describe 'Complete-GatherCallRecordSegment [public]' -Tag 'Unit' {
  Context 'Command and load surface' {
    It 'defines only the eponymous advanced function and supports ShouldProcess' {
      $command = Get-Command Complete-GatherCallRecordSegment -CommandType Function
      $command.CmdletBinding | Should -BeTrue
      $command.Parameters.Keys | Should -Contain 'WhatIf'
      $command.Parameters.Keys | Should -Contain 'Confirm'

      $tokens = $null
      $errors = $null
      $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $script:functionPath, [ref]$tokens, [ref]$errors)
      $errors | Should -BeNullOrEmpty
      @($ast.EndBlock.Statements | Where-Object {
          $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst]
        }) | Should -BeNullOrEmpty
    }

    It 'uses PSFramework logging and the non-overwriting two-argument File.Move overload' {
      $source = Get-Content -LiteralPath $script:functionPath -Raw
      $source | Should -Match 'Write-PSFMessage'
      $source | Should -Not -Match 'Write-Host|Copy-Item|File\]::Copy'
      $source | Should -Match '\[System\.IO\.File\]::Move\(\$sourcePath, \$destinationPath\)'
    }
  }

  Context 'Successful sealing' {
    It 'moves to the exact sprint partition and returns exact counts and equal hashes' {
      $fixture = New-SealingFixture 'success'
      $source = Join-Path $fixture.Staging 'segment-a.jsonl'
      $records = @((New-GatherRecord), (New-GatherRecord))
      Write-TestSegment -Path $source -Records $records
      $expectedBytes = (Get-Item -LiteralPath $source).Length
      $expectedHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus
      $expectedDestination = Join-Path $fixture.Corpus 'sprint-0015\segment-a.jsonl'

      $result.Ok | Should -BeTrue
      $result.Validation.Succeeded | Should -BeTrue
      $result.Movement.Planned | Should -BeTrue
      $result.Movement.Performed | Should -BeTrue
      $result.Movement.SameVolume | Should -BeTrue
      $result.Counts.RecordCount | Should -Be 2
      $result.Counts.ByteCount | Should -Be $expectedBytes
      $result.Hashes.BeforeMove | Should -Be $expectedHash
      $result.Hashes.AfterMove | Should -Be $expectedHash
      $result.Hashes.Match | Should -BeTrue
      $result.Acl.Planned | Should -BeTrue
      $result.Acl.Applied | Should -BeTrue
      $result.Acl.Verified | Should -BeTrue
      $result.Destination.Path | Should -Be ([System.IO.Path]::GetFullPath($expectedDestination))
      Test-Path -LiteralPath $source | Should -BeFalse
      Test-Path -LiteralPath $expectedDestination -PathType Leaf | Should -BeTrue
    }

    It 'resolves omitted roots only through both exact Get-PVal keys' {
      $fixture = New-SealingFixture 'get-pval'
      $source = Join-Path $fixture.Staging 'segment-setting.jsonl'
      Write-TestSegment -Path $source
      Mock Get-PVal {
        param($ParameterName, $originalPSBoundParameters, $dottedPath)
        if ($ParameterName -ne $dottedPath) { throw 'mismatched exact key' }
        if ($ParameterName -eq 'CorpusGatherRecordsStagingPath') { return $fixture.Staging }
        if ($ParameterName -eq 'CorpusGatherRecordsPath') { return $fixture.Corpus }
        throw "unexpected key $ParameterName"
      }

      $result = Complete-GatherCallRecordSegment -StagingFilePath $source -SprintNumber '0015' `
        -CaptureIdentity $script:captureSid -ExpiryIdentity $script:expirySid

      $result.Ok | Should -BeTrue
      Should -Invoke Get-PVal -Exactly 1 -ParameterFilter {
        $ParameterName -eq 'CorpusGatherRecordsStagingPath' -and
        $dottedPath -eq 'CorpusGatherRecordsStagingPath'
      }
      Should -Invoke Get-PVal -Exactly 1 -ParameterFilter {
        $ParameterName -eq 'CorpusGatherRecordsPath' -and
        $dottedPath -eq 'CorpusGatherRecordsPath'
      }
    }
  }

  Context 'Immutable artifact ACL transition' {
    It 'preserves the hardened descriptor across the same-volume move and removes capture modify/delete' -Skip:(-not $IsWindows) {
      $fixture = New-SealingFixture 'acl-preserve'
      $source = Join-Path $fixture.Staging 'acl-preserve.jsonl'
      Write-TestSegment -Path $source

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus
      $destinationAcl = Get-Acl -LiteralPath $result.Destination.Path
      $rules = @($destinationAcl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))
      $captureRules = @($rules | Where-Object { $_.IdentityReference.Value -eq $script:captureSid })
      $expiryRules = @($rules | Where-Object { $_.IdentityReference.Value -eq $script:expirySid })

      $result.Ok | Should -BeTrue
      $destinationAcl.Sddl | Should -Be $result.Acl.AfterSddl
      $dangerous = [Security.AccessControl.FileSystemRights]::WriteData -bor
        [Security.AccessControl.FileSystemRights]::AppendData -bor
        [Security.AccessControl.FileSystemRights]::WriteAttributes -bor
        [Security.AccessControl.FileSystemRights]::WriteExtendedAttributes -bor
        [Security.AccessControl.FileSystemRights]::Delete -bor
        [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
        [Security.AccessControl.FileSystemRights]::ChangePermissions -bor
        [Security.AccessControl.FileSystemRights]::TakeOwnership
      @($captureRules | Where-Object { $_.AccessControlType -eq 'Allow' -and
          ($_.FileSystemRights -band $dangerous) -ne 0 }).Count | Should -Be 0
      $captureDenyRules = @($captureRules | Where-Object AccessControlType -EQ 'Deny')
      $denied = [Security.AccessControl.FileSystemRights]0
      foreach($rule in $captureDenyRules){ $denied = $denied -bor $rule.FileSystemRights }
      ($denied -band $dangerous) | Should -Be $dangerous
      @($expiryRules | Where-Object { ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::FullControl) -eq [Security.AccessControl.FileSystemRights]::FullControl }).Count | Should -BeGreaterThan 0
    }

    It 'restores the exact source descriptor if movement fails after hardening' {
      $fixture = New-SealingFixture 'acl-move-rollback'
      $source = Join-Path $fixture.Staging 'acl-move-rollback.jsonl'
      Write-TestSegment -Path $source
      $beforeSddl = (Get-Acl -LiteralPath $source).Sddl
      $destination = Join-Path $fixture.Corpus 'sprint-0015\acl-move-rollback.jsonl'
      Mock Set-CorpusFileSystemAcl {
        param($Path,$BoundaryKind,$CaptureIdentity,$ExpiryIdentity,$RestoreSddl,$PlanOnly,$Confirm)
        if ($PSBoundParameters.ContainsKey('RestoreSddl')) {
          return [pscustomobject]@{ Applied=$true; Verified=$true }
        }
        if ($PlanOnly) {
          return [pscustomobject]@{ BeforeOwner='before'; BeforeSddl=$beforeSddl; DesiredSddl='desired' }
        }
        [IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
        [IO.File]::WriteAllText($destination,'collision')
        [pscustomobject]@{ Applied=$true; Verified=$true; BeforeOwner='before'; BeforeSddl=$beforeSddl; AfterOwner='after'; AfterSddl='after' }
      }

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus

      $result.Ok | Should -BeFalse
      $result.Failure.Code | Should -Be 'movement-failed'
      $result.Acl.RollbackAttempted | Should -BeTrue
      $result.Acl.RollbackSucceeded | Should -BeTrue
      Test-Path -LiteralPath $source | Should -BeTrue
      Should -Invoke Set-CorpusFileSystemAcl -Exactly 1 -ParameterFilter { $RestoreSddl -eq $beforeSddl }
    }

    It 'resolves omitted identities only through their exact Get-PVal keys' {
      $fixture = New-SealingFixture 'acl-settings'
      $source = Join-Path $fixture.Staging 'acl-settings.jsonl'
      Write-TestSegment -Path $source
      Mock Get-PVal {
        param($ParameterName,$originalPSBoundParameters,$dottedPath)
        if ($ParameterName -ne $dottedPath) { throw 'mismatched exact key' }
        if ($ParameterName -eq 'CorpusCaptureIdentity') { return $script:captureSid }
        if ($ParameterName -eq 'CorpusExpiryIdentity') { return $script:expirySid }
        throw "unexpected key $ParameterName"
      }

      $result = Complete-GatherCallRecordSegment -StagingFilePath $source `
        -CorpusGatherRecordsStagingPath $fixture.Staging `
        -CorpusGatherRecordsPath $fixture.Corpus -SprintNumber '0015'

      $result.Ok | Should -BeTrue
      Should -Invoke Get-PVal -Exactly 1 -ParameterFilter { $ParameterName -eq 'CorpusCaptureIdentity' -and $dottedPath -eq $ParameterName }
      Should -Invoke Get-PVal -Exactly 1 -ParameterFilter { $ParameterName -eq 'CorpusExpiryIdentity' -and $dottedPath -eq $ParameterName }
    }

    It 'does not fall back when an explicit identity is null or blank' -ForEach @(
      @{ Capture=$null; Expiry='valid' }, @{ Capture=' '; Expiry='valid' },
      @{ Capture='valid'; Expiry=$null }, @{ Capture='valid'; Expiry=' ' }
    ) {
      $fixture = New-SealingFixture 'acl-explicit-invalid'
      $source = Join-Path $fixture.Staging "$([guid]::NewGuid().ToString('N')).jsonl"
      Write-TestSegment -Path $source
      Mock Get-PVal { throw 'must not fall back' }
      $captureValue = if($Capture -eq 'valid'){$script:captureSid}else{$Capture}
      $expiryValue = if($Expiry -eq 'valid'){$script:expirySid}else{$Expiry}

      $result = Complete-GatherCallRecordSegment -StagingFilePath $source `
        -CorpusGatherRecordsStagingPath $fixture.Staging -CorpusGatherRecordsPath $fixture.Corpus `
        -SprintNumber '0015' -CaptureIdentity $captureValue -ExpiryIdentity $expiryValue

      $result.Ok | Should -BeFalse
      $result.Failure.Code | Should -Be 'acl-validation-failed'
      Should -Invoke Get-PVal -Exactly 0
    }
  }

  Context 'Fail-closed JSONL validation' {
    It 'rejects a truncated final line and leaves the source untouched' {
      $fixture = New-SealingFixture 'truncated'
      $source = Join-Path $fixture.Staging 'truncated.jsonl'
      Write-TestSegment -Path $source -NoFinalNewline

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus

      $result.Ok | Should -BeFalse
      $result.Failure.Message | Should -Match 'terminating newline'
      Test-Path -LiteralPath $source | Should -BeTrue
    }

    It 'rejects malformed JSON and leaves the source untouched' {
      $fixture = New-SealingFixture 'malformed'
      $source = Join-Path $fixture.Staging 'malformed.jsonl'
      Write-TestSegment -Path $source -Records @('{"recordVersion":"1.0.0"')

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus

      $result.Ok | Should -BeFalse
      $result.Failure.Message | Should -Match 'malformed JSON'
      Test-Path -LiteralPath $source | Should -BeTrue
    }

    It 'rejects a blank JSONL line' {
      $fixture = New-SealingFixture 'blank-line'
      $source = Join-Path $fixture.Staging 'blank-line.jsonl'
      Write-TestSegment -Path $source -Records @((New-GatherRecord), '   ')

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus

      $result.Ok | Should -BeFalse
      $result.Failure.Message | Should -Match 'line 2 is blank'
    }

    It 'rejects UTF-8 with a BOM' {
      $fixture = New-SealingFixture 'bom'
      $source = Join-Path $fixture.Staging 'bom.jsonl'
      Write-TestSegment -Path $source -Bom

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus

      $result.Ok | Should -BeFalse
      $result.Failure.Message | Should -Match 'UTF-8 BOM'
    }

    It 'rejects an unsupported record version' {
      $fixture = New-SealingFixture 'version'
      $source = Join-Path $fixture.Staging 'version.jsonl'
      Write-TestSegment -Path $source -Records @((New-GatherRecord -RecordVersion '2.0.0'))

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus

      $result.Ok | Should -BeFalse
      $result.Failure.Message | Should -Match 'unsupported recordVersion'
    }

    It 'rejects a missing required identity or time field' -ForEach @(
      @{ Field = 'invocationId' }
      @{ Field = 'timestampUtc' }
      @{ Field = 'agentName' }
      @{ Field = 'requestResponsePairId' }
    ) {
      $fixture = New-SealingFixture "missing-$Field"
      $source = Join-Path $fixture.Staging "missing-$Field.jsonl"
      $record = New-GatherRecord
      $record.Remove($Field)
      Write-TestSegment -Path $source -Records @($record)

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus

      $result.Ok | Should -BeFalse
      $result.Failure.Message | Should -Match "missing required identity/time field '$Field'"
    }

    It 'rejects a JSON value that is not an object' {
      $fixture = New-SealingFixture 'not-object'
      $source = Join-Path $fixture.Staging 'not-object.jsonl'
      Write-TestSegment -Path $source -Records @('[1,2,3]')

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus

      $result.Ok | Should -BeFalse
      $result.Failure.Message | Should -Match 'not one JSON object'
    }
  }

  Context 'Source and destination boundaries' {
    It 'rejects a source outside staging' {
      $fixture = New-SealingFixture 'escape'
      $source = Join-Path $fixture.Root 'outside.jsonl'
      Write-TestSegment -Path $source

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus

      $result.Ok | Should -BeFalse
      $result.Failure.Code | Should -Be 'source-escape'
      Test-Path -LiteralPath $source | Should -BeTrue
    }

    It 'rejects ambiguous source and root values without falling back' {
      $fixture = New-SealingFixture 'ambiguous'
      $first = Join-Path $fixture.Staging 'first.jsonl'
      $second = Join-Path $fixture.Staging 'second.jsonl'
      Write-TestSegment -Path $first
      Write-TestSegment -Path $second
      Mock Get-PVal { throw 'must not fall back' }

      $sourceResult = Complete-GatherCallRecordSegment -StagingFilePath @($first, $second) `
        -CorpusGatherRecordsStagingPath $fixture.Staging `
        -CorpusGatherRecordsPath $fixture.Corpus -SprintNumber '0015'
      $rootResult = Complete-GatherCallRecordSegment -StagingFilePath $first `
        -CorpusGatherRecordsStagingPath @($fixture.Staging, $fixture.Root) `
        -CorpusGatherRecordsPath $fixture.Corpus -SprintNumber '0015'

      $sourceResult.Failure.Code | Should -Be 'ambiguous-source'
      $rootResult.Failure.Message | Should -Match 'exactly one absolute path'
      Should -Invoke Get-PVal -Exactly 0
    }

    It 'does not fall back when either explicit root is null or blank' -ForEach @(
      @{ Name = 'null-staging'; Staging = $null; Corpus = 'valid' }
      @{ Name = 'blank-staging'; Staging = '   '; Corpus = 'valid' }
      @{ Name = 'null-corpus'; Staging = 'valid'; Corpus = $null }
      @{ Name = 'blank-corpus'; Staging = 'valid'; Corpus = '   ' }
    ) {
      $fixture = New-SealingFixture $Name
      $source = Join-Path $fixture.Staging "$Name.jsonl"
      Write-TestSegment -Path $source
      Mock Get-PVal { throw 'must not fall back' }
      $stagingValue = if ($Staging -eq 'valid') { $fixture.Staging } else { $Staging }
      $corpusValue = if ($Corpus -eq 'valid') { $fixture.Corpus } else { $Corpus }

      $result = Complete-GatherCallRecordSegment -StagingFilePath $source `
        -CorpusGatherRecordsStagingPath $stagingValue `
        -CorpusGatherRecordsPath $corpusValue -SprintNumber '0015'

      $result.Ok | Should -BeFalse
      $result.Failure.Code | Should -Be 'root-resolution-failed'
      Should -Invoke Get-PVal -Exactly 0
    }

    It 'rejects a directory as the source' {
      $fixture = New-SealingFixture 'directory'

      $result = Invoke-Sealer -Source $fixture.Staging -Staging $fixture.Staging -Corpus $fixture.Corpus

      $result.Ok | Should -BeFalse
      $result.Failure.Code | Should -Match 'source'
    }

    It 'fails when the source cannot be opened exclusively' -Skip:(-not $IsWindows) {
      $fixture = New-SealingFixture 'open'
      $source = Join-Path $fixture.Staging 'open.jsonl'
      Write-TestSegment -Path $source
      $held = [System.IO.File]::Open($source, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
      try {
        $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus
      } finally {
        $held.Dispose()
      }

      $result.Ok | Should -BeFalse
      $result.Failure.Code | Should -Be 'validation-failed'
      $result.Failure.Message | Should -Match 'being used by another process|cannot access'
      Test-Path -LiteralPath $source | Should -BeTrue
    }

    It 'rejects a reparse-point input when symbolic links are available' {
      $fixture = New-SealingFixture 'reparse'
      $target = Join-Path $fixture.Staging 'target.jsonl'
      $link = Join-Path $fixture.Staging 'link.jsonl'
      Write-TestSegment -Path $target
      try {
        New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop | Out-Null
      } catch {
        Set-ItResult -Skipped -Because "symbolic links unavailable: $($_.Exception.Message)"
        return
      }

      $result = Invoke-Sealer -Source $link -Staging $fixture.Staging -Corpus $fixture.Corpus

      $result.Ok | Should -BeFalse
      $result.Failure.Code | Should -Be 'reparse-point'
      Test-Path -LiteralPath $target | Should -BeTrue
    }

    It 'rejects a reparse-point source ancestor when symbolic links are available' {
      $fixture = New-SealingFixture 'reparse-ancestor'
      $external = Join-Path $fixture.Root 'external-source'
      $linkDirectory = Join-Path $fixture.Staging 'linked-source'
      New-Item -ItemType Directory -Path $external -Force | Out-Null
      $target = Join-Path $external 'ancestor.jsonl'
      Write-TestSegment -Path $target
      $beforeHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
      try {
        New-Item -ItemType SymbolicLink -Path $linkDirectory -Target $external -ErrorAction Stop | Out-Null
      } catch {
        Set-ItResult -Skipped -Because "symbolic links unavailable: $($_.Exception.Message)"
        return
      }
      $source = Join-Path $linkDirectory 'ancestor.jsonl'

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus

      $result.Ok | Should -BeFalse
      $result.Failure.Code | Should -Be 'reparse-point'
      Test-Path -LiteralPath $source | Should -BeTrue
      (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash | Should -Be $beforeHash
    }

    It 'rejects an existing reparse-point sprint partition without redirecting bytes' {
      $fixture = New-SealingFixture 'reparse-partition'
      $source = Join-Path $fixture.Staging 'partition.jsonl'
      Write-TestSegment -Path $source
      $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
      $external = Join-Path $fixture.Root 'external-partition'
      $partition = Join-Path $fixture.Corpus 'sprint-0015'
      $sentinel = Join-Path $external 'sentinel.bin'
      New-Item -ItemType Directory -Path $external -Force | Out-Null
      [System.IO.File]::WriteAllText($sentinel, 'preserve')
      try {
        New-Item -ItemType SymbolicLink -Path $partition -Target $external -ErrorAction Stop | Out-Null
      } catch {
        Set-ItResult -Skipped -Because "symbolic links unavailable: $($_.Exception.Message)"
        return
      }

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus

      $result.Ok | Should -BeFalse
      $result.Failure.Code | Should -Be 'reparse-point'
      Test-Path -LiteralPath $source | Should -BeTrue
      (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash | Should -Be $sourceHash
      [System.IO.File]::ReadAllText($sentinel) | Should -Be 'preserve'
      Test-Path -LiteralPath (Join-Path $external 'partition.jsonl') | Should -BeFalse
    }

    It 'hard-refuses a cross-volume close variant without mutating another volume' -Skip:(-not $IsWindows) {
      $fixture = New-SealingFixture 'cross-volume'
      $source = Join-Path $fixture.Staging 'cross-volume.jsonl'
      Write-TestSegment -Path $source
      $sourceRoot = [System.IO.Path]::GetPathRoot($source)
      $otherDrive = @('Z:', 'Y:', 'X:') | Where-Object {
        -not [string]::Equals("$_\", $sourceRoot, [System.StringComparison]::OrdinalIgnoreCase)
      } | Select-Object -First 1
      $uncreatedCorpus = "$otherDrive\codex-disposable-corpus"

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $uncreatedCorpus

      $result.Ok | Should -BeFalse
      $result.Failure.Code | Should -Be 'cross-volume-refused'
      $result.Movement.Performed | Should -BeFalse
      Test-Path -LiteralPath $source | Should -BeTrue
    }

    It 'fails closed on duplicate destination and repeated invocation' {
      $fixture = New-SealingFixture 'duplicate'
      $source = Join-Path $fixture.Staging 'repeat.jsonl'
      Write-TestSegment -Path $source
      $first = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus
      $sealed = $first.Destination.Path
      [System.IO.File]::Copy($sealed, $source)

      $second = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus

      $first.Ok | Should -BeTrue
      $second.Ok | Should -BeFalse
      $second.Failure.Code | Should -Be 'destination-exists'
      Test-Path -LiteralPath $source | Should -BeTrue
      (Get-FileHash -LiteralPath $sealed).Hash | Should -Be (Get-FileHash -LiteralPath $source).Hash
    }

    It 'validates and plans under WhatIf without creating a partition or moving bytes' {
      $fixture = New-SealingFixture 'whatif-seal'
      $source = Join-Path $fixture.Staging 'whatif.jsonl'
      Write-TestSegment -Path $source
      $partition = Join-Path $fixture.Corpus 'sprint-0015'

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus -WhatIf

      $result.Ok | Should -BeTrue
      $result.Validation.Succeeded | Should -BeTrue
      $result.Movement.Planned | Should -BeTrue
      $result.Movement.Performed | Should -BeFalse
      Test-Path -LiteralPath $partition | Should -BeFalse
      Test-Path -LiteralPath $source | Should -BeTrue
    }
  }

  Context 'Explicit invalid-remnant quarantine' {
    It 'leaves an invalid partial remnant untouched by default' {
      $fixture = New-SealingFixture 'partial-default'
      $source = Join-Path $fixture.Staging '_partial-bad.tmp'
      [System.IO.File]::WriteAllBytes($source, [byte[]](0xff, 0x00, 0x01))

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus

      $result.Ok | Should -BeFalse
      $result.Failure.Code | Should -Be 'quarantine-intent-required'
      Test-Path -LiteralPath $source | Should -BeTrue
      Test-Path -LiteralPath (Join-Path $fixture.Staging 'quarantine') | Should -BeFalse
    }

    It 'atomically quarantines invalid bytes only on explicit intent without repairing them' {
      $fixture = New-SealingFixture 'partial-explicit'
      $source = Join-Path $fixture.Staging '_partial-bad.tmp'
      $bytes = [byte[]](0xff, 0x00, 0x01, 0x02)
      [System.IO.File]::WriteAllBytes($source, $bytes)

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging `
        -Corpus $fixture.Corpus -Quarantine

      $result.Ok | Should -BeTrue
      $result.Action | Should -Be 'Quarantine'
      $result.Movement.Performed | Should -BeTrue
      $result.Hashes.BeforeMove | Should -BeNullOrEmpty
      $result.Hashes.AfterMove | Should -BeNullOrEmpty
      Test-Path -LiteralPath $source | Should -BeFalse
      [System.IO.File]::ReadAllBytes($result.Destination.Path) | Should -Be $bytes
      $result.Destination.Path | Should -Be (Join-Path $fixture.Staging 'quarantine\_partial-bad.tmp')
    }

    It 'fails closed on a quarantine collision without overwriting either file' {
      $fixture = New-SealingFixture 'partial-collision'
      $source = Join-Path $fixture.Staging '_partial-collision.tmp'
      $quarantine = Join-Path $fixture.Staging 'quarantine'
      $destination = Join-Path $quarantine '_partial-collision.tmp'
      New-Item -ItemType Directory -Path $quarantine -Force | Out-Null
      [System.IO.File]::WriteAllText($source, 'source')
      [System.IO.File]::WriteAllText($destination, 'existing')

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging `
        -Corpus $fixture.Corpus -Quarantine

      $result.Ok | Should -BeFalse
      $result.Failure.Code | Should -Be 'destination-exists'
      [System.IO.File]::ReadAllText($source) | Should -Be 'source'
      [System.IO.File]::ReadAllText($destination) | Should -Be 'existing'
    }

    It 'rejects an existing reparse-point quarantine child without redirecting bytes' {
      $fixture = New-SealingFixture 'reparse-quarantine'
      $source = Join-Path $fixture.Staging '_partial-reparse.tmp'
      $sourceBytes = [byte[]](0xff, 0x11, 0x22)
      [System.IO.File]::WriteAllBytes($source, $sourceBytes)
      $external = Join-Path $fixture.Root 'external-quarantine'
      $quarantine = Join-Path $fixture.Staging 'quarantine'
      $sentinel = Join-Path $external 'sentinel.bin'
      New-Item -ItemType Directory -Path $external -Force | Out-Null
      [System.IO.File]::WriteAllText($sentinel, 'preserve')
      try {
        New-Item -ItemType SymbolicLink -Path $quarantine -Target $external -ErrorAction Stop | Out-Null
      } catch {
        Set-ItResult -Skipped -Because "symbolic links unavailable: $($_.Exception.Message)"
        return
      }

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging -Corpus $fixture.Corpus -Quarantine

      $result.Ok | Should -BeFalse
      $result.Failure.Code | Should -Be 'reparse-point'
      [System.IO.File]::ReadAllBytes($source) | Should -Be $sourceBytes
      [System.IO.File]::ReadAllText($sentinel) | Should -Be 'preserve'
      Test-Path -LiteralPath (Join-Path $external '_partial-reparse.tmp') | Should -BeFalse
    }

    It 'plans quarantine under WhatIf without creating a directory or moving bytes' {
      $fixture = New-SealingFixture 'partial-whatif'
      $source = Join-Path $fixture.Staging '_partial-whatif.tmp'
      [System.IO.File]::WriteAllText($source, 'invalid')
      $quarantine = Join-Path $fixture.Staging 'quarantine'

      $result = Invoke-Sealer -Source $source -Staging $fixture.Staging `
        -Corpus $fixture.Corpus -Quarantine -WhatIf

      $result.Ok | Should -BeTrue
      $result.Validation.Succeeded | Should -BeTrue
      $result.Movement.Planned | Should -BeTrue
      $result.Movement.Performed | Should -BeFalse
      Test-Path -LiteralPath $quarantine | Should -BeFalse
      Test-Path -LiteralPath $source | Should -BeTrue
    }
  }
}
