#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

BeforeAll {
  . (Join-Path $PSScriptRoot '../../Resources/Resident/Invoke-CoordClerkResident.ps1')
  . (Join-Path $PSScriptRoot '../../Resources/Resident/Register-CoordClerkLogonTask.ps1')
  # Untyped fixture definitions prevent a mock's synthetic objects from being
  # coerced into real CIM instances; no task definition reaches Task Scheduler.
  function New-ScheduledTask { [CmdletBinding()] param($Action, $Trigger, $Principal, $Settings, $Description) }
  function Register-ScheduledTask { [CmdletBinding()] param($TaskPath, $TaskName, $InputObject) }
  function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }
}

Describe 'Disabled resident logon task registration contract' -Tag 'Unit' {
  BeforeEach {
    $identity = Get-CoordResidentIdentity
    $base = 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.BuildTooling.Orchestration.PowerShell\0.1.16'
    $script:registrarBinding = @{ mode = 'Held'; windowsSid = $identity.WindowsSid; module = @{ version = '0.1.16'; manifestPath = Join-Path $base 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psd1'; rootModulePath = Join-Path $base 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psm1'; manifestSha256 = 'A' * 64; rootModuleSha256 = 'A' * 64; hostScriptSha256 = 'A' * 64; signerThumbprint = 'A' * 40 } }
    Mock Read-CoordResidentBinding { $script:registrarBinding }
    Mock Assert-CoordResidentPath { param($Path) [IO.Path]::GetFullPath($Path) }
    Mock Get-FileHash { @{ Hash = 'A' * 64 } }
    Mock Get-AuthenticodeSignature { @{ Status = 'Valid'; SignerCertificate = @{ Thumbprint = 'A' * 40 } } }
    Mock Get-ScheduledTask { $null }
    Mock New-ScheduledTaskTrigger { @{ Trigger = 'fixture' } }
    Mock New-ScheduledTaskPrincipal { @{ Principal = 'fixture' } }
    Mock New-ScheduledTaskAction { @{ Action = 'fixture' } }
    Mock New-ScheduledTaskSettingsSet { @{ Enabled = $false } }
    Mock New-ScheduledTask { @{ Fixture = $true } }
    Mock Register-ScheduledTask { @{ Registered = 'fixture' } }
    Mock Write-PSFMessage {}
    Mock Enable-ScheduledTask { throw 'MustNeverEnable' }
    Mock Start-ScheduledTask { throw 'MustNeverStart' }
  }
  AfterEach {
    Should -Invoke Enable-ScheduledTask -Times 0
    Should -Invoke Start-ScheduledTask -Times 0
  }

  It 'WhatIf proposes only with no task query or registration' {
    $result = Register-CoordClerkLogonTask -BindingPath 'C:\fixture\held.json' -ExpectedBindingSha256 ('A' * 64) -WhatIf
    $result.Status | Should -BeExactly 'ProposedOnly'
    $result.Enabled | Should -BeFalse
    Should -Invoke Get-ScheduledTask -Times 0
    Should -Invoke Register-ScheduledTask -Times 0
  }

  It 'registers disabled AtLogOn for the actual interactive Windows SID at limited privilege' {
    $sid = (Get-CoordResidentIdentity).WindowsSid
    $result = Register-CoordClerkLogonTask -BindingPath 'C:\fixture\held.json' -ExpectedBindingSha256 ('A' * 64) -Confirm:$false
    $result.Status | Should -BeExactly 'RegisteredDisabled'
    $result.WindowsSid | Should -BeExactly $sid
    $result.Arguments | Should -Not -Match '-NoProfile'
    Should -Invoke New-ScheduledTaskTrigger -Times 1 -ParameterFilter { $AtLogOn -and $User -eq $sid }
    Should -Invoke New-ScheduledTaskPrincipal -Times 1 -ParameterFilter { $UserId -eq $sid -and $LogonType -eq 'Interactive' -and $RunLevel -eq 'Limited' }
    Should -Invoke New-ScheduledTaskSettingsSet -Times 1 -ParameterFilter { $Disable -and $MultipleInstances -eq 'IgnoreNew' -and $ExecutionTimeLimit -eq [TimeSpan]::Zero }
    Should -Invoke Register-ScheduledTask -Times 1
  }

  It 'never replaces an existing task' {
    Mock Get-ScheduledTask { @{ TaskName = 'CoordClerkResident' } }
    { Register-CoordClerkLogonTask -BindingPath 'C:\fixture\held.json' -ExpectedBindingSha256 ('A' * 64) -Confirm:$false } | Should -Throw '*ResidentTaskAlreadyExists*'
    Should -Invoke Register-ScheduledTask -Times 0
  }

  It 'refuses an Active descriptor instead of registering an activation' {
    $script:registrarBinding.mode = 'Active'
    { Register-CoordClerkLogonTask -BindingPath 'C:\fixture\active.json' -ExpectedBindingSha256 ('A' * 64) -Confirm:$false } | Should -Throw '*ResidentHeldInstalledBindingRequired*'
    Should -Invoke Register-ScheduledTask -Times 0
  }

  It 'refuses an invalid host signature before consulting or registering tasks' {
    Mock Get-AuthenticodeSignature { @{ Status = 'NotSigned'; SignerCertificate = $null } }
    { Register-CoordClerkLogonTask -BindingPath 'C:\fixture\held.json' -ExpectedBindingSha256 ('A' * 64) -Confirm:$false } | Should -Throw '*ResidentHostSignatureRejected*'
    Should -Invoke Get-ScheduledTask -Times 0
    Should -Invoke Register-ScheduledTask -Times 0
  }
}
