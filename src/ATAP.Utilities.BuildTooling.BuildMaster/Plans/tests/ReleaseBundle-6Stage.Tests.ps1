# AI assisted using Powershell.instructions.md as guidelines
# Pester 5+ static-contract tests for V4-A07: the ReleaseBundle-6Stage
# OtterScript plan must keep the existing per-stage OtterScript surface
# (because Create-Artifact directives are stage-scoped) but every Exec
# block invokes a dedicated pwsh -File runner; no inline pwsh -Command
# block exposes secrets to BuildMaster transcripts.

BeforeAll {
    $script:PlansDir   = Join-Path $PSScriptRoot '..'
    $script:PlanPath   = Join-Path $script:PlansDir 'ReleaseBundle-6Stage.otter'
    $script:PlanText   = Get-Content -LiteralPath $script:PlanPath -Raw

    $script:RunnerPaths = @{
        Initialize  = Join-Path $script:PlansDir 'Initialize-ReleaseBundleBuildContext.ps1'
        New         = Join-Path $script:PlansDir 'New-ReleaseBundleBuildMasterPackage.ps1'
        Promote     = Join-Path $script:PlansDir 'Promote-ReleaseBundleBuildMasterPackage.ps1'
        Flyway      = Join-Path $script:PlansDir 'Invoke-ReleaseBundleFlywayRehearsal.ps1'
        Distribute  = Join-Path $script:PlansDir 'Publish-ReleaseBundleDistribution.ps1'
    }
}

Describe 'V4-A07 plan shape: ReleaseBundle-6Stage.otter is a thin runner plan' {

    It 'plan file exists' {
        $script:PlanPath | Should -Exist
    }

    It 'plan contains no inline pwsh -Command blocks' {
        $script:PlanText | Should -Not -Match '(?i)-NoProfile\s+-Command\b'
    }

    It 'plan does not assign $env:PROGET_* inside an Arguments block' {
        $script:PlanText | Should -Not -Match '\$\$env:PROGET_[A-Z_]+\s*=\s*[''"]'
    }

    It 'plan does not pass any ApiKey on the command line' {
        $script:PlanText | Should -Not -Match '(?i)-ProGetApiKey\b'
        $script:PlanText | Should -Not -Match '(?i)-ApiKey\s+["\$]'
    }

    It 'plan does not call $Decrypt(' {
        $script:PlanText | Should -Not -Match '\$Decrypt\('
    }

    It 'plan does not inline Promote-ProGetPackage in Arguments' {
        $script:PlanText | Should -Not -Match 'Arguments:[^\r\n]*Promote-ProGetPackage'
    }

    It 'plan does not inline Invoke-FlywayRehearsal in Arguments' {
        $script:PlanText | Should -Not -Match 'Arguments:[^\r\n]*Invoke-FlywayRehearsal'
    }

    It 'plan does not inline Publish-ChocolateyRelease or Update-WinGetManifestSource in Arguments' {
        $script:PlanText | Should -Not -Match 'Arguments:[^\r\n]*Publish-ChocolateyRelease'
        $script:PlanText | Should -Not -Match 'Arguments:[^\r\n]*Update-WinGetManifestSource'
    }

    It 'plan preserves the six stage blocks required by the BuildMaster pipeline' {
        foreach ($stageName in @('Experimental', 'Development', 'Integration', 'QA', 'Production', 'Distribution')) {
            $script:PlanText | Should -Match "(?im)^\s*stage\s+$stageName\s*\{"
        }
    }

    It 'plan declares set variables for every V4-A07 runner script' {
        $script:PlanText | Should -Match 'set\s+\$InitializeBuildContextScript\s*=\s*\$PathCombine'
        $script:PlanText | Should -Match 'set\s+\$NewReleaseBundleBuildMasterPackageScript\s*=\s*\$PathCombine'
        $script:PlanText | Should -Match 'set\s+\$PromoteReleaseBundleScript\s*=\s*\$PathCombine'
        $script:PlanText | Should -Match 'set\s+\$InvokeReleaseBundleFlywayRehearsalScript\s*=\s*\$PathCombine'
        $script:PlanText | Should -Match 'set\s+\$PublishReleaseBundleDistributionScript\s*=\s*\$PathCombine'
    }

    It 'plan invokes the Promote runner for each post-Experimental ProGet promotion' {
        # Development, Integration, QA, Production each call Promote runner once.
        $promoteCalls = [regex]::Matches(
            $script:PlanText,
            '-File\s+"\$PromoteReleaseBundleScript"'
        )
        $promoteCalls.Count | Should -Be 4
    }

    It 'plan invokes the Flyway-rehearsal runner exactly once (Integration stage)' {
        $flywayCalls = [regex]::Matches(
            $script:PlanText,
            '-File\s+"\$InvokeReleaseBundleFlywayRehearsalScript"'
        )
        $flywayCalls.Count | Should -Be 1
    }

    It 'plan invokes the Distribution runner exactly once (Distribution stage)' {
        $distCalls = [regex]::Matches(
            $script:PlanText,
            '-File\s+"\$PublishReleaseBundleDistributionScript"'
        )
        $distCalls.Count | Should -Be 1
    }

    It 'plan preserves the stage-scoped Create-Artifact directives' {
        $script:PlanText | Should -Match 'Create-Artifact\s+ReleaseManifest'
        $script:PlanText | Should -Match 'Create-Artifact\s+ReleaseBundle'
        $script:PlanText | Should -Match 'Create-Artifact\s+FlywayRehearsal'
    }

    It 'plan passes the Flyway rehearsal connection contract by Bitwarden secret name only' {
        # Integration stage must pass -IntegrationDatabaseDBConnectionStringSecretName but
        # never a raw connection string in Arguments.
        $script:PlanText | Should -Match '-IntegrationDatabaseDBConnectionStringSecretName\s+"\$IntegrationDatabaseDBConnectionStringSecretName"'
        $script:PlanText | Should -Not -Match 'Arguments:[^\r\n]*Server\s*='
        $script:PlanText | Should -Not -Match 'Arguments:[^\r\n]*User\s+Id\s*='
    }
}

Describe 'V4-A07 runner shapes: each release-bundle runner exists and parses' {

    It 'all five release-bundle runner scripts exist' {
        foreach ($key in $script:RunnerPaths.Keys) {
            $script:RunnerPaths[$key] | Should -Exist
        }
    }

    It 'all five release-bundle runner scripts parse without errors' {
        foreach ($key in $script:RunnerPaths.Keys) {
            $tokens = $null
            $parseErrors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $script:RunnerPaths[$key], [ref]$tokens, [ref]$parseErrors) | Out-Null
            $parseErrors | Should -BeNullOrEmpty -Because "$($script:RunnerPaths[$key]) must parse cleanly."
        }
    }
}

Describe 'V4-A07 Promote runner contract: Promote-ReleaseBundleBuildMasterPackage.ps1' {

    BeforeAll {
        $script:RunnerText = Get-Content -LiteralPath $script:RunnerPaths.Promote -Raw
    }

    It 'declares the parameters the plan supplies' {
        foreach ($param in @(
            'BuildToolingModulePath',
            'SourcePath',
            'Stage',
            'ReleaseBundleNameFile',
            'ReleaseBundleBundleVersionFile',
            'FromFeed',
            'ToFeed',
            'CeilingTier',
            'ProGetUrl'
        )) {
            $script:RunnerText | Should -Match "\[string\]\$\b$param\b"
        }
    }

    It 'restricts Stage to Development | Integration | QA | Production' {
        $script:RunnerText | Should -Match "ValidateSet\(\s*'Development'\s*,\s*'Integration'\s*,\s*'QA'\s*,\s*'Production'\s*\)"
    }

    It 'resolves API key from environment, never from a parameter' {
        $script:RunnerText | Should -Match '\$env:PROGET_BUILDMASTER_API_KEY'
        $script:RunnerText | Should -Match '\$env:PROGET_ADMIN_API_KEY'
        $script:RunnerText | Should -Not -Match '\[string\]\s*\$ProGetApiKey'
    }

    It 'sets global ProGetBaseUrl before calling Promote-ProGetPackage' {
        $script:RunnerText | Should -Match '\$global:ProGetBaseUrl\s*=\s*\$ProGetUrl'
        $script:RunnerText | Should -Match 'Promote-ProGetPackage'
    }

    It 'reads bundle name and version from per-build marker files (not from Arguments)' {
        $script:RunnerText | Should -Match 'Get-Content[^\r\n]*\$ReleaseBundleNameFile'
        $script:RunnerText | Should -Match 'Get-Content[^\r\n]*\$ReleaseBundleBundleVersionFile'
    }

    It 'passes -CeilingTier to Promote-ProGetPackage' {
        # The runner calls Promote-ProGetPackage with backtick line continuation,
        # so -CeilingTier may appear several lines below the cmdlet name.
        $script:RunnerText | Should -Match '(?s)Promote-ProGetPackage[\s\S]{0,400}-CeilingTier'
    }

    It 'never echoes the resolved API key into a log or trace line' {
        foreach ($pattern in @(
            'Write-PSFMessage[^\r\n]*\$resolvedApiKey',
            'Write-Output[^\r\n]*\$resolvedApiKey'
        )) {
            $script:RunnerText | Should -Not -Match $pattern
        }
    }
}

Describe 'V4-A07 Flyway-rehearsal runner contract: Invoke-ReleaseBundleFlywayRehearsal.ps1' {

    BeforeAll {
        $script:RunnerText = Get-Content -LiteralPath $script:RunnerPaths.Flyway -Raw
    }

    It 'declares the parameters the plan supplies' {
        foreach ($param in @(
            'BuildToolingModulePath',
            'DatabaseManagementModulePath',
            'SourcePath',
            'ProductName',
            'ReleaseBundlePathFile',
            'BackupPath',
            'IntegrationDatabaseDBConnectionStringSecretName',
            'LogPath'
        )) {
            $script:RunnerText | Should -Match "\[string\]\$\b$param\b"
        }
    }

    It 'requires -IntegrationDatabaseDBConnectionStringSecretName as Mandatory + ValidateNotNullOrEmpty' {
        $script:RunnerText | Should -Match '(?s)\[Parameter\s*\(\s*Mandatory\s*\)\][^\]]*\[ValidateNotNullOrEmpty\(\)\][^\]]*\[string\]\$IntegrationDatabaseDBConnectionStringSecretName'
    }

    It 'never accepts a raw connection string parameter' {
        $script:RunnerText | Should -Not -Match '\[string\]\s*\$SqlConnectionString'
        $script:RunnerText | Should -Not -Match '\[string\]\s*\$ConnectionString'
        $script:RunnerText | Should -Not -Match '\[string\]\s*\$DatabasePassword'
    }

    It 'reads bundle path from a marker file rather than the command line' {
        $script:RunnerText | Should -Match 'Get-Content[^\r\n]*\$ReleaseBundlePathFile'
    }

    It 'invokes Invoke-FlywayRehearsal and passes DBConnectionStringSecretName' {
        $script:RunnerText | Should -Match 'Invoke-FlywayRehearsal'
        # Use single-quoted pattern so the regex stays literal under PowerShell expansion.
        $script:RunnerText | Should -Match 'DBConnectionStringSecretName\s*=\s*\$IntegrationDatabaseDBConnectionStringSecretName'
    }
}

Describe 'V4-A07 Distribution runner contract: Publish-ReleaseBundleDistribution.ps1' {

    BeforeAll {
        $script:RunnerText = Get-Content -LiteralPath $script:RunnerPaths.Distribute -Raw
    }

    It 'declares only the parameters the plan supplies' {
        foreach ($param in @(
            'BuildToolingModulePath',
            'SourcePath',
            'ReleaseBundleBundleVersionFile'
        )) {
            $script:RunnerText | Should -Match "\[string\]\$\b$param\b"
        }
    }

    It 'does not declare any -*ApiKey or raw-secret parameter' {
        $script:RunnerText | Should -Not -Match '\[string\]\s*\$ProGetApiKey'
        $script:RunnerText | Should -Not -Match '\[string\]\s*\$ChocolateyApiKey'
        $script:RunnerText | Should -Not -Match '\[string\]\s*\$WinGetApiKey'
        $script:RunnerText | Should -Not -Match '\[string\]\s*\$ApiKey'
    }

    It 'invokes Publish-ChocolateyRelease and Update-WinGetManifestSource' {
        $script:RunnerText | Should -Match 'Publish-ChocolateyRelease'
        $script:RunnerText | Should -Match 'Update-WinGetManifestSource'
    }

    It 'reads bundle version from a marker file rather than the command line' {
        $script:RunnerText | Should -Match 'Get-Content[^\r\n]*\$ReleaseBundleBundleVersionFile'
    }
}
