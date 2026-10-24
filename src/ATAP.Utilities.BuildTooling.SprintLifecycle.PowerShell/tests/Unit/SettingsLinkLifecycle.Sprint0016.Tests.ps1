BeforeAll {
  $script:moduleRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  $script:repoRoot = [IO.Path]::GetFullPath((Join-Path $script:moduleRoot '../..'))
  $script:evidenceRoot = Join-Path $script:repoRoot "_generated/Sprint0016/Task16.11/fixtures-$([guid]::NewGuid().ToString('N'))"
  New-Item -ItemType Directory -Path $script:evidenceRoot -Force | Out-Null
  $script:originalAppData = $env:APPDATA
  . (Join-Path $script:moduleRoot 'private/Set-UserSettingsSymlink.ps1')
}
AfterAll { $env:APPDATA = $script:originalAppData }

Describe 'Settings link transaction Task16.11' {
  BeforeEach {
    $script:fixture = Join-Path $script:evidenceRoot ([guid]::NewGuid().ToString('N'))
    $script:stable = Join-Path $script:fixture 'SharedVSCode'
    $script:sprint = Join-Path $script:fixture 'SharedVSCode-wt-68-Sprint-0016-work-items'
    $env:APPDATA = Join-Path $script:fixture 'AppData'
    $script:link = Join-Path $env:APPDATA 'Code/User/settings.json'
    New-Item -ItemType Directory -Path $script:stable, $script:sprint, (Split-Path $script:link) -Force | Out-Null
    Set-Content (Join-Path $script:stable 'UserSettings.jsonc') '{"stable":true}'
    Set-Content (Join-Path $script:sprint 'UserSettings.jsonc') '{"sprint":true}'
  }
  It 'selects actual Start root then stable End destination and is idempotent' {
    $start = Set-UserSettingsSymlink $script:sprint -Confirm:$false
    $start.Ok | Should -BeTrue
    $start.Changed | Should -BeTrue
    $start.After.ResolvedTarget | Should -Be (Join-Path $script:sprint 'UserSettings.jsonc')
    $firstTime = (Get-Item -LiteralPath $script:link -Force).CreationTimeUtc
    $again = Set-UserSettingsSymlink $script:sprint -Confirm:$false
    $again.Ok | Should -BeTrue
    $again.Changed | Should -BeFalse
    (Get-Item -LiteralPath $script:link -Force).CreationTimeUtc | Should -Be $firstTime
    $end = Set-UserSettingsSymlink $script:stable -WorktreePaths $script:sprint -Confirm:$false
    $end.Ok | Should -BeTrue
    (Set-UserSettingsSymlink $script:stable -CheckOnly -WorktreePaths $script:sprint).Ok | Should -BeTrue
  }
  It 'recovers a dangling link while retaining raw prior metadata' {
    $missing = Join-Path $script:fixture 'absent/UserSettings.jsonc'
    New-Item -ItemType SymbolicLink -Path $script:link -Target $missing | Out-Null
    $result = Set-UserSettingsSymlink $script:stable -Confirm:$false
    $result.Ok | Should -BeTrue
    $result.Before.Target | Should -Contain $missing
    $result.Before.LinkType | Should -Be 'SymbolicLink'
  }
  It 'rejects a readable wrong link in audit and repairs it on apply' {
    New-Item -ItemType SymbolicLink -Path $script:link -Target (Join-Path $script:sprint 'UserSettings.jsonc') | Out-Null
    (Set-UserSettingsSymlink $script:stable -CheckOnly).Ok | Should -BeFalse
    (Set-UserSettingsSymlink $script:stable -Confirm:$false).Ok | Should -BeTrue
  }
  It 'accepts a relative link only when it resolves to the exact readable destination' {
    $relative = [IO.Path]::GetRelativePath((Split-Path $script:link), (Join-Path $script:stable 'UserSettings.jsonc'))
    New-Item -ItemType SymbolicLink -Path $script:link -Target $relative | Out-Null
    $result = Set-UserSettingsSymlink $script:stable -Confirm:$false
    $result.Ok | Should -BeTrue
    $result.Changed | Should -BeFalse
    $result.After.Target | Should -Be $relative
  }
  It 'fails closed for a missing destination and preserves the previous regular file' {
    Set-Content $script:link 'original regular settings'
    $hash = (Get-FileHash $script:link).Hash
    { Set-UserSettingsSymlink (Join-Path $script:fixture 'absent') -Confirm:$false } | Should -Throw
    (Get-FileHash $script:link).Hash | Should -Be $hash
    (Get-Item $script:link).LinkType | Should -BeNullOrEmpty
  }
  It 'rejects a directory as destination before mutating the prior entry' {
    Set-Content $script:link 'original'
    New-Item -ItemType Directory -Path (Join-Path $script:fixture 'bad/UserSettings.jsonc') -Force | Out-Null
    { Set-UserSettingsSymlink (Join-Path $script:fixture 'bad') -Confirm:$false } | Should -Throw
    Get-Content $script:link -Raw | Should -Match 'original'
  }
  It 'refuses an expected target underneath a removal root' {
    (Set-UserSettingsSymlink $script:sprint -CheckOnly -WorktreePaths $script:sprint).Ok | Should -BeFalse
    { Set-UserSettingsSymlink $script:sprint -WorktreePaths $script:sprint -Confirm:$false } | Should -Throw '*removed*'
    Get-Item -LiteralPath $script:link -Force -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
  }
  It 'does not confuse a sibling sharing the removal prefix with a removal child' {
    (Set-UserSettingsSymlink $script:stable -WorktreePaths ($script:stable + '-other') -Confirm:$false).Ok | Should -BeTrue
  }
  It 'WhatIf preserves the existing entry and creates no recovery path' {
    Set-Content $script:link 'original'
    $result = Set-UserSettingsSymlink $script:sprint -WhatIf
    $result.Planned | Should -BeTrue
    $result.Ok | Should -BeFalse
    Get-Content $script:link -Raw | Should -Match 'original'
    Get-ChildItem (Split-Path $script:link) -Filter '*.recovery-*' | Should -BeNullOrEmpty
  }
  It 'WhatIf does not create an absent settings directory' {
    $env:APPDATA = Join-Path $script:fixture 'no-AppData'
    (Set-UserSettingsSymlink $script:sprint -WhatIf).Planned | Should -BeTrue
    Test-Path $env:APPDATA | Should -BeFalse
  }
  It 'restores exact regular content and metadata after injected access denial' {
    [IO.File]::WriteAllBytes($script:link, [byte[]](0, 1, 255, 13, 10))
    $before = Get-Item $script:link
    $hash = (Get-FileHash $script:link).Hash
    Mock New-Item { throw [UnauthorizedAccessException]::new('Injected access denial') } -ParameterFilter { $ItemType -eq 'SymbolicLink' }
    $caught = $null
    try { Set-UserSettingsSymlink $script:sprint -Confirm:$false } catch { $caught = $_ }
    $caught | Should -Not -BeNullOrEmpty
    $caught.Exception.Data['SettingsLinkResult'].Rollback.Succeeded | Should -BeTrue
    (Get-FileHash $script:link).Hash | Should -Be $hash
    (Get-Item $script:link).CreationTimeUtc | Should -Be $before.CreationTimeUtc
    (Get-Item $script:link).LastWriteTimeUtc | Should -Be $before.LastWriteTimeUtc
    (Get-Item $script:link).LinkType | Should -BeNullOrEmpty
  }
  It 'restores a dangling prior link after creation fails' {
    $missing = Join-Path $script:fixture 'missing.jsonc'
    New-Item -ItemType SymbolicLink -Path $script:link -Target $missing | Out-Null
    Mock New-Item { throw 'Injected create failure' } -ParameterFilter { $ItemType -eq 'SymbolicLink' }
    { Set-UserSettingsSymlink $script:stable -Confirm:$false } | Should -Throw '*Rollback succeeded: True*'
    (Get-Item -LiteralPath $script:link -Force).Target | Should -Be $missing
  }
  It 'restores the previous link on incorrect post-create readback' {
    $old = Join-Path $script:stable 'UserSettings.jsonc'
    New-Item -ItemType SymbolicLink -Path $script:link -Target $old | Out-Null
    Mock New-Item { [IO.File]::CreateSymbolicLink($Path, $old) } -ParameterFilter { $ItemType -eq 'SymbolicLink' }
    { Set-UserSettingsSymlink $script:sprint -Confirm:$false } | Should -Throw '*target mismatch*'
    (Get-Item -LiteralPath $script:link -Force).Target | Should -Be $old
  }
  It 'rolls back a creation that writes the link before throwing' {
    Set-Content $script:link 'original settings'
    Mock New-Item {
      [void][IO.File]::CreateSymbolicLink($Path, $Target)
      throw 'Injected error after link creation'
    } -ParameterFilter { $ItemType -eq 'SymbolicLink' }
    { Set-UserSettingsSymlink $script:sprint -Confirm:$false } | Should -Throw '*Rollback succeeded: True*'
    Get-Content $script:link -Raw | Should -Match 'original settings'
    (Get-Item $script:link).LinkType | Should -BeNullOrEmpty
  }
  It 'restores the old settings when the new destination becomes unreadable during readback' {
    Set-Content $script:link 'original settings'
    $script:readbackLock = $null
    Mock New-Item {
      [void][IO.File]::CreateSymbolicLink($Path, $Target)
      $script:readbackLock = [IO.File]::Open($Target, 'Open', 'ReadWrite', 'None')
    } -ParameterFilter { $ItemType -eq 'SymbolicLink' }
    try {
      { Set-UserSettingsSymlink $script:sprint -Confirm:$false } | Should -Throw '*Rollback succeeded: True*'
      Get-Content $script:link -Raw | Should -Match 'original settings'
    } finally { if ($script:readbackLock) { $script:readbackLock.Dispose() } }
  }
  It 'reports partial recovery and retains the original when rollback is denied' {
    Set-Content $script:link 'recover me'
    Mock New-Item { throw 'Injected create failure' } -ParameterFilter { $ItemType -eq 'SymbolicLink' }
    Mock Move-Item { [IO.File]::Move($LiteralPath, $Destination) }
    Mock Move-Item { throw 'Injected rollback denial' } -ParameterFilter { $Destination -eq $script:link }
    $caught = $null
    try { Set-UserSettingsSymlink $script:sprint -Confirm:$false } catch { $caught = $_ }
    $result = $caught.Exception.Data['SettingsLinkResult']
    $result.Rollback.Attempted | Should -BeTrue
    $result.Rollback.Succeeded | Should -BeFalse
    $result.Rollback.Error | Should -Match 'rollback denial'
    Get-Content -LiteralPath $result.RecoveryPath -Raw | Should -Match 'recover me'
    $result.Before.Hash | Should -Not -BeNullOrEmpty
  }
  It 'a failed first creation leaves no settings entry' {
    Mock New-Item { throw 'Injected create failure' } -ParameterFilter { $ItemType -eq 'SymbolicLink' }
    { Set-UserSettingsSymlink $script:sprint -Confirm:$false } | Should -Throw
    Get-Item -LiteralPath $script:link -Force -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
  }
  It 'rejects a lexically stable settings source hiding a sprint symlink' {
    Remove-Item (Join-Path $script:stable 'UserSettings.jsonc')
    New-Item -ItemType SymbolicLink -Path (Join-Path $script:stable 'UserSettings.jsonc') -Target (Join-Path $script:sprint 'UserSettings.jsonc') | Out-Null
    (Set-UserSettingsSymlink $script:stable -CheckOnly -WorktreePaths $script:sprint).Ok | Should -BeFalse
  }
  It 'fails closed when the new source cannot be opened for reading' {
    Set-Content $script:link 'previous settings'
    $lock = [IO.File]::Open((Join-Path $script:sprint 'UserSettings.jsonc'), 'Open', 'ReadWrite', 'None')
    try {
      { Set-UserSettingsSymlink $script:sprint -Confirm:$false } | Should -Throw
      Get-Content $script:link -Raw | Should -Match 'previous settings'
    } finally { $lock.Dispose() }
  }
  It 'confirmation decline preserves the original settings entry' {
    if (-not ('SettingsDeclineHost' -as [type])) {
      Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Globalization;
using System.Management.Automation;
using System.Management.Automation.Host;
using System.Security;
public sealed class SettingsDeclineHost : PSHost {
  readonly Guid id = Guid.NewGuid();
  readonly SettingsDeclineUI ui = new SettingsDeclineUI();
  public override Guid InstanceId => id;
  public override string Name => "SettingsDeclineHost";
  public override Version Version => new Version(1,0);
  public override PSHostUserInterface UI => ui;
  public override CultureInfo CurrentCulture => CultureInfo.InvariantCulture;
  public override CultureInfo CurrentUICulture => CultureInfo.InvariantCulture;
  public override void SetShouldExit(int code) { }
  public override void EnterNestedPrompt() { throw new NotSupportedException(); }
  public override void ExitNestedPrompt() { }
  public override void NotifyBeginApplication() { }
  public override void NotifyEndApplication() { }
}
public sealed class SettingsDeclineUI : PSHostUserInterface {
  public override PSHostRawUserInterface RawUI => null;
  public override int PromptForChoice(string caption, string message, Collection<ChoiceDescription> choices, int defaultChoice) {
    for (int i=0; i<choices.Count; i++) if (choices[i].Label.Replace("&", "") == "No") return i;
    throw new InvalidOperationException("No decline choice provided");
  }
  public override Dictionary<string, PSObject> Prompt(string c, string m, Collection<FieldDescription> d) { throw new NotSupportedException(); }
  public override PSCredential PromptForCredential(string c,string m,string u,string t) { throw new NotSupportedException(); }
  public override PSCredential PromptForCredential(string c,string m,string u,string t,PSCredentialTypes a,PSCredentialUIOptions o) { throw new NotSupportedException(); }
  public override string ReadLine() { throw new NotSupportedException(); }
  public override SecureString ReadLineAsSecureString() { throw new NotSupportedException(); }
  public override void Write(string s) { }
  public override void Write(ConsoleColor f, ConsoleColor b, string s) { }
  public override void WriteLine(string s) { }
  public override void WriteDebugLine(string s) { }
  public override void WriteErrorLine(string s) { }
  public override void WriteVerboseLine(string s) { }
  public override void WriteWarningLine(string s) { }
  public override void WriteProgress(long id, ProgressRecord record) { }
}
"@
    }
    Set-Content $script:link 'operator declined'
    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace([SettingsDeclineHost]::new())
    $shell = [powershell]::Create()
    try {
      $runspace.Open()
      $shell.Runspace = $runspace
      [void]$shell.AddScript('param($helper) function Write-PSFMessage { param([Parameter(ValueFromRemainingArguments=$true)]$Rest) }; . $helper').AddArgument((Join-Path $script:moduleRoot 'private/Set-UserSettingsSymlink.ps1'))
      [void]$shell.Invoke()
      $shell.Commands.Clear()
      [void]$shell.AddCommand('Set-UserSettingsSymlink').AddParameter('SharedVSCodeWorktreePath', $script:sprint).AddParameter('Confirm', $true)
      $result = $shell.Invoke()
      @($shell.Streams.Error | ForEach-Object { $_.ToString() }) | Should -BeNullOrEmpty
      $result[0].Planned | Should -BeTrue
      Get-Content $script:link -Raw | Should -Match 'operator declined'
      Get-ChildItem (Split-Path $script:link) -Filter '*.recovery-*' | Should -BeNullOrEmpty
    } finally { $shell.Dispose(); $runspace.Dispose() }
  }
  It 'facade and child helper implementations are byte-identical' {
    $facade = Join-Path $script:moduleRoot '../ATAP.Utilities.BuildTooling.PowerShell/private/Set-UserSettingsSymlink.ps1'
    (Get-FileHash $facade).Hash | Should -Be (Get-FileHash (Join-Path $script:moduleRoot 'private/Set-UserSettingsSymlink.ps1')).Hash
  }
}





Describe 'Settings lifecycle entrypoint integration Task16.11' {
  BeforeAll {
    foreach ($publicFunction in Get-ChildItem (Join-Path $script:moduleRoot 'public') -Filter '*.ps1' -File) { . $publicFunction.FullName }
    function Set-SprintLoginScheduledTaskTarget {
      [CmdletBinding(SupportsShouldProcess)]
      param([string]$Boundary, [string]$GitRoot, [string[]]$WorktreePaths, [switch]$CheckOnly)
      throw 'Unmocked login maintenance is forbidden in settings fixtures.'
    }
    # Exercise the production Stage2 settings block without unrelated startup effects.
    $tokens = $null; $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $script:moduleRoot 'public/New-SprintStage2.ps1'), [ref]$tokens, [ref]$parseErrors)
    $settingsTry = @($ast.FindAll({ param($node)
      $node -is [Management.Automation.Language.TryStatementAst] -and
      $node.Body.Extent.Text -match '\$settingsResult = Set-UserSettingsSymlink'
    }, $true))
    if ($settingsTry.Count -ne 1) { throw 'Expected one Stage2 settings transaction block.' }
    $prefix = '[CmdletBinding(SupportsShouldProcess)] param([string]$svWorktreePath) $fn="Fixture"; $mn="Fixture"; $userSettingsLinked=$false; $userSettingsError=$null; '
    Set-Item Function:Invoke-Stage2SettingsBlock -Value ([scriptblock]::Create($prefix + $settingsTry[0].Extent.Text + '; [PSCustomObject]@{ Linked=$userSettingsLinked; Error=$userSettingsError }'))
  }
  BeforeEach {
    $script:fixture = Join-Path $script:evidenceRoot ([guid]::NewGuid().ToString('N'))
    $script:stable = Join-Path $script:fixture 'SharedVSCode'
    $script:sprint = Join-Path $script:fixture 'SharedVSCode-wt-68-Sprint-0016-work-items'
    $script:planning = Join-Path $script:fixture '_Planning-wt-40-Sprint-0016-work-items'
    $env:APPDATA = Join-Path $script:fixture 'AppData'
    $script:link = Join-Path $env:APPDATA 'Code/User/settings.json'
    New-Item -ItemType Directory -Path $script:stable, $script:sprint, (Join-Path $script:planning 'SprintRetrospective'), (Split-Path $script:link) -Force | Out-Null
    Set-Content (Join-Path $script:stable 'UserSettings.jsonc') '{"stable":true}'
    Set-Content (Join-Path $script:sprint 'UserSettings.jsonc') '{"sprint":true}'
    Set-Content (Join-Path $script:planning 'SprintRetrospective/Notebook-SprintWorkSession-0016-End.md') '# End'
    Mock Invoke-SprintAIAdapterLifecycle { [PSCustomObject]@{ DriftClean = $true } }
    Mock Sync-SprintBoundaryPrimaryRoleMarker { [PSCustomObject]@{ Action = 'Unchanged' } }
    Mock Get-SprintEndContext { [PSCustomObject]@{ Ok = $true; ClosedSprintNumber = '0016'; NextSprintNumber = '0017' } }
    Mock Test-SprintEndWriteTarget { [PSCustomObject]@{ Ok = $true; BlockedPaths = @() } }
    Mock Get-SprintEndApprovalPlan { [PSCustomObject]@{ Ok = $true; Concerns = @(); RequiredPrompts = @() } }
    Mock Test-SprintEndCommandSurface { [PSCustomObject]@{ Ok = $true } }
    Mock Test-SprintPrerequisites { [PSCustomObject]@{ AllOk = $true } }
    Mock Test-SprintEndWorktreeState { [PSCustomObject]@{ Ok = $true } }
    Mock Test-SprintCheckpointCoverage { [PSCustomObject]@{ Ok = $true } }
    Mock Set-SprintLoginScheduledTaskTarget { [PSCustomObject]@{ Ok = $true } }
    Mock Invoke-SprintEndInfrastructureCleanup { [PSCustomObject]@{ Ok = $true } }
    Mock New-SprintEndHandoff { [PSCustomObject]@{ Ok = $true } }
    Mock Invoke-SprintEndGitHubClose { [PSCustomObject]@{ Ok = $true } }
    Mock Test-SprintEndBoundaryState { [PSCustomObject]@{ Ok = $true } }
    $script:boundaryParameters = @{
      GitRoot = $script:fixture; SharedVSCodeWorktreePath = $script:sprint
      SkipProfileSymlinks = $true; SkipLoginScheduledTasks = $true; SkipServiceAccountGitTrust = $true
      SkipAIAdapterLifecycle = $true; Confirm = $false
    }
    $script:endParameters = @{
      GitRoot = $script:fixture; PlanningRoot = $script:planning; SharedVSCodeWorktreePath = $script:sprint
      WorktreePaths = @($script:sprint); VerifyCheckpoints = $true; Confirm = $false
    }
  }
  It 'Stage2 links the actual invocation Shared root and reports verified success' {
    $result = Invoke-Stage2SettingsBlock -svWorktreePath $script:sprint -Confirm:$false
    $result.Linked | Should -BeTrue
    $result.Error | Should -BeNullOrEmpty
    (Get-Item -LiteralPath $script:link -Force).Target | Should -Be (Join-Path $script:sprint 'UserSettings.jsonc')
  }
  It 'Stage2 reports a failed settings transaction instead of claiming linked' {
    Mock Set-UserSettingsSymlink { throw 'Injected settings failure' }
    $result = Invoke-Stage2SettingsBlock -svWorktreePath $script:sprint -Confirm:$false
    $result.Linked | Should -BeFalse
    $result.Error | Should -Match 'Injected settings failure'
  }
  It 'Stage2 refuses a helper that returns without a verification result' {
    Mock Set-UserSettingsSymlink { }
    $result = Invoke-Stage2SettingsBlock -svWorktreePath $script:sprint -Confirm:$false
    $result.Linked | Should -BeFalse
    $result.Error | Should -Match 'did not verify'
  }
  It 'boundary Start selects actual Shared sprint settings' {
    $result = Set-SprintBoundaryContext @script:boundaryParameters -Boundary Start
    $result.Errors | Should -BeNullOrEmpty
    (Get-Item -LiteralPath $script:link -Force).Target | Should -Be (Join-Path $script:sprint 'UserSettings.jsonc')
  }
  It 'boundary End selects stable settings even when caller supplies the departing Shared root' {
    Set-UserSettingsSymlink $script:sprint -Confirm:$false | Out-Null
    $result = Set-SprintBoundaryContext @script:boundaryParameters -Boundary End
    $result.Errors | Should -BeNullOrEmpty
    (Get-Item -LiteralPath $script:link -Force).Target | Should -Be (Join-Path $script:stable 'UserSettings.jsonc')
  }
  It 'adapter failure remains reported while settings still recover to stable' {
    Set-UserSettingsSymlink $script:sprint -Confirm:$false | Out-Null
    Mock Invoke-SprintAIAdapterLifecycle { throw 'Injected adapter failure' }
    $result = Set-SprintBoundaryContext @script:boundaryParameters -Boundary End
    $result.Errors -join ';' | Should -Match 'Injected adapter failure'
    (Get-Item -LiteralPath $script:link -Force).Target | Should -Be (Join-Path $script:stable 'UserSettings.jsonc')
  }
  It 'End blocks every close effect if settings still points at the departing sprint without ApplyBoundary' {
    Set-UserSettingsSymlink $script:sprint -Confirm:$false | Out-Null
    $result = Invoke-SprintEndLifecycle @script:endParameters -CleanupInfrastructure -WriteHandoff -CreatePullRequests
    $result.Ok | Should -BeFalse
    $result.Failures | Should -Contain 'SettingsPreCleanup'
    Should -Invoke Invoke-SprintEndInfrastructureCleanup -Times 0
    Should -Invoke New-SprintEndHandoff -Times 0
    Should -Invoke Invoke-SprintEndGitHubClose -Times 0
  }
  It 'End independently blocks cleanup after ApplyBoundary when settings was skipped' {
    Set-UserSettingsSymlink $script:sprint -Confirm:$false | Out-Null
    Mock Set-SprintBoundaryContext { [PSCustomObject]@{ Errors = @() } }
    $result = Invoke-SprintEndLifecycle @script:endParameters -ApplyBoundary -SkipSharedVSCodeSettings -CleanupInfrastructure
    $result.Failures | Should -Contain 'SettingsPreCleanup'
    Should -Invoke Invoke-SprintEndInfrastructureCleanup -Times 0
  }
  It 'End allows cleanup-only after independent exact stable target verification' {
    Set-UserSettingsSymlink $script:stable -Confirm:$false | Out-Null
    $result = Invoke-SprintEndLifecycle @script:endParameters -CleanupInfrastructure
    $result.Ok | Should -BeTrue
    $result.Phases.SettingsPreCleanup.Ok | Should -BeTrue
    Should -Invoke Invoke-SprintEndInfrastructureCleanup -Times 1
  }
  It 'End WhatIf audits current settings and refuses a dangling sprint dependency' {
    New-Item -ItemType SymbolicLink -Path $script:link -Target (Join-Path $script:sprint 'absent.jsonc') | Out-Null
    $result = Invoke-SprintEndLifecycle @script:endParameters -CleanupInfrastructure -WhatIf
    $result.Failures | Should -Contain 'SettingsPreCleanup'
    Should -Invoke Invoke-SprintEndInfrastructureCleanup -Times 0
  }
}
