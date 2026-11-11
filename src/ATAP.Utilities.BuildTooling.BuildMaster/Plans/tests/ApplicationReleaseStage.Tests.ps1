BeforeAll {
  . (Join-Path $PSScriptRoot '../Invoke-ApplicationReleaseStage.ps1')
  function New-ReleaseContextFixture {
    param([string]$ProductId = 'AceCommander', [string]$Version = '0.1.1', [switch]$ProductionDatabase)
    # Same Dropbox exclusion as New-ReleaseBundle.Tests.ps1: fixtures written under a
    # Dropbox-synced path can be locked by the indexer between write and reopen.
    $fixtureBase = if ($env:ARTIFACTS_PATH) { Join-Path $env:ARTIFACTS_PATH 'test-fixtures/ApplicationReleaseStage' }
                   else { Join-Path ([IO.Path]::GetTempPath()) 'atap-test-fixtures/ApplicationReleaseStage' }
    if ($fixtureBase -match '(?i)[\/]Dropbox[\/]') { throw "Fixture root must not be under Dropbox: $fixtureBase" }
    $root = Join-Path $fixtureBase ([guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($root) | Out-Null
    $bundle = Join-Path $root 'bundle.upack'; Set-Content $bundle 'fixture'
    $verifier = Join-Path $root 'verify.ps1'; Set-Content $verifier '# fixture'
    $schema = Join-Path $root 'schema.json'; Set-Content $schema '{}'
    $context = [ordered]@{
      productId=$ProductId; ceilingTier='Production'; version=$Version; bundlePath=$bundle
      bundleSha256=(Get-FileHash $bundle).Hash; evidenceRoot=(Join-Path $root '_generated/evidence')
      bundleVerifier=$verifier; manifestSchema=$schema; proGetBaseUrl='https://utat022:50000'
      tooling=@(@{path=$verifier;sha256=(Get-FileHash $verifier).Hash},@{path=$schema;sha256=(Get-FileHash $schema).Hash})
    }
    if ($ProductId -eq 'AceOutpost') {
      # Shape written by Invoke-ApplicationBuildMasterStage.ps1 (Task 16.78).
      $context.databasePackageReference = [ordered]@{ id='ATAPUtilities.Database'; pinnedVersion='0.1.17'; compatibleVersionRange='[0.1.17,0.1.18)'; lifecycleCeiling='database-stable'; nupkgSha256=('b' * 64); feed='database-stable' }
      $context.feedVersion = ($Version -split '\+', 2)[0]
    }
    if ($ProductId -ceq 'AceCommander') {
      $context.ceilingTier = 'Experimental'
      $context.databasePackageReference = [ordered]@{ id='ATAPUtilities.Database'; pinnedVersion='0.1.19-Sprint.1'; compatibleVersionRange='[0.1.19-Sprint.1]'; lifecycleCeiling='database-experimental'; feed='database-experimental'; nupkgSha256='BA6ACB51DA41103D52A99C676096E9F1A35BBD1C9A4016F99633D96CE7828A2D' }
      if ($ProductionDatabase) {
        $context.ceilingTier = 'Production'
        $context.databasePackageReference = [ordered]@{ id='ATAPUtilities.Database'; pinnedVersion='0.1.20'; compatibleVersionRange='[0.1.20]'; lifecycleCeiling='database-stable'; feed='database-stable'; nupkgSha256='33850F533FA266705EC017778BD45A35E9067CC57860E798139992C3C674CFF7' }
      }
    }
    $path = Join-Path $root 'context.json'
    $context | ConvertTo-Json -Depth 5 | Set-Content $path
    @{Context=$context;Path=$path;Hash=(Get-FileHash $path).Hash}
  }
  function Save-FixtureContext($Fixture) {
    $Fixture.Context | ConvertTo-Json -Depth 5 | Set-Content $Fixture.Path
    $Fixture.Hash = (Get-FileHash $Fixture.Path).Hash
  }
}

Describe 'Application release fail-closed preparation' {
  It 'WhatIf never creates an evidence directory or invokes the verifier' {
    $fixture = New-ReleaseContextFixture
    Invoke-ApplicationReleaseStage -ContextPath $fixture.Path -ExpectedContextSha256 $fixture.Hash -Stage Experimental -BuildId 42 -WhatIf
    Test-Path $fixture.Context.evidenceRoot | Should -BeFalse
  }
  It 'rejects context tampering before any mutation' {
    $fixture = New-ReleaseContextFixture
    Add-Content $fixture.Path ' '
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw '*context hash mismatch*'
  }
  It 'rejects bundle tampering' {
    $fixture = New-ReleaseContextFixture
    Add-Content $fixture.Context.bundlePath 'changed'
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw '*bundle hash mismatch*'
  }
  It 'rejects prerelease identities' {
    $fixture = New-ReleaseContextFixture; $fixture.Context.version = '0.1.1-Sprint.2'; Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw '*stable AceCommander*'
  }
  It 'rejects products the approval boundary does not admit' {
    $fixture = New-ReleaseContextFixture; $fixture.Context.productId = 'AceMobile'; Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw '*not admitted*'
  }
  It 'rejects modified tooling' {
    $fixture = New-ReleaseContextFixture; Add-Content $fixture.Context.bundleVerifier 'changed'
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw '*tooling hash mismatch*'
  }
  It 'rejects an unbound schema' {
    $fixture = New-ReleaseContextFixture; $fixture.Context.tooling = @($fixture.Context.tooling[0]); Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw '*schema must be hash-bound*'
  }
  It 'rejects advancing without a preceding successful stage' {
    $fixture = New-ReleaseContextFixture -ProductId AceOutpost
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Production 42 -ErrorAction Stop } | Should -Throw
  }
  It 'rejects cross-build preceding-stage evidence' {
    $fixture = New-ReleaseContextFixture -ProductId AceOutpost
    $runRoot = Join-Path $fixture.Context.evidenceRoot '42'; [IO.Directory]::CreateDirectory($runRoot) | Out-Null
    @{success=$true; contextSha256=$fixture.Hash; bundleSha256=$fixture.Context.bundleSha256; buildId='41';stage='Experimental'} | ConvertTo-Json | Set-Content (Join-Path $runRoot 'Experimental.json')
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Development 42 } | Should -Throw '*Preceding stage evidence*'
  }
  It 'accepts matching previous-stage evidence during WhatIf' {
    $fixture = New-ReleaseContextFixture -ProductId AceOutpost
    $runRoot = Join-Path $fixture.Context.evidenceRoot '42'; [IO.Directory]::CreateDirectory($runRoot) | Out-Null
    @{success=$true; contextSha256=$fixture.Hash; bundleSha256=$fixture.Context.bundleSha256; buildId='42';stage='Experimental'} | ConvertTo-Json | Set-Content (Join-Path $runRoot 'Experimental.json')
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Development 42 -WhatIf } | Should -Not -Throw
  }
  It 'refuses an unsupported distribution stage' {
    $fixture = New-ReleaseContextFixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Distribution 42 } | Should -Throw
  }
  It 'keeps the live raft adapter thin and noninteractive without stripping profiles' {
    $plan = Get-Content (Join-Path $PSScriptRoot '../AceCommander-ApplicationRelease.otter') -Raw
    $plan | Should -Match 'InedoCore::Exec'
    $plan | Should -Match '-NonInteractive -File'
    $plan | Should -Not -Match '-NoProfile|Flyway|Chocolatey|WinGet'
  }
  It 'wires every stage to the Commander-only script with no automatic listeners' {
    # Task 15.196.r: pipelines are global raft items named by their JSON 'Name'; the file is
    # '<Name>.pipeline.json' and every stage targets the global:: plan.
    $pipeline = Get-Content (Join-Path $PSScriptRoot '../AceCommander-ApplicationRelease-5Stage.pipeline.json') -Raw | ConvertFrom-Json
    $pipeline.Name | Should -Be 'AceCommander-ApplicationRelease-5Stage'
    ($pipeline.Stages.Name -join ',') | Should -Be 'Experimental,Development,Integration,QA,Production'
    foreach ($stage in $pipeline.Stages) {
      @($stage.Targets).Count | Should -Be 1
      $stage.Targets[0].ScriptId | Should -Be 'global::AceCommander-ApplicationRelease.otter'
      ($stage.Targets[0].ServerNames -join ',') | Should -Be 'localhost'
    }
    @($pipeline.EventListeners).Count | Should -Be 0
  }
  It 'accepts exact stable .NET informational provenance but not prerelease provenance' {
    $schema = Get-Content (Join-Path $PSScriptRoot '../../../../SolutionDocumentation/schemas/manifest.schema.json') -Raw | ConvertFrom-Json -AsHashtable
    $pattern = $schema['$defs'].applicationComponent.properties.version.pattern
    '0.1.1.1+8f98cb8a30' | Should -Match $pattern
    '0.1.1' | Should -Match $pattern
    '0.1.1-Sprint.1' | Should -Not -Match $pattern
    '0.1.1.1-Sprint.1' | Should -Not -Match $pattern
    $schema.properties.sourceBranch['$ref'] | Should -Be '#/$defs/nonEmptyToken'
    $schema.properties.releaseVersion['$ref'] | Should -Be '#/$defs/semVerString'
  }
  It 'retains boundary admission and excludes historical database literals' {
    $source = Get-Content (Join-Path $PSScriptRoot '../Invoke-ApplicationReleaseStage.ps1') -Raw
    $source | Should -Not -Match "COMMANDER02|0\.1\.6|0\.1\.17|E9CA804E"
    $source | Should -Match 'Get-ApplicationReleaseDatabaseAdmission'
  }
  It 'uses the native form-encoded promotion endpoint for releasebundle feeds' {
    $source = Get-Content (Join-Path $PSScriptRoot '../Invoke-ApplicationReleaseStage.ps1') -Raw
    $source | Should -Match '/api/promotions/promote'
    $source | Should -Match 'application/x-www-form-urlencoded'
    $source | Should -Not -Match 'Promote-ProGetPackage'
    $source | Should -Match 'fromFeed=\$sourceFeed;toFeed=\$feed'
    $source | Should -Match '/upload" -Method Post'
    $source | Should -Match "ContentType 'application/zip'"
    ([regex]::Matches($source, '-MaximumRedirection 0')).Count | Should -Be 3
  }
}

Describe 'Task 16.88.c ProGet key resolved once per stage with 429 backoff' {
  BeforeAll {
    $script:rateLimited = 'bws secret list failed (exit 1). Output: Error: 0: Received error message from server: [429 Too Many Requests] {"object":"error","message":"Slow down! Too many requests. Try again in 1m."}'
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) { function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments)]$Rest) } }
    if (-not (Get-Command Get-SecretATAP -ErrorAction SilentlyContinue)) { function global:Get-SecretATAP { param($SecretName, $SecretStoreType) } }
  }
  BeforeEach {
    $script:calls = 0
    $script:waits = [System.Collections.Generic.List[int]]::new()
    $script:sleep = { param([int]$Seconds) $script:waits.Add($Seconds) }
  }
  It 'returns the key from a single call when Bitwarden answers' {
    Mock Get-SecretATAP { $script:calls++; 'fixture-key' }
    Resolve-ApplicationReleaseSecret -SecretName 'ProGet.BuildMaster.API.Key.fixture' -Sleep $script:sleep | Should -BeExactly 'fixture-key'
    $script:calls | Should -Be 1
    $script:waits.Count | Should -Be 0
  }
  It 'waits the hinted interval plus 5 s after a 429, then succeeds: <Hint>' -ForEach @(
    @{ Hint = 'Try again in 1m.'; Wait = 65 }, @{ Hint = 'Try again in 1s.'; Wait = 6 }, @{ Hint = 'no hint'; Wait = 65 }
  ) {
    $script:message = "bws secret list failed (exit 1). Output: [429 Too Many Requests] $Hint"
    Mock Get-SecretATAP { $script:calls++; if ($script:calls -eq 1) { throw $script:message }; 'fixture-key' }
    Resolve-ApplicationReleaseSecret -SecretName 'ProGet.BuildMaster.API.Key.fixture' -Sleep $script:sleep | Should -BeExactly 'fixture-key'
    $script:calls | Should -Be 2
    @($script:waits) | Should -Be @($Wait)
  }
  It 'rethrows a non-429 failure immediately without waiting' {
    Mock Get-SecretATAP { $script:calls++; throw 'bws secret list failed (exit 1). Output: [504 Gateway Timeout]' }
    { Resolve-ApplicationReleaseSecret -SecretName 'ProGet.BuildMaster.API.Key.fixture' -Sleep $script:sleep } | Should -Throw '*504*'
    $script:calls | Should -Be 1
    $script:waits.Count | Should -Be 0
  }
  It 'stops after MaxAttempts consecutive 429s and rethrows' {
    Mock Get-SecretATAP { $script:calls++; throw $script:rateLimited }
    { Resolve-ApplicationReleaseSecret -SecretName 'ProGet.BuildMaster.API.Key.fixture' -MaxAttempts 3 -Sleep $script:sleep } | Should -Throw '*429*'
    $script:calls | Should -Be 3
    @($script:waits) | Should -Be @(65, 65)
  }
  It 'resolves the ProGet key exactly once in the stage script' {
    $source = Get-Content (Join-Path $PSScriptRoot '../Invoke-ApplicationReleaseStage.ps1') -Raw
    ([regex]::Matches($source, 'Get-SecretATAP -SecretName')).Count | Should -Be 1
    ([regex]::Matches($source, 'Resolve-ApplicationReleaseSecret -SecretName \$secretName')).Count | Should -Be 1
    ([regex]::Matches($source, '\$key = \$proGetKey')).Count | Should -Be 3
    $source | Should -Match '\$proGetKey = \$null'
  }
}

Describe 'Task 16.78 generalized product admission' {
  It 'admits an AceOutpost Production-ceiling context during WhatIf: <Version>' -ForEach @(
    @{ Version = '0.1.16' }, @{ Version = '0.1.16+85df38d1a2' }
  ) {
    $fixture = New-ReleaseContextFixture -ProductId AceOutpost -Version $Version
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 -WhatIf } | Should -Not -Throw
    Test-Path $fixture.Context.evidenceRoot | Should -BeFalse
  }
  It 'keeps the AceCommander pin: a conflicting context database hash is refused' {
    $fixture = New-ReleaseContextFixture
    $fixture.Context.databasePackageReference.nupkgSha256 = ('c' * 64)
    Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 -WhatIf } | Should -Throw '*exact adopted context*'
  }
  It 'refuses an AceOutpost context with the wrong database pin: <Case>' -ForEach @(
    @{ Case = 'Commander version'; Field = 'pinnedVersion'; Value = '0.1.6' },
    @{ Case = 'wrong range'; Field = 'compatibleVersionRange'; Value = '[0.1.17,0.2.0)' },
    @{ Case = 'lower ceiling'; Field = 'lifecycleCeiling'; Value = 'database-experimental' },
    @{ Case = 'other package'; Field = 'id'; Value = 'ATAPUtilities.Other' }
  ) {
    $fixture = New-ReleaseContextFixture -ProductId AceOutpost -Version '0.1.16'
    $fixture.Context.databasePackageReference[$Field] = $Value; Save-FixtureContext $fixture
    $expected = if ($Field -eq 'pinnedVersion') { '*no admitted release database pin*' } else { '*outside the admitted AceOutpost release pin*' }
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 -WhatIf } | Should -Throw $expected
  }
  It 'refuses an AceOutpost context without a hash-approved database package hash' {
    $fixture = New-ReleaseContextFixture -ProductId AceOutpost -Version '0.1.16'
    $fixture.Context.databasePackageReference.Remove('nupkgSha256'); Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 -WhatIf } | Should -Throw '*nupkgSha256*'
  }
  It 'refuses prerelease AceOutpost versions and a feedVersion that disagrees with the version' {
    $fixture = New-ReleaseContextFixture -ProductId AceOutpost -Version '0.1.16-rc.1'
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 -WhatIf } | Should -Throw '*stable AceOutpost*'
    $fixture = New-ReleaseContextFixture -ProductId AceOutpost -Version '0.1.16+abc'
    $fixture.Context.feedVersion = '0.1.15'; Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 -WhatIf } | Should -Throw '*feedVersion*'
  }
  It 'refuses out-of-order AceOutpost stages and accepts the next stage after matching evidence' {
    $fixture = New-ReleaseContextFixture -ProductId AceOutpost -Version '0.1.16'
    $runRoot = Join-Path $fixture.Context.evidenceRoot '77'; [IO.Directory]::CreateDirectory($runRoot) | Out-Null
    @{success=$true; contextSha256=$fixture.Hash; bundleSha256=$fixture.Context.bundleSha256; buildId='77';stage='Integration'} | ConvertTo-Json | Set-Content (Join-Path $runRoot 'Integration.json')
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Production 77 -WhatIf } | Should -Throw
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash QA 77 -WhatIf } | Should -Not -Throw
  }
  It 'exposes the admitted database pins from the approval boundary' {
    . (Join-Path $PSScriptRoot '../ApplicationReleaseAuthenticodeSigning.ps1')
    (Get-ApplicationReleaseDatabaseAdmission -ProductId AceOutpost).PinnedVersion | Should -BeExactly '0.1.17'
    (Get-ApplicationReleaseDatabaseAdmission -ProductId AceCommander).NupkgSha256 | Should -Match '^[A-F0-9]{64}$'
    { Get-ApplicationReleaseDatabaseAdmission -ProductId aceoutpost } | Should -Throw '*no admitted release database pin*'
  }
}

Describe 'Unit 845 exact Experimental-only AceCommander database dependency' -Tag 'Admission1729' {
  BeforeEach {
    Mock Import-Module { throw 'Unexpected module import' }
    Mock Resolve-ApplicationReleaseSecret { throw 'Unexpected secret lookup' }
    Mock Invoke-WebRequest { throw 'Unexpected download' }
    Mock Invoke-RestMethod { throw 'Unexpected upload or promotion' }
    Mock Start-Transcript { throw 'Unexpected transcript' }
  }
  AfterEach {
    Should -Invoke Import-Module -Times 0 -Exactly
    Should -Invoke Resolve-ApplicationReleaseSecret -Times 0 -Exactly
    Should -Invoke Invoke-WebRequest -Times 0 -Exactly
    Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    Should -Invoke Start-Transcript -Times 0 -Exactly
  }
  It 'admits the exact tuple for Experimental preparation with a stable application identity' {
    $fixture = New-ReleaseContextFixture -Version '0.1.12+89a3339a44'
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 -WhatIf } | Should -Not -Throw
    Test-Path $fixture.Context.evidenceRoot | Should -BeFalse
  }
  It 'refuses the retired 018 immutable tuple before any effects' {
    $fixture = New-ReleaseContextFixture
    $fixture.Context.databasePackageReference.pinnedVersion = '0.1.18-Sprint.1'
    $fixture.Context.databasePackageReference.compatibleVersionRange = '[0.1.18-Sprint.1]'
    $fixture.Context.databasePackageReference.nupkgSha256 = '789CC87195813DE4B40ED0A2AD4AB0DC9B2520F06149DC914D9C92216CD3269B'
    Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw '*no admitted release database pin*'
    Test-Path $fixture.Context.evidenceRoot | Should -BeFalse
  }
  It 'refuses the candidate before any effects in <Stage>' -ForEach @(
    @{ Stage='Development' }, @{ Stage='Integration' }, @{ Stage='QA' }, @{ Stage='Production' }
  ) {
    $fixture = New-ReleaseContextFixture -Version '0.1.12'
    # No WhatIf: the ceiling guard itself must refuse before the process block.
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash $Stage 42 } | Should -Throw '*permits only the Experimental stage*'
    Test-Path $fixture.Context.evidenceRoot | Should -BeFalse
  }
  It 'refuses an altered reference field: <Field>' -ForEach @(
    @{ Field='id'; Value='ATAPUtilities.Other' },
    @{ Field='pinnedVersion'; Value='0.1.6' },
    @{ Field='compatibleVersionRange'; Value='[0.1.19-Sprint.1,0.1.19)' },
    @{ Field='lifecycleCeiling'; Value='database-stable' },
    @{ Field='feed'; Value='database-stable' },
    @{ Field='nupkgSha256'; Value=('c' * 64) }
  ) {
    $fixture = New-ReleaseContextFixture
    $fixture.Context.databasePackageReference[$Field] = $Value; Save-FixtureContext $fixture
    $expected = if ($Field -eq 'pinnedVersion') { '*no admitted release database pin*' } else { '*exact adopted context*' }
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw $expected
    Test-Path $fixture.Context.evidenceRoot | Should -BeFalse
  }
  It 'refuses a missing context binding: <Field>' -ForEach @(
    @{ Field='id' }, @{ Field='pinnedVersion' }, @{ Field='compatibleVersionRange' },
    @{ Field='lifecycleCeiling' }, @{ Field='feed' }, @{ Field='nupkgSha256' }
  ) {
    $fixture = New-ReleaseContextFixture
    $fixture.Context.databasePackageReference.Remove($Field); Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw '*exact adopted context*'
  }
  It 'refuses a missing database reference even with a Production ceiling' {
    $fixture = New-ReleaseContextFixture
    $fixture.Context.Remove('databasePackageReference'); $fixture.Context.ceilingTier='Production'; Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw '*exact adopted context*'
  }
  It 'refuses a changed application ceiling: <Ceiling>' -ForEach @(
    @{ Ceiling='Production' }, @{ Ceiling='Development' }, @{ Ceiling='experimental' }
  ) {
    $fixture = New-ReleaseContextFixture
    $fixture.Context.ceilingTier=$Ceiling; Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw '*exact adopted context*'
  }
  It 'refuses context tampering before the candidate exception' {
    $fixture = New-ReleaseContextFixture
    Add-Content $fixture.Path ' '
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw '*context hash mismatch*'
  }
  It 'does not admit an Experimental-ceiling AceOutpost context' {
    $fixture = New-ReleaseContextFixture -ProductId AceOutpost
    $fixture.Context.ceilingTier='Experimental'; Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw '*stable AceOutpost Production-ceiling context*'
  }
  It 'retains AceOutpost Production-ceiling admission' {
    $fixture = New-ReleaseContextFixture -ProductId AceOutpost
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 -WhatIf } | Should -Not -Throw
  }
}

Describe 'Exact 020 Commander Production context preparation' -Tag 'Admission020' {
  BeforeEach {
    Mock Import-Module { throw 'Unexpected module import' }
    Mock Resolve-ApplicationReleaseSecret { throw 'Unexpected secret lookup' }
    Mock Invoke-WebRequest { throw 'Unexpected download' }
    Mock Invoke-RestMethod { throw 'Unexpected upload or promotion' }
    Mock Start-Transcript { throw 'Unexpected transcript' }
  }
  AfterEach {
    Should -Invoke Import-Module -Times 0 -Exactly
    Should -Invoke Resolve-ApplicationReleaseSecret -Times 0 -Exactly
    Should -Invoke Invoke-WebRequest -Times 0 -Exactly
    Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    Should -Invoke Start-Transcript -Times 0 -Exactly
  }
  It 'requires the immediately preceding matching receipt for each tier in order' {
    $fixture = New-ReleaseContextFixture -ProductionDatabase -Version '0.1.13+23b039f0e2'
    $tiers = @('Experimental','Development','Integration','QA','Production')
    $runRoot = Join-Path $fixture.Context.evidenceRoot '42'
    for ($index=0; $index -lt $tiers.Count; $index++) {
      $stage = $tiers[$index]
      if ($index -gt 0) {
        { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash $stage 42 -WhatIf } | Should -Throw
        [IO.Directory]::CreateDirectory($runRoot) | Out-Null
        @{success=$true; contextSha256=$fixture.Hash; bundleSha256=$fixture.Context.bundleSha256; buildId='42';stage=$tiers[$index-1]} | ConvertTo-Json | Set-Content (Join-Path $runRoot ($tiers[$index-1]+'.json'))
      }
      { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash $stage 42 -WhatIf } | Should -Not -Throw
    }
  }
  It 'refuses changed Production context field <Field> before effects' -ForEach @(
    @{Field='id';Value='Other.Database'}, @{Field='pinnedVersion';Value='0.1.21'},
    @{Field='pinnedVersion';Value=''}, @{Field='compatibleVersionRange';Value='[0.1.20,0.1.21)'},
    @{Field='lifecycleCeiling';Value='database-experimental'}, @{Field='feed';Value='database-experimental'},
    @{Field='nupkgSha256';Value=('a'*64)}
  ) {
    $fixture = New-ReleaseContextFixture -ProductionDatabase
    $fixture.Context.databasePackageReference[$Field]=$Value; Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw
    Test-Path $fixture.Context.evidenceRoot | Should -BeFalse
  }
  It 'refuses missing Production binding <Field> before effects' -ForEach @(
    @{Field='id'}, @{Field='pinnedVersion'}, @{Field='compatibleVersionRange'},
    @{Field='lifecycleCeiling'}, @{Field='feed'}, @{Field='nupkgSha256'}
  ) {
    $fixture = New-ReleaseContextFixture -ProductionDatabase
    $fixture.Context.databasePackageReference.Remove($Field); Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw
    Test-Path $fixture.Context.evidenceRoot | Should -BeFalse
  }
  It 'refuses a missing reference or changed ceiling instead of inheriting Production' {
    $fixture = New-ReleaseContextFixture -ProductionDatabase
    $fixture.Context.Remove('databasePackageReference'); Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw
    $fixture = New-ReleaseContextFixture -ProductionDatabase
    $fixture.Context.ceilingTier='Experimental'; Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw
  }
}

Describe 'Exact 020 stable feed remains an actual release gate' -Tag 'Admission020' {
  BeforeAll {
    function New-ReleaseBundle { param($BundlePath,$VerificationPath,$ManifestSchema) throw 'Unmocked verifier prohibited' }
  }
  BeforeEach {
    $script:release020Fixture=New-ReleaseContextFixture -ProductionDatabase -Version '0.1.13+23b039f0e2'
    $script:release020Variant=''
    $script:release020Settings=$global:settings; $script:release020Keys=$global:configRootKeys
    $global:configRootKeys=@{ServicePlacementMapConfigRootKey='Placement'}
    $global:settings=@{Placement=@{ProGet='utat022'}}
    Mock Import-Module { }
    Mock Write-PSFMessage { }
    Mock Start-Transcript { }
    Mock Stop-Transcript { }
    Mock Resolve-ApplicationReleaseSecret { 'SYNTHETIC-NOT-A-CREDENTIAL' }
    Mock Invoke-RestMethod { throw 'Unexpected upload/promotion in already-present fixture' }
    Mock New-ReleaseBundle {
      [IO.Directory]::CreateDirectory($VerificationPath) | Out-Null
      @{databasePackageReference=$script:release020Fixture.Context.databasePackageReference; applicationProvenance=@{root=@{qualityTier='Production';version='0.1.13.1+23b039f0e2'};components=@()}} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $VerificationPath 'manifest.json')
      [pscustomobject]@{ProductId='AceCommander';BundleVersion=$script:release020Fixture.Context.version;VerificationPath=[IO.DirectoryInfo]::new($VerificationPath);VerifiedEntryCount=1}
    }
    Mock Invoke-WebRequest {
      if ($Uri -like '*/nuget/*') {
        $Uri | Should -BeExactly 'https://utat022:50000/nuget/database-stable/v3/flatcontainer/ataputilities.database/0.1.20/ataputilities.database.0.1.20.nupkg'
        if ($script:release020Variant -eq 'MissingStable') { throw 'Synthetic required stable package missing' }
        Set-Content -LiteralPath $OutFile 'synthetic database bytes'
      } else {
        Copy-Item -LiteralPath $script:release020Fixture.Context.bundlePath -Destination $OutFile
      }
    }
    Mock Get-FileHash {
      $selectedPath = if ($LiteralPath) { [string]@($LiteralPath)[0] } else { [string]@($Path)[0] }
      [pscustomobject]@{Hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($selectedPath)))}
    }
    Mock Get-FileHash {
      [pscustomobject]@{Hash=if($script:release020Variant -eq 'WrongStableBytes'){'A'*64}else{'33850F533FA266705EC017778BD45A35E9067CC57860E798139992C3C674CFF7'}}
    } -ParameterFilter { [IO.Path]::GetFileName($LiteralPath) -ceq 'database-reference.nupkg' }
  }
  AfterEach {
    $global:settings=$script:release020Settings; $global:configRootKeys=$script:release020Keys
    Should -Invoke Invoke-RestMethod -Times 0 -Exactly
  }
  It 're-downloads the exact stable database at all five ordered idempotent stages' {
    $fixture=$script:release020Fixture
    foreach ($stage in @('Experimental','Development','Integration','QA','Production')) {
      $receipt=Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash $stage 42 -Confirm:$false
      $receipt.success | Should -BeTrue
      $receipt.stage | Should -BeExactly $stage
      $receipt.databaseReferenceVerified | Should -BeTrue
      $receipt.databaseApplied | Should -BeFalse
    }
    Should -Invoke Invoke-WebRequest -Times 5 -Exactly -ParameterFilter { $Uri -like '*/nuget/database-stable/*' }
  }
  It 'refuses <Variant> before publishing any application or writing a success receipt' -ForEach @(
    @{Variant='MissingStable'}, @{Variant='WrongStableBytes'}
  ) {
    $script:release020Variant=$Variant; $fixture=$script:release020Fixture
    $expected = if ($Variant -eq 'MissingStable') { '*Release download failed*' } else { '*Downloaded artifact hash conflicts*' }
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 -Confirm:$false } | Should -Throw $expected
    Test-Path (Join-Path $fixture.Context.evidenceRoot '42/Experimental.json') | Should -BeFalse
    Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter { $Uri -like '*/nuget/database-stable/*' }
    Should -Invoke Invoke-WebRequest -Times 0 -Exactly -ParameterFilter { $Uri -like '*/upack/*' }
  }
}
