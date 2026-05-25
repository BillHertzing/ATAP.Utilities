# AI assisted using Powershell.instructions.md as guidelines
# Pester 5+ static-contract tests for V4-C02: the CSharpPackage-5Stage
# OtterScript plan must be a thin runner plan, and the runner script must
# preserve the contracts the plan depends on.

BeforeAll {
    $script:PlansDir   = Join-Path $PSScriptRoot '..'
    $script:PlanPath   = Join-Path $script:PlansDir 'CSharpPackage-5Stage.otter'
    $script:RunnerPath = Join-Path $script:PlansDir 'Invoke-CSharpPackageBuildMasterStage.ps1'
    $script:PlanText   = Get-Content -LiteralPath $script:PlanPath -Raw
    $script:RunnerText = Get-Content -LiteralPath $script:RunnerPath -Raw
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
            'ProGetUrl'
        )) {
            $script:RunnerText | Should -Match "\[string\]\$\b$param\b"
        }
    }

    It 'runner resolves API key from environment, not from a parameter' {
        $script:RunnerText | Should -Match '\$env:PROGET_BUILDMASTER_API_KEY'
        $script:RunnerText | Should -Match '\$env:PROGET_ADMIN_API_KEY'
        $script:RunnerText | Should -Not -Match '\[Parameter\(Mandatory\)\][^\]]*\$ProGetApiKey'
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
