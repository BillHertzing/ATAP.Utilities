# AI assisted using Powershell.instructions.md as guidelines
# Pester 5+ tests for DBA2-T05 / V4-E11: Resolve-DatabasePackageFeed must
# map each canonical environment tier to its canonical database-* feed,
# and must reject unknown tiers with a terminating error.

BeforeAll {
    $script:CmdletPath = Join-Path $PSScriptRoot '..\public\Resolve-DatabasePackageFeed.ps1'

    if (-not (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments)]$args) }
    }

    . $script:CmdletPath
}

Describe 'Resolve-DatabasePackageFeed — tier-to-feed mapping' {

    It 'maps Experimental to database-experimental' {
        Resolve-DatabasePackageFeed -Tier 'Experimental' | Should -Be 'database-experimental'
    }

    It 'maps Development to database-development' {
        Resolve-DatabasePackageFeed -Tier 'Development' | Should -Be 'database-development'
    }

    It 'maps Integration to database-integration' {
        Resolve-DatabasePackageFeed -Tier 'Integration' | Should -Be 'database-integration'
    }

    It 'maps QA to database-qa' {
        Resolve-DatabasePackageFeed -Tier 'QA' | Should -Be 'database-qa'
    }

    It 'maps Production to database-stable' {
        Resolve-DatabasePackageFeed -Tier 'Production' | Should -Be 'database-stable'
    }
}

Describe 'Resolve-DatabasePackageFeed — input validation' {

    It 'throws a terminating error for an unknown tier' {
        { Resolve-DatabasePackageFeed -Tier 'BogusTier' } | Should -Throw
    }

    It 'throws a terminating error for an empty tier' {
        { Resolve-DatabasePackageFeed -Tier '' } | Should -Throw
    }

    It 'has a [ValidateSet] that lists exactly the five canonical tiers' {
        $cmdlet = Get-Command Resolve-DatabasePackageFeed
        $tierParam = $cmdlet.Parameters['Tier']
        $validateSet = $tierParam.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
            Select-Object -First 1
        $validateSet | Should -Not -BeNullOrEmpty
        @($validateSet.ValidValues | Sort-Object) |
            Should -Be @('Development', 'Experimental', 'Integration', 'Production', 'QA')
    }
}

Describe 'Resolve-DatabasePackageFeed — output contract' {

    It 'returns a single non-null, non-empty string' {
        $result = Resolve-DatabasePackageFeed -Tier 'Experimental'
        $result | Should -BeOfType [string]
        $result | Should -Not -BeNullOrEmpty
    }

    It 'never returns a feed name that is not one of the five canonical names' {
        foreach ($tier in @('Experimental', 'Development', 'Integration', 'QA', 'Production')) {
            $feed = Resolve-DatabasePackageFeed -Tier $tier
            $feed | Should -BeIn @(
                'database-experimental',
                'database-development',
                'database-integration',
                'database-qa',
                'database-stable'
            )
        }
    }
}
