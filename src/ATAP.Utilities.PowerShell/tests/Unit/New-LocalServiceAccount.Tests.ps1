# New-LocalServiceAccount.Tests.ps1
# Unit tests for New-LocalServiceAccount

# Derive function name from test filename and dot-source if not already loaded
$functionName = ($MyInvocation.MyCommand.Name -replace '\.Tests\.ps1$', '')

if (-not (Get-Command -Name $functionName -CommandType Function -ErrorAction SilentlyContinue)) {
    $functionPath = Join-Path $PSScriptRoot '..\..\public\New-LocalServiceAccount.ps1'
    if (Test-Path $functionPath) {
        . $functionPath
    }
    else {
        throw "Function file not found: $functionPath"
    }
}

Describe 'New-LocalServiceAccount' {

    BeforeAll {
        Write-PSFMessage -Level Debug -Message 'Starting New-LocalServiceAccount tests' -Tag 'Trace', 'Tests'

        # A dummy SecureString password for all test cases
        $script:testPassword = ConvertTo-SecureString 'TestPassword123!' -AsPlainText -Force

        # Minimal stub for a LocalUser object returned by Get-LocalUser
        $script:existingUserStub = [PSCustomObject]@{
            Name    = 'SvcTest'
            Enabled = $true
        }
    }

    # -------------------------------------------------------------------------
    Context 'State = Present — user does not yet exist' {

        BeforeEach {
            Mock -CommandName Get-LocalUser -MockWith { $null }
            Mock -CommandName New-LocalUser -MockWith { }
        }

        It 'returns Status = Success' {
            $result = New-LocalServiceAccount -AccountName 'SvcTest' -Password $script:testPassword
            $result.Status | Should -Be 'Success'
        }

        It 'sets UserCreated = $true' {
            $result = New-LocalServiceAccount -AccountName 'SvcTest' -Password $script:testPassword
            $result.UserCreated | Should -BeTrue
        }

        It 'sets UserAlreadyExisted = $false' {
            $result = New-LocalServiceAccount -AccountName 'SvcTest' -Password $script:testPassword
            $result.UserAlreadyExisted | Should -BeFalse
        }

        It 'calls New-LocalUser exactly once' {
            New-LocalServiceAccount -AccountName 'SvcTest' -Password $script:testPassword | Out-Null
            Should -Invoke New-LocalUser -Exactly 1
        }

        It 'echoes AccountName in the result' {
            $result = New-LocalServiceAccount -AccountName 'SvcTest' -Password $script:testPassword
            $result.AccountName | Should -Be 'SvcTest'
        }
    }

    # -------------------------------------------------------------------------
    Context 'State = Present — user already exists (idempotency)' {

        BeforeEach {
            Mock -CommandName Get-LocalUser -MockWith { $script:existingUserStub }
            Mock -CommandName New-LocalUser -MockWith { }
        }

        It 'returns Status = Success' {
            $result = New-LocalServiceAccount -AccountName 'SvcTest' -Password $script:testPassword
            $result.Status | Should -Be 'Success'
        }

        It 'sets UserAlreadyExisted = $true' {
            $result = New-LocalServiceAccount -AccountName 'SvcTest' -Password $script:testPassword
            $result.UserAlreadyExisted | Should -BeTrue
        }

        It 'does NOT call New-LocalUser' {
            New-LocalServiceAccount -AccountName 'SvcTest' -Password $script:testPassword | Out-Null
            Should -Invoke New-LocalUser -Exactly 0
        }
    }

    # -------------------------------------------------------------------------
    Context 'State = Absent — user exists' {

        BeforeEach {
            Mock -CommandName Get-LocalUser -MockWith { $script:existingUserStub }
            Mock -CommandName Remove-LocalUser -MockWith { }
        }

        It 'returns Status = Success' {
            $result = New-LocalServiceAccount -AccountName 'SvcTest' -Password $script:testPassword -State Absent
            $result.Status | Should -Be 'Success'
        }

        It 'sets UserRemoved = $true' {
            $result = New-LocalServiceAccount -AccountName 'SvcTest' -Password $script:testPassword -State Absent
            $result.UserRemoved | Should -BeTrue
        }

        It 'calls Remove-LocalUser exactly once' {
            New-LocalServiceAccount -AccountName 'SvcTest' -Password $script:testPassword -State Absent | Out-Null
            Should -Invoke Remove-LocalUser -Exactly 1
        }
    }

    # -------------------------------------------------------------------------
    Context 'State = Absent — user does not exist (idempotency)' {

        BeforeEach {
            Mock -CommandName Get-LocalUser -MockWith { $null }
            Mock -CommandName Remove-LocalUser -MockWith { }
        }

        It 'returns Status = Success' {
            $result = New-LocalServiceAccount -AccountName 'SvcTest' -Password $script:testPassword -State Absent
            $result.Status | Should -Be 'Success'
        }

        It 'does NOT call Remove-LocalUser' {
            New-LocalServiceAccount -AccountName 'SvcTest' -Password $script:testPassword -State Absent | Out-Null
            Should -Invoke Remove-LocalUser -Exactly 0
        }
    }

    # -------------------------------------------------------------------------
    Context '-WhatIf suppresses all changes' {

        BeforeEach {
            Mock -CommandName Get-LocalUser -MockWith { $null }
            Mock -CommandName New-LocalUser -MockWith { }
        }

        It 'does NOT call New-LocalUser when -WhatIf is specified' {
            New-LocalServiceAccount -AccountName 'SvcTest' -Password $script:testPassword -WhatIf | Out-Null
            Should -Invoke New-LocalUser -Exactly 0
        }
    }

    # -------------------------------------------------------------------------
    Context 'Error handling' {

        BeforeEach {
            Mock -CommandName Get-LocalUser -MockWith { $null }
            Mock -CommandName New-LocalUser -MockWith { throw [System.Exception]'Simulated creation failure' }
        }

        It 're-throws when New-LocalUser fails' {
            { New-LocalServiceAccount -AccountName 'SvcTest' -Password $script:testPassword } |
                Should -Throw 'Simulated creation failure'
        }
    }

    # -------------------------------------------------------------------------
    Context 'AccountName validation' {

        It 'rejects names that begin with a digit' {
            {
                New-LocalServiceAccount -AccountName '1Invalid' -Password $script:testPassword
            } | Should -Throw
        }

        It 'rejects names longer than 20 characters' {
            {
                New-LocalServiceAccount -AccountName 'A' * 21 -Password $script:testPassword
            } | Should -Throw
        }
    }
}
