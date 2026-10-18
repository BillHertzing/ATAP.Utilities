BeforeAll {
  . (Join-Path $PSScriptRoot '../Invoke-ApplicationReleaseStage.ps1')
  function New-ReleaseContextFixture {
    param([string]$ProductId = 'AceCommander', [string]$Version = '0.1.1')
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
    $fixture = New-ReleaseContextFixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Production 42 -ErrorAction Stop } | Should -Throw
  }
  It 'rejects cross-build preceding-stage evidence' {
    $fixture = New-ReleaseContextFixture
    $runRoot = Join-Path $fixture.Context.evidenceRoot '42'; [IO.Directory]::CreateDirectory($runRoot) | Out-Null
    @{success=$true; contextSha256=$fixture.Hash; bundleSha256=$fixture.Context.bundleSha256; buildId='41';stage='Experimental'} | ConvertTo-Json | Set-Content (Join-Path $runRoot 'Experimental.json')
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Development 42 } | Should -Throw '*Preceding stage evidence*'
  }
  It 'accepts matching previous-stage evidence during WhatIf' {
    $fixture = New-ReleaseContextFixture
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
  It 'keeps product and database pins out of the stage script (Task 16.78)' {
    $source = Get-Content (Join-Path $PSScriptRoot '../Invoke-ApplicationReleaseStage.ps1') -Raw
    $source | Should -Not -Match "COMMANDER02|'AceCommander'|0\.1\.6|0\.1\.17|E9CA804E"
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
    $fixture.Context.databasePackageReference = [ordered]@{ id='ATAPUtilities.Database'; pinnedVersion='0.1.6'; nupkgSha256=('c' * 64) }
    Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 -WhatIf } | Should -Throw '*conflicts with the admitted pin*'
  }
  It 'refuses an AceOutpost context with the wrong database pin: <Case>' -ForEach @(
    @{ Case = 'Commander version'; Field = 'pinnedVersion'; Value = '0.1.6' },
    @{ Case = 'wrong range'; Field = 'compatibleVersionRange'; Value = '[0.1.17,0.2.0)' },
    @{ Case = 'lower ceiling'; Field = 'lifecycleCeiling'; Value = 'database-experimental' },
    @{ Case = 'other package'; Field = 'id'; Value = 'ATAPUtilities.Other' }
  ) {
    $fixture = New-ReleaseContextFixture -ProductId AceOutpost -Version '0.1.16'
    $fixture.Context.databasePackageReference[$Field] = $Value; Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 -WhatIf } | Should -Throw '*outside the admitted AceOutpost release pin*'
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
