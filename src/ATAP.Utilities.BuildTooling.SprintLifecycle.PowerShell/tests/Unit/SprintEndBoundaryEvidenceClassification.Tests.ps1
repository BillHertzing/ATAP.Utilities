#Requires -Version 7.0

BeforeAll {
  function Set-SprintLoginScheduledTaskTarget {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Boundary, [string]$GitRoot, [string[]]$WorktreePaths, [switch]$CheckOnly)
    [PSCustomObject]@{ Ok = $true; Failures = @() }
  }
  . (Join-Path $PSScriptRoot '../../public/Test-SprintEndBoundaryState.ps1')
  $script:physicalSearchCommand = Get-Command Select-String -CommandType Cmdlet
}

Describe 'SprintEnd planning evidence classification and bounded receipts' -Tag 'Unit' {
  BeforeEach {
    Mock Write-PSFMessage {}
    Mock Set-SprintLoginScheduledTaskTarget { [PSCustomObject]@{ Ok = $true; Failures = @() } }
    $script:logicalPaths = @()
    $script:fixtureText = '{"source":"ATAP.Utilities-wt-137-Sprint-0015-work-items"}'
    Mock Get-ChildItem -ParameterFilter { $File -and $Recurse } {
      foreach ($logicalPath in $script:logicalPaths) {
        if ($logicalPath -like $Filter) { [PSCustomObject]@{ FullName = $logicalPath } }
      }
    }
    Mock Select-String {
      $script:fixtureText | & $script:physicalSearchCommand -Pattern $Pattern -AllMatches
    }
  }

  It 'recognizes retained Planning JSON at <Path>' -ForEach @(
    @{ Path = 'C:\Fixture\_Planning\InformationForTheFuture\Sprint0015\AgentStruggleRemediation\cause-countermeasure-matrix.json' },
    @{ Path = 'C:/Fixture/_Planning-wt-35-Sprint-0015-work-items/InformationForTheFuture/input-manifest.json' },
    @{ Path = 'C:\Fixture\_PLANNING\informationforthefuture\EvidenceManifest.JSON' },
    @{ Path = 'C:/Fixture/_Planning/Research/OrganizationalModel/SeedData/ATAPUtilities/vocabulary.source.json' },
    @{ Path = 'C:/Fixture/ATAP.Utilities/src/Configuration/obj/ATAP.Utilities.Configuration.csproj.nuget.dgspec.json' },
    @{ Path = 'C:/Fixture/ATAP.Utilities/tests/Unit/obj/project.assets.json' },
    @{ Path = 'C:/Fixture/Ace/obj/Debug/net10.0/Ace.sourcelink.json' },
    @{ Path = 'C:\Fixture\Ace\OBJ\DEBUG\Ace.SourceLink.JSON' }
  ) {
    $script:logicalPaths = @($Path)
    $result = Test-SprintEndBoundaryState -GitRoot $TestDrive -ProfilePaths @() -ProhibitedEnvironmentVariableNames @()
    $result.Ok | Should -BeTrue
    $result.HistoricalStaleReferences.Count | Should -Be 1
    $result.StaleReferences.Count | Should -Be 1
    $result.StaleReferences[0].MatchedReferenceTokens | Should -Contain '-wt-137-Sprint-0015-work-items'
  }

  It 'keeps true config and lookalike evidence identities live at <Path>' -ForEach @(
    @{ Path = 'C:/Fixture/_Planning/.mcp.json' },
    @{ Path = 'C:/Fixture/_Planning/InformationForTheFuture/.mcp.json' },
    @{ Path = 'C:/Fixture/_Planning/InformationForTheFuture/.codex/config.toml' },
    @{ Path = 'C:/Fixture/_Planning/InformationForTheFuture/.claude/settings.json' },
    @{ Path = 'C:/Fixture/_Planning/InformationForTheFuture/settings.json' },
    @{ Path = 'C:/Fixture/SharedVSCode/UserSettings/settings.jsonc' },
    @{ Path = 'C:/Fixture/_Planning/InformationForTheFuture/Overview.code-workspace' },
    @{ Path = 'C:/Fixture/_Planning/InformationForTheFutureExtra/evidence.json' },
    @{ Path = 'C:/Fixture/Fake_Planning/InformationForTheFuture/evidence.json' },
    @{ Path = 'C:/Fixture/_PlanningExtra/InformationForTheFuture/evidence.json' },
    @{ Path = 'C:/Fixture/_Planning/Research/OrganizationalModel/SeedDataExtra/evidence.json' },
    @{ Path = 'C:/Fixture/_Planning/Research/Other/config.json' },
    @{ Path = 'C:/Fixture/Ace/InformationForTheFuture/config.json' },
    @{ Path = 'C:/Fixture/Ace/obj/.mcp.json' },
    @{ Path = 'C:/Fixture/Ace/obj/.codex/Ace.sourcelink.json' },
    @{ Path = 'C:/Fixture/Ace/obj/config.json' },
    @{ Path = 'C:/Fixture/Ace/objExtra/project.assets.json' },
    @{ Path = 'C:/Fixture/Ace/bin/project.assets.json' },
    @{ Path = 'C:/Fixture/Ace/obj/notproject.assets.json' },
    @{ Path = 'C:/Fixture/Ace/obj/Ace.csproj.nuget.dgspec.json.backup.json' }
  ) {
    $script:logicalPaths = @($Path)
    $result = Test-SprintEndBoundaryState -GitRoot $TestDrive -ProfilePaths @() -ProhibitedEnvironmentVariableNames @()
    $result.Ok | Should -BeFalse
    $result.LiveStaleReferences.Count | Should -Be 1
    $result.Failures | Should -Contain 'StaleSprintReferences'
  }

  It 'still reports existing historical identities including archived config names' -ForEach @(
    @{ Path = 'C:/Fixture/Ace/_generated/receipt.json' },
    @{ Path = 'C:/Fixture/_Planning/SprintHistory/Archived/.mcp.json' },
    @{ Path = 'C:/Fixture/SharedVSCode/SolutionDocumentation/Inventory-Task-8.20.before.summary.json' }
  ) {
    $script:logicalPaths = @($Path)
    $result = Test-SprintEndBoundaryState -GitRoot $TestDrive -ProfilePaths @() -ProhibitedEnvironmentVariableNames @()
    $result.Ok | Should -BeTrue
    $result.HistoricalStaleReferences.Count | Should -Be 1
  }

  It 'bounds a long receipt while retaining markers beyond its excerpt and all distinct tokens' {
    $script:logicalPaths = @('C:/Fixture/_Planning/.mcp.json')
    $script:fixtureText = ('x' * 2000) + 'Ace-wt-45-Sprint-0015-work-items ATAP.Utilities-wt-137-Sprint-0015-work-items Ace-wt-45-Sprint-0015-work-items'
    $result = Test-SprintEndBoundaryState -GitRoot $TestDrive -ProfilePaths @() -ProhibitedEnvironmentVariableNames @()
    $row = $result.LiveStaleReferences[0]
    $row.Text.Length | Should -Be 512
    $row.TextTruncated | Should -BeTrue
    $row.MatchedReferenceTokens.Count | Should -Be 2
    $row.MatchedReferenceTokens | Should -Contain '-wt-45-Sprint-0015-work-items'
    $row.MatchedReferenceTokens | Should -Contain '-wt-137-Sprint-0015-work-items'
    $result.Ok | Should -BeFalse
  }

  It 'preserves short Text and explicitly marks it untruncated' {
    $script:logicalPaths = @('C:/Fixture/_Planning/.mcp.json')
    $result = Test-SprintEndBoundaryState -GitRoot $TestDrive -ProfilePaths @() -ProhibitedEnvironmentVariableNames @()
    $result.StaleReferences[0].Text | Should -Be $script:fixtureText
    $result.StaleReferences[0].TextTruncated | Should -BeFalse
  }
}
