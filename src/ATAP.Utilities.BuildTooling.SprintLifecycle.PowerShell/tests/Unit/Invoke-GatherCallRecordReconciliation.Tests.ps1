#Requires -Version 7.0

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param([string]$FunctionName, [string]$ModuleName, [string]$Level,
        [string]$Message, [string]$Tag)
    }
    $script:CreatedWritePsfTestDouble = $true
  }
  if (-not (Get-Command Get-PVal -ErrorAction SilentlyContinue)) {
    function global:Get-PVal { throw 'Get-PVal test double was not configured.' }
    $script:CreatedGetPValTestDouble = $true
  }
  if (-not (Get-Command Request-ElevatedInstall -ErrorAction SilentlyContinue)) {
    function global:Request-ElevatedInstall {
      [CmdletBinding(SupportsShouldProcess)]
      param([string]$InstallerId, [hashtable]$Parameters)
      throw 'Request-ElevatedInstall test double was not configured.'
    }
    $script:CreatedRequestElevatedInstallTestDouble = $true
  }

  $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:functionPath = Join-Path $script:moduleRoot 'public\Invoke-GatherCallRecordReconciliation.ps1'
  $script:manifestPath = Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell.psd1'
  $script:testModuleName = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell.Task15191Public'
  $sourcePaths = @(
    (Join-Path $script:moduleRoot 'private\Set-CorpusFileSystemAcl.ps1'),
    (Join-Path $script:moduleRoot 'public\Complete-GatherCallRecordSegment.ps1'),
    (Join-Path $script:moduleRoot 'private\Invoke-GatherCallRecordStagingReconciliation.ps1'),
    $script:functionPath
  )
  $moduleBody = {
    param([string[]]$SourcePaths)
    foreach ($sourcePath in $SourcePaths) { . $sourcePath }
    Export-ModuleMember -Function 'Invoke-GatherCallRecordReconciliation'
  }
  $script:testModule = New-Module -Name $script:testModuleName -ScriptBlock $moduleBody `
    -ArgumentList (,$sourcePaths)
  Import-Module $script:testModule -Force
  $script:now = [datetime]::SpecifyKind([datetime]'2026-09-13T18:00:00', [DateTimeKind]::Utc)
  $script:captureSid = 'S-1-5-19'
  $script:expirySid = 'S-1-5-20'

  function New-PublicReconciliationFixture {
    param([string]$Name)
    $root = Join-Path $TestDrive "$Name-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $staging = Join-Path $root 'CorpusGatherRecordsStaging'
    $corpus = Join-Path $root 'CorpusGatherRecords'
    New-Item -ItemType Directory -Path $staging, $corpus -Force | Out-Null
    [pscustomobject]@{ Root = $root; Staging = $staging; Corpus = $corpus }
  }

  function New-PublicReconciliationRecord {
    param([string]$SessionId = 'session-a')
    [ordered]@{
      recordVersion = '1.0.0'
      invocationId = [guid]::NewGuid().ToString().ToLowerInvariant()
      requestResponsePairId = $null
      ordinal = 1
      ordinalScope = 'session'
      timestampUtc = '2026-09-13T17:00:00.000Z'
      agentName = 'junior-dev-coder-sh'
      agentModel = $null
      sessionId = $SessionId
      taskId = '15.191.c'
      worktreePath = 'C:/fixture/worktree'
      repositoryName = 'ATAP.Utilities'
      conversationId = $null
      conversationTitle = $null
    }
  }

  function New-PublicSegmentFile {
    param(
      [object]$Fixture,
      [object]$Record = (New-PublicReconciliationRecord),
      [timespan]$Age = ([timespan]::FromMinutes(1))
    )
    $name = '20260913T170000000Z-' + [guid]::NewGuid().ToString().ToLowerInvariant() + '.jsonl'
    $path = Join-Path $Fixture.Staging $name
    $text = ($Record | ConvertTo-Json -Compress -Depth 8) + "`n"
    [System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false))
    (Get-Item -LiteralPath $path).LastWriteTimeUtc = $script:now - $Age
    $path
  }

  function Invoke-PublicFixture {
    param(
      [object]$Fixture,
      [string[]]$ClosedSessionId = @(),
      [timespan]$MaximumSegmentAge = ([timespan]::FromHours(1)),
      [long]$MaximumSegmentBytes = 1000000,
      [timespan]$AbandonedRemnantAge = ([timespan]::FromHours(1)),
      [switch]$WhatIf
    )
    $arguments = @{
      CorpusGatherRecordsStagingPath = $Fixture.Staging
      CorpusGatherRecordsPath = $Fixture.Corpus
      SprintNumber = '0015'
      ClosedSessionId = $ClosedSessionId
      MaximumSegmentAge = $MaximumSegmentAge
      MaximumSegmentBytes = $MaximumSegmentBytes
      AbandonedRemnantAge = $AbandonedRemnantAge
      NowUtc = $script:now
      Confirm = $false
    }
    if ($WhatIf) { $arguments.WhatIf = $true }
    Invoke-GatherCallRecordReconciliation @arguments
  }
}

AfterAll {
  Remove-Module -Name $script:testModuleName -Force -ErrorAction SilentlyContinue
  Remove-Variable -Name 'Task15191Sentinel' -Scope Global -ErrorAction SilentlyContinue
  if ($script:CreatedRequestElevatedInstallTestDouble) {
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath 'Function:\Request-ElevatedInstall' `
      -ErrorAction SilentlyContinue
  }
  if ($script:CreatedGetPValTestDouble) {
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath 'Function:\Get-PVal' -ErrorAction SilentlyContinue
  }
  if ($script:CreatedWritePsfTestDouble) {
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath 'Function:\Write-PSFMessage' -ErrorAction SilentlyContinue
  }
}

Describe 'Invoke-GatherCallRecordReconciliation [public imported module]' -Tag 'Unit' {
  BeforeEach {
    Mock Get-PVal -ModuleName $script:testModuleName {
      param($ParameterName, $originalPSBoundParameters, $dottedPath)
      if ($ParameterName -ne $dottedPath) { throw 'mismatched exact key' }
      if ($ParameterName -eq 'CorpusCaptureIdentity') { return $script:captureSid }
      if ($ParameterName -eq 'CorpusExpiryIdentity') { return $script:expirySid }
      throw "unexpected key $ParameterName"
    }
    $script:nonAdministrativePrincipal = [pscustomobject]@{}
    $script:nonAdministrativePrincipal | Add-Member -MemberType ScriptMethod -Name IsInRole `
      -Value { param($Role) $false }
    Mock New-Object -ModuleName $script:testModuleName {
      $script:nonAdministrativePrincipal
    } -ParameterFilter {
      $TypeName -eq 'System.Security.Principal.WindowsPrincipal'
    }
    Mock Request-ElevatedInstall -ModuleName $script:testModuleName {
      param($InstallerId, $Parameters, $Confirm)
      $destinationDirectory = Join-Path ([string]$Parameters.CorpusGatherRecordsPath) `
        "sprint-$([string]$Parameters.SprintNumber)"
      [System.IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null
      $destinationPath = Join-Path $destinationDirectory `
        ([System.IO.Path]::GetFileName([string]$Parameters.StagingFilePath))
      [System.IO.File]::Move([string]$Parameters.StagingFilePath, $destinationPath)
      [pscustomobject]@{
        requestId = 'unit-broker-request'
        status = 'succeeded'
        error = $null
        transcriptPath = 'unit-broker-transcript.log'
      }
    }
  }

  It 'is exported exactly once as an advanced function with ShouldProcess support' {
    $commands = @(Get-Command Invoke-GatherCallRecordReconciliation -CommandType Function -All |
        Where-Object { $_.ModuleName -eq $script:testModuleName })
    $commands.Count | Should -Be 1
    $commands[0].CmdletBinding | Should -BeTrue
    $commands[0].Parameters.Keys | Should -Contain 'WhatIf'
    $commands[0].Parameters.Keys | Should -Contain 'Confirm'
    $manifest = Import-PowerShellDataFile -LiteralPath $script:manifestPath
    @($manifest.FunctionsToExport | Where-Object {
        $_ -eq 'Invoke-GatherCallRecordReconciliation'
      }).Count | Should -Be 1
  }

  It 'defines only the eponymous function and contains no implementation primitive' {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
      $script:functionPath, [ref]$tokens, [ref]$errors)
    $errors | Should -BeNullOrEmpty
    @($ast.EndBlock.Statements | Where-Object {
        $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst]
      }) | Should -BeNullOrEmpty
    $source = Get-Content -LiteralPath $script:functionPath -Raw
    $source | Should -Match 'Write-PSFMessage'
    $source | Should -Not -Match '(?i)\b(Move-Item|Copy-Item|Remove-Item|robocopy|icacls)\b'
    $source | Should -Not -Match '(?i)\[System\.IO\.File\]::(Move|Copy|Delete)\s*\('
    $source | Should -Not -Match 'Get-ChildItem|ConvertFrom-Json|Get-FileHash'
  }

  It 'passes explicit roots, boundaries, thresholds, and injected UTC without changing the result' {
    $global:Task15191Sentinel = [pscustomobject]@{
      Ok = $false
      Failure = [pscustomobject]@{ Code = 'sentinel' }
    }
    Mock Invoke-GatherCallRecordStagingReconciliation -ModuleName $script:testModuleName {
      $global:Task15191Sentinel
    }
    $fixture = New-PublicReconciliationFixture 'forwarding'
    $result = Invoke-PublicFixture -Fixture $fixture -ClosedSessionId @('closed-a', 'closed-b') `
      -MaximumSegmentAge ([timespan]::FromMinutes(7)) -MaximumSegmentBytes 321 `
      -AbandonedRemnantAge ([timespan]::FromMinutes(11))
    [object]::ReferenceEquals($result, $global:Task15191Sentinel) | Should -BeTrue
    Should -Invoke Invoke-GatherCallRecordStagingReconciliation -ModuleName $script:testModuleName `
      -Exactly 1 -ParameterFilter {
        $CorpusGatherRecordsStagingPath -eq $fixture.Staging -and
        $CorpusGatherRecordsPath -eq $fixture.Corpus -and $SprintNumber -eq '0015' -and
        $ClosedSessionId.Count -eq 2 -and $ClosedSessionId[1] -eq 'closed-b' -and
        $MaximumSegmentAge -eq [timespan]::FromMinutes(7) -and
        $MaximumSegmentBytes -eq 321 -and
        $AbandonedRemnantAge -eq [timespan]::FromMinutes(11) -and
        $NowUtc -eq $script:now -and -not $WhatIf -and -not $Confirm
      }
  }

  It 'preserves omitted roots for exact Get-PVal resolution and supplies current UTC' {
    $fixture = New-PublicReconciliationFixture 'omitted-roots'
    Mock Get-PVal -ModuleName $script:testModuleName {
      if ($ParameterName -eq 'CorpusGatherRecordsStagingPath') { return $fixture.Staging }
      if ($ParameterName -eq 'CorpusGatherRecordsPath') { return $fixture.Corpus }
      throw "unexpected key $ParameterName"
    }
    $result = Invoke-GatherCallRecordReconciliation -SprintNumber '0015' `
      -MaximumSegmentAge ([timespan]::FromHours(1)) -MaximumSegmentBytes 1000 `
      -AbandonedRemnantAge ([timespan]::FromHours(1)) -Confirm:$false
    $result.Ok | Should -BeTrue
    $result.Counts.Discovered | Should -Be 0
    $result.Failure | Should -BeNullOrEmpty
    Should -Invoke Get-PVal -ModuleName $script:testModuleName -Exactly 2
  }

  It 'preserves an explicitly bound invalid staging root without configuration fallback' -ForEach @(
    @{ Name = 'null'; Value = $null },
    @{ Name = 'blank'; Value = '   ' }
  ) {
    $fixture = New-PublicReconciliationFixture "explicit-$Name"
    Mock Get-PVal -ModuleName $script:testModuleName { throw 'must not fall back' }
    $result = Invoke-GatherCallRecordReconciliation `
      -CorpusGatherRecordsStagingPath $Value -CorpusGatherRecordsPath $fixture.Corpus `
      -SprintNumber '0015' -MaximumSegmentAge ([timespan]::FromHours(1)) `
      -MaximumSegmentBytes 1000 -AbandonedRemnantAge ([timespan]::FromHours(1)) `
      -NowUtc $script:now -Confirm:$false
    $result.Ok | Should -BeFalse
    $result.Failure.Code | Should -Be 'reconciliation-failed'
    $result.Failure.Message | Should -Match 'Root resolution failed'
    Should -Invoke Get-PVal -ModuleName $script:testModuleName -Exactly 0
  }

  It 'seals a segment when its session is closed' {
    $fixture = New-PublicReconciliationFixture 'session'
    $source = New-PublicSegmentFile -Fixture $fixture
    $result = Invoke-PublicFixture -Fixture $fixture -ClosedSessionId 'session-a'
    $result.Ok | Should -BeTrue
    $result.Counts.Sealed | Should -Be 1
    $result.Files[0].Boundary | Should -Contain 'closed-session'
    $result.Files[0].Result.Broker.Attempted | Should -BeTrue
    $result.Files[0].Result.Broker.Status | Should -Be 'succeeded'
    $result.Files[0].Result.Movement.Performed | Should -BeFalse
    Test-Path -LiteralPath $source | Should -BeFalse
    Should -Invoke Request-ElevatedInstall -ModuleName $script:testModuleName -Exactly 1 `
      -ParameterFilter {
        $InstallerId -eq 'seal-gather-call-record-segment' -and
        $Parameters.Count -eq 7 -and
        @($Parameters.Values | Where-Object { $_ -isnot [string] }).Count -eq 0 -and
        $Parameters.StagingFilePath -eq $source -and
        $Parameters.CorpusGatherRecordsStagingPath -eq $fixture.Staging -and
        $Parameters.CorpusGatherRecordsPath -eq $fixture.Corpus -and
        $Parameters.SprintNumber -eq '0015' -and
        $Parameters.CaptureIdentity -eq $script:captureSid -and
        $Parameters.ExpiryIdentity -eq $script:expirySid -and
        $Parameters.ExpectedSha256 -match '^[0-9A-F]{64}$' -and
        -not $Confirm
      }
  }

  It 'seals a segment at the maximum-age boundary' {
    $fixture = New-PublicReconciliationFixture 'age'
    $source = New-PublicSegmentFile -Fixture $fixture -Age ([timespan]::FromHours(1))
    $result = Invoke-PublicFixture -Fixture $fixture
    $result.Ok | Should -BeTrue
    $result.Counts.Sealed | Should -Be 1
    $result.Files[0].Boundary | Should -Contain 'maximum-age'
    Test-Path -LiteralPath $source | Should -BeFalse
  }

  It 'seals a segment at the maximum-byte boundary' {
    $fixture = New-PublicReconciliationFixture 'size'
    $source = New-PublicSegmentFile -Fixture $fixture
    $length = (Get-Item -LiteralPath $source).Length
    $result = Invoke-PublicFixture -Fixture $fixture -MaximumSegmentBytes $length
    $result.Ok | Should -BeTrue
    $result.Counts.Sealed | Should -Be 1
    $result.Files[0].Boundary | Should -Contain 'maximum-bytes'
    Test-Path -LiteralPath $source | Should -BeFalse
  }

  It 'quarantines an abandoned partial remnant' {
    $fixture = New-PublicReconciliationFixture 'partial'
    $source = Join-Path $fixture.Staging '_partial-session-abc.tmp'
    [System.IO.File]::WriteAllText($source, 'partial', [System.Text.UTF8Encoding]::new($false))
    (Get-Item -LiteralPath $source).LastWriteTimeUtc = $script:now - [timespan]::FromHours(1)
    $result = Invoke-PublicFixture -Fixture $fixture
    $result.Ok | Should -BeTrue
    $result.Counts.Quarantined | Should -Be 1
    $result.Files[0].Boundary | Should -Contain 'abandoned-remnant-age'
    Test-Path -LiteralPath (Join-Path $fixture.Staging 'quarantine\_partial-session-abc.tmp') |
      Should -BeTrue
  }

  It 'preserves an incomplete segment failure returned by the sealing primitive' {
    $fixture = New-PublicReconciliationFixture 'invalid'
    $record = New-PublicReconciliationRecord
    $record.Remove('agentName')
    $source = New-PublicSegmentFile -Fixture $fixture -Record $record
    $result = Invoke-PublicFixture -Fixture $fixture -ClosedSessionId 'session-a'
    $result.Ok | Should -BeFalse
    $result.Counts.Failed | Should -Be 1
    $result.Files[0].Reason | Should -Be 'primitive-refused'
    $result.Files[0].Result.Failure.Code | Should -Be 'validation-failed'
    Test-Path -LiteralPath $source | Should -BeTrue
  }

  It 'preserves malformed JSON as a session-inspection failure' {
    $fixture = New-PublicReconciliationFixture 'malformed'
    $name = '20260913T170000000Z-' + [guid]::NewGuid().ToString().ToLowerInvariant() + '.jsonl'
    $source = Join-Path $fixture.Staging $name
    [System.IO.File]::WriteAllText($source, "{`n", [System.Text.UTF8Encoding]::new($false))
    (Get-Item -LiteralPath $source).LastWriteTimeUtc = $script:now - [timespan]::FromHours(1)
    $result = Invoke-PublicFixture -Fixture $fixture
    $result.Ok | Should -BeFalse
    $result.Counts.Failed | Should -Be 1
    $result.Files[0].Reason | Should -Be 'session-inspection-failed'
    $result.Files[0].Result.Failure | Should -Not -BeNullOrEmpty
    Test-Path -LiteralPath $source | Should -BeTrue
  }

  It 'propagates WhatIf through validation without mutating a qualifying segment' {
    $fixture = New-PublicReconciliationFixture 'whatif'
    $source = New-PublicSegmentFile -Fixture $fixture
    $result = Invoke-PublicFixture -Fixture $fixture -ClosedSessionId 'session-a' -WhatIf
    $result.Ok | Should -BeTrue
    $result.Counts.Invoked | Should -Be 1
    $result.Files[0].Status | Should -Be 'Planned'
    Test-Path -LiteralPath $source | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $fixture.Corpus 'sprint-0015') | Should -BeFalse
  }
}
