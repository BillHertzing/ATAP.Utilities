# AI assisted using Powershell.instructions.md as guidelines
# Pester 5+ static-contract + behavioral tests for V4-B02: the PowerShell-module
# 5-tier pipeline must be -NoProfile-safe. BuildMaster invokes the runner via
# `pwsh -NoProfile -File`, so the user profile that populates $global:settings /
# $global:configRootKeys never loads. Every settings lookup used by the plan and
# runner must resolve through an explicit parameter, an environment variable, or a
# null-guarded read with a default. These tests pin that contract so a future edit
# cannot reintroduce a profile-dependent lookup.
#
# Policy of record: SolutionDocumentation/PowerShellModule-Pipeline-NoProfile-Runbook.md

BeforeAll {
    $script:PlansDir       = Join-Path $PSScriptRoot '..'
    $script:BuildMasterDir = Resolve-Path -LiteralPath (Join-Path $script:PlansDir '..')
    $script:RepoRoot       = Resolve-Path -LiteralPath (Join-Path $script:BuildMasterDir '..\..')
    $script:PlanPath       = Join-Path $script:PlansDir 'PowerShellModule-5Stage.otter'
    $script:RunnerPath     = Join-Path $script:PlansDir 'Invoke-PowerShellModuleBuildMasterStage.ps1'
    $script:GetPValPath    = Join-Path $script:RepoRoot 'src/ATAP.Utilities.PowerShell/public/Get-ParameterValueFromNeoConfigurationRoot.ps1'
    $script:PlanText       = Get-Content -LiteralPath $script:PlanPath -Raw
    $script:RunnerText     = Get-Content -LiteralPath $script:RunnerPath -Raw
}

Describe 'V4-B02 plan shape: PowerShellModule-5Stage.otter is a thin -NoProfile runner plan' {

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

    It 'the single Exec invokes pwsh -NoProfile -File with the runner script' {
        $script:PlanText | Should -Match 'FileName:\s*pwsh'
        $script:PlanText | Should -Match '-NoProfile\s+-File\s+"\$InvokePowerShellModuleStageScript"'
    }

    It 'plan contains no inline pwsh -Command blocks' {
        $script:PlanText | Should -Not -Match '(?i)-NoProfile\s+-Command\s'
    }

    It 'plan performs no $global:settings / $global:configRootKeys lookup in OtterScript' {
        $script:PlanText | Should -Not -Match '(?i)\$global:settings'
        $script:PlanText | Should -Not -Match '(?i)\$global:configRootKeys'
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

    It 'plan passes the non-secret settings the runner needs explicitly' {
        $script:PlanText | Should -Match '-ProGetUrl\s+"\$ProGetUrl"'
        $script:PlanText | Should -Match '-SourcePath\s+"\$SourcePath"'
        $script:PlanText | Should -Match '-ModuleName\s+"\$ModuleName"'
        $script:PlanText | Should -Match '-PackageName\s+"\$PackageName"'
        $script:PlanText | Should -Match '-ApplicationName\s+"\$ApplicationName"'
    }

    It 'plan references the runner via $BuildMasterPlanScriptDir + Invoke-PowerShellModuleBuildMasterStage.ps1' {
        $script:PlanText | Should -Match 'set\s+\$BuildMasterPlanScriptDir\s*=\s*\$PathCombine'
        $script:PlanText | Should -Match 'Invoke-PowerShellModuleBuildMasterStage\.ps1'
    }
}

Describe 'V4-B02 runner no-profile contract: Invoke-PowerShellModuleBuildMasterStage.ps1' {

    It 'runner declares the parameters the plan supplies' {
        foreach ($param in @(
            'BuildToolingModulePath',
            'SourcePath',
            'BuildMasterBuildId',
            'BuildNumber',
            'ExecutionId',
            'ApplicationName',
            'ModuleName',
            'PackageName',
            'ModulePath',
            'Branch',
            'Stage',
            'ProGetUrl'
        )) {
            $script:RunnerText | Should -Match "\[string\]\$\b$param\b"
        }
    }

    It 'runner resolves the ProGet API key from environment, never from a parameter' {
        $script:RunnerText | Should -Match '\$env:PROGET_BUILDMASTER_API_KEY'
        $script:RunnerText | Should -Match '\$env:PROGET_ADMIN_API_KEY'
        # No ProGetApiKey parameter is declared anywhere in the runner surface.
        $script:RunnerText | Should -Not -Match '\$ProGetApiKey'
    }

    It 'runner throws an actionable error when no API key env var is set' {
        $script:RunnerText | Should -Match 'Unable to resolve ProGet API key'
    }

    It 'runner performs no unguarded $global:settings / $global:configRootKeys read' {
        # The PS-module runner must not depend on profile-populated globals.
        $script:RunnerText | Should -Not -Match '\$global:settings'
        $script:RunnerText | Should -Not -Match '\$global:configRootKeys'
    }

    It 'runner never calls Resolve-ProGetFeedFromSettings (the profile-dependent feed resolver)' {
        # Unlike the C# runner, the PS-module path computes feed URIs directly from
        # $ProGetUrl, so it needs no Set-NoProfileProGetFeedSettings bootstrap.
        $script:RunnerText | Should -Not -Match 'Resolve-ProGetFeedFromSettings'
    }

    It 'runner seeds $global:ProGetBaseUrl and the key env var before promotion' {
        $script:RunnerText | Should -Match '\$global:ProGetBaseUrl\s*=\s*\$ProGetUrl'
        $script:RunnerText | Should -Match '\$env:PROGET_BUILDMASTER_API_KEY\s*=\s*\$script:resolvedProGetApiKey'
    }

    It 'runner passes -ProGetBaseUrl and -ApiKey explicitly into Invoke-PromotedModuleTests' {
        $script:RunnerText | Should -Match 'Invoke-PromotedModuleTests'
        $script:RunnerText | Should -Match '-ProGetBaseUrl\s+\$ProGetUrl'
        $script:RunnerText | Should -Match '-ApiKey\s+\$script:resolvedProGetApiKey'
    }

    It 'runner promotes via Promote-ProGetPackage and computes feed URIs from $ProGetUrl' {
        $script:RunnerText | Should -Match 'Promote-ProGetPackage'
        $script:RunnerText | Should -Match 'Get-PowerShellGetFeedUri\s+-BaseUrl\s+\$ProGetUrl'
    }

    It 'runner derives feed names from canonical defaults, not from settings' {
        $script:RunnerText | Should -Match "ExperimentalFeed\s*=\s*'powershellget-experimental'"
        $script:RunnerText | Should -Match "DevelopmentFeed\s*=\s*'powershellget-development'"
        $script:RunnerText | Should -Match "IntegrationFeed\s*=\s*'powershellget-integration'"
        $script:RunnerText | Should -Match "QAFeed\s*=\s*'powershellget-qa'"
        $script:RunnerText | Should -Match "ProductionFeed\s*=\s*'powershellget-stable'"
    }

    It 'runner is invocable from PowerShell (parser succeeds with no errors)' {
        $tokens = $null
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $script:RunnerPath, [ref]$tokens, [ref]$parseErrors) | Out-Null
        $parseErrors | Should -BeNullOrEmpty
    }
}

Describe 'V4-B02 behavioral proof: Get-PVal degrades to DefaultValue under -NoProfile' {

    It 'the Get-PVal helper the runner depends on exists' {
        $script:GetPValPath | Should -Exist
    }

    It 'Get-PVal returns the DefaultValue (no throw) when no profile globals are loaded' {
        # Faithful -NoProfile reproduction: a clean child process with neither
        # $global:settings nor $global:configRootKeys must resolve to the default
        # rather than throwing. This is the lynchpin that makes the param -> env ->
        # settings -> default chain in Move-ProGetPackageInterTier / Invoke-PromotedModuleTests
        # safe under BuildMaster's -NoProfile invocation.
        $probe = @"
. '$script:GetPValPath'
`$resolved = Get-PVal -ParameterName 'ATAP_NoProfile_Probe_DoesNotExist' -originalPSBoundParameters @{} -DefaultValue 'fallback'
Write-Output `$resolved
"@
        $output = pwsh -NoProfile -Command $probe 2>&1
        ($output -join "`n").Trim() | Should -Be 'fallback'
    }
}
