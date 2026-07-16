# New-LocalServiceAccount.Tests.ps1
# Unit tests for Bitwarden-backed local service account provisioning.

BeforeAll {
    $functionPath = Join-Path $PSScriptRoot '..\..\public\New-LocalServiceAccount.ps1'
    if (-not (Test-Path -LiteralPath $functionPath -PathType Leaf)) {
        throw "Function file not found: $functionPath"
    }

    if (-not (Get-Command -Name 'Write-PSFMessage' -CommandType Function -ErrorAction SilentlyContinue)) {
        function global:Write-PSFMessage { param() }
    }
    if (-not (Get-Command -Name 'Get-SecretATAP' -CommandType Function -ErrorAction SilentlyContinue)) {
        function global:Get-SecretATAP { param() }
    }

    . $functionPath
    $script:existingUserStub = [PSCustomObject]@{
        Name = 'SvcTest'
        Enabled = $true
    }
}

Describe 'New-LocalServiceAccount' {
    BeforeEach {
        Mock -CommandName Write-PSFMessage -MockWith { }
    }

    Context 'State = Present and the account does not exist' {
        BeforeEach {
            Mock -CommandName Get-LocalUser -MockWith { $null }
            Mock -CommandName New-LocalUser -MockWith { }
            Mock -CommandName Get-SecretATAP -MockWith { 'unit-test-password' }
        }

        It 'creates the account with a supplied Bitwarden secret name' {
            $result = New-LocalServiceAccount -AccountName 'SvcTest' -SecretNameServiceAccountLoginCredentials 'SvcTest.utat022'

            $result.Status | Should -Be 'Success'
            $result.UserCreated | Should -BeTrue
            Should -Invoke Get-SecretATAP -Exactly 1 -ParameterFilter {
                $SecretName -eq 'SvcTest.utat022' -and
                $SecretField -eq 'password' -and
                $SecretStoreType -eq 'BitwardenSecretsManager'
            }
            Should -Invoke New-LocalUser -Exactly 1 -ParameterFilter {
                $Password -is [System.Security.SecureString]
            }
        }

        It 'derives the secret name from the account name and lowercase hostname when omitted' {
            $expectedSecretName = '{0}.{1}' -f 'SvcTest', $env:COMPUTERNAME.ToLowerInvariant()
            New-LocalServiceAccount -AccountName 'SvcTest' | Out-Null

            Should -Invoke Get-SecretATAP -Exactly 1 -ParameterFilter { $SecretName -eq $expectedSecretName }
        }

        It 'does not contact Bitwarden or create an account when WhatIf is specified' {
            New-LocalServiceAccount -AccountName 'SvcTest' -SecretNameServiceAccountLoginCredentials 'SvcTest.utat022' -WhatIf | Out-Null

            Should -Invoke Get-SecretATAP -Exactly 0
            Should -Invoke New-LocalUser -Exactly 0
        }
    }

    Context 'State = Present and the account already exists' {
        BeforeEach {
            Mock -CommandName Get-LocalUser -MockWith { $script:existingUserStub }
            Mock -CommandName New-LocalUser -MockWith { }
            Mock -CommandName Get-SecretATAP -MockWith { 'unit-test-password' }
        }

        It 'is idempotent and does not resolve the secret or create the account' {
            $result = New-LocalServiceAccount -AccountName 'SvcTest'

            $result.Status | Should -Be 'Success'
            $result.UserAlreadyExisted | Should -BeTrue
            Should -Invoke Get-SecretATAP -Exactly 0
            Should -Invoke New-LocalUser -Exactly 0
        }
    }

    Context 'State = Absent' {
        BeforeEach {
            Mock -CommandName Get-SecretATAP -MockWith { throw 'Get-SecretATAP must not be called when removing an account.' }
        }

        It 'removes an existing account without resolving a secret' {
            Mock -CommandName Get-LocalUser -MockWith { $script:existingUserStub }
            Mock -CommandName Remove-LocalUser -MockWith { }

            $result = New-LocalServiceAccount -AccountName 'SvcTest' -State Absent

            $result.Status | Should -Be 'Success'
            $result.UserRemoved | Should -BeTrue
            Should -Invoke Get-SecretATAP -Exactly 0
            Should -Invoke Remove-LocalUser -Exactly 1
        }

        It 'is idempotent when the account is already absent' {
            Mock -CommandName Get-LocalUser -MockWith { $null }
            Mock -CommandName Remove-LocalUser -MockWith { }

            $result = New-LocalServiceAccount -AccountName 'SvcTest' -State Absent

            $result.Status | Should -Be 'Success'
            $result.UserRemoved | Should -BeFalse
            Should -Invoke Get-SecretATAP -Exactly 0
            Should -Invoke Remove-LocalUser -Exactly 0
        }
    }
}
