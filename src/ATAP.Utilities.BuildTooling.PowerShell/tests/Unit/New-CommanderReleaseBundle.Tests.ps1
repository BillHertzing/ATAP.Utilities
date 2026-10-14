#Requires -Modules Pester

# Unit coverage for New-CommanderReleaseBundle's guard rails.
#
# These tests deliberately exercise only the parameter contract and the provenance
# gates that run BEFORE any bundle is assembled. Assembling a real bundle needs a
# published payload, a committed installer and committed tooling, which belongs in an
# integration test alongside New-ReleaseManifest.Integration.Tests.ps1 rather than here.
#
# The gates under test are the ones whose absence produced real defects: a hardcoded
# version, an uncommitted installer, and a database reference missing its lifecycle
# ceiling.

BeforeAll {
  $script:functionPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public/New-CommanderReleaseBundle.ps1'
  . $script:functionPath
  $script:command = Get-Command New-CommanderReleaseBundle
}

Describe 'New-CommanderReleaseBundle' {

  Context 'module loading rules' {
    It 'defines only a function and no top-level executable code' {
      $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:functionPath, [ref]$null, [ref]$null)
      $topLevel = @($ast.EndBlock.Statements | Where-Object { $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst] })
      $topLevel.Count | Should -Be 0
    }

    It 'parses without error' {
      $errors = $null
      $null = [System.Management.Automation.Language.Parser]::ParseFile($script:functionPath, [ref]$null, [ref]$errors)
      $errors | Should -BeNullOrEmpty
    }
  }

  Context 'parameter contract' {
    It 'requires <Name>' -ForEach @(
      @{ Name = 'RepoRoot' }
      @{ Name = 'BuildToolingRoot' }
      @{ Name = 'PublishRoot' }
      @{ Name = 'OutputRoot' }
      @{ Name = 'Version' }
      @{ Name = 'SourceCommit' }
      @{ Name = 'SourceTag' }
      @{ Name = 'ConversationId' }
      @{ Name = 'DatabasePackageReference' }
      @{ Name = 'ReleaseNotes' }
      @{ Name = 'ExpectedTestsPassed' }
    ) {
      $attribute = $script:command.Parameters[$Name].Attributes |
        Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
        Select-Object -First 1
      $attribute.Mandatory | Should -BeTrue
    }

    It 'supports ShouldProcess so a caller can dry-run an assembly' {
      $script:command.Parameters.Keys | Should -Contain 'WhatIf'
    }

    It 'accepts canonical three-part release SemVer with optional build metadata' {
      $validation = $script:command.Parameters['Version'].Attributes |
        Where-Object { $_ -is [System.Management.Automation.ValidatePatternAttribute] }
      foreach ($valid in @('0.1.2', '0.1.2+7e134a7136', '10.20.30+build.1-sha.abcdef')) {
        $valid | Should -Match $validation.RegexPattern
      }
    }

    It 'rejects noncanonical, prerelease, and close-variant versions' {
      $validation = $script:command.Parameters['Version'].Attributes |
        Where-Object { $_ -is [System.Management.Automation.ValidatePatternAttribute] }
      foreach ($invalid in @('v0.1.2', '01.1.2', '0.01.2', '0.1.02', '0.1', '0.1.2.3',
          '0.1.2-rc.1', '0.1.2+', '0.1.2+abc..def', '0.1.2+abc_', '0.1.2_7e134a7136')) {
        $invalid | Should -Not -Match $validation.RegexPattern
      }
    }

    It 'rejects a version prefix before entering bundle assembly' {
      { New-CommanderReleaseBundle -Version 'v0.1.2' -RepoRoot $TestDrive -BuildToolingRoot $TestDrive `
          -PublishRoot $TestDrive -OutputRoot $TestDrive -SourceCommit ('a' * 40) -SourceTag 't' `
          -ConversationId '01a07e2b-6577-7f90-96bc-c191ae41fdf5' `
          -DatabasePackageReference @{} -ReleaseNotes 'n' -ExpectedTestsPassed 1 -WhatIf } |
        Should -Throw
    }

    It 'rejects a source commit that is not a full 40-character SHA' {
      { New-CommanderReleaseBundle -Version '0.1.2' -RepoRoot $TestDrive -BuildToolingRoot $TestDrive `
          -PublishRoot $TestDrive -OutputRoot $TestDrive -SourceCommit '1091b76' -SourceTag 't' `
          -ConversationId '01a07e2b-6577-7f90-96bc-c191ae41fdf5' `
          -DatabasePackageReference @{} -ReleaseNotes 'n' -ExpectedTestsPassed 1 -WhatIf } |
        Should -Throw
    }

    It 'rejects an unknown ceiling tier' {
      { New-CommanderReleaseBundle -Version '0.1.2' -RepoRoot $TestDrive -BuildToolingRoot $TestDrive `
          -PublishRoot $TestDrive -OutputRoot $TestDrive -SourceCommit ('a' * 40) -SourceTag 't' `
          -ConversationId '01a07e2b-6577-7f90-96bc-c191ae41fdf5' `
          -DatabasePackageReference @{} -ReleaseNotes 'n' -ExpectedTestsPassed 1 -CeilingTier 'Staging' -WhatIf } |
        Should -Throw
    }

    It 'accepts only a canonical lowercase GUID conversation ID' {
      $validation = $script:command.Parameters['ConversationId'].Attributes |
        Where-Object { $_ -is [System.Management.Automation.ValidatePatternAttribute] }
      '01a07e2b-6577-7f90-96bc-c191ae41fdf5' | Should -MatchExactly $validation.RegexPattern
      foreach ($invalid in @('01A07E2B-6577-7F90-96BC-C191AE41FDF5',
          '01a07e2b65777f9096bcc191ae41fdf5', '{01a07e2b-6577-7f90-96bc-c191ae41fdf5}', 'not-a-guid')) {
        $invalid | Should -Not -MatchExactly $validation.RegexPattern
      }
    }

    It 'rejects a malformed conversation ID before entering bundle assembly' {
      { New-CommanderReleaseBundle -Version '0.1.2' -RepoRoot $TestDrive -BuildToolingRoot $TestDrive `
          -PublishRoot $TestDrive -OutputRoot $TestDrive -SourceCommit ('a' * 40) -SourceTag 't' `
          -ConversationId 'not-a-guid' -DatabasePackageReference @{} -ReleaseNotes 'n' `
          -ExpectedTestsPassed 1 -WhatIf } | Should -Throw
    }
  }

  Context 'provenance gates' {
    BeforeEach {
      $script:validDb = @{
        id                     = 'ATAPUtilities.Database'
        pinnedVersion          = '0.1.6'
        compatibleVersionRange = '[0.1.6,0.1.7)'
        lifecycleCeiling       = 'database-stable'
      }
      $script:baseArgs = @{
        RepoRoot            = $TestDrive
        BuildToolingRoot    = $TestDrive
        PublishRoot         = $TestDrive
        OutputRoot          = $TestDrive
        Version             = '0.1.2'
        SourceCommit        = ('a' * 40)
        SourceTag           = 'AceCommander/v0.1.2'
        ConversationId      = '01a07e2b-6577-7f90-96bc-c191ae41fdf5'
        ReleaseNotes        = 'notes'
        ExpectedTestsPassed = 1
      }
    }

    It 'rejects a DatabasePackageReference missing <Missing>' -ForEach @(
      @{ Missing = 'id' }
      @{ Missing = 'pinnedVersion' }
      @{ Missing = 'compatibleVersionRange' }
      @{ Missing = 'lifecycleCeiling' }
    ) {
      $db = $script:validDb.Clone()
      $db.Remove($Missing)
      { New-CommanderReleaseBundle @script:baseArgs -DatabasePackageReference $db -WhatIf } |
        Should -Throw -ExpectedMessage "*$Missing*"
    }

    It 'rejects a DatabasePackageReference whose value is whitespace' {
      $db = $script:validDb.Clone()
      $db.pinnedVersion = '   '
      { New-CommanderReleaseBundle @script:baseArgs -DatabasePackageReference $db -WhatIf } |
        Should -Throw -ExpectedMessage '*pinnedVersion*'
    }

    It 'rejects a directory parameter that does not exist' {
      $missing = Join-Path $TestDrive 'no-such-directory'
      { New-CommanderReleaseBundle @script:baseArgs -PublishRoot $missing -DatabasePackageReference $script:validDb -WhatIf } |
        Should -Throw -ExpectedMessage '*PublishRoot*'
    }

    It 'requires the manifest schema to exist under BuildToolingRoot' {
      # BuildToolingRoot is $TestDrive, which has no SolutionDocumentation/schemas.
      { New-CommanderReleaseBundle @script:baseArgs -DatabasePackageReference $script:validDb -WhatIf } |
        Should -Throw -ExpectedMessage '*schema*'
    }
  }

  Context 'traceable deterministic output' {
    It 'stamps the exact conversation ID before reproducibility hashing' {
      $conversationId = '01a07e2b-6577-7f90-96bc-c191ae41fdf5'
      $repoRoot = Join-Path $TestDrive 'repo'
      $publishRoot = Join-Path $TestDrive 'publish'
      $outputRoot = Join-Path $TestDrive 'output'
      $installer = Join-Path $repoRoot 'AceCommander/Deployment/Install-AceCommanderRelease.ps1'
      New-Item -ItemType Directory -Path (Split-Path -Parent $installer), $publishRoot, $outputRoot -Force | Out-Null
      Set-Content -LiteralPath $installer -Value 'function Install-AceCommanderRelease { }' -Encoding utf8
      Set-Content -LiteralPath (Join-Path $publishRoot 'AceCommander.dll') -Value 'fixture payload' -Encoding utf8
      $provenancePath = Join-Path $TestDrive 'application-provenance.json'
      [ordered]@{
        productId = 'AceCommander'
        root = [ordered]@{
          id = 'AceCommander.Server'
          version = '0.1.2.2+trace.1'
          qualityTier = 'Production'
          projectPath = 'AceCommander/AceCommander.Server/AceCommander.Server.csproj'
        }
        components = @()
      } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $provenancePath -Encoding utf8
      Mock Write-PSFMessage { }
      Mock git {
        if ($args -contains 'status') { return }
        if ($args -contains 'log') { return ('b' * 40) }
        throw "Unexpected git arguments: $args"
      }
      $buildToolingRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $script:functionPath)))
      $result = New-CommanderReleaseBundle -RepoRoot $repoRoot -BuildToolingRoot $buildToolingRoot `
        -PublishRoot $publishRoot -OutputRoot $outputRoot -Version '0.1.2+trace.1' `
        -SourceCommit ('a' * 40) -SourceTag 'AceCommander/v0.1.2+trace.1' -ConversationId $conversationId `
        -Branch 'test' -BuildAgent 'test' `
        -ApplicationProvenancePath $provenancePath `
        -DatabasePackageReference @{ id = 'ATAPUtilities.Database'; pinnedVersion = '0.1.13'; compatibleVersionRange = '[0.1.13,0.1.14)'; lifecycleCeiling = 'database-stable' } `
        -ReleaseNotes 'traceability fixture' -ExpectedTestsPassed 1 -Confirm:$false
      $verificationPath = Join-Path $result.Root 'staging/tests/verification.json'
      $verification = Get-Content -LiteralPath $verificationPath -Raw | ConvertFrom-Json
      $releaseContext = Get-Content -LiteralPath $result.ContextPath -Raw | ConvertFrom-Json
      $verification.conversationId | Should -BeExactly $conversationId
      $releaseContext.conversationId | Should -BeExactly $conversationId
      (Get-FileHash -LiteralPath $result.ContextPath).Hash | Should -BeExactly $result.ContextSha256
      $manifestA = Join-Path $result.Root 'manifest-a/manifest.json'
      $manifestB = Join-Path $result.Root 'manifest-b/manifest.json'
      (Get-FileHash -LiteralPath $manifestA).Hash | Should -BeExactly (Get-FileHash -LiteralPath $manifestB).Hash
      $archiveA = Get-ChildItem -LiteralPath (Join-Path $result.Root 'archive-a') -File -Filter '*.upack' | Select-Object -First 1
      $archiveB = Get-ChildItem -LiteralPath (Join-Path $result.Root 'archive-b') -File -Filter '*.upack' | Select-Object -First 1
      (Get-FileHash -LiteralPath $archiveA.FullName).Hash | Should -BeExactly (Get-FileHash -LiteralPath $archiveB.FullName).Hash
      $manifest = Get-Content -LiteralPath $manifestA -Raw | ConvertFrom-Json
      $testEvidence = @($manifest.testEvidence | Where-Object path -EQ 'tests/verification.json')
      $testEvidence.Count | Should -Be 1
      $testEvidence[0].checksumSha256 | Should -BeExactly (Get-FileHash -LiteralPath $verificationPath).Hash.ToLowerInvariant()
    }
  }
}
