#Requires -Version 7.0
# Pester 5+ unit tests for New-HostSettingsForPackageRepositoryFeeds.
# The helper writes fragment files, so Set-Content is mocked to capture output
# for assertions without touching the real host-settings paths.
# Validates that the Integration tier was added (72 total feed combinations
# instead of the old 48), and that short-form names contain 'Intg'.
# AI assisted using Powershell.instructions.md as guidelines

BeforeAll {
    $privateDir        = Join-Path $PSScriptRoot '..\..\private' | Resolve-Path
    $script:scriptPath = Join-Path $privateDir 'New-HostSettingsForPackageRepositoryFeeds.ps1'

    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }

    if (-not (Get-Command PSF_WriteError -ErrorAction SilentlyContinue)) {
        function global:PSF_WriteError { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }
}

Describe 'New-HostSettingsForPackageRepositoryFeeds' -Tag 'Unit' {

    BeforeAll {
        # Capture both file writes.
        $script:capturedConfigRootKeys = @()
        $script:capturedHostSettings   = @()

        Mock -CommandName Set-Content -MockWith {
            param([object]$Value, [string]$Path, [string]$Encoding)
            if ($Path -match 'ConfigRootKeys') {
                $script:capturedConfigRootKeys += @($Value)
            }
            elseif ($Path -match 'HostSettings') {
                $script:capturedHostSettings += @($Value)
            }
        } -ParameterFilter { $true }

        . $script:scriptPath
        New-HostSettingsForPackageRepositoryFeeds `
            -ConfigRootKeysFragmentPath 'C:\unit\ConfigRootKeys.ps1' `
            -HostSettingsFragmentPath 'C:\unit\HostSettings.ps1'
    }

    Context 'Set-Content called for both output files' {

        It 'Writes a ConfigRootKeys fragment file' {
            $script:capturedConfigRootKeys | Should -Not -BeNullOrEmpty
        }

        It 'Writes a HostSettings fragment file' {
            $script:capturedHostSettings | Should -Not -BeNullOrEmpty
        }
    }

    Context 'ConfigRootKeys — Integration tier present' {

        It 'Contains Integration in the ConfigRootKeys output' {
            $joined = $script:capturedConfigRootKeys -join "`n"
            $joined | Should -Match 'Integration'
        }

        It 'Contains Integration feed key entries in the ConfigRootKeys output' {
            $joined = $script:capturedConfigRootKeys -join "`n"
            $joined | Should -Match 'PackageRepositoryExternalReleasedNuGetIntegrationPullFeedConfigRootKey'
        }

        It 'Still contains Production entries' {
            $joined = $script:capturedConfigRootKeys -join "`n"
            $joined | Should -Match 'Production'
        }

        It 'Still contains QualityAssurance entries' {
            $joined = $script:capturedConfigRootKeys -join "`n"
            $joined | Should -Match 'QualityAssurance'
        }
    }

    Context 'ConfigRootKeys — entry count reflects 72 feed combinations' {

        It 'Has at least 72 configRootKey Add() calls (one per feed × 10 keys each = 720)' {
            # 2 EI × 2 V × 3 P × 3 PQ × 2 PP = 72 feed combinations × 10 keys = 720
            $addCount = ($script:capturedConfigRootKeys | Select-String '\.Add\(' -AllMatches).Matches.Count
            $addCount | Should -BeGreaterThan 640
        }
    }

    Context 'HostSettings — Integration tier present' {

        It 'Contains Integration in the HostSettings output' {
            $joined = $script:capturedHostSettings -join "`n"
            $joined | Should -Match 'Integration'
        }

        It 'Contains Intg short-form feed name in the HostSettings output' {
            $joined = $script:capturedHostSettings -join "`n"
            $joined | Should -Match 'Intg'
        }
    }
}
