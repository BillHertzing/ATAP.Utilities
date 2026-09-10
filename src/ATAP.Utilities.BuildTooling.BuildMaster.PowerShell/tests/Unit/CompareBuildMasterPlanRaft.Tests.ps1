BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  # Get-PVal and Get-SecretATAP live in sibling BuildTooling modules; the unit under test
  # is dot-sourced in isolation, so both are stubbed here. The stub key value is never a
  # real secret and is asserted never to appear in emitted output.
  function global:Get-PVal {
    param($ParameterName, $originalPSBoundParameters, $DefaultValue)
    $DefaultValue
  }

  function global:Get-SecretATAP { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) 'stub-api-key' }

  . "$PSScriptRoot\..\..\public\Compare-BuildMasterPlanRaft.ps1"

  # A distinctive token planted in the plan body. No emitted record may ever contain it.
  $script:planBodyMarker = 'SECRETPLANBODYMARKER'

  $script:planTemplate = @'
##########################################################################
# Fixture-Stage - BuildMaster OtterScript Plan
# !! EDITING THIS FILE IS NOT ENOUGH - SYNC IT TO THE RAFT !!
# This comment mentions Invoke-DecoyStage.ps1 and Arguments: on purpose,
# because comment prose must never be parsed as a declaration.
##########################################################################

set $FixtureStageScript = $PathCombine($SourcePath, Invoke-FixtureStage.ps1);

Exec
(
    FileName: pwsh,
    Arguments: >>-NoProfile -File "$FixtureStageScript" -Alpha "$Alpha" -Beta "$Beta">>,
    WorkingDirectory: $SourcePath,
    SuccessExitCode: 0
);

Log-Information SECRETPLANBODYMARKER;
'@

  $script:runnerTemplate = @'
#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$Alpha,
  [string]$Beta
)

function Invoke-FixtureStage {
  param([string]$NotAScriptParameter)
  $NotAScriptParameter
}
'@

  function global:New-RaftItemResponse {
    param(
      [Parameter(Mandatory)][string]$Content,
      [string]$ItemName = 'Fixture.otter',
      [int]$ItemId = 3012
    )

    [PSCustomObject]@{
      RaftItem_Id          = $ItemId
      RaftItem_Name        = $ItemName
      Content_Bytes        = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Content))
      ModifiedOn_Date      = '2026-09-04T11:22:33.0000000Z'
      ModifiedBy_User_Name = 'whertzing'
    }
  }
}

AfterAll {
  Remove-Item -Path 'Function:\New-RaftItemResponse' -Force -ErrorAction SilentlyContinue
}

Describe 'Compare-BuildMasterPlanRaft [public]' {
  BeforeEach {
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "bm_cmp_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null

    $script:planPath = Join-Path $script:tempDir 'Fixture.otter'
    $script:runnerPath = Join-Path $script:tempDir 'Invoke-FixtureStage.ps1'
    [System.IO.File]::WriteAllText($script:planPath, $script:planTemplate, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($script:runnerPath, $script:runnerTemplate, [System.Text.UTF8Encoding]::new($false))

    $script:diskText = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($script:planPath))

    $script:commonArgs = @{
      BuildMasterAdminApiKeySecretName = 'BuildMaster.Admin.API.Key.test'
      BuildMasterBaseUrl               = 'http://buildmaster.test'
    }
  }

  AfterEach {
    Remove-Item -LiteralPath $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    $global:configRootKeys = $null
    $global:settings = $null
  }

  It 'reports Match when the raft content is byte-identical to the file on disk' {
    Mock Invoke-RestMethod { @(New-RaftItemResponse -Content $script:diskText) }

    $result = Compare-BuildMasterPlanRaft -Path $script:planPath @script:commonArgs

    $result.Status | Should -Be 'Match'
    $result.ContentMatches | Should -BeTrue
    $result.NormalizedContentMatches | Should -BeTrue
    $result.RaftContentSha256 | Should -Be $result.DiskContentSha256
    $result.RaftItemId | Should -Be 3012
    $result.ModifiedByUserName | Should -Be 'whertzing'
    $result.DriftReasons.Count | Should -Be 0
    $result.ArgumentComparison[0].RunnerScript | Should -Be 'Invoke-FixtureStage.ps1'
    $result.ArgumentComparison[0].ArgumentNamesMatch | Should -BeTrue
  }

  It 'reports Drift with ContentDrift when the raft content differs from disk' {
    $driftedText = $script:diskText + "`nLog-Information extra;`n"
    Mock Invoke-RestMethod { @(New-RaftItemResponse -Content $driftedText) }

    $result = Compare-BuildMasterPlanRaft -Path $script:planPath @script:commonArgs

    $result.Status | Should -Be 'Drift'
    $result.ContentMatches | Should -BeFalse
    $result.DriftReasons | Should -Contain 'ContentDrift'
    $result.RaftContentSha256 | Should -Not -Be $result.DiskContentSha256
    $result.RaftContentLength | Should -BeGreaterThan $result.DiskContentLength
  }

  It 'reports ArgumentNameDrift when the deployed plan passes an argument the runner does not declare' {
    # The 2026-08-03 failure mode in miniature: the raft plan's argument list and the
    # on-disk runner's parameter block have diverged.
    $driftedText = $script:diskText -replace '-Beta "\$Beta"', '-Beta "$Beta" -Gamma "$Gamma"'
    Mock Invoke-RestMethod { @(New-RaftItemResponse -Content $driftedText) }

    $result = Compare-BuildMasterPlanRaft -Path $script:planPath @script:commonArgs

    $result.Status | Should -Be 'Drift'
    $result.DriftReasons | Should -Contain 'ArgumentNameDrift'
    $result.ArgumentSource | Should -Be 'Raft'
    $result.ArgumentComparison[0].ArgumentNamesMatch | Should -BeFalse
    $result.ArgumentComparison[0].ArgumentsNotInRunner | Should -Contain 'Gamma'
    $result.ArgumentComparison[0].RunnerParameterNames | Should -Contain 'Alpha'
    # pwsh host switches are not runner parameters and must not be compared as such.
    $result.ArgumentComparison[0].PlanArgumentNames | Should -Not -Contain 'NoProfile'
    $result.ArgumentComparison[0].PlanArgumentNames | Should -Not -Contain 'File'
  }

  It 'reports MissingFromRaft when the raft returns no matching item' {
    Mock Invoke-RestMethod { @() }

    $result = Compare-BuildMasterPlanRaft -Path $script:planPath @script:commonArgs

    $result.Status | Should -Be 'MissingFromRaft'
    $result.ContentMatches | Should -BeFalse
    $result.RaftContentSha256 | Should -BeNullOrEmpty
    $result.DiskContentSha256 | Should -Not -BeNullOrEmpty
  }

  It 'reports MissingOnDisk when the raft holds an item whose file is absent' {
    Mock Invoke-RestMethod { @(New-RaftItemResponse -Content $script:diskText) }

    $absent = Join-Path $script:tempDir 'Absent.otter'
    $result = Compare-BuildMasterPlanRaft -Path $absent -RaftItemName 'Fixture.otter' @script:commonArgs

    $result.Status | Should -Be 'MissingOnDisk'
    $result.DiskContentSha256 | Should -BeNullOrEmpty
    $result.RaftContentSha256 | Should -Not -BeNullOrEmpty
  }

  It 'fails closed as Unreachable when the BuildMaster call throws' {
    Mock Invoke-RestMethod { throw 'No connection could be made because the target machine actively refused it.' }

    $result = Compare-BuildMasterPlanRaft -Path $script:planPath @script:commonArgs

    $result.Status | Should -Be 'Unreachable'
    $result.Status | Should -Not -Be 'Match'
    $result.ContentMatches | Should -BeFalse
    $result.DriftReasons | Should -Contain 'Unreachable'
    $result.Reason | Should -Match 'actively refused'
  }

  It 'scopes the raft query to the application when ApplicationId is supplied' {
    # An unscoped query silently omits application-scoped items such as
    # AceCommander-ApplicationRelease under Application_Id 1003.
    Mock Invoke-RestMethod { @(New-RaftItemResponse -Content $script:diskText) }

    $result = Compare-BuildMasterPlanRaft -Path $script:planPath -ApplicationId 1003 @script:commonArgs

    $result.ApplicationScoped | Should -BeTrue
    $result.ApplicationId | Should -Be 1003
    Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
      $Uri -like '*/Rafts_GetRaftItems' -and $Body['Application_Id'] -eq 1003
    }
  }

  It 'never calls a BuildMaster write endpoint' {
    Mock Invoke-RestMethod { @(New-RaftItemResponse -Content $script:diskText) }

    Compare-BuildMasterPlanRaft -Path $script:planPath @script:commonArgs | Out-Null

    Should -Not -Invoke Invoke-RestMethod -ParameterFilter {
      $Uri -match 'CreateOrUpdate|Delete|Set_|Create_'
    }
  }

  It 'emits metadata only - no plan body text and no secret value in any record' {
    $driftedText = $script:diskText + "`nLog-Information extra;`n"
    Mock Invoke-RestMethod { @(New-RaftItemResponse -Content $driftedText) }

    $records = @(Compare-BuildMasterPlanRaft -Path $script:planPath @script:commonArgs)
    $serialized = $records | ConvertTo-Json -Depth 12

    $serialized | Should -Not -Match $script:planBodyMarker
    $serialized | Should -Not -Match 'Log-Information'
    $serialized | Should -Not -Match 'stub-api-key'
    $serialized | Should -Not -Match 'Content_Bytes'
  }

  It 'exposes no ShouldProcess surface, because it never writes' {
    $command = Get-Command Compare-BuildMasterPlanRaft
    $command.Parameters.ContainsKey('WhatIf') | Should -BeFalse
    $command.Parameters.ContainsKey('Confirm') | Should -BeFalse
  }
}
