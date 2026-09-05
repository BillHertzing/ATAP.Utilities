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

    $tokens = $null
    $parseErrors = $null
    $runnerAst = [System.Management.Automation.Language.Parser]::ParseFile(
        $script:RunnerPath, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        throw "Runner parse failed: $($parseErrors.Message -join '; ')"
    }
    $resolverAst = $runnerAst.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Resolve-PowerShellModuleArtifactDirectory'
        }, $true)
    . ([scriptblock]::Create($resolverAst.Extent.Text))
    if (-not (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }
    }
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
        $script:PlanText | Should -Match '-CodeSigningCertificateThumbprint\s+"\$CodeSigningCertificateThumbprint"'
        $script:PlanText | Should -Match '-TimestampServerUri\s+"\$TimestampServerUri"'
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
            'ProGetUrl',
            'ProGetApiKeySecretName',
            'CodeSigningCertificateThumbprint'
        )) {
            $script:RunnerText | Should -Match "\[string\]\$\b$param\b"
        }
        $script:RunnerText | Should -Match '\[uri\]\$TimestampServerUri\b'
    }

    It 'runner carries only the canonical BuildMaster SecretName' {
        $script:RunnerText | Should -Match "ProGetApiKeySecretName\s*=\s*'ProGet\.BuildMaster\.API\.Key'"
        $script:RunnerText | Should -Not -Match 'PROGET_(?:BUILDMASTER|ADMIN)_API_KEY'
        [regex]::IsMatch($script:RunnerText, '\$ProGetApiKey\b') | Should -BeFalse
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

    It 'runner seeds only $global:ProGetBaseUrl before promotion' {
        $script:RunnerText | Should -Match '\$global:ProGetBaseUrl\s*=\s*\$ProGetUrl'
    }

    It 'runner passes -ProGetBaseUrl and -ProGetApiKeySecretName into Invoke-PromotedModuleTests' {
        $script:RunnerText | Should -Match 'Invoke-PromotedModuleTests'
        $script:RunnerText | Should -Match '-ProGetBaseUrl\s+\$ProGetUrl'
        $script:RunnerText | Should -Match '-ProGetApiKeySecretName\s+\$ProGetApiKeySecretName'
    }

    It 'runner passes explicit signing inputs into Invoke-ModuleBuildWithRetry' {
        $script:RunnerText | Should -Match '-CodeSigningCertificateThumbprint\s+\$CodeSigningCertificateThumbprint'
        $script:RunnerText | Should -Match '-TimestampServerUri\s+\$TimestampServerUri'
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

Describe 'PowerShell module BuildMaster external artifact boundary' {

    It 'resolves an explicit external root to a build-scoped directory outside Dropbox' {
        $externalRoot = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)) 'ATAPArtifacts/Pester/PowerShellModuleBuildMaster'
        $resolved = Resolve-PowerShellModuleArtifactDirectory `
            -ArtifactsRoot $externalRoot `
            -SourcePath $script:RepoRoot `
            -BuildMasterBuildId '910001'

        $resolved | Should -Be ([IO.Path]::GetFullPath((Join-Path $externalRoot 'BuildMaster/PowerShellModules/910001')))
        $resolved | Should -Not -Match '(?i)[\\/]Dropbox(?:[\\/]|$)'
        $resolved | Should -Exist
    }

    It 'uses ATAP_ARTIFACTS_ROOT when no explicit root is supplied' {
        $original = [Environment]::GetEnvironmentVariable('ATAP_ARTIFACTS_ROOT', 'Process')
        $environmentRoot = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)) 'ATAPArtifacts/Pester/PowerShellModuleBuildMaster/env'
        try {
            [Environment]::SetEnvironmentVariable('ATAP_ARTIFACTS_ROOT', $environmentRoot, 'Process')
            $resolved = Resolve-PowerShellModuleArtifactDirectory `
                -SourcePath $script:RepoRoot `
                -BuildMasterBuildId '910002'
            $resolved | Should -Be ([IO.Path]::GetFullPath((Join-Path $environmentRoot 'BuildMaster/PowerShellModules/910002')))
        }
        finally {
            [Environment]::SetEnvironmentVariable('ATAP_ARTIFACTS_ROOT', $original, 'Process')
        }
    }

    It 'defaults this Dropbox worktree owner to the matching external user artifact root' {
        $configuredRoot = @('Process', 'User', 'Machine') |
            ForEach-Object { [Environment]::GetEnvironmentVariable('ATAP_ARTIFACTS_ROOT', [EnvironmentVariableTarget]$_) } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -First 1
        $expectedRoot = if ($configuredRoot) {
            $configuredRoot
        }
        else {
            'C:\Users\whertzing\ATAPArtifacts'
        }

        $resolved = Resolve-PowerShellModuleArtifactDirectory `
            -SourcePath $script:RepoRoot `
            -BuildMasterBuildId '910003'
        $resolved | Should -Be ([IO.Path]::GetFullPath((Join-Path $expectedRoot 'BuildMaster/PowerShellModules/910003')))
    }

    It 'rejects roots inside Dropbox' {
        {
            Resolve-PowerShellModuleArtifactDirectory `
                -ArtifactsRoot (Join-Path $script:RepoRoot '_generated/forbidden-artifacts') `
                -SourcePath $script:RepoRoot `
                -BuildMasterBuildId '910004'
        } | Should -Throw '*outside Dropbox*'
    }

    It 'rejects a non-Dropbox artifact root contained by SourcePath' {
        $externalSource = 'C:\Users\whertzing\ATAPArtifacts\Pester\PowerShellModuleBuildMaster\synthetic-source'
        {
            Resolve-PowerShellModuleArtifactDirectory `
                -ArtifactsRoot (Join-Path $externalSource 'artifacts') `
                -SourcePath $externalSource `
                -BuildMasterBuildId '910005'
        } | Should -Throw '*outside SourcePath*'
    }

    It 'rejects traversal and nonnumeric BuildMaster build identifiers' {
        $externalRoot = 'C:\Users\whertzing\ATAPArtifacts\Pester\PowerShellModuleBuildMaster'
        foreach ($invalidBuildId in @('.', '..', '21356/..', 'build-21356')) {
            {
                Resolve-PowerShellModuleArtifactDirectory `
                    -ArtifactsRoot $externalRoot `
                    -SourcePath $script:RepoRoot `
                    -BuildMasterBuildId $invalidBuildId
            } | Should -Throw '*decimal digits only*'
        }
    }

    It 'routes every package log test restore evidence and temp producer to the external directory' {
        $script:RunnerText | Should -Match '\$moduleBuildOutputRoot\s*=\s*Join-Path\s+-Path\s+\$artifactDirectory'
        $script:RunnerText | Should -Match '\$buildLogPath\s*=\s*Join-Path\s+-Path\s+\$artifactDirectory'
        $script:RunnerText | Should -Match '\$publishTracePath\s*=\s*Join-Path\s+-Path\s+\$artifactDirectory'
        $script:RunnerText | Should -Match '\$promotionTracePath\s*=\s*Join-Path\s+-Path\s+\$artifactDirectory'
        $script:RunnerText | Should -Match '-EvidenceRoot\s+\(Join-Path\s+-Path\s+\$artifactDirectory'
        $script:RunnerText | Should -Match '\$resultsPath\s*=\s*Join-Path\s+-Path\s+\$artifactDirectory'
        $script:RunnerText | Should -Match '-WorkingDirectory\s+\$externalWorkingDirectory'
        $script:RunnerText | Should -Match '\$env:TEMP\s*=\s*\$externalTempDirectory'
        $script:RunnerText | Should -Match '\$env:TMP\s*=\s*\$externalTempDirectory'

        $script:RunnerText | Should -Not -Match 'Join-Path -Path \$contextDirectory -ChildPath ''psmodules'''
        $script:RunnerText | Should -Not -Match 'Join-Path -Path \$contextDirectory -ChildPath ''PSModuleBuildLogs'''
        $script:RunnerText | Should -Not -Match 'Join-Path -Path \$contextDirectory -ChildPath "\$\(\$Tier\)TestResults"'
        $script:RunnerText | Should -Not -Match '-EvidenceRoot \(Join-Path -Path \$contextDirectory'
        $script:RunnerText | Should -Not -Match '-WorkingDirectory \$SourcePath'
    }

    It 'retains only compact coordination state beneath the repository run context' {
        $script:RunnerText | Should -Match 'Initialize-BuildMasterRunContextDirectory\s+-SourcePath\s+\$SourcePath'
        $script:RunnerText | Should -Match 'Write-BuildMasterRunContextJson'
        $script:RunnerText | Should -Match 'Write-BuildMasterRunStateFiles'
        $script:RunnerText | Should -Match 'Set-PowerShellModuleStageCompleted'
    }
}

Describe 'V4-B02 behavioral proof: Get-PVal fails loud under -NoProfile unless settings are initialized' {

    It 'the Get-PVal helper the runner depends on exists' {
        $script:GetPValPath | Should -Exist
    }

    It 'Get-PVal throws when no profile globals are loaded and no settings are supplied' {
        # With the removal of the bypass logic (Task 9.38), Get-PVal must fail loud
        # under a bare -NoProfile session if settings were not bootstrapped.
        $probe = @"
. '$script:GetPValPath'
try {
    Get-PVal -ParameterName 'ATAP_NoProfile_Probe_DoesNotExist' -originalPSBoundParameters @{} -DefaultValue 'fallback'
    Write-Output 'Success'
} catch {
    Write-Output 'Thrown'
}
"@
        $output = pwsh -NoProfile -Command $probe 2>&1
        ($output -join "`n").Trim() | Should -Be 'Thrown'
    }

    It 'the runner initializes local host settings via Initialize-LocalHostSettings' {
        $script:RunnerText | Should -Match 'Initialize-LocalHostSettings'
    }

    It 'loads Get-SecretATAP from the extracted Secrets child module' {
        $script:RunnerText | Should -Match "FunctionName = 'Get-SecretATAP'; ModuleName = 'ATAP\.Utilities\.BuildTooling\.Secrets\.PowerShell'"
        $script:RunnerText | Should -Not -Match "FunctionName = 'Get-SecretATAP'; ModuleName = 'ATAP\.Utilities\.BuildTooling\.PowerShell'"
    }
}
