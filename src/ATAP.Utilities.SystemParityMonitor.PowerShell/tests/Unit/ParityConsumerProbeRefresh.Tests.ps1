#Requires -Modules @{ModuleName='Pester';ModuleVersion='6.2.0'}
# Plan 8510CC89 (AceOutpost-scheduled consumer evidence refresh), phase P1; SC-0518.
# No test registers a real task, edits a real task SDDL, or writes outside its own temp fixture.

Describe 'Consumer probe refresh: start-right SDDL' -Tag 'Unit' {
  BeforeAll {
    $modulePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'ATAP.Utilities.SystemParityMonitor.PowerShell.psd1'
    Import-Module -Name $modulePath -Force
  }

  It 'appends a start-only GRGX ACE for the SID' {
    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell {
      $result = Get-ParityTaskStartRightSddl -Sddl 'O:BAG:SYD:(A;;FA;;;BA)(A;;FR;;;S-1-5-21-1-2-3-1001)' -Sid 'S-1-5-21-1-2-3-1015'
      $result.Changed | Should -BeTrue
      $result.Sddl | Should -BeExactly 'O:BAG:SYD:(A;;FA;;;BA)(A;;FR;;;S-1-5-21-1-2-3-1001)(A;;GRGX;;;S-1-5-21-1-2-3-1015)'
    }
  }

  It 'is idempotent for an existing grant in either spelling' {
    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell {
      foreach ($mask in 'GRGX', '0x1200a9') {
        $sddl = "O:BAG:SYD:(A;;FA;;;BA)(A;;$mask;;;S-1-5-21-1-2-3-1015)"
        $result = Get-ParityTaskStartRightSddl -Sddl $sddl -Sid 'S-1-5-21-1-2-3-1015'
        $result.Changed | Should -BeFalse
        $result.Sddl | Should -BeExactly $sddl
      }
    }
  }

  It 'ignores an inherited ACE for the SID and still adds the explicit grant' {
    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell {
      $result = Get-ParityTaskStartRightSddl -Sddl 'O:BAG:SYD:(A;ID;CCDCLCWPSDRC;;;S-1-5-21-1-2-3-1015)' -Sid 'S-1-5-21-1-2-3-1015'
      $result.Changed | Should -BeTrue
      $result.Sddl | Should -Match '\(A;;GRGX;;;S-1-5-21-1-2-3-1015\)$'
    }
  }

  It 'refuses to change a different explicit grant for the SID' {
    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell {
      { Get-ParityTaskStartRightSddl -Sddl 'O:BAG:SYD:(A;;FA;;;S-1-5-21-1-2-3-1015)' -Sid 'S-1-5-21-1-2-3-1015' } |
        Should -Throw '*different explicit task grant*'
    }
  }

  It 'refuses a descriptor without a DACL' {
    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell {
      { Get-ParityTaskStartRightSddl -Sddl 'O:BAG:SY' -Sid 'S-1-5-21-1-2-3-1015' } | Should -Throw '*no DACL*'
    }
  }
}

Describe 'Consumer probe refresh: dispatcher content' -Tag 'Unit' {
  BeforeAll {
    $modulePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'ATAP.Utilities.SystemParityMonitor.PowerShell.psd1'
    Import-Module -Name $modulePath -Force
  }

  It 'runs the task script with -File and the consumer arguments, loads profiles (no -NoProfile), and propagates the exit code' {
    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell {
      $content = New-ParityConsumerProbeDispatcherContent -ModuleVersion '0.1.32' `
        -ScriptPath 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.SystemParityMonitor.PowerShell\0.1.32\scripts\Invoke-ParityConsumerProbeTask.ps1' `
        -LogicalIdentity 'BuildMaster' -PolicyPath 'C:\ProgramData\ATAP\ParityState\Configuration\SharedDotNetTools.v1.json' `
        -StatePath 'C:\ProgramData\ATAP\ParityState' -PwshPath 'C:\Program Files\PowerShell\7\pwsh.exe'
      $content | Should -Match ([regex]::Escape("& 'C:\Program Files\PowerShell\7\pwsh.exe' -NonInteractive -ExecutionPolicy Bypass -File 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.SystemParityMonitor.PowerShell\0.1.32\scripts\Invoke-ParityConsumerProbeTask.ps1' -LogicalIdentity 'BuildMaster'"))
      $content | Should -Not -Match '(?i)-NoProfile'
      $content | Should -Match 'exit \$LASTEXITCODE$'
      $content | Should -Match 'SystemParityMonitor 0\.1\.32\. Do not edit by hand'
      $errors = $null
      $null = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$errors)
      $errors.Count | Should -Be 0
    }
  }

  It 'registers the task action with profiles loading (no -NoProfile)' {
    # The COM registration is mocked elsewhere, so assert on the action string in the definition.
    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell {
      $definitionText = (Get-Command Register-ParityConsumerProbeTaskDefinition).Definition
      $definitionText | Should -Match ([regex]::Escape('$action.Arguments = "-NonInteractive -ExecutionPolicy Bypass -File'))
      $argumentLines = @($definitionText -split "`n" | Where-Object { $_ -match '\$action\.Arguments\s*=' })
      $argumentLines.Count | Should -Be 1
      $argumentLines[0] | Should -Not -Match '(?i)-NoProfile'
    }
  }

  It 'escapes single quotes in paths' {
    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell {
      $content = New-ParityConsumerProbeDispatcherContent -ModuleVersion '0.1.32' -ScriptPath "C:\O'Neil\scripts\Invoke-ParityConsumerProbeTask.ps1" `
        -LogicalIdentity 'Developer' -PolicyPath 'C:\p.json' -StatePath 'C:\s' -PwshPath 'C:\pwsh.exe'
      $content | Should -Match ([regex]::Escape("'C:\O''Neil\scripts\Invoke-ParityConsumerProbeTask.ps1'"))
      $errors = $null
      $null = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$errors)
      $errors.Count | Should -Be 0
    }
  }

  It 'rejects relative paths and unsafe logical identities' {
    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell {
      { New-ParityConsumerProbeDispatcherContent -ModuleVersion '1' -ScriptPath 'scripts\x.ps1' -LogicalIdentity 'Developer' -PolicyPath 'C:\p.json' -StatePath 'C:\s' -PwshPath 'C:\pwsh.exe' } |
        Should -Throw '*fully qualified*'
      { New-ParityConsumerProbeDispatcherContent -ModuleVersion '1' -ScriptPath 'C:\x.ps1' -LogicalIdentity "Dev'; calc" -PolicyPath 'C:\p.json' -StatePath 'C:\s' -PwshPath 'C:\pwsh.exe' } |
        Should -Throw '*may contain only*'
    }
  }
}

Describe 'Consumer probe refresh: Register-ParityConsumerProbeTasks' -Tag 'Unit' {
  BeforeAll {
    $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Import-Module -Name (Join-Path $script:moduleRoot 'ATAP.Utilities.SystemParityMonitor.PowerShell.psd1') -Force

    function script:New-ProbePolicyFile {
      param([string] $Path, [object[]] $Consumers)
      [pscustomobject]@{
        SchemaVersion = 1
        SharedPath = 'C:\ProgramData\dotnet\tools'
        EvidenceMaxAgeHours = 168
        Tools = @([pscustomobject]@{ PackageId = 'dotnet-trace'; CommandName = 'dotnet-trace.exe'; ExpectedVersion = '10.0.731102' })
        Consumers = $Consumers
        RequiredChanges = @()
      } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding utf8
    }
    $script:standardConsumers = @(
      [pscustomobject]@{ LogicalIdentity = 'Developer'; ActualIdentity = 'UTAT022\whertzing'; EvidenceMode = 'EvidenceFile'; EvidencePath = 'C:\ProgramData\ATAP\ParityState\ConsumerEvidence\Developer.dotnet-tools.v1.json' }
      [pscustomobject]@{ LogicalIdentity = 'BuildMaster'; ActualIdentity = 'UTAT022\SvcBuildmaster'; EvidenceMode = 'EvidenceFile'; EvidencePath = 'C:\ProgramData\ATAP\ParityState\ConsumerEvidence\BuildMaster.dotnet-tools.v1.json' }
      [pscustomobject]@{ LogicalIdentity = 'ParityAudit'; ActualIdentity = 'UTAT022\SvcParityAudit'; EvidenceMode = 'CurrentProcess' }
    )
  }

  BeforeEach {
    $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('CPR_' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($fixtureRoot)
    $policyPath = Join-Path $fixtureRoot 'SharedDotNetTools.v1.json'
    $dispatcherDirectory = Join-Path $fixtureRoot 'Dispatchers'
    $backupDirectory = Join-Path $fixtureRoot 'Backups'
    New-ProbePolicyFile -Path $policyPath -Consumers $script:standardConsumers
    $common = @{
      PolicyPath = $policyPath
      StatePath = (Join-Path $fixtureRoot 'ParityState')
      SchedulerIdentity = 'UTAT022\SvcAceOutpost'
      DispatcherDirectory = $dispatcherDirectory
      ModuleRoot = $script:moduleRoot
      PwshPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
      BackupDirectory = $backupDirectory
    }
  }

  AfterEach {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
  }

  It 'registers one trigger-less S4U task per EvidenceFile consumer, writes its dispatcher, and grants the scheduler start rights' {
    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell -Parameters @{ Common = $common; DispatcherDirectory = $dispatcherDirectory } {
      Mock Resolve-ParityAccountSid { 'S-1-5-21-1-2-3-' + [Math]::Abs($AccountName.GetHashCode() % 10000) }
      Mock Register-ParityConsumerProbeTaskDefinition { }
      Mock Grant-ParityScheduledTaskStartRight { [pscustomobject]@{ Changed = $true } }

      $results = @(Register-ParityConsumerProbeTasks @Common -Confirm:$false)

      $results.Count | Should -Be 2
      ($results.LogicalIdentity | Sort-Object) | Should -Be @('BuildMaster', 'Developer')
      $results | ForEach-Object { $_.LogonType | Should -Be 'S4U'; $_.StartRight | Should -Be 'Granted'; $_.Applied | Should -BeTrue }
      Should -Invoke Register-ParityConsumerProbeTaskDefinition -Times 2 -Exactly
      Should -Invoke Register-ParityConsumerProbeTaskDefinition -Times 1 -Exactly -ParameterFilter {
        $TaskName -eq 'ATAP-ParityConsumerProbe-BuildMaster' -and $UserId -eq 'UTAT022\SvcBuildmaster' -and $LogonType -eq 'S4U' -and
        $DispatcherPath -eq (Join-Path $DispatcherDirectory 'ATAP-ParityConsumerProbe-BuildMaster.ps1') -and -not $Credential
      }
      Should -Invoke Register-ParityConsumerProbeTaskDefinition -Times 0 -Exactly -ParameterFilter { $TaskName -like '*ParityAudit*' }
      Should -Invoke Grant-ParityScheduledTaskStartRight -Times 2 -Exactly
      $dispatcher = Get-Content -LiteralPath (Join-Path $DispatcherDirectory 'ATAP-ParityConsumerProbe-Developer.ps1') -Raw
      $dispatcher | Should -Match "-LogicalIdentity 'Developer'"
      $dispatcher | Should -Match ([regex]::Escape('scripts\Invoke-ParityConsumerProbeTask.ps1'))
    }
  }

  It 'changes nothing under -WhatIf' {
    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell -Parameters @{ Common = $common; DispatcherDirectory = $dispatcherDirectory } {
      Mock Resolve-ParityAccountSid { 'S-1-5-21-1-2-3-1015' }
      Mock Register-ParityConsumerProbeTaskDefinition { }
      Mock Grant-ParityScheduledTaskStartRight { [pscustomobject]@{ Changed = $true } }

      $results = @(Register-ParityConsumerProbeTasks @Common -WhatIf)

      $results.Count | Should -Be 2
      $results | ForEach-Object { $_.Applied | Should -BeFalse; $_.StartRight | Should -Be 'NotApplied' }
      Should -Invoke Register-ParityConsumerProbeTaskDefinition -Times 0 -Exactly
      Should -Invoke Grant-ParityScheduledTaskStartRight -Times 0 -Exactly
      Test-Path -LiteralPath $DispatcherDirectory | Should -BeFalse
    }
  }

  It 'uses Password logon only for the consumer whose credential is supplied' {
    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell -Parameters @{ Common = $common } {
      Mock Resolve-ParityAccountSid { 'S-1-5-21-1-2-3-1015' }
      Mock Register-ParityConsumerProbeTaskDefinition { }
      Mock Grant-ParityScheduledTaskStartRight { [pscustomobject]@{ Changed = $false } }
      $credential = [pscredential]::new('UTAT022\SvcBuildmaster', (ConvertTo-SecureString 'fixture-not-a-secret' -AsPlainText -Force))

      $results = @(Register-ParityConsumerProbeTasks @Common -Credential $credential -Confirm:$false)

      ($results | Where-Object LogicalIdentity -eq 'BuildMaster').LogonType | Should -Be 'Password'
      ($results | Where-Object LogicalIdentity -eq 'Developer').LogonType | Should -Be 'S4U'
      $results | ForEach-Object { $_.StartRight | Should -Be 'AlreadyGranted' }
      Should -Invoke Register-ParityConsumerProbeTaskDefinition -Times 1 -Exactly -ParameterFilter {
        $TaskName -eq 'ATAP-ParityConsumerProbe-BuildMaster' -and $LogonType -eq 'Password' -and $Credential.UserName -eq 'UTAT022\SvcBuildmaster'
      }
    }
  }

  It 'refuses a credential that matches no EvidenceFile consumer' {
    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell -Parameters @{ Common = $common } {
      Mock Resolve-ParityAccountSid { 'S-1-5-21-1-2-3-1015' }
      $credential = [pscredential]::new('UTAT022\SvcParityAudit', (ConvertTo-SecureString 'fixture-not-a-secret' -AsPlainText -Force))
      { Register-ParityConsumerProbeTasks @Common -Credential $credential -Confirm:$false } | Should -Throw '*does not match any EvidenceFile consumer*'
    }
  }

  It 'refuses a policy without EvidenceFile consumers or with a duplicate logical identity' {
    New-ProbePolicyFile -Path $policyPath -Consumers @([pscustomobject]@{ LogicalIdentity = 'ParityAudit'; ActualIdentity = 'UTAT022\SvcParityAudit'; EvidenceMode = 'CurrentProcess' })
    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell -Parameters @{ Common = $common } {
      { Register-ParityConsumerProbeTasks @Common -Confirm:$false } | Should -Throw '*no EvidenceFile consumers*'
    }
    New-ProbePolicyFile -Path $policyPath -Consumers @($script:standardConsumers[0], $script:standardConsumers[0])
    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell -Parameters @{ Common = $common } {
      { Register-ParityConsumerProbeTasks @Common -Confirm:$false } | Should -Throw '*more than once*'
    }
  }

  It 'refuses to write a dispatcher into a directory that broad identities can write' {
    [void][IO.Directory]::CreateDirectory($dispatcherDirectory)
    $acl = Get-Acl -LiteralPath $dispatcherDirectory
    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new('BUILTIN\Users', 'Modify', 'Allow'))
    Set-Acl -LiteralPath $dispatcherDirectory -AclObject $acl
    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell -Parameters @{ Common = $common } {
      Mock Resolve-ParityAccountSid { 'S-1-5-21-1-2-3-1015' }
      Mock Register-ParityConsumerProbeTaskDefinition { }
      Mock Grant-ParityScheduledTaskStartRight { [pscustomobject]@{ Changed = $true } }
      { Register-ParityConsumerProbeTasks @Common -Confirm:$false } | Should -Throw '*writable by an untrusted identity*'
      Should -Invoke Register-ParityConsumerProbeTaskDefinition -Times 0 -Exactly
    }
  }

  It 'refuses an unresolvable scheduler identity before changing anything' {
    InModuleScope ATAP.Utilities.SystemParityMonitor.PowerShell -Parameters @{ Common = $common } {
      Mock Resolve-ParityAccountSid { throw "Account '$AccountName' could not be resolved to a SID." }
      Mock Register-ParityConsumerProbeTaskDefinition { }
      { Register-ParityConsumerProbeTasks @Common -Confirm:$false } | Should -Throw '*could not be resolved*'
      Should -Invoke Register-ParityConsumerProbeTaskDefinition -Times 0 -Exactly
    }
  }

  It 'is exported by the module' {
    (Get-Module ATAP.Utilities.SystemParityMonitor.PowerShell).ExportedFunctions.Keys | Should -Contain 'Register-ParityConsumerProbeTasks'
    (Get-Module ATAP.Utilities.SystemParityMonitor.PowerShell).ExportedFunctions.Keys | Should -Not -Contain 'Grant-ParityScheduledTaskStartRight'
  }
}

Describe 'Consumer probe refresh: Invoke-ParityConsumerProbeTask (fail-closed)' -Tag 'Unit' {
  BeforeAll {
    $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Import-Module -Name (Join-Path $script:moduleRoot 'ATAP.Utilities.SystemParityMonitor.PowerShell.psd1') -Force
    # Dot-sourcing defines the function; the &-proof guard keeps the task body from running.
    . (Join-Path $script:moduleRoot 'scripts\Invoke-ParityConsumerProbeTask.ps1')
  }

  BeforeEach {
    $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('CPT_' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($fixtureRoot)
    $statePath = Join-Path $fixtureRoot 'ParityState'
    $evidencePath = Join-Path $fixtureRoot 'ConsumerEvidence\Developer.dotnet-tools.v1.json'
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $evidencePath))
    Set-Content -LiteralPath $evidencePath -Value '{"CapturedAtUtc":"2026-11-07T15:51:03Z","fixture":"old"}' -Encoding utf8
    $oldHash = (Get-FileHash -LiteralPath $evidencePath).Hash
    $policyPath = Join-Path $fixtureRoot 'SharedDotNetTools.v1.json'
    [pscustomobject]@{
      SchemaVersion = 1
      SharedPath = 'C:\ProgramData\dotnet\tools'
      EvidenceMaxAgeHours = 168
      Tools = @([pscustomobject]@{ PackageId = 'dotnet-trace'; CommandName = 'dotnet-trace.exe'; ExpectedVersion = '10.0.731102' })
      Consumers = @(
        [pscustomobject]@{ LogicalIdentity = 'Developer'; ActualIdentity = 'UTAT022\whertzing'; EvidenceMode = 'EvidenceFile'; EvidencePath = $evidencePath }
        [pscustomobject]@{ LogicalIdentity = 'ParityAudit'; ActualIdentity = 'UTAT022\SvcParityAudit'; EvidenceMode = 'CurrentProcess' }
      )
      RequiredChanges = @()
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $policyPath -Encoding utf8

    function script:New-FixtureEvidence {
      param([string] $OutputPath, [string] $Version = '10.0.731102', [int] $VersionExit = 0, [int] $HelpExit = 0, [switch] $NoFile)
      $evidence = [pscustomobject]@{
        SchemaVersion = 1; HostName = 'utat022'; LogicalIdentity = 'Developer'; ActualIdentity = 'UTAT022\whertzing'
        CapturedAtUtc = '2026-11-16T03:00:00.0000000Z'
        Tools = @([pscustomobject]@{ PackageId = 'dotnet-trace'; ResolvedPath = 'C:\ProgramData\dotnet\tools\dotnet-trace.exe'; Version = $Version; VersionExitCode = $VersionExit; HelpExitCode = $HelpExit })
      }
      if (-not $NoFile) { $evidence | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding utf8 }
      $evidence
    }
  }

  AfterEach {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
  }

  It 'replaces the evidence only after both checks pass, and records a Refreshed result' {
    Mock Invoke-SharedDotNetToolConsumerProbe { New-FixtureEvidence -OutputPath $OutputPath }
    $result = Invoke-ParityConsumerProbeTask -LogicalIdentity 'Developer' -PolicyPath $policyPath -StatePath $statePath
    $result.Outcome | Should -Be 'Refreshed'
    $result.ExitCode | Should -Be 0
    # Compare the raw text: ConvertFrom-Json would turn the ISO string into a DateTime.
    Get-Content -LiteralPath $evidencePath -Raw | Should -Match '"CapturedAtUtc":\s*"2026-11-16T03:00:00\.0000000Z"'
    (Get-FileHash -LiteralPath $evidencePath).Hash | Should -Not -Be $oldHash
    @(Get-ChildItem -LiteralPath (Split-Path -Parent $evidencePath) -Filter '*.pending').Count | Should -Be 0
    $records = @(Get-ChildItem -LiteralPath (Join-Path $statePath 'TaskResults') -Filter 'ParityConsumerProbeTaskResult.*.developer.*.json')
    $records.Count | Should -Be 1
    (Get-Content -LiteralPath $records[0].FullName -Raw | ConvertFrom-Json).Outcome | Should -Be 'Refreshed'
    Should -Invoke Invoke-SharedDotNetToolConsumerProbe -Times 1 -Exactly -ParameterFilter { $OutputPath -like '*.pending' -and $LogicalIdentity -eq 'Developer' }
  }

  It 'leaves the evidence untouched when a check exits non-zero' {
    Mock Invoke-SharedDotNetToolConsumerProbe { New-FixtureEvidence -OutputPath $OutputPath -HelpExit 1 }
    $result = Invoke-ParityConsumerProbeTask -LogicalIdentity 'Developer' -PolicyPath $policyPath -StatePath $statePath
    $result.Outcome | Should -Be 'Failed'
    $result.ExitCode | Should -Be 1
    $result.Reason | Should -Match 'evidence NOT refreshed'
    (Get-FileHash -LiteralPath $evidencePath).Hash | Should -Be $oldHash
    @(Get-ChildItem -LiteralPath (Split-Path -Parent $evidencePath) -Filter '*.pending').Count | Should -Be 0
  }

  It 'leaves the evidence untouched when the version differs from the policy' {
    Mock Invoke-SharedDotNetToolConsumerProbe { New-FixtureEvidence -OutputPath $OutputPath -Version '9.0.1' }
    $result = Invoke-ParityConsumerProbeTask -LogicalIdentity 'Developer' -PolicyPath $policyPath -StatePath $statePath
    $result.ExitCode | Should -Be 1
    (Get-FileHash -LiteralPath $evidencePath).Hash | Should -Be $oldHash
  }

  It 'leaves the evidence untouched when the probe refuses (for example a wrong identity)' {
    Mock Invoke-SharedDotNetToolConsumerProbe { throw "Current identity 'UTAT022\Other' does not match configured identity 'UTAT022\whertzing' for 'Developer'." }
    $result = Invoke-ParityConsumerProbeTask -LogicalIdentity 'Developer' -PolicyPath $policyPath -StatePath $statePath
    $result.ExitCode | Should -Be 1
    $result.Reason | Should -Match 'does not match configured identity'
    (Get-FileHash -LiteralPath $evidencePath).Hash | Should -Be $oldHash
  }

  It 'fails when the probe reports success but wrote no evidence file' {
    Mock Invoke-SharedDotNetToolConsumerProbe { New-FixtureEvidence -OutputPath $OutputPath -NoFile }
    $result = Invoke-ParityConsumerProbeTask -LogicalIdentity 'Developer' -PolicyPath $policyPath -StatePath $statePath
    $result.ExitCode | Should -Be 1
    $result.Reason | Should -Match 'wrote no evidence file'
    (Get-FileHash -LiteralPath $evidencePath).Hash | Should -Be $oldHash
  }

  It 'refuses a CurrentProcess consumer and an unknown consumer without calling the probe' {
    Mock Invoke-SharedDotNetToolConsumerProbe { New-FixtureEvidence -OutputPath $OutputPath }
    (Invoke-ParityConsumerProbeTask -LogicalIdentity 'ParityAudit' -PolicyPath $policyPath -StatePath $statePath).Reason | Should -Match 'not an EvidenceFile consumer'
    (Invoke-ParityConsumerProbeTask -LogicalIdentity 'Nobody' -PolicyPath $policyPath -StatePath $statePath).Reason | Should -Match 'exactly one consumer'
    Should -Invoke Invoke-SharedDotNetToolConsumerProbe -Times 0 -Exactly
  }
}
