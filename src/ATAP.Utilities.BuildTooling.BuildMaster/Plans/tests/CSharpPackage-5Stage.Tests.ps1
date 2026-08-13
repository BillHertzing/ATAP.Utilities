# AI assisted using Powershell.instructions.md as guidelines
# Pester 5+ static-contract tests for V4-C02: the CSharpPackage-5Stage
# OtterScript plan must be a thin runner plan, and the runner script must
# preserve the contracts the plan depends on.

BeforeAll {
    $script:PlansDir       = Join-Path $PSScriptRoot '..'
    $script:BuildMasterDir = Resolve-Path -LiteralPath (Join-Path $script:PlansDir '..')
    $script:RepoRoot       = Resolve-Path -LiteralPath (Join-Path $script:BuildMasterDir '..\..')
    $script:PlanPath       = Join-Path $script:PlansDir 'CSharpPackage-5Stage.otter'
    $script:RunnerPath     = Join-Path $script:PlansDir 'Invoke-CSharpPackageBuildMasterStage.ps1'
    $script:MonitorPath    = Join-Path $script:BuildMasterDir 'Monitors/CSharpPackage-RepositoryMonitors.otter'
    $script:PlanText       = Get-Content -LiteralPath $script:PlanPath -Raw
    $script:RunnerText     = Get-Content -LiteralPath $script:RunnerPath -Raw
    $script:MonitorText    = Get-Content -LiteralPath $script:MonitorPath -Raw
}

Describe 'V4-C02 plan shape: CSharpPackage-5Stage.otter is a thin runner plan' {

    It 'plan and runner files both exist' {
        $script:PlanPath   | Should -Exist
        $script:RunnerPath | Should -Exist
    }

    It 'plan contains no Stage blocks (runner owns stage branching)' {
        $script:PlanText | Should -Not -Match '(?im)^\s*stage\s+\w+\s*\{'
    }

    It 'plan contains exactly one Exec block' {
        $execMatches = [regex]::Matches($script:PlanText, '(?im)^\s*Exec\s*\(')
        $execMatches.Count | Should -Be 1
    }

    It 'the single Exec invokes pwsh -File with the runner script' {
        $script:PlanText | Should -Match 'FileName:\s*pwsh'
        $script:PlanText | Should -Match '-NoProfile\s+-File\s+"\$InvokeCSharpPackageStageScript"'
    }

    It 'plan does not call dotnet build or dotnet pack inline (runner owns them)' {
        $script:PlanText | Should -Not -Match '(?i)FileName:\s*dotnet'
    }

    It 'plan contains no inline pwsh -Command blocks' {
        $script:PlanText | Should -Not -Match '(?i)-NoProfile\s+-Command\s'
    }

    It 'plan does not pass any ApiKey on the command line' {
        $script:PlanText | Should -Not -Match '(?i)-ProGetApiKey\b'
        $script:PlanText | Should -Not -Match '(?i)-ApiKey\s+["\$]'
    }

    It 'plan does not assign $env:PROGET_* inside an Arguments block' {
        $script:PlanText | Should -Not -Match '\$\$env:PROGET_[A-Z_]+\s*=\s*[''"]'
    }

    It 'plan passes the BuildMaster stage name explicitly via $PipelineStageName' {
        $script:PlanText | Should -Match '-Stage\s+"\$PipelineStageName"'
    }

    It 'plan passes the canonical smoke-target variables to the runner' {
        $script:PlanText | Should -Match '-MetaPackageName\s+"\$MetaPackageName"'
        $script:PlanText | Should -Match '-PackageName\s+"\$PackageName"'
        $script:PlanText | Should -Match '-ProjectPath\s+"\$ProjectPath"'
        $script:PlanText | Should -Match '-SolutionPath\s+"\$SolutionPath"'
        $script:PlanText | Should -Match '-Configuration\s+"\$Configuration"'
        $script:PlanText | Should -Match '-ApplicationName\s+"\$ApplicationName"'
    }

    It 'plan references the runner script via $BuildMasterPlanScriptDir + Invoke-CSharpPackageBuildMasterStage.ps1' {
        $script:PlanText | Should -Match 'set\s+\$BuildMasterPlanScriptDir\s*=\s*\$PathCombine'
        $script:PlanText | Should -Match 'Invoke-CSharpPackageBuildMasterStage\.ps1'
    }
}

Describe 'V4-C02 monitor shape: CSharpPackage repository monitors are concrete for the pilot package' {

    It 'monitor file exists beside the BuildMaster plans' {
        $script:MonitorPath | Should -Exist
    }

    It 'declares exactly the two live StronglyTypedId monitors' {
        $matches = [regex]::Matches(
            $script:MonitorText,
            '(?im)^\s*GitHub::Repository-Monitor\s+CSharpPackage-StronglyTypedId-(Main|Sprint)-Monitor\b')

        $matches.Count | Should -Be 2
        $script:MonitorText | Should -Not -Match '(?im)^\s*GitHub::Repository-Monitor\s+CSharpPackages-'
    }

    It 'routes main and sprint branch pushes to CSharpPackage-5Stage' {
        $mainPattern = '(?ms)^GitHub::Repository-Monitor\s+CSharpPackage-StronglyTypedId-Main-Monitor\b.*?^\);'
        $sprintPattern = '(?ms)^GitHub::Repository-Monitor\s+CSharpPackage-StronglyTypedId-Sprint-Monitor\b.*?^\);'
        $mainBlock = [regex]::Match($script:MonitorText, $mainPattern).Value
        $sprintBlock = [regex]::Match($script:MonitorText, $sprintPattern).Value

        $mainBlock | Should -Match 'BranchFilter:\s*main'
        $mainBlock | Should -Match 'PollInterval:\s*600'
        $mainBlock | Should -Match 'PipelineName:\s*CSharpPackage-5Stage'

        $sprintBlock | Should -Match 'BranchFilter:\s*\*-Sprint-\*-work-items'
        $sprintBlock | Should -Match 'PollInterval:\s*120'
        $sprintBlock | Should -Match 'PipelineName:\s*CSharpPackage-5Stage'
    }

    It 'filters live monitors to the StronglyTypedId source tree' {
        $matches = [regex]::Matches(
            $script:MonitorText,
            '(?im)^\s*PathFilter:\s*src/ATAP\.Utilities\.StronglyTypedId/\*\*')

        $matches.Count | Should -Be 2
        $script:MonitorText | Should -Not -Match '(?im)^\s*PathFilter:\s*src/\*\*\s*,'
    }

    It 'supplies the C# package tuple the thin runner requires' {
        $monitorNames = @(
            'CSharpPackage-StronglyTypedId-Main-Monitor',
            'CSharpPackage-StronglyTypedId-Sprint-Monitor'
        )

        $expectedBuildVariables = @(
            'Branch: $Branch',
            'ApplicationName: ATAP.Utilities',
            'MetaPackageName: ATAP.Utilities.StronglyTypedId',
            'PackageName: ATAP.Utilities.StronglyTypedId',
            'ProjectPath: src/ATAP.Utilities.StronglyTypedId/ATAP.Utilities.StronglyTypedId.csproj',
            'SolutionPath: ATAP.Utilities.Production.slnf',
            'Configuration: Release'
        )

        foreach ($monitorName in $monitorNames) {
            $pattern = '(?ms)^GitHub::Repository-Monitor\s+' + [regex]::Escape($monitorName) + '\b.*?^\);'
            $block = [regex]::Match($script:MonitorText, $pattern).Value
            $block | Should -Not -BeNullOrEmpty

            foreach ($expectedBuildVariable in $expectedBuildVariables) {
                $block | Should -Match ([regex]::Escape($expectedBuildVariable))
            }
        }
    }

    It 'points to existing pilot package and solution-filter paths' {
        Join-Path $script:RepoRoot 'src/ATAP.Utilities.StronglyTypedId/ATAP.Utilities.StronglyTypedId.csproj' | Should -Exist
        Join-Path $script:RepoRoot 'ATAP.Utilities.Production.slnf' | Should -Exist
    }

    It 'does not pass ProGet secrets as monitor build variables' {
        $script:MonitorText | Should -Match 'BUILDMASTER_GH_WEBHOOK_SECRET'
        $script:MonitorText | Should -Not -Match '(?im)^\s*ProGetApiKey\s*:'
        $script:MonitorText | Should -Not -Match '(?im)^\s*ApiKey\s*:'
        $script:MonitorText | Should -Not -Match 'PROGET_ADMIN_API_KEY'
    }
}

Describe 'V4-C02 runner shape: Invoke-CSharpPackageBuildMasterStage.ps1 contract' {

    It 'runner declares the parameters the plan supplies' {
        foreach ($param in @(
            'BuildToolingModulePath',
            'SourcePath',
            'BuildMasterBuildId',
            'BuildNumber',
            'ExecutionId',
            'ApplicationName',
            'MetaPackageName',
            'PackageName',
            'ProjectPath',
            'SolutionPath',
            'Configuration',
            'Branch',
            'Stage',
            'ProGetUrl',
            'ProGetApiKeySecretName'
        )) {
            $script:RunnerText | Should -Match "\[string\]\$\b$param\b"
        }
    }

    It 'runner carries only the canonical BuildMaster SecretName' {
        $script:RunnerText | Should -Match "ProGetApiKeySecretName\s*=\s*'ProGet\.BuildMaster\.API\.Key'"
        $script:RunnerText | Should -Not -Match 'PROGET_(?:BUILDMASTER|ADMIN)_API_KEY'
        $script:RunnerText | Should -Not -Match '\$ProGetApiKey\b'
    }

    It 'runner invokes Publish-NuGetPackageToProGet (no inline dotnet nuget push)' {
        $script:RunnerText | Should -Match 'Publish-NuGetPackageToProGet'
        $script:RunnerText | Should -Not -Match 'dotnet\s+nuget\s+push'
    }

    It 'runner invokes Promote-ProGetPackage for non-Experimental tiers' {
        $script:RunnerText | Should -Match 'Promote-ProGetPackage'
    }

    It 'runner invokes Invoke-PromotedPackageTests for non-Experimental tiers' {
        $script:RunnerText | Should -Match 'Invoke-PromotedPackageTests'
    }

    It 'runner enables locked restore only for Integration, QA, and Production promoted-package tests' {
        $script:RunnerText | Should -Match 'if\s*\(\s*\$Tier\s+-in\s+@\(''Integration'', ''QA'', ''Production''\)\s*\)'
        $script:RunnerText | Should -Match '\$testParameters\[''LockedRestore''\]\s*=\s*\$true'
    }

    It 'runner forces ContinuousIntegrationBuild=true on both build and pack' {
        $ciMatches = [regex]::Matches($script:RunnerText, 'ContinuousIntegrationBuild=true')
        $ciMatches.Count | Should -BeGreaterOrEqual 2
    }

    It 'runner resolves stable Visual Studio Build Tools with the NuGet Build Tools component' {
        $script:RunnerText | Should -Match 'function\s+Resolve-DeterministicNuGetMSBuild'
        $script:RunnerText | Should -Match '-requires\s+Microsoft\.VisualStudio\.Component\.NuGet\.BuildTools'
        $script:RunnerText | Should -Match "-lt\s+\[version\]'18\.8\.0\.0'"
        $script:RunnerText | Should -Match "-lt\s+\[version\]'7\.8\.0\.0'"
        $script:RunnerText | Should -Match 'Microsoft\.NetCore\.Component\.SDK'
        $script:RunnerText | Should -Match 'NuGet\.Build\.Tasks\.Pack\.dll'
        $script:RunnerText | Should -Match '\$sdkPackTaskVersion\s+-lt\s+\[version\]''7\.8\.0\.0'''
    }

    It 'runner uses Visual Studio MSBuild Pack with deterministic properties and never invokes dotnet pack' {
        $script:RunnerText | Should -Match "'/t:Pack'"
        $script:RunnerText | Should -Match "'/p:Deterministic=true'"
        $script:RunnerText | Should -Match 'Get-SourceDateEpoch\s+-RepositoryPath\s+\$SourcePath'
        $script:RunnerText | Should -Match '"/p:DeterministicTimestamp=\$sourceDateEpoch"'
        $script:RunnerText | Should -Match '&\s+\$deterministicPackTool\.MSBuildPath\s+@packArgs'
        $script:RunnerText | Should -Not -Match '(?m)^\s*dotnet\s+@packArgs\s*$'
    }

    It 'runner derives the deterministic package timestamp from Git HEAD and fails closed if unavailable' {
        $script:RunnerText | Should -Match 'function\s+Get-SourceDateEpoch'
        $script:RunnerText | Should -Match 'git\s+-C\s+\$RepositoryPath\s+show\s+-s\s+--format=%ct\s+HEAD'
        $script:RunnerText | Should -Match 'deterministic pack is refused'
    }

    It 'runner packs twice and blocks publication unless every package hash matches' {
        $script:RunnerText | Should -Match 'foreach\s*\(\$packRun\s+in\s+1\.\.2\)'
        $script:RunnerText | Should -Match 'Get-FileHash[^\r\n]+SHA256'
        $script:RunnerText | Should -Match 'Deterministic two-pack SHA-256 gate failed\. No feed was mutated'
        $script:RunnerText | Should -Match 'Copy-Item\s+-LiteralPath\s+\$_\.Path\s+-Destination\s+\$PackageOutputPath'
        $script:RunnerText | Should -Match 'two-pack SHA-256 gate passed'
    }

    It 'runner fails closed with actionable setup guidance when deterministic pack prerequisites are absent or old' {
        $script:RunnerText | Should -Match 'Deterministic production NuGet pack currently requires'
        $script:RunnerText | Should -Match 'SolutionDocumentation/NewComputerSetup\.md'
        $script:RunnerText | Should -Match 'Stable deterministic pack requires Visual Studio Build Tools 2026 18\.8\+ and NuGet 7\.8\+'
    }

    It 'runner uses the canonical per-build run-context directory' {
        $script:RunnerText | Should -Match 'Initialize-BuildMasterRunContextDirectory'
        $script:RunnerText | Should -Match "Join-Path[^\r\n]*PSScriptRoot[^\r\n]*BuildMasterRunContext\.Common\.ps1"
    }

    It 'runner writes per-package per-tier completion markers' {
        $script:RunnerText | Should -Match 'Set-CSharpPackageStageCompleted'
        $script:RunnerText | Should -Match 'Test-CSharpPackageStageCompleted'
        $script:RunnerText | Should -Match '\$MetaPackageName\.\$Tier\.completed\.tmp'
    }

    It 'runner enforces the version.json ceiling clamp' {
        $script:RunnerText | Should -Match 'Get-BuildMasterAllowDecisions'
        $script:RunnerText | Should -Match 'exceeds version ceiling'
    }

    It 'runner uses the canonical NuGet feed names' {
        $script:RunnerText | Should -Match "ExperimentalFeed\s*=\s*'nuget-experimental'"
        $script:RunnerText | Should -Match "DevelopmentFeed\s*=\s*'nuget-development'"
        $script:RunnerText | Should -Match "IntegrationFeed\s*=\s*'nuget-integration'"
        $script:RunnerText | Should -Match "QAFeed\s*=\s*'nuget-qa'"
        $script:RunnerText | Should -Match "ProductionFeed\s*=\s*'nuget-stable'"
    }

    It 'runner contains a Find-CSharpMetaPackageNupkg helper that picks by MetaPackageName prefix' {
        $script:RunnerText | Should -Match 'function\s+Find-CSharpMetaPackageNupkg'
        $script:RunnerText | Should -Match '\$prefix\s*=\s*"\$MetaPackageName\."'
    }

    It 'runner is invocable from PowerShell (parser succeeds with no errors)' {
        $tokens = $null
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $script:RunnerPath, [ref]$tokens, [ref]$parseErrors) | Out-Null
        $parseErrors | Should -BeNullOrEmpty
    }
}

Describe 'V4-C02 runner SEC-T1: no secret in command-line arguments to dotnet/proget' {

    It 'runner never spawns dotnet with an --api-key argument' {
        $script:RunnerText | Should -Not -Match '--api-key'
    }

    It 'runner never echoes $script:resolvedProGetApiKey into a string' {
        # The API key may appear in env-var assignments but not in interpolated log/trace lines.
        $patterns = @(
            'Write-PSFMessage[^\r\n]*\$script:resolvedProGetApiKey',
            'Add-BuildMasterPublishTrace[^\r\n]*\$script:resolvedProGetApiKey',
            'Write-Output[^\r\n]*\$script:resolvedProGetApiKey'
        )
        foreach ($pattern in $patterns) {
            $script:RunnerText | Should -Not -Match $pattern
        }
    }
}
