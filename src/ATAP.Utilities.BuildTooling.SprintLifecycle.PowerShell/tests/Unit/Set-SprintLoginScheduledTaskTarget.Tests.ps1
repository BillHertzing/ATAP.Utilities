BeforeAll {
  . (Join-Path $PSScriptRoot '..' '..' 'private' 'Set-SprintLoginScheduledTaskTarget.ps1')

  # Local throwing commands shadow any host TaskScheduler cmdlets before mocks are
  # installed. A missing mock cannot touch a retained host registration.
  function Get-ScheduledTask { [CmdletBinding()] param() throw 'Unmocked scheduler read.' }
  function Export-ScheduledTask { [CmdletBinding()] param($TaskName, $TaskPath) throw 'Unmocked scheduler export.' }
  function Set-ScheduledTask { [CmdletBinding(SupportsShouldProcess)] param($TaskName, $TaskPath, $Action) throw 'Unmocked scheduler write.' }
  function Write-PSFMessage { [CmdletBinding()] param($FunctionName, $ModuleName, $Level, $Message) }
  $script:realGetItem = Get-Command Get-Item -CommandType Cmdlet

  function copyTestObject($Value) {
    [Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize($Value))
  }

  function newTestLoginFile([string] $Root) {
    $target = Join-Path $Root 'src/ATAP.Utilities.PowerShell/Profiles/LoginScript.ps1'
    New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
    Set-Content -LiteralPath $target -Value '# inert fixture; never executed' -Encoding utf8
    $target
  }

  function newTestTask([string] $Name, [string] $Binding) {
    [PSCustomObject]@{
      TaskName = $Name; TaskPath = '\ATAP\'; Enabled = $false; Description = 'retained metadata'
      Actions = @(
        [PSCustomObject]@{ Id = 'login'; Execute = 'C:\Program Files\PowerShell\7\pwsh.exe'; Arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$Binding`" -Unrelated `"value with spaces`""; WorkingDirectory = 'C:\existing work' },
        [PSCustomObject]@{ Id = 'other'; Execute = 'C:\Windows\System32\cmd.exe'; Arguments = '/c echo retained'; WorkingDirectory = 'C:\other' },
        [PSCustomObject]@{ Id = 'powershell-other'; Execute = 'pwsh.exe'; Arguments = '-NoProfile -Command "exit 0"'; WorkingDirectory = '' }
      )
    }
  }

  function exportTestTask($Task) {
    $actionXml = foreach ($action in $Task.Actions) {
      $execute = [Security.SecurityElement]::Escape($action.Execute)
      $arguments = [Security.SecurityElement]::Escape($action.Arguments)
      $working = [Security.SecurityElement]::Escape($action.WorkingDirectory)
      "<Exec id=`"$($action.Id)`"><Command>$execute</Command><Arguments>$arguments</Arguments><WorkingDirectory>$working</WorkingDirectory></Exec>"
    }
    $enabled = ([string]$Task.Enabled).ToLowerInvariant()
    $description = [Security.SecurityElement]::Escape($Task.Description)
    "<Task xmlns=`"http://schemas.microsoft.com/windows/2004/02/mit/task`" version=`"1.4`"><RegistrationInfo><Date>2026-10-08T01:00:00</Date><Author>retained</Author><Description>$description</Description></RegistrationInfo><Triggers><LogonTrigger><Enabled>true</Enabled></LogonTrigger></Triggers><Principals><Principal id=`"Author`"><UserId>retained-user</UserId><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals><Settings><Enabled>$enabled</Enabled><ExecutionTimeLimit>PT0S</ExecutionTimeLimit></Settings><Actions Context=`"Author`">$($actionXml -join '')</Actions></Task>"
  }
}

Describe 'Set-SprintLoginScheduledTaskTarget private pair updater' {
  BeforeEach {
    $script:fixtureRoot = Join-Path $PSScriptRoot '..' '..' '..' '..' '_generated/Sprint0015/Task15.208/Task-15.208.b.helper/fixtures' ([guid]::NewGuid().ToString('N'))
    $script:fixtureRoot = [IO.Path]::GetFullPath($script:fixtureRoot)
    New-Item -ItemType Directory -Path $script:fixtureRoot -Force | Out-Null
    $script:sprintRoot = Join-Path $script:fixtureRoot 'ATAP.Utilities-wt-137-Sprint-0015-work-items'
    $script:stableRoot = Join-Path $script:fixtureRoot 'ATAP.Utilities'
    $script:sprintTarget = newTestLoginFile $script:sprintRoot
    $script:stableTarget = newTestLoginFile $script:stableRoot
    $script:developmentTarget = newTestLoginFile (Join-Path $script:fixtureRoot 'development with spaces')
    $script:taskStore = @(
      (newTestTask 'ATAPLoginScript' $script:stableTarget),
      (newTestTask 'Unlock BitWarden' $script:stableTarget)
    )
    $script:writeNames = [Collections.Generic.List[string]]::new()
    $script:writeCount = 0
    $script:inventoryCount = 0
    $script:failWrite = 0
    $script:partialFailure = $false
    $script:corruptAfterWrite = $false
    $script:failRollback = $false
    $script:concurrentInventory = 0
    $script:concurrentTask = 1
    $script:changeTargetInventory = 0
    $script:dropWrite = 0
    $script:exportCount = 0
    $script:failExportAt = 0
    Mock Write-PSFMessage { }
    Mock Get-ScheduledTask {
      $script:inventoryCount++
      if ($script:inventoryCount -eq $script:concurrentInventory) {
        $script:taskStore[$script:concurrentTask].Description = 'concurrent actor'
      }
      if ($script:inventoryCount -eq $script:changeTargetInventory) {
        Add-Content -LiteralPath $script:sprintTarget -Value '# changed after preflight'
      }
      foreach ($task in $script:taskStore) { copyTestObject $task }
    }
    Mock Export-ScheduledTask {
      $script:exportCount++
      if ($script:exportCount -eq $script:failExportAt) { throw 'injected readback failure' }
      $task = @($script:taskStore | Where-Object { $_.TaskName -eq $TaskName -and $_.TaskPath -eq $TaskPath })
      if ($task.Count -ne 1) { throw 'Ambiguous test export.' }
      exportTestTask $task[0]
    }
    Mock Set-ScheduledTask {
      $script:writeCount++
      $script:writeNames.Add($TaskName)
      $task = $script:taskStore | Where-Object { $_.TaskName -eq $TaskName -and $_.TaskPath -eq $TaskPath }
      if ($script:writeCount -eq $script:dropWrite) { return (copyTestObject $task) }
      if ($script:writeCount -eq $script:failWrite) {
        if ($script:partialFailure) { $task.Actions = @(copyTestObject $Action) }
        throw 'injected write failure'
      }
      if ($script:failRollback -and $script:writeCount -gt $script:failWrite) { throw 'injected rollback failure' }
      $task.Actions = @(copyTestObject $Action)
      if ($script:corruptAfterWrite -and $script:writeCount -eq 1) { $task.Description = 'corrupted metadata' }
      copyTestObject $task
    }
  }

  It 'selects Start from its explicit active Utilities root and preserves complete definitions' {
    $before = @($script:taskStore | ForEach-Object { exportTestTask $_ })
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $result.Ok | Should -BeTrue
    $result.SelectionMode | Should -Be 'SprintDefault'
    $result.TargetPath | Should -Be $script:sprintTarget
    $result.TargetHash | Should -Be (Get-FileHash -LiteralPath $script:sprintTarget).Hash
    $result.Changed | Should -BeTrue
    $result.Tasks.Outcome | Should -Be @('Applied', 'Applied')
    $result.Tasks.PreservedPropertiesVerified | Should -Be @($true, $true)
    for ($i = 0; $i -lt 2; $i++) {
      (exportTestTask $script:taskStore[$i]).Replace($script:sprintTarget, $script:stableTarget) | Should -Be $before[$i]
      $script:taskStore[$i].Enabled | Should -BeFalse
    }
  }

  It 'selects a unique Utilities entry from the invocation worktree set' {
    $other = Join-Path $script:fixtureRoot 'Ace-wt-45-Sprint-0015-work-items'
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -WorktreePaths @($other, $script:sprintRoot, $script:sprintRoot)
    $result.Ok | Should -BeTrue
    $result.TargetPath | Should -Be $script:sprintTarget
  }

  It 'selects stable GitRoot at End and is idempotent when both tasks already match' {
    $result = Set-SprintLoginScheduledTaskTarget -Boundary End -GitRoot $script:fixtureRoot -WorktreePaths @($script:sprintRoot)
    $result.Ok | Should -BeTrue
    $result.SelectionMode | Should -Be 'StableDefault'
    $result.Changed | Should -BeFalse
    $result.Tasks.Outcome | Should -Be @('Unchanged', 'Unchanged')
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'transitions Start then End and reports the before and after bindings' {
    $start = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $end = Set-SprintLoginScheduledTaskTarget -Boundary End -GitRoot $script:fixtureRoot -WorktreePaths @($script:sprintRoot)
    $start.Ok | Should -BeTrue
    $end.Ok | Should -BeTrue
    $end.Tasks.BeforeBinding | Should -Be @($script:sprintTarget, $script:sprintTarget)
    $end.Tasks.AfterBinding | Should -Be @($script:stableTarget, $script:stableTarget)
  }

  It 'keeps an explicit quoted-space development override invocation-only' {
    $override = Set-SprintLoginScheduledTaskTarget -Boundary Start -LoginScriptPath $script:developmentTarget
    $reset = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $override.Ok | Should -BeTrue
    $override.SelectionMode | Should -Be 'ExplicitDevelopmentOverride'
    $override.TargetPath | Should -Be $script:developmentTarget
    $reset.Ok | Should -BeTrue
    $reset.SelectionMode | Should -Be 'SprintDefault'
    $reset.TargetPath | Should -Be $script:sprintTarget
  }

  It 'preserves enabled state as well as disabled state' {
    $script:taskStore[1].Enabled = $true
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $result.Ok | Should -BeTrue
    $script:taskStore[0].Enabled | Should -BeFalse
    $script:taskStore[1].Enabled | Should -BeTrue
  }

  It 'recognizes an unquoted old file binding and retains surrounding arguments byte for byte' {
    $script:taskStore[0].Actions[0].Arguments = '-NoProfile -File C:\obsolete\LoginScript.ps1 -Flag "two words"'
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $result.Ok | Should -BeTrue
    $script:taskStore[0].Actions[0].Arguments | Should -Be "-NoProfile -File `"$script:sprintTarget`" -Flag `"two words`""
  }

  It 'copies real client-only CIM action instances independently' {
    foreach ($task in $script:taskStore) {
      $task.Actions = @($task.Actions | ForEach-Object {
          $action = $_
          $cim = [Microsoft.Management.Infrastructure.CimInstance]::new('MSFT_TaskExecAction', 'root/Microsoft/Windows/TaskScheduler')
          foreach ($property in @('Id', 'Execute', 'Arguments', 'WorkingDirectory')) {
            $cim.CimInstanceProperties.Add([Microsoft.Management.Infrastructure.CimProperty]::Create($property, [string]$action.$property, [Microsoft.Management.Infrastructure.CimType]::String, [Microsoft.Management.Infrastructure.CimFlags]::None))
          }
          $cim
        })
    }
    $beforeActions = @($script:taskStore[0].Actions)
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $result.Failures | Should -BeNullOrEmpty
    $result.Ok | Should -BeTrue
    $beforeActions[0].Arguments | Should -Match ([regex]::Escape($script:stableTarget))
    $script:taskStore[0].Actions[0].Arguments | Should -Match ([regex]::Escape($script:sprintTarget))
  }

  It 'plans WhatIf with zero writes and leaves task definitions intact' {
    $before = @($script:taskStore | ForEach-Object { exportTestTask $_ })
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot -WhatIf
    $result.Ok | Should -BeTrue
    $result.Planned | Should -BeTrue
    $result.Changed | Should -BeFalse
    $result.Tasks.Outcome | Should -Be @('Planned', 'Planned')
    @($script:taskStore | ForEach-Object { exportTestTask $_ }) | Should -Be $before
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'performs a matching read-only CheckOnly audit with zero writes' {
    $result = Set-SprintLoginScheduledTaskTarget -Boundary End -GitRoot $script:fixtureRoot -CheckOnly
    $result.Ok | Should -BeTrue
    $result.Tasks.Outcome | Should -Be @('Checked', 'Checked')
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'fails a stale CheckOnly audit without repairing either task' {
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot -CheckOnly
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'does not match'
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'rejects an explicitly empty override rather than falling back' {
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot -LoginScriptPath ''
    $result.Ok | Should -BeFalse
    $result.SelectionMode | Should -Be 'ExplicitDevelopmentOverride'
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'rejects relative wildcard missing directory and renamed override targets' -ForEach @(
    @{ Kind = 'Relative' }, @{ Kind = 'Wildcard' }, @{ Kind = 'Missing' }, @{ Kind = 'Directory' }, @{ Kind = 'Renamed' }
  ) {
    $path = switch ($Kind) {
      'Relative' { 'LoginScript.ps1' }
      'Wildcard' { Join-Path $script:fixtureRoot '*.ps1' }
      'Missing' { Join-Path $script:fixtureRoot 'absent/LoginScript.ps1' }
      'Directory' { $script:sprintRoot }
      'Renamed' { $otherFile = Join-Path $script:fixtureRoot 'Other.ps1'; Set-Content -LiteralPath $otherFile -Value '# inert'; $otherFile }
    }
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -LoginScriptPath $path
    $result.Ok | Should -BeFalse
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'fails Start with no roots without stable fallback' {
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -GitRoot $script:fixtureRoot
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'exactly one'
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'rejects a stable explicit root for Start' {
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:stableRoot
    $result.Ok | Should -BeFalse
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'rejects ambiguous Utilities sprint candidates' {
    $second = Join-Path $script:fixtureRoot 'ATAP.Utilities-wt-999-Sprint-0015-work-items'
    $null = newTestLoginFile $second
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -WorktreePaths @($script:sprintRoot, $second)
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'found 2'
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'rejects an explicit Utilities root from another invocation sprint' {
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot -WorktreePaths @(Join-Path $script:fixtureRoot 'Ace-wt-45-Sprint-0014-work-items')
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'sprint identity'
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'rejects a missing default login target before task access' {
    $emptyRoot = Join-Path $script:fixtureRoot 'ATAP.Utilities-wt-999-Sprint-0015-work-items'
    New-Item -ItemType Directory -Path $emptyRoot | Out-Null
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $emptyRoot
    $result.Ok | Should -BeFalse
    Should -Invoke Get-ScheduledTask -Times 0 -Exactly
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'preflights both tasks before writes when the second task is missing' {
    $script:taskStore = @($script:taskStore[0])
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'Unlock BitWarden.*found 0'
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'rejects duplicate task names in distinct folders' {
    $duplicate = newTestTask 'Unlock BitWarden' $script:stableTarget
    $duplicate.TaskPath = '\Other\'
    $script:taskStore += $duplicate
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'Unlock BitWarden.*found 2'
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'rejects unsupported malformed and ambiguous login actions' -ForEach @(
    @{ Kind = 'MalformedQuotes' }, @{ Kind = 'Command' }, @{ Kind = 'TwoFileFlags' },
    @{ Kind = 'TwoLoginActions' }, @{ Kind = 'OtherExecutable' }, @{ Kind = 'NoBinding' }, @{ Kind = 'ScriptExpression' }
  ) {
    switch ($Kind) {
      'MalformedQuotes' { $script:taskStore[1].Actions[0].Arguments = '-File "C:\missing\LoginScript.ps1' }
      'Command' { $script:taskStore[1].Actions[0].Arguments = '-Command "& C:\missing\LoginScript.ps1"' }
      'TwoFileFlags' { $script:taskStore[1].Actions[0].Arguments = '-File C:\one\LoginScript.ps1 -File C:\two\LoginScript.ps1' }
      'TwoLoginActions' { $script:taskStore[1].Actions += copyTestObject $script:taskStore[1].Actions[0] }
      'OtherExecutable' { $script:taskStore[1].Actions[0].Execute = 'cmd.exe' }
      'NoBinding' { $script:taskStore[1].Actions[0].Arguments = '-File C:\other\Other.ps1' }
      'ScriptExpression' { $script:taskStore[1].Actions[0].Arguments = '-File $(C:\missing\LoginScript.ps1)' }
    }
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $result.Ok | Should -BeFalse
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'rejects an End override under a removal root' {
    $result = Set-SprintLoginScheduledTaskTarget -Boundary End -LoginScriptPath $script:sprintTarget -WorktreePaths @($script:sprintRoot)
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'being removed'
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'uses directory boundaries rather than text-prefix containment' {
    $neighbor = newTestLoginFile ($script:sprintRoot + '-other')
    $result = Set-SprintLoginScheduledTaskTarget -Boundary End -LoginScriptPath $neighbor -WorktreePaths @($script:sprintRoot)
    $result.Ok | Should -BeTrue
  }

  It 'handles a drive-root removal boundary without truncating its separator' {
    $driveRoot = [IO.Path]::GetPathRoot($script:fixtureRoot)
    $result = Set-SprintLoginScheduledTaskTarget -Boundary End -GitRoot $script:fixtureRoot -WorktreePaths @($driveRoot)
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'being removed'
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'rejects an End override whose parent junction resolves into a removal root' {
    $alias = Join-Path $script:fixtureRoot 'outside-alias'
    New-Item -ItemType Junction -Path $alias -Target $script:sprintRoot -ErrorAction Stop | Out-Null
    $aliasedTarget = Join-Path $alias 'src/ATAP.Utilities.PowerShell/Profiles/LoginScript.ps1'
    $result = Set-SprintLoginScheduledTaskTarget -Boundary End -LoginScriptPath $aliasedTarget -WorktreePaths @($script:sprintRoot)
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'being removed'
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'resolves a removal-root alias before testing containment' {
    $alias = Join-Path $script:fixtureRoot 'removal-alias'
    New-Item -ItemType Junction -Path $alias -Target $script:sprintRoot -ErrorAction Stop | Out-Null
    $result = Set-SprintLoginScheduledTaskTarget -Boundary End -LoginScriptPath $script:sprintTarget -WorktreePaths @($alias)
    $result.Ok | Should -BeFalse
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'audits stable tasks after prior teardown roots no longer exist' {
    $result = Set-SprintLoginScheduledTaskTarget -Boundary End -GitRoot $script:fixtureRoot -WorktreePaths @(Join-Path $script:fixtureRoot 'missing-root') -CheckOnly
    $result.Ok | Should -BeTrue
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'rejects a missing target below a stale removal root' {
    $missingRoot = Join-Path $script:fixtureRoot 'already-removed'
    $result = Set-SprintLoginScheduledTaskTarget -Boundary End -LoginScriptPath (Join-Path $missingRoot 'LoginScript.ps1') -WorktreePaths @($missingRoot) -CheckOnly
    $result.Ok | Should -BeFalse
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'retargets a literal ephemeral alias even when it currently resolves to stable' {
    $alias = Join-Path $script:fixtureRoot 'ephemeral-alias'
    New-Item -ItemType Junction -Path $alias -Target $script:stableRoot -ErrorAction Stop | Out-Null
    $binding = Join-Path $alias 'src/ATAP.Utilities.PowerShell/Profiles/LoginScript.ps1'
    foreach ($task in $script:taskStore) { $task.Actions[0].Arguments = "-File `"$binding`"" }
    $result = Set-SprintLoginScheduledTaskTarget -Boundary End -GitRoot $script:fixtureRoot -WorktreePaths @($script:sprintRoot)
    $result.Ok | Should -BeTrue
    $result.Changed | Should -BeTrue
    $result.Tasks.BeforeBinding | Should -Be @($binding, $binding)
    $result.Tasks.AfterBinding | Should -Be @($script:stableTarget, $script:stableTarget)
  }

  It 'accepts CloudFiles metadata reparsepoints without treating them as links' {
    Mock Get-Item {
      $item = & $script:realGetItem -LiteralPath $LiteralPath -Force -ErrorAction Stop
      if ($item.FullName -eq $script:sprintRoot) {
        $cloudItem = [PSCustomObject]@{ FullName = $item.FullName; PSIsContainer = $true; LinkType = $null; Attributes = [IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint }
        $cloudItem | Add-Member -MemberType ScriptMethod -Name ResolveLinkTarget -Value { throw 'CloudFiles metadata is not a link.' }
        return $cloudItem
      }
      $item
    }
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $result.Failures | Should -BeNullOrEmpty
    $result.Ok | Should -BeTrue
  }

  It 'restores every attempted task in reverse order after first or second write failures' -ForEach @(
    @{ FailAt = 1; Partial = $false }, @{ FailAt = 1; Partial = $true },
    @{ FailAt = 2; Partial = $false }, @{ FailAt = 2; Partial = $true }
  ) {
    $before = @($script:taskStore | ForEach-Object { exportTestTask $_ })
    $script:failWrite = $FailAt
    $script:partialFailure = $Partial
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $result.Ok | Should -BeFalse
    $result.Rollback.Attempted | Should -BeTrue
    $result.Rollback.Succeeded | Should -BeTrue
    $result.Rollback.Failures | Should -BeNullOrEmpty
    $result.Changed | Should -BeFalse
    @($script:taskStore | ForEach-Object { exportTestTask $_ }) | Should -Be $before
    if ($FailAt -eq 1) { @($script:writeNames) | Should -Be @('ATAPLoginScript', 'ATAPLoginScript') }
    else { @($script:writeNames) | Should -Be @('ATAPLoginScript', 'Unlock BitWarden', 'Unlock BitWarden', 'ATAPLoginScript') }
  }

  It 'reports rollback write and verification failures distinctly' {
    $script:failWrite = 2
    $script:partialFailure = $true
    $script:failRollback = $true
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $result.Ok | Should -BeFalse
    $result.Rollback.Attempted | Should -BeTrue
    $result.Rollback.Succeeded | Should -BeFalse
    $result.Changed | Should -BeTrue
    $result.Rollback.Failures.Count | Should -Be 4
    $result.Rollback.Failures -join ' ' | Should -Match 'Restore.*Verify'
  }

  It 'rolls back both attempts when a successful write silently fails its readback' {
    $script:dropWrite = 2
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $result.Ok | Should -BeFalse
    $result.Rollback.Attempted | Should -BeTrue
    $result.Rollback.Succeeded | Should -BeTrue
    @($script:writeNames) | Should -Be @('ATAPLoginScript', 'Unlock BitWarden', 'Unlock BitWarden', 'ATAPLoginScript')
    $result.Tasks.AfterBinding | Should -Be @($script:stableTarget, $script:stableTarget)
  }

  It 'rolls back both attempts when final definition export fails' {
    $script:failExportAt = 9
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'readback failure'
    $result.Rollback.Succeeded | Should -BeTrue
    $result.Tasks.AfterBinding | Should -Be @($script:stableTarget, $script:stableTarget)
  }

  It 'still compensates attempted writes when error logging fails' {
    $script:failWrite = 2
    $script:partialFailure = $true
    Mock Write-PSFMessage { if ($Level -eq 'Error') { throw 'injected logging failure' } }
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'Failure logging'
    $result.Rollback.Succeeded | Should -BeTrue
    $result.Tasks.AfterBinding | Should -Be @($script:stableTarget, $script:stableTarget)
  }

  It 'detects changed preserved metadata during readback and reports incomplete rollback' {
    $script:corruptAfterWrite = $true
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $result.Ok | Should -BeFalse
    $result.Rollback.Attempted | Should -BeTrue
    $result.Rollback.Succeeded | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'outside the approved binding'
    $result.Rollback.Failures -join ' ' | Should -Match 'Snapshot readback differs'
  }

  It 'detects concurrency before the first write without overwriting another actor' {
    $script:concurrentInventory = 3
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $result.Ok | Should -BeFalse
    $result.Rollback.Attempted | Should -BeFalse
    $script:taskStore[1].Description | Should -Be 'concurrent actor'
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'rejects a target whose content changes after selection before either write' {
    $script:changeTargetInventory = 1
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'target changed after preflight'
    Should -Invoke Set-ScheduledTask -Times 0 -Exactly
  }

  It 'restores its attempted first write when the second task changes concurrently' {
    $script:concurrentInventory = 4
    $result = Set-SprintLoginScheduledTaskTarget -Boundary Start -ATAPUtilitiesRoot $script:sprintRoot
    $result.Ok | Should -BeFalse
    $result.Rollback.Attempted | Should -BeTrue
    $result.Rollback.Succeeded | Should -BeFalse
    @($script:writeNames) | Should -Be @('ATAPLoginScript', 'ATAPLoginScript')
    $script:taskStore[1].Description | Should -Be 'concurrent actor'
  }
}
