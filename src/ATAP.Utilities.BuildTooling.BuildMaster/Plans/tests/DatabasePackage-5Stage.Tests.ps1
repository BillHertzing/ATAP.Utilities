# AI assisted using Powershell.instructions.md as guidelines
# Pester 5+ static-contract tests for V4-E08 / DBA2-T03: the
# DatabaseChangePackage-5Stage OtterScript plan must be a thin runner plan,
# and the runner script must preserve the contracts the plan depends on.

BeforeAll {
    $script:PlansDir   = Join-Path $PSScriptRoot '..'
    $script:PlanPath   = Join-Path $script:PlansDir 'DatabaseChangePackage-5Stage.otter'
    $script:RunnerPath = Join-Path $script:PlansDir 'Invoke-DatabasePackageBuildMasterStage.ps1'
    $script:PlanText   = Get-Content -LiteralPath $script:PlanPath -Raw
    $script:RunnerText = Get-Content -LiteralPath $script:RunnerPath -Raw
}

Describe 'V4-E08 plan shape: DatabaseChangePackage-5Stage.otter is a thin runner plan' {

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
        $script:PlanText | Should -Match '-NoProfile\s+-File\s+"\$InvokeDatabasePackageStageScript"'
    }

    It 'plan contains no inline pwsh -Command blocks' {
        $script:PlanText | Should -Not -Match '(?i)-NoProfile\s+-Command\s'
    }

    It 'plan does not pass any ApiKey on the command line' {
        $script:PlanText | Should -Not -Match '(?i)-ProGetApiKey\b'
        $script:PlanText | Should -Not -Match '(?i)-ApiKey\s+["\$]'
    }

    It 'plan does not contain a $Decrypt( call' {
        $script:PlanText | Should -Not -Match '\$Decrypt\('
    }

    It 'plan does not assign $env:PROGET_* inside an Arguments block' {
        $script:PlanText | Should -Not -Match '\$\$env:PROGET_[A-Z_]+\s*=\s*[''"]'
    }

    It 'plan does not embed a literal Database application name' {
        # Plan must read $DatabaseApplication from BuildMaster Application
        # Variables, not hard-code names like ATAPUtilities or AceCommander.
        $script:PlanText | Should -Not -Match '(?i)Database\\(ATAPUtilities|AceCommander)\b'
        $script:PlanText | Should -Match '-DatabaseApplication\s+"\$DatabaseApplication"'
    }

    It 'plan passes the BuildMaster stage name explicitly via $PipelineStageName' {
        $script:PlanText | Should -Match '-Stage\s+"\$PipelineStageName"'
    }

    It 'plan passes the required runner parameters' {
        $script:PlanText | Should -Match '-BuildMasterBuildId\s+"\$BuildMasterBuildId"'
        $script:PlanText | Should -Match '-ApplicationName\s+"\$ApplicationName"'
        $script:PlanText | Should -Match '-DatabaseStream\s+"\$DatabaseStream"'
        $script:PlanText | Should -Match '-ProGetUrl\s+"\$ProGetBaseUrl"'
    }

    It 'plan references the runner script via $BuildMasterPlanScriptDir + Invoke-DatabasePackageBuildMasterStage.ps1' {
        $script:PlanText | Should -Match 'set\s+\$BuildMasterPlanScriptDir\s*=\s*\$PathCombine'
        $script:PlanText | Should -Match 'Invoke-DatabasePackageBuildMasterStage\.ps1'
    }
}

Describe 'V4-E08 runner shape: Invoke-DatabasePackageBuildMasterStage.ps1 contract' {

    It 'runner declares the parameters the plan supplies' {
        foreach ($param in @(
            'BuildToolingModulePath',
            'SourcePath',
            'BuildMasterBuildId',
            'BuildNumber',
            'ExecutionId',
            'ApplicationName',
            'DatabaseApplication',
            'DatabaseStream',
            'Branch',
            'Stage',
            'ProGetUrl'
        )) {
            $script:RunnerText | Should -Match "\[string\]\$\b$param\b"
        }
    }

    It 'runner resolves API key from User-scope environment, not from a parameter' {
        $script:RunnerText | Should -Match 'PROGET_BUILDMASTER_API_KEY'
        $script:RunnerText | Should -Match 'PROGET_ADMIN_API_KEY'
        $script:RunnerText | Should -Match "GetEnvironmentVariable\('PROGET_BUILDMASTER_API_KEY',\s*'User'\)"
        $script:RunnerText | Should -Not -Match '\[Parameter\(Mandatory\)\][^\]]*\$ProGetApiKey'
    }

    It 'runner invokes Publish-DatabaseChangePackageToProGet (no inline dotnet nuget push)' {
        $script:RunnerText | Should -Match 'Publish-DatabaseChangePackageToProGet'
        $script:RunnerText | Should -Not -Match 'dotnet\s+nuget\s+push'
    }

    It 'runner invokes Promote-DatabaseChangePackage for non-Experimental tiers' {
        $script:RunnerText | Should -Match 'Promote-DatabaseChangePackage'
    }

    It 'runner invokes New-DatabaseChangePackage during the Experimental stage' {
        $script:RunnerText | Should -Match 'New-DatabaseChangePackage'
    }

    It 'runner invokes Get-DatabasePackageBuildContext' {
        $script:RunnerText | Should -Match 'Get-DatabasePackageBuildContext'
    }

    It 'runner uses the canonical per-build run-context directory' {
        $script:RunnerText | Should -Match 'Initialize-BuildMasterRunContextDirectory'
        $script:RunnerText | Should -Match "Join-Path[^\r\n]*PSScriptRoot[^\r\n]*BuildMasterRunContext\.Common\.ps1"
    }

    It 'runner writes per-package per-tier completion markers' {
        $script:RunnerText | Should -Match 'Set-DatabasePackageStageCompleted'
        $script:RunnerText | Should -Match 'Test-DatabasePackageStageCompleted'
        $script:RunnerText | Should -Match '\$databasePackageId\.\$Tier\.completed\.tmp'
    }

    It 'runner enforces the version.json ceiling clamp' {
        $script:RunnerText | Should -Match 'Get-BuildMasterAllowDecisions'
        $script:RunnerText | Should -Match 'exceeds version ceiling'
    }

    It 'runner uses the canonical database feed names' {
        $script:RunnerText | Should -Match "ExperimentalFeed\s*=\s*'database-experimental'"
        $script:RunnerText | Should -Match "DevelopmentFeed\s*=\s*'database-development'"
        $script:RunnerText | Should -Match "IntegrationFeed\s*=\s*'database-integration'"
        $script:RunnerText | Should -Match "QAFeed\s*=\s*'database-qa'"
        $script:RunnerText | Should -Match "ProductionFeed\s*=\s*'database-stable'"
    }

    It 'runner is invocable from PowerShell (parser succeeds with no errors)' {
        $tokens = $null
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $script:RunnerPath, [ref]$tokens, [ref]$parseErrors) | Out-Null
        $parseErrors | Should -BeNullOrEmpty
    }
}

Describe 'V4-E08 runner SEC-T1: no secret in command-line arguments or trace output' {

    It 'runner never spawns dotnet with an --api-key argument' {
        $script:RunnerText | Should -Not -Match '--api-key'
    }

    It 'runner does not contain a literal connection-string pattern' {
        $script:RunnerText | Should -Not -Match '(?i)Server\s*=\s*[^;]+;\s*Database\s*='
        $script:RunnerText | Should -Not -Match '(?i)Password\s*=\s*[''"]\w'
    }

    It 'runner never echoes $script:resolvedProGetApiKey into a string' {
        # The API key may appear in env-var assignments but not in interpolated log/trace lines.
        $patterns = @(
            'Write-PSFMessage[^\r\n]*\$script:resolvedProGetApiKey',
            'Add-DatabasePackagePublishTrace[^\r\n]*\$script:resolvedProGetApiKey',
            'Write-Output[^\r\n]*\$script:resolvedProGetApiKey'
        )
        foreach ($pattern in $patterns) {
            $script:RunnerText | Should -Not -Match $pattern
        }
    }
}

Describe 'V4-E08 skip-marker logic: completion marker prevents double-execution' {

    BeforeAll {
        $script:TempContextDir = Join-Path ([System.IO.Path]::GetTempPath()) (
            'DBA2-T03-' + [Guid]::NewGuid().ToString('N')
        )
        New-Item -ItemType Directory -Path $script:TempContextDir -Force | Out-Null

        # Dot-source the runner so the helper functions are available in scope.
        # The runner ends with a call to Invoke-DatabasePackageBuildMasterStage,
        # so we cannot dot-source the file as-is. Read the file, strip the
        # final invocation, and execute the helper-function definitions only.
        $runnerLines = Get-Content -LiteralPath $script:RunnerPath
        # Find the last call to the public worker and cut there.
        $lastInvokeIndex = -1
        for ($i = $runnerLines.Count - 1; $i -ge 0; $i--) {
            if ($runnerLines[$i] -match '^\s*Invoke-DatabasePackageBuildMasterStage\b') {
                $lastInvokeIndex = $i
                break
            }
        }
        $helperScript = if ($lastInvokeIndex -gt 0) {
            ($runnerLines[0..($lastInvokeIndex - 1)] -join [Environment]::NewLine)
        } else {
            $script:RunnerText
        }

        # Stub Write-PSFMessage so dot-sourcing in a profile-less Pester run
        # does not depend on PSFramework.
        if (-not (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue)) {
            function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments)]$args) }
        }

        # Stub the BuildMasterRunContext.Common.ps1 dependencies; we only care
        # about the marker helpers in this Describe.
        function global:Initialize-BuildMasterRunContextDirectory { param($SourcePath, $BuildMasterBuildId) return $script:TempContextDir }
        function global:Read-BuildMasterRunContextJson { param($ContextDirectory) return $null }
        function global:Get-BuildMasterAllowDecisions { param($CeilingTier) return @{ Experimental = $true; Development = $true; Integration = $true; QA = $true; Production = $true } }
        function global:Write-BuildMasterRunStateFiles { param($StateFiles, $Values) }
        function global:Write-BuildMasterRunContextJson { param([Parameter(ValueFromRemainingArguments)]$args) }

        Invoke-Expression $helperScript
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:TempContextDir) {
            Remove-Item -LiteralPath $script:TempContextDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        Remove-Item -Path Function:\Initialize-BuildMasterRunContextDirectory -ErrorAction SilentlyContinue
        Remove-Item -Path Function:\Read-BuildMasterRunContextJson -ErrorAction SilentlyContinue
        Remove-Item -Path Function:\Get-BuildMasterAllowDecisions -ErrorAction SilentlyContinue
        Remove-Item -Path Function:\Write-BuildMasterRunStateFiles -ErrorAction SilentlyContinue
        Remove-Item -Path Function:\Write-BuildMasterRunContextJson -ErrorAction SilentlyContinue
    }

    It 'Test-DatabasePackageStageCompleted returns $false before the marker exists' {
        (Test-DatabasePackageStageCompleted `
            -ContextDirectory $script:TempContextDir `
            -DatabasePackageId 'ATAPUtilities.Database' `
            -Tier 'Experimental') | Should -BeFalse
    }

    It 'Set-DatabasePackageStageCompleted writes a marker file at the expected path' {
        Set-DatabasePackageStageCompleted `
            -ContextDirectory $script:TempContextDir `
            -DatabasePackageId 'ATAPUtilities.Database' `
            -Tier 'Experimental' `
            -PackageVersion '1.0.0-experimental.42'

        $expectedPath = Join-Path $script:TempContextDir 'ATAPUtilities.Database.Experimental.completed.tmp'
        Test-Path -LiteralPath $expectedPath -PathType Leaf | Should -BeTrue
    }

    It 'Test-DatabasePackageStageCompleted returns $true after the marker exists' {
        (Test-DatabasePackageStageCompleted `
            -ContextDirectory $script:TempContextDir `
            -DatabasePackageId 'ATAPUtilities.Database' `
            -Tier 'Experimental') | Should -BeTrue
    }
}
