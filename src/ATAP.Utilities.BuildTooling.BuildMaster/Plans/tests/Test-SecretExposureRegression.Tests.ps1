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
}

Describe 'SEC-T1 — New-ReleaseBundleBuildMasterPackage.ps1 must not require ProGetApiKey' {

    BeforeAll {
        $script:ScriptPath = Join-Path $script:PlansDir 'New-ReleaseBundleBuildMasterPackage.ps1'
    }

    It 'Script file exists' {
        $script:ScriptPath | Should -Exist
    }

    It '-ProGetApiKey parameter is not marked [Parameter(Mandatory)]' {
        $content = Get-Content -LiteralPath $script:ScriptPath -Raw
        # A mandatory ProGetApiKey would look like [Parameter(Mandatory)]\n...$ProGetApiKey
        $content | Should -Not -Match '(?s)\[Parameter\s*\(\s*Mandatory\s*\)\]\s+[^\]]*\[string\]\$ProGetApiKey'
    }

    It 'Script resolves API key from PROGET_BUILDMASTER_API_KEY or PROGET_ADMIN_API_KEY when param is empty' {
        $content = Get-Content -LiteralPath $script:ScriptPath -Raw
        $content | Should -Match 'PROGET_BUILDMASTER_API_KEY'
        $content | Should -Match 'PROGET_ADMIN_API_KEY'
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
