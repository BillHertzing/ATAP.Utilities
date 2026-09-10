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

  It 'reports UndeclaredArgument when the deployed plan passes an argument the runner does not declare' {
    # Broken loudly rather than silently: the runner errors on the next run instead of
    # hanging, so this is a lesser condition than a missing mandatory parameter - but it
    # is still drift and must still be reported.
    $driftedText = $script:diskText -replace '-Beta "\$Beta"', '-Beta "$Beta" -Gamma "$Gamma"'
    Mock Invoke-RestMethod { @(New-RaftItemResponse -Content $driftedText) }

    $result = Compare-BuildMasterPlanRaft -Path $script:planPath @script:commonArgs

    $result.Status | Should -Be 'Drift'
    $result.DriftReasons | Should -Contain 'UndeclaredArgument'
    $result.DriftReasons | Should -Not -Contain 'MandatoryArgumentMissing'
    $result.SilentHangSignaturePresent | Should -BeFalse
    $result.ArgumentSource | Should -Be 'Raft'
    $result.ArgumentComparison[0].ArgumentNamesMatch | Should -BeFalse
    $result.ArgumentComparison[0].ArgumentBindingSatisfied | Should -BeFalse
    $result.ArgumentComparison[0].ArgumentsNotInRunner | Should -Contain 'Gamma'
    $result.ArgumentComparison[0].RunnerParameterNames | Should -Contain 'Alpha'
    # pwsh host switches are not runner parameters and must not be compared as such.
    $result.ArgumentComparison[0].PlanArgumentNames | Should -Not -Contain 'NoProfile'
    $result.ArgumentComparison[0].PlanArgumentNames | Should -Not -Contain 'File'
  }

  Context 'argument asymmetry classification (Task 15.171.e)' {
    It 'does NOT report Drift when the runner declares an OPTIONAL parameter the plan does not pass' {
      # The cry-wolf defect. Adding an optional parameter to a runner is a routine,
      # permanent, benign asymmetry; before this fix it turned every healthy plan red.
      [System.IO.File]::WriteAllText($script:runnerPath, ($script:runnerTemplate -replace '(?m)^\s*\[string\]\$Beta$', "  [string]`$Beta,`n  [string]`$Gamma"), [System.Text.UTF8Encoding]::new($false))
      Mock Invoke-RestMethod { @(New-RaftItemResponse -Content $script:diskText) }

      $result = Compare-BuildMasterPlanRaft -Path $script:planPath @script:commonArgs

      $result.Status | Should -Be 'Match'
      $result.DriftReasons.Count | Should -Be 0
      $result.InformationalReasons | Should -Contain 'OptionalParametersNotPassed'
      $result.SilentHangSignaturePresent | Should -BeFalse
      $result.ArgumentComparison[0].OptionalRunnerParametersNotInPlan | Should -Contain 'Gamma'
      $result.ArgumentComparison[0].MandatoryRunnerParametersNotInPlan.Count | Should -Be 0
      # The raw name sets genuinely differ - that fact is preserved - but the binding is
      # satisfied, and the binding is what the verdict rests on.
      $result.ArgumentComparison[0].ArgumentNamesMatch | Should -BeFalse
      $result.ArgumentComparison[0].ArgumentBindingSatisfied | Should -BeTrue
    }

    It 'reports MandatoryArgumentMissing, distinguishably, when a MANDATORY runner parameter is absent from the raft Arguments line' {
      # The 2026-08-03 silent-hang signature exactly: the stage blocks forever on an
      # invisible mandatory-parameter prompt under the non-interactive LocalAgent.
      [System.IO.File]::WriteAllText($script:runnerPath, ($script:runnerTemplate -replace '(?m)^\s*\[string\]\$Beta$', "  [string]`$Beta,`n  [Parameter(Mandatory)]`n  [string]`$Gamma"), [System.Text.UTF8Encoding]::new($false))
      Mock Invoke-RestMethod { @(New-RaftItemResponse -Content $script:diskText) }

      $result = Compare-BuildMasterPlanRaft -Path $script:planPath @script:commonArgs

      $result.Status | Should -Be 'Drift'
      $result.DriftReasons | Should -Contain 'MandatoryArgumentMissing'
      # Distinguishable in the OUTPUT, not merely in the code.
      $result.SilentHangSignaturePresent | Should -BeTrue
      $result.MandatoryParameterAnalysis[0].MandatoryRunnerParametersMissingFromRaft | Should -Contain 'Gamma'
      $result.MandatoryParameterAnalysis[0].MandatoryRunnerParameterCount | Should -Be 1
      $result.MandatoryParameterAnalysis[0].SilentHangSignaturePresent | Should -BeTrue
      $result.ArgumentComparison[0].MandatoryRunnerParametersNotInPlan | Should -Contain 'Gamma'
      $result.ArgumentComparison[0].OptionalRunnerParametersNotInPlan.Count | Should -Be 0
      $result.ArgumentComparison[0].ArgumentBindingSatisfied | Should -BeFalse
      # A missing mandatory parameter must never be filed under the benign heading.
      $result.InformationalReasons | Should -Not -Contain 'OptionalParametersNotPassed'
    }

    It 'treats the explicit [Parameter(Mandatory = $true)] form as mandatory' {
      # The bare form is what the real runners use, but the explicit form must not be a
      # hole in the detection - it would read as optional and hide the hang.
      [System.IO.File]::WriteAllText($script:runnerPath, ($script:runnerTemplate -replace '(?m)^\s*\[string\]\$Beta$', "  [string]`$Beta,`n  [Parameter(Mandatory = `$true)]`n  [string]`$Gamma"), [System.Text.UTF8Encoding]::new($false))
      Mock Invoke-RestMethod { @(New-RaftItemResponse -Content $script:diskText) }

      $result = Compare-BuildMasterPlanRaft -Path $script:planPath @script:commonArgs

      $result.Status | Should -Be 'Drift'
      $result.DriftReasons | Should -Contain 'MandatoryArgumentMissing'
      $result.SilentHangSignaturePresent | Should -BeTrue
    }

    It 'reports both conditions independently when a mandatory parameter is missing AND an undeclared argument is passed' {
      [System.IO.File]::WriteAllText($script:runnerPath, ($script:runnerTemplate -replace '(?m)^\s*\[string\]\$Beta$', "  [string]`$Beta,`n  [Parameter(Mandatory)]`n  [string]`$Gamma"), [System.Text.UTF8Encoding]::new($false))
      $driftedText = $script:diskText -replace '-Beta "\$Beta"', '-Beta "$Beta" -Delta "$Delta"'
      Mock Invoke-RestMethod { @(New-RaftItemResponse -Content $driftedText) }

      $result = Compare-BuildMasterPlanRaft -Path $script:planPath @script:commonArgs

      $result.Status | Should -Be 'Drift'
      $result.DriftReasons | Should -Contain 'MandatoryArgumentMissing'
      $result.DriftReasons | Should -Contain 'UndeclaredArgument'
      $result.SilentHangSignaturePresent | Should -BeTrue
    }

    It 'leaves SilentHangSignaturePresent null - never false - when the argument check could not run' {
      # RunnerScriptMissing means the check did not happen. A check that did not happen
      # must not be indistinguishable from a check that found no hang signature.
      Remove-Item -LiteralPath $script:runnerPath -Force
      Mock Invoke-RestMethod { @(New-RaftItemResponse -Content $script:diskText) }

      $result = Compare-BuildMasterPlanRaft -Path $script:planPath @script:commonArgs

      $result.Status | Should -Be 'Drift'
      $result.DriftReasons | Should -Contain 'RunnerScriptMissing'
      $result.SilentHangSignaturePresent | Should -BeNullOrEmpty
      $result.SilentHangSignaturePresent | Should -Not -Be $false
    }

    It 'leaves SilentHangSignaturePresent null when the server is Unreachable, and still fails closed' {
      Mock Invoke-RestMethod { throw 'No connection could be made because the target machine actively refused it.' }

      $result = Compare-BuildMasterPlanRaft -Path $script:planPath @script:commonArgs

      $result.Status | Should -Be 'Unreachable'
      $result.Status | Should -Not -Be 'Match'
      $result.SilentHangSignaturePresent | Should -BeNullOrEmpty
      $result.SilentHangSignaturePresent | Should -Not -Be $false
    }
  }

  Context 'regression - the real CSharpPackage-5Stage shape from unit 15.171.b' {
    BeforeEach {
      # Reproduces raft item 2009 exactly as measured live on 2026-09-09: content
      # byte-identical to disk, 22 argument names on the deployed Arguments: line, a
      # 29-parameter runner of which 8 are [Parameter(Mandatory)] and all 8 are passed,
      # and 7 unpassed OPTIONAL parameters. That plan reported Status = Drift, caused
      # solely by those 7 - the specific bug unit 15.171.e exists to fix.
      $script:csharpPassedArguments = @(
        'BuildToolingModulePath', 'SourcePath', 'ArtifactsPath', 'BuildMasterBuildId', 'BuildNumber',
        'ExecutionId', 'ApplicationName', 'MetaPackageName', 'PackageName', 'ProjectPath',
        'SolutionPath', 'Configuration', 'Branch', 'Stage', 'ApprovalAction',
        'ExpectedPreparedManifestSha256', 'ApprovedBy', 'AuthenticodeApprovalPath', 'SignToolPath',
        'BwsExecutablePath', 'ProGetUrl', 'ProGetApiKeySecretName'
      )
      # The seven the runner declares and the plan does not pass. All optional.
      $script:csharpUnpassedOptional = @(
        'PackageOutputPath', 'NupkgPathFile', 'ExperimentalFeed', 'DevelopmentFeed',
        'IntegrationFeed', 'QAFeed', 'ProductionFeed'
      )
      # The eight the live runner marks [Parameter(Mandatory)]; every one is passed.
      $script:csharpMandatory = @(
        'BuildToolingModulePath', 'SourcePath', 'ArtifactsPath', 'BuildMasterBuildId',
        'ApplicationName', 'MetaPackageName', 'ProjectPath', 'ProGetUrl'
      )

      $argumentText = ($script:csharpPassedArguments | ForEach-Object { "-$_ `"`$$_`"" }) -join ' '
      $csharpPlanText = @"
##########################################################################
# CSharpPackage-5Stage - fixture mirroring raft item 2009
##########################################################################

set `$InvokeCSharpPackageStageScript = `$PathCombine(`$SourcePath, Invoke-CSharpPackageBuildMasterStage.ps1);

Exec
(
    FileName: pwsh,
    Arguments: >>-File "`$InvokeCSharpPackageStageScript" $argumentText>>,
    WorkingDirectory: `$SourcePath,
    SuccessExitCode: 0
);
"@

      # Parameter order as declared by the live runner, mandatory flags as measured.
      $declarationOrder = @(
        'BuildToolingModulePath', 'SourcePath', 'ArtifactsPath', 'BuildMasterBuildId', 'BuildNumber',
        'ExecutionId', 'ApplicationName', 'MetaPackageName', 'PackageName', 'ProjectPath',
        'SolutionPath', 'Configuration', 'Branch', 'Stage', 'ApprovalAction',
        'ExpectedPreparedManifestSha256', 'ApprovedBy', 'AuthenticodeApprovalPath', 'SignToolPath',
        'BwsExecutablePath', 'PackageOutputPath', 'NupkgPathFile', 'ProGetUrl', 'ProGetApiKeySecretName',
        'ExperimentalFeed', 'DevelopmentFeed', 'IntegrationFeed', 'QAFeed', 'ProductionFeed'
      )
      $declarations = ($declarationOrder | ForEach-Object {
          if ($script:csharpMandatory -contains $_) { "  [Parameter(Mandatory)]`n  [string]`$$_" } else { "  [string]`$$_" }
        }) -join ",`n"
      $csharpRunnerText = "#Requires -Version 7.0`n[CmdletBinding()]`nparam(`n$declarations`n)`n"

      $script:csharpPlanPath = Join-Path $script:tempDir 'CSharpPackage-5Stage.otter'
      $csharpRunnerPath = Join-Path $script:tempDir 'Invoke-CSharpPackageBuildMasterStage.ps1'
      [System.IO.File]::WriteAllText($script:csharpPlanPath, $csharpPlanText, [System.Text.UTF8Encoding]::new($false))
      [System.IO.File]::WriteAllText($csharpRunnerPath, $csharpRunnerText, [System.Text.UTF8Encoding]::new($false))
      $script:csharpDiskText = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($script:csharpPlanPath))
    }

    It 'reports the fixture as a faithful reproduction: 29 runner parameters, 8 mandatory, 22 passed, 7 unpassed optional' {
      Mock Invoke-RestMethod { @(New-RaftItemResponse -Content $script:csharpDiskText -ItemName 'CSharpPackage-5Stage.otter' -ItemId 2009) }

      $result = Compare-BuildMasterPlanRaft -Path $script:csharpPlanPath @script:commonArgs
      $comparison = $result.ArgumentComparison[0]

      $comparison.RunnerParameterNames.Count | Should -Be 29
      $comparison.MandatoryRunnerParameterNames.Count | Should -Be 8
      $comparison.PlanArgumentNames.Count | Should -Be 22
      $comparison.RunnerParametersNotInPlan.Count | Should -Be 7
      $comparison.OptionalRunnerParametersNotInPlan | Should -Be $script:csharpUnpassedOptional
      $result.RaftContentSha256 | Should -Be $result.DiskContentSha256
    }

    It 'now reports CSharpPackage-5Stage CLEAN - the exact plan that used to report Drift for seven optional parameters' {
      Mock Invoke-RestMethod { @(New-RaftItemResponse -Content $script:csharpDiskText -ItemName 'CSharpPackage-5Stage.otter' -ItemId 2009) }

      $result = Compare-BuildMasterPlanRaft -Path $script:csharpPlanPath @script:commonArgs

      $result.Status | Should -Be 'Match'
      $result.DriftReasons.Count | Should -Be 0
      $result.ContentMatches | Should -BeTrue
      $result.RaftItemId | Should -Be 2009
      $result.InformationalReasons | Should -Contain 'OptionalParametersNotPassed'
      $result.SilentHangSignaturePresent | Should -BeFalse
      $result.MandatoryParameterAnalysis[0].MandatoryRunnerParameterCount | Should -Be 8
      $result.MandatoryParameterAnalysis[0].MandatoryRunnerParametersMissingFromRaft.Count | Should -Be 0
      $result.ArgumentComparison[0].ArgumentBindingSatisfied | Should -BeTrue
    }

    It 'still reports the hang signature on this real shape when one mandatory argument is dropped from the raft plan' {
      # Detection must not have been weakened to obtain the green light above. Same
      # fixture, minus -ProjectPath from the deployed Arguments: line.
      $driftedText = $script:csharpDiskText -replace ' -ProjectPath "\$ProjectPath"', ''
      Mock Invoke-RestMethod { @(New-RaftItemResponse -Content $driftedText -ItemName 'CSharpPackage-5Stage.otter' -ItemId 2009) }

      $result = Compare-BuildMasterPlanRaft -Path $script:csharpPlanPath @script:commonArgs

      $result.Status | Should -Be 'Drift'
      $result.DriftReasons | Should -Contain 'MandatoryArgumentMissing'
      $result.SilentHangSignaturePresent | Should -BeTrue
      $result.MandatoryParameterAnalysis[0].MandatoryRunnerParametersMissingFromRaft | Should -Contain 'ProjectPath'
      # The seven benign optional parameters are still reported, still benign, and still
      # not the reason the plan is red.
      $result.ArgumentComparison[0].OptionalRunnerParametersNotInPlan.Count | Should -Be 7
    }
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

  It 'is listed in the module manifest FunctionsToExport' {
    # Defect 2 of Task 15.171.e. Without this, Import-Module does not surface the cmdlet
    # and it is reachable only by dot-sourcing - which a scheduled gate cannot rely on.
    $manifestPath = Join-Path $PSScriptRoot '..\..\ATAP.Utilities.BuildTooling.BuildMaster.PowerShell.psd1'
    $manifest = Import-PowerShellDataFile -Path $manifestPath

    $manifest.FunctionsToExport | Should -Contain 'Compare-BuildMasterPlanRaft'
  }

  It 'exposes no ShouldProcess surface, because it never writes' {
    $command = Get-Command Compare-BuildMasterPlanRaft
    $command.Parameters.ContainsKey('WhatIf') | Should -BeFalse
    $command.Parameters.ContainsKey('Confirm') | Should -BeFalse
  }
}
