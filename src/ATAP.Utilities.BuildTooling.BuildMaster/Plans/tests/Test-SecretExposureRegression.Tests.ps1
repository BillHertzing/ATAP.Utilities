# AI assisted using Powershell.instructions.md as guidelines
# Pester 5+ regression tests for SEC-T1 / BLOCKER-8:
# Verify no ProGet API key appears in OtterScript plan Arguments or build artifacts.

BeforeAll {
    $script:PlansDir   = Join-Path $PSScriptRoot '..'
    $script:OtterFiles = Get-ChildItem -LiteralPath $script:PlansDir -Filter '*.otter' -File
}

Describe 'SEC-T1 — OtterScript plans must not expose secrets in Arguments' {

    It 'PowerShellModule-5Stage.otter contains no $Decrypt( call' {
        $file = $script:OtterFiles | Where-Object { $_.Name -eq 'PowerShellModule-5Stage.otter' }
        $file | Should -Not -BeNullOrEmpty
        $content = Get-Content -LiteralPath $file.FullName -Raw
        $content | Should -Not -Match '\$Decrypt\('
    }

    It 'CSharpPackage-5Stage.otter contains no $Decrypt( call' {
        $file = $script:OtterFiles | Where-Object { $_.Name -eq 'CSharpPackage-5Stage.otter' }
        $file | Should -Not -BeNullOrEmpty
        $content = Get-Content -LiteralPath $file.FullName -Raw
        $content | Should -Not -Match '\$Decrypt\('
    }

    It 'ReleaseBundle-6Stage.otter contains no $Decrypt( call' {
        $file = $script:OtterFiles | Where-Object { $_.Name -eq 'ReleaseBundle-6Stage.otter' }
        $file | Should -Not -BeNullOrEmpty
        $content = Get-Content -LiteralPath $file.FullName -Raw
        $content | Should -Not -Match '\$Decrypt\('
    }

    It 'No .otter plan passes -ProGetApiKey in an Arguments: block' {
        foreach ($file in $script:OtterFiles) {
            $content = Get-Content -LiteralPath $file.FullName -Raw
            # Arguments: lines must not contain a -ProGetApiKey value
            $content | Should -Not -Match 'Arguments:.*-ProGetApiKey\s+'
        }
    }

    It 'No .otter plan embeds an inline env:PROGET env-var assignment in Arguments' {
        foreach ($file in $script:OtterFiles) {
            $content = Get-Content -LiteralPath $file.FullName -Raw
            # Pattern: $$env:PROGET_* = '...' inside an Arguments block
            $content | Should -Not -Match '\$\$env:PROGET_[A-Z_]+\s*=\s*[''"]'
        }
    }

    It 'No .otter plan uses pwsh -Command anywhere (runner pattern required; V4-A07)' {
        foreach ($file in $script:OtterFiles) {
            $content = Get-Content -LiteralPath $file.FullName -Raw
            $content | Should -Not -Match '(?i)-NoProfile\s+-Command\b' `
                -Because "$($file.Name) must use 'pwsh -File' runner scripts, not inline 'pwsh -Command' blocks (V4-A07 / SEC-T1)."
        }
    }

    It 'No .otter plan inlines a ProGet promote/publish cmdlet call in Arguments (V4-A07)' {
        foreach ($file in $script:OtterFiles) {
            $content = Get-Content -LiteralPath $file.FullName -Raw
            foreach ($cmdlet in @('Promote-ProGetPackage', 'Publish-NuGetPackageToProGet', 'Publish-UniversalPackageToProGet')) {
                $content | Should -Not -Match "Arguments:[^\r\n]*$cmdlet" `
                    -Because "$($file.Name) must not invoke '$cmdlet' inline in an Arguments block (V4-A07 / SEC-T1)."
            }
        }
    }
}

Describe 'SEC-T1 — V4-A07 ReleaseBundle runner contracts' {

    BeforeAll {
        $script:PromoteScriptPath          = Join-Path $script:PlansDir 'Promote-ReleaseBundleBuildMasterPackage.ps1'
        $script:FlywayRehearsalScriptPath  = Join-Path $script:PlansDir 'Invoke-ReleaseBundleFlywayRehearsal.ps1'
        $script:DistributionScriptPath     = Join-Path $script:PlansDir 'Publish-ReleaseBundleDistribution.ps1'
    }

    It 'Promote-ReleaseBundleBuildMasterPackage.ps1 exists' {
        $script:PromoteScriptPath | Should -Exist
    }

    It 'Promote-ReleaseBundleBuildMasterPackage.ps1 does NOT declare -ProGetApiKey as a parameter' {
        $content = Get-Content -LiteralPath $script:PromoteScriptPath -Raw
        $content | Should -Not -Match '\$ProGetApiKey\b'
    }

    It 'Promote-ReleaseBundleBuildMasterPackage.ps1 carries only the canonical SecretName' {
        $content = Get-Content -LiteralPath $script:PromoteScriptPath -Raw
        $content | Should -Match 'ProGet\.BuildMaster\.API\.Key'
        $content | Should -Not -Match 'PROGET_(?:BUILDMASTER|ADMIN)_API_KEY'
    }

    It 'Promote-ReleaseBundleBuildMasterPackage.ps1 calls Promote-ProGetPackage' {
        $content = Get-Content -LiteralPath $script:PromoteScriptPath -Raw
        $content | Should -Match 'Promote-ProGetPackage'
    }

    It 'Invoke-ReleaseBundleFlywayRehearsal.ps1 exists' {
        $script:FlywayRehearsalScriptPath | Should -Exist
    }

    It 'Invoke-ReleaseBundleFlywayRehearsal.ps1 requires -IntegrationDatabaseDBConnectionStringSecretName and rejects empty values' {
        $content = Get-Content -LiteralPath $script:FlywayRehearsalScriptPath -Raw
        $content | Should -Match 'IntegrationDatabaseDBConnectionStringSecretName'
        $content | Should -Match '(?s)\[Parameter\s*\(\s*Mandatory\s*\)\][^\]]*\[ValidateNotNullOrEmpty\(\)\][^\]]*\[string\]\$IntegrationDatabaseDBConnectionStringSecretName'
    }

    It 'Invoke-ReleaseBundleFlywayRehearsal.ps1 does NOT accept a raw connection string parameter' {
        $content = Get-Content -LiteralPath $script:FlywayRehearsalScriptPath -Raw
        $content | Should -Not -Match '\[string\]\s*\$SqlConnectionString'
        $content | Should -Not -Match '\[string\]\s*\$ConnectionString'
    }

    It 'Publish-ReleaseBundleDistribution.ps1 exists' {
        $script:DistributionScriptPath | Should -Exist
    }

    It 'Publish-ReleaseBundleDistribution.ps1 does NOT declare -ProGetApiKey or raw secret params' {
        $content = Get-Content -LiteralPath $script:DistributionScriptPath -Raw
        $content | Should -Not -Match '\[string\]\s*\$ProGetApiKey'
        $content | Should -Not -Match '\[string\]\s*\$ChocolateyApiKey'
        $content | Should -Not -Match '\[string\]\s*\$WinGetApiKey'
    }

    It 'All three V4-A07 runner scripts parse without errors' {
        foreach ($path in @(
            $script:PromoteScriptPath,
            $script:FlywayRehearsalScriptPath,
            $script:DistributionScriptPath
        )) {
            $tokens = $null
            $parseErrors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $path, [ref]$tokens, [ref]$parseErrors) | Out-Null
            $parseErrors | Should -BeNullOrEmpty -Because "$path must parse cleanly."
        }
    }
}

Describe 'SEC-T1 — New-ReleaseBundleBuildMasterPackage.ps1 must not require ProGetApiKey' {

    BeforeAll {
        $script:ScriptPath = Join-Path $script:PlansDir 'New-ReleaseBundleBuildMasterPackage.ps1'
    }

    It 'Script file exists' {
        $script:ScriptPath | Should -Exist
    }

    It '-ProGetApiKey raw parameter is absent' {
        $content = Get-Content -LiteralPath $script:ScriptPath -Raw
        $content | Should -Not -Match '\$ProGetApiKey\b'
    }

    It 'Script carries only the canonical SecretName' {
        $content = Get-Content -LiteralPath $script:ScriptPath -Raw
        $content | Should -Match 'ProGet\.BuildMaster\.API\.Key'
        $content | Should -Not -Match 'PROGET_(?:BUILDMASTER|ADMIN)_API_KEY'
    }
}

Describe 'SEC-T1 — Build artifact folders must not contain a known secret prefix' {

    BeforeAll {
        # Resolve repo root: climb until _generated/ exists or we hit the drive root
        $search = $script:PlansDir
        $repoRoot = $null
        while ($search -and $search -ne (Split-Path $search -Parent)) {
            if (Test-Path (Join-Path $search '_generated')) {
                $repoRoot = $search
                break
            }
            $search = Split-Path $search -Parent
        }
        $script:GeneratedBuildMasterRoot = if ($repoRoot) {
            Join-Path $repoRoot '_generated\buildmaster'
        }
        else {
            $null
        }

        # Sentinel prefix: any value that starts with the conventional ProGet key prefix.
        # The actual key value is never stored here; we match the env var NAME instead.
        # In practice, no file under _generated/buildmaster/ should contain the raw
        # 13-character placeholder 'PROGET_APIKEY_' as a value (only as a variable name).
        $script:SentinelPattern = 'PROGET_APIKEY_\w+\s*='
    }

    It '_generated/buildmaster folder does not exist or contains no files matching the sentinel pattern' {
        if ($null -eq $script:GeneratedBuildMasterRoot -or
            -not (Test-Path -LiteralPath $script:GeneratedBuildMasterRoot -PathType Container)) {
            Set-ItResult -Skipped -Because '_generated/buildmaster does not exist on this workstation'
            return
        }
        $hits = Get-ChildItem -LiteralPath $script:GeneratedBuildMasterRoot -Recurse -File |
            Where-Object { $_.Extension -in @('.log', '.tmp', '.json', '.txt') } |
            Select-String -Pattern $script:SentinelPattern -SimpleMatch:$false |
            Select-Object -First 5
        $hits | Should -BeNullOrEmpty -Because 'no build artifact file should contain a ProGet API key assignment'
    }

    It 'publish.log files under _generated/buildmaster do not contain a raw API key value (pattern: long hex string)' {
        if ($null -eq $script:GeneratedBuildMasterRoot -or
            -not (Test-Path -LiteralPath $script:GeneratedBuildMasterRoot -PathType Container)) {
            Set-ItResult -Skipped -Because '_generated/buildmaster does not exist on this workstation'
            return
        }
        $publishLogs = Get-ChildItem -LiteralPath $script:GeneratedBuildMasterRoot -Recurse -Filter '*.publish.log'
        foreach ($log in $publishLogs) {
            $content = Get-Content -LiteralPath $log.FullName -Raw
            # A ProGet API key is typically a 36+ character alphanumeric/hyphen token.
            # If a line in the log contains such a token right after "ApiKey" or "api-key",
            # that is a leak. We use a conservative heuristic pattern.
            $content | Should -Not -Match '(?i)(apikey|api-key|x-apikey)\s*[:=]\s*[A-Za-z0-9\-]{36,}' `
                -Because "publish.log '$($log.FullName)' must not contain a raw API key value"
        }
    }
}
