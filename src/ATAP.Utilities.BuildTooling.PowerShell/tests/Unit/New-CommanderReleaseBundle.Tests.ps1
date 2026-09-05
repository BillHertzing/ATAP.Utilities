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

    It 'rejects a version that is not three dotted integers' {
      # Guards against the one-shot predecessor's habit of embedding a literal.
      { New-CommanderReleaseBundle -Version 'v0.1.2' -RepoRoot $TestDrive -BuildToolingRoot $TestDrive `
          -PublishRoot $TestDrive -OutputRoot $TestDrive -SourceCommit ('a' * 40) -SourceTag 't' `
          -DatabasePackageReference @{} -ReleaseNotes 'n' -ExpectedTestsPassed 1 -WhatIf } |
        Should -Throw
    }

    It 'rejects a source commit that is not a full 40-character SHA' {
      { New-CommanderReleaseBundle -Version '0.1.2' -RepoRoot $TestDrive -BuildToolingRoot $TestDrive `
          -PublishRoot $TestDrive -OutputRoot $TestDrive -SourceCommit '1091b76' -SourceTag 't' `
          -DatabasePackageReference @{} -ReleaseNotes 'n' -ExpectedTestsPassed 1 -WhatIf } |
        Should -Throw
    }

    It 'rejects an unknown ceiling tier' {
      { New-CommanderReleaseBundle -Version '0.1.2' -RepoRoot $TestDrive -BuildToolingRoot $TestDrive `
          -PublishRoot $TestDrive -OutputRoot $TestDrive -SourceCommit ('a' * 40) -SourceTag 't' `
          -DatabasePackageReference @{} -ReleaseNotes 'n' -ExpectedTestsPassed 1 -CeilingTier 'Staging' -WhatIf } |
        Should -Throw
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
}
