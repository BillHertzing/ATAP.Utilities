BeforeAll {
  . (Join-Path $PSScriptRoot '../Invoke-ApplicationReleaseStage.ps1')
  function New-ReleaseContextFixture {
    $root = Join-Path $PSScriptRoot ('../../../../_generated/Sprint0015/Task15.185/COMMANDER02-release-repair/stage-fixtures/' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($root) | Out-Null
    $bundle = Join-Path $root 'bundle.upack'; Set-Content $bundle 'fixture'
    $verifier = Join-Path $root 'verify.ps1'; Set-Content $verifier '# fixture'
    $schema = Join-Path $root 'schema.json'; Set-Content $schema '{}'
    $context = [ordered]@{
      productId='AceCommander'; ceilingTier='Production'; version='0.1.1'; bundlePath=$bundle
      bundleSha256=(Get-FileHash $bundle).Hash; evidenceRoot=(Join-Path $root '_generated/evidence')
      bundleVerifier=$verifier; manifestSchema=$schema; proGetBaseUrl='https://utat022:50000'
      tooling=@(@{path=$verifier;sha256=(Get-FileHash $verifier).Hash},@{path=$schema;sha256=(Get-FileHash $schema).Hash})
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
  It 'rejects other products' {
    $fixture = New-ReleaseContextFixture; $fixture.Context.productId = 'AceOutpost'; Save-FixtureContext $fixture
    { Invoke-ApplicationReleaseStage $fixture.Path $fixture.Hash Experimental 42 } | Should -Throw '*stable AceCommander*'
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
    $pipeline = Get-Content (Join-Path $PSScriptRoot '../AceCommander-ApplicationRelease.pipeline.json') -Raw | ConvertFrom-Json
    ($pipeline.Stages.Name -join ',') | Should -Be 'Experimental,Development,Integration,QA,Production'
    foreach ($stage in $pipeline.Stages) {
      @($stage.Targets).Count | Should -Be 1
      $stage.Targets[0].ScriptId | Should -Be 'AceCommander-ApplicationRelease.otter'
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
