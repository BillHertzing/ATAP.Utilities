BeforeAll {
  $moduleRoot = Join-Path $PSScriptRoot '../..'
  . (Join-Path $moduleRoot 'private/Resolve-SprintEndHostDisposition.ps1')
  foreach ($name in @('Test-SprintEndBoundaryState', 'Test-SprintInfrastructureHealth', 'Set-SprintBoundaryContext', 'Invoke-SprintEndInfrastructureCleanup', 'Invoke-SprintEndLifecycle', 'New-SprintEndHandoff')) {
    . (Join-Path $moduleRoot "public/$name.ps1")
  }
  $repoRoot = [IO.Path]::GetFullPath((Join-Path $moduleRoot '../..'))
  $script:fixtureRoot = Join-Path $repoRoot '_generated/Sprint0015/SprintEnd-HostPolicy-20261014/integration-fixtures'
  New-Item -ItemType Directory -Path $script:fixtureRoot -Force | Out-Null
  function Write-PSFMessage { [CmdletBinding()] param($FunctionName, $ModuleName, $Level, $Message, $Tag) }
  function Set-SprintLoginScheduledTaskTarget {
    [CmdletBinding(SupportsShouldProcess)]
    param($Boundary, $GitRoot, $WorktreePaths, $LoginScriptPath, [switch]$CheckOnly, $HostDisposition)
    throw 'Unmocked task helper.'
  }
  function Set-SprintBoundaryUserProfiles { [CmdletBinding(SupportsShouldProcess)] param($ATAPUtilitiesRoot, $ATAPIACRoot, $GitRoot) throw 'Unmocked profiles.' }
  function Invoke-SprintEndServiceAccountFreshShell { param() throw 'Unmocked account shell.' }
  # Isolate the boundary's settings-link audit from the host settings entry (as Test-SprintEndBoundaryState.Tests.ps1 does);
  # without it the real CheckOnly audit runs against the live host and the boundary Ok depends on machine state.
  function Set-UserSettingsSymlink {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$SharedVSCodeWorktreePath, [switch]$CheckOnly, [string[]]$WorktreePaths)
    [PSCustomObject]@{ Ok = $true; Planned = $false; Changed = $false }
  }
  function Get-SecretATAP { [CmdletBinding()] param($SecretName, $SecretField, $SecretStoreType) throw 'Unmocked secret retrieval.' }
  function git { param([Parameter(ValueFromRemainingArguments)]$Arguments) throw 'Unmocked Git.' }
  function Get-RepositoryRoot { [CmdletBinding()] param([switch]$Absolute) $script:fixtureRoot }
  function Remove-SprintDatabases { [CmdletBinding(SupportsShouldProcess)] param($InstanceNames, $Databases, [switch]$Force) throw 'Unmocked database removal.' }
  function Get-DbaDatabase { [CmdletBinding()] param($SqlInstance, $Database, [switch]$EnableException) throw 'Unmocked SQL read.' }
  function Clear-BuildMasterSprintVariables { [CmdletBinding(SupportsShouldProcess)] param() throw 'Unmocked BuildMaster write.' }
  function Remove-SprintWorktreeSafely { [CmdletBinding(SupportsShouldProcess)] param($RepositoryPath, $WorktreePath, $MaxAttempts, $RetryDelayMilliseconds, [switch]$ThrowOnFailure) throw 'Unmocked worktree removal.' }
  function Test-SprintEndPullOverlap { param($RepoPath, [switch]$Fetch, [switch]$ThrowOnOverlap) throw 'Unmocked pull overlap.' }
  function New-TestDisposition {
    @{ SchemaVersion = 1; DispositionId = 'Sprint0015-UTAT01-personal-vault'; HostName = 'UTAT01'; Identity = 'UTAT01\whertzing'; LoginTaskMode = 'ExpectedAbsent'; PersonalVaultSessionScopes = @('Process', 'User') }
  }
  function Invoke-TestBoundary {
    param([hashtable]$Extra = @{})
    Test-SprintEndBoundaryState -GitRoot $script:fixtureRoot -SearchRoots @() -ProfilePaths @() @Extra
  }
  function Invoke-TestHealth {
    param([hashtable]$Extra = @{})
    Test-SprintInfrastructureHealth -BuildMasterAdminApiKeySecretName 'fixture.secret' -BuildMasterBaseUrl '' -ProGetBaseUrl '' -SqlInstancePaths @() @Extra
  }
}

Describe 'SprintEnd scoped personal-vault metadata in actual checkers' {
  BeforeEach {
    $script:policy = New-TestDisposition
    $script:presentKeys = @('User:BW_SESSION', 'Process:BW_SESSION')
    Mock Get-SprintEndHostContext { [PSCustomObject]@{ HostName='UTAT01'; Identity='UTAT01\whertzing'; IsElevated=$true } }
    Mock Test-SprintEndEnvironmentVariablePresent { "$($Scope):$Name" -in $script:presentKeys }
    Mock Write-PSFMessage {}
    Mock Set-SprintLoginScheduledTaskTarget { [PSCustomObject]@{ Ok=$true; Failures=@(); Tasks=@() } }
    Mock Get-SecretATAP { 'inert-fixture-key' }
    Mock Test-InfraUrlReachable { [PSCustomObject]@{ Ok=$true; Detail='Mocked'; Skipped=$true } }
    # Pester 6 throws for a call no -ParameterFilter matches; pass the helper-presence probes
    # through to the real cmdlet so only flyway/nbgv are intercepted. The cmdlet object is
    # captured before mocking and called with explicit parameters: a module-qualified call or a
    # PSBoundParameters splat inside the mock body hangs under Pester 6.
    $realGetCommand = Get-Command -Name Get-Command -CommandType Cmdlet
    Mock Get-Command {
      if ($CommandType) { & $realGetCommand -Name $Name -CommandType $CommandType -ErrorAction SilentlyContinue }
      else { & $realGetCommand -Name $Name -ErrorAction SilentlyContinue }
    }
    Mock Get-Command { throw 'Inert absent optional executable.' } -ParameterFilter { $Name -in @('flyway', 'nbgv') }
    Mock git { $global:LASTEXITCODE=0; '*' }
    Mock Invoke-RestMethod { throw 'No real network calls allowed.' }
  }

  It 'keeps User and Process personal-vault observations visible while boundary succeeds' {
    $result = Invoke-TestBoundary @{ HostDisposition=$script:policy }
    $result.Ok | Should -BeTrue
    $result.SecretEnvironmentVariables | Should -BeNullOrEmpty
    $result.AllowedPersonalVaultEnvironmentVariables.Count | Should -Be 2
    $result.AllowedPersonalVaultEnvironmentVariables.Scope | Should -Be @('Process', 'User')
    $result.AllowedPersonalVaultEnvironmentVariables.Name | Should -Be @('BW_SESSION', 'BW_SESSION')
    $result.AllowedPersonalVaultEnvironmentVariables[0].PSObject.Properties.Name | Should -Be @('Name', 'Scope', 'Present', 'DispositionId')
    Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 1 -Exactly -ParameterFilter {
      $HostDisposition.Identity -eq 'UTAT01\whertzing' -and $HostDisposition.PersonalVaultSessionScopes -join ',' -eq 'User,Process'
    }
    Should -Invoke Get-SecretATAP -Times 0 -Exactly
  }

  It 'keeps User and Process personal-vault observations visible in infrastructure health' {
    $result = Invoke-TestHealth @{ HostDisposition=$script:policy }
    $result.Checks.SecretEnvironmentVariables.Ok | Should -BeTrue
    $result.Checks.SecretEnvironmentVariables.Present | Should -BeNullOrEmpty
    $result.Checks.SecretEnvironmentVariables.AllowedPersonalVaultEnvironmentVariables.Count | Should -Be 2
    $result.Checks.SecretEnvironmentVariables.AllowedPersonalVaultEnvironmentVariables[0].PSObject.Properties.Name | Should -Be @('Name', 'Scope', 'Present', 'DispositionId')
    Should -Invoke Get-SecretATAP -Times 1 -Exactly -ParameterFilter { $SecretStoreType -eq 'BitwardenSecretsManager' }
    Should -Invoke Invoke-RestMethod -Times 0 -Exactly
  }

  It 'still fails both checkers for prohibited <Scope> <Name>' -ForEach @(
    @{ Name='BW_SESSION'; Scope='Machine' },
    @{ Name='BUILDMASTER_ADMIN_API_KEY'; Scope='User' },
    @{ Name='BUILDMASTER_GH_WEBHOOK_SECRET'; Scope='Process' },
    @{ Name='PROGET_ADMIN_API_KEY'; Scope='Machine' },
    @{ Name='PROGET_BUILDMASTER_API_KEY'; Scope='User' },
    @{ Name='BWS_ACCESS_TOKEN'; Scope='Process' }
  ) {
    $script:presentKeys += "$($Scope):$Name"
    $boundary = Invoke-TestBoundary @{ HostDisposition=$script:policy }
    $health = Invoke-TestHealth @{ HostDisposition=$script:policy }
    $boundary.Ok | Should -BeFalse
    $boundary.Failures | Should -Contain 'SecretEnvironmentVariables'
    $boundary.SecretEnvironmentVariables.Count | Should -Be 1
    $boundary.SecretEnvironmentVariables[0].Name | Should -Be $Name
    $boundary.SecretEnvironmentVariables[0].Scope | Should -Be $Scope
    $health.Checks.SecretEnvironmentVariables.Ok | Should -BeFalse
    $health.Checks.SecretEnvironmentVariables.Present.Count | Should -Be 1
    $health.Checks.SecretEnvironmentVariables.Present[0].Scope | Should -Be $Scope
  }

  It 'keeps no-policy calls strict for both personal-vault observations' {
    $boundary = Invoke-TestBoundary
    $health = Invoke-TestHealth
    $boundary.SecretEnvironmentVariables.Count | Should -Be 2
    $boundary.AllowedPersonalVaultEnvironmentVariables | Should -BeNullOrEmpty
    $boundary.Failures | Should -Contain 'SecretEnvironmentVariables'
    $health.Checks.SecretEnvironmentVariables.Present.Count | Should -Be 2
    $health.Checks.SecretEnvironmentVariables.AllowedPersonalVaultEnvironmentVariables | Should -BeNullOrEmpty
    Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 1 -Exactly -ParameterFilter { -not $PSBoundParameters.ContainsKey('HostDisposition') }
    Should -Invoke Get-SprintEndHostContext -Times 0 -Exactly
  }
}

Describe 'SprintEnd cleanup validates and forwards policy before effects' {
  BeforeEach {
    $script:policy = New-TestDisposition
    $script:callOrder = [Collections.Generic.List[string]]::new()
    Mock Get-SprintEndHostContext { [PSCustomObject]@{ HostName='UTAT01'; Identity='UTAT01\whertzing'; IsElevated=$true } }
    Mock Write-PSFMessage {}
    Mock Set-SprintLoginScheduledTaskTarget { $script:callOrder.Add('Login'); @{ Ok=$true; Tasks=@(); Failures=@() } }
    Mock Test-SprintInfrastructureHealth { $script:callOrder.Add('Health'); @{ AllOk=$true; Failures=@() } }
    Mock Remove-SprintDatabases {
      $script:callOrder.Add('Database')
      @{ instanceName='QA'; database='fixture'; error=$null; instanceReady=$true; dryRun=$false; dropped=$true; skipped=$false }
    }
    Mock Get-DbaDatabase {}
    Mock Clear-BuildMasterSprintVariables { @{ errors=@() } }
    Mock Set-SprintBoundaryContext { @{ Errors=@() } }
  }

  It 'passes normalized metadata to login and health before database effects and final boundary reassertion' {
    $result = Invoke-SprintEndInfrastructureCleanup -GitRoot $script:fixtureRoot -HostDisposition $script:policy -BuildMasterAdminApiKeySecretName 'fixture.secret' -DatabaseCleanupTargets @(@{ InstanceName='QA'; Databases=@('fixture') }) -Apply -Confirm:$false
    $result.Ok | Should -BeTrue
    $result.Applied | Should -BeTrue
    @($script:callOrder) | Should -Be @('Login', 'Health', 'Database')
    foreach ($command in @('Set-SprintLoginScheduledTaskTarget', 'Test-SprintInfrastructureHealth', 'Set-SprintBoundaryContext')) {
      Should -Invoke $command -Times 1 -Exactly -ParameterFilter {
        $HostDisposition.DispositionId -eq 'Sprint0015-UTAT01-personal-vault' -and $HostDisposition.PersonalVaultSessionScopes -join ',' -eq 'User,Process'
      }
    }
  }

  It 'rejects null or mismatched policy before task, health or database access' -ForEach @(
    @{ Invalid=$null }, @{ Invalid=@{ SchemaVersion=1; DispositionId='wrong'; HostName='OTHER'; Identity='OTHER\whertzing'; LoginTaskMode='ExpectedAbsent'; PersonalVaultSessionScopes=@('User') } }
  ) {
    { Invoke-SprintEndInfrastructureCleanup -GitRoot $script:fixtureRoot -HostDisposition $Invalid -BuildMasterAdminApiKeySecretName 'fixture.secret' -Apply -Confirm:$false } | Should -Throw
    Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 0 -Exactly
    Should -Invoke Test-SprintInfrastructureHealth -Times 0 -Exactly
    Should -Invoke Remove-SprintDatabases -Times 0 -Exactly
  }

  It 'stops at a policy-qualified failed login audit before health or database effects' {
    Mock Set-SprintLoginScheduledTaskTarget { @{ Ok=$false; Tasks=@(); Failures=@('Task visibility unavailable') } }
    $result = Invoke-SprintEndInfrastructureCleanup -GitRoot $script:fixtureRoot -HostDisposition $script:policy -BuildMasterAdminApiKeySecretName 'fixture.secret' -Apply -Confirm:$false
    $result.Ok | Should -BeFalse
    $result.Failures | Should -Contain 'LoginScheduledTasks'
    $result.HostDisposition.Identity | Should -Be 'UTAT01\whertzing'
    Should -Invoke Test-SprintInfrastructureHealth -Times 0 -Exactly
    Should -Invoke Remove-SprintDatabases -Times 0 -Exactly
  }

  It 'stops at policy-qualified failed health before database effects' {
    Mock Test-SprintInfrastructureHealth { @{ AllOk=$false; Failures=@('SecretEnvironmentVariables') } }
    { Invoke-SprintEndInfrastructureCleanup -GitRoot $script:fixtureRoot -HostDisposition $script:policy -BuildMasterAdminApiKeySecretName 'fixture.secret' -Apply -Confirm:$false } | Should -Throw '*infrastructure health failed*'
    Should -Invoke Test-SprintInfrastructureHealth -Times 1 -Exactly -ParameterFilter { $HostDisposition.Identity -eq 'UTAT01\whertzing' }
    Should -Invoke Remove-SprintDatabases -Times 0 -Exactly
  }
}

Describe 'Generated SprintEnd handoff executes policy-qualified calls under effect stubs' {
  BeforeEach {
    $script:policy = New-TestDisposition
    Mock Get-SprintEndHostContext { [PSCustomObject]@{ HostName='UTAT01'; Identity='UTAT01\whertzing'; IsElevated=$true } }
    Mock Write-PSFMessage {}
    Mock Import-Module {}
    Mock git { $global:LASTEXITCODE=0 }
    Mock Remove-SprintWorktreeSafely { @{ Ok=$true } }
    Mock Test-SprintEndPullOverlap {}
    Mock Set-SprintBoundaryContext { @{ Errors=@() } }
    Mock Invoke-SprintEndInfrastructureCleanup { @{ Ok=$true; Applied=$true; Failures=@() } }
    Mock Test-SprintEndBoundaryState { @{ Ok=$true } }
    Mock Remove-Item {}
    # Generated block assigns only these Git editor process preferences. Retain them.
    $script:priorGitEditor = $env:GIT_EDITOR
    $script:priorGitMergeAutoEdit = $env:GIT_MERGE_AUTOEDIT
    $script:priorLocation = Get-Location
  }
  AfterEach {
    $env:GIT_EDITOR = $script:priorGitEditor
    $env:GIT_MERGE_AUTOEDIT = $script:priorGitMergeAutoEdit
    Set-Location -LiteralPath $script:priorLocation.Path
  }

  It 'parses and executes the complete generated block with explicit policy forwarded to all three calls' {
    $output = Join-Path $script:fixtureRoot ('handoff-' + [guid]::NewGuid().ToString('N') + '.md')
    $result = New-SprintEndHandoff -GitRoot $script:fixtureRoot -WorktreePaths @((Join-Path $script:fixtureRoot 'Ace-wt-45-Sprint-0015-work-items')) -SprintNumber 15 -HostDisposition $script:policy -OutputPath $output -Confirm:$false
    $result.HostDisposition.PersonalVaultSessionScopes | Should -Be @('User', 'Process')
    $content = Get-Content -LiteralPath $result.Path -Raw
    $code = [regex]::Match($content, '(?s)```powershell\r?\n(.*?)\r?\n```').Groups[1].Value
    $tokens=$null; $errors=$null
    $null = [Management.Automation.Language.Parser]::ParseInput($code, [ref]$tokens, [ref]$errors)
    @($errors).Count | Should -Be 0
    & ([scriptblock]::Create($code))
    foreach ($command in @('Set-SprintBoundaryContext', 'Invoke-SprintEndInfrastructureCleanup', 'Test-SprintEndBoundaryState')) {
      Should -Invoke $command -Times 1 -Exactly -ParameterFilter {
        $HostDisposition.DispositionId -eq 'Sprint0015-UTAT01-personal-vault' -and $HostDisposition.LoginTaskMode -eq 'ExpectedAbsent' -and $HostDisposition.PersonalVaultSessionScopes -join ',' -eq 'User,Process'
      }
    }
    Should -Invoke Remove-SprintWorktreeSafely -Times 1 -Exactly
    Should -Invoke Remove-Item -Times 1 -Exactly -ParameterFilter { $LiteralPath -eq $output }
  }

  It 'keeps the complete no-policy handoff execution strict without injecting a declaration' {
    $output = Join-Path $script:fixtureRoot ('strict-' + [guid]::NewGuid().ToString('N') + '.md')
    $result = New-SprintEndHandoff -GitRoot $script:fixtureRoot -WorktreePaths @((Join-Path $script:fixtureRoot 'Ace-wt-45-Sprint-0015-work-items')) -SprintNumber 15 -OutputPath $output -Confirm:$false
    $code = [regex]::Match((Get-Content -LiteralPath $result.Path -Raw), '(?s)```powershell\r?\n(.*?)\r?\n```').Groups[1].Value
    & ([scriptblock]::Create($code))
    foreach ($command in @('Set-SprintBoundaryContext', 'Invoke-SprintEndInfrastructureCleanup', 'Test-SprintEndBoundaryState')) {
      Should -Invoke $command -Times 1 -Exactly -ParameterFilter { -not $PSBoundParameters.ContainsKey('HostDisposition') }
    }
    Should -Invoke Get-SprintEndHostContext -Times 0 -Exactly
  }

  It 'rejects an injection-shaped declaration before writing a handoff' {
    $script:policy.DispositionId = 'bad''; throw "injection"; #'
    $output = Join-Path $script:fixtureRoot 'must-not-exist.md'
    { New-SprintEndHandoff -GitRoot $script:fixtureRoot -HostDisposition $script:policy -OutputPath $output -SprintNumber 15 -Confirm:$false } | Should -Throw '*safe identifier*'
    Test-Path -LiteralPath $output | Should -BeFalse
    Should -Invoke Set-SprintBoundaryContext -Times 0 -Exactly
    Should -Invoke Invoke-SprintEndInfrastructureCleanup -Times 0 -Exactly
  }
}

Describe 'Public lifecycle rejects invalid disposition before external prerequisites' {
  BeforeEach {
    Mock Write-PSFMessage {}
    Mock Set-SprintBoundaryContext { throw 'Effects must not run.' }
    Mock Set-SprintLoginScheduledTaskTarget { throw 'Effects must not run.' }
    Mock Get-SecretATAP { throw 'Effects must not run.' }
    Mock git { throw 'Effects must not run.' }
  }
  It 'rejects explicit null in the public orchestrator before execution' {
    { Invoke-SprintEndLifecycle -GitRoot $script:fixtureRoot -PlanningRoot $script:fixtureRoot -SharedVSCodeWorktreePath $script:fixtureRoot -WorktreePaths @('C:\fixture-wt-1-Sprint-0015-work-items') -HostDisposition $null -Confirm:$false } | Should -Throw '*non-null six-field*'
    Should -Invoke Set-SprintBoundaryContext -Times 0 -Exactly
    Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 0 -Exactly
    Should -Invoke Get-SecretATAP -Times 0 -Exactly
    Should -Invoke git -Times 0 -Exactly
  }
}

Describe 'All six public entry points reject explicit null before dependencies' {
  BeforeEach {
    Mock Write-PSFMessage {}
    Mock Get-SprintEndHostContext { throw 'Invalid input must fail before context probing.' }
    Mock Test-SprintEndEnvironmentVariablePresent { throw 'Invalid input must fail before presence reads.' }
    Mock Set-SprintLoginScheduledTaskTarget { throw 'Invalid input must fail before task access.' }
    Mock Get-SecretATAP { throw 'Invalid input must fail before secret retrieval.' }
    Mock git { throw 'Invalid input must fail before Git.' }
  }
  It '<FunctionName> fails before dependencies' -ForEach @(
    @{ FunctionName='Test-SprintEndBoundaryState' },
    @{ FunctionName='Test-SprintInfrastructureHealth' },
    @{ FunctionName='Set-SprintBoundaryContext' },
    @{ FunctionName='Invoke-SprintEndInfrastructureCleanup' },
    @{ FunctionName='Invoke-SprintEndLifecycle' },
    @{ FunctionName='New-SprintEndHandoff' }
  ) {
    $parameters = @{ HostDisposition=$null }
    if ($FunctionName -ne 'Test-SprintInfrastructureHealth') { $parameters.GitRoot=$script:fixtureRoot }
    if ($FunctionName -in @('Set-SprintBoundaryContext', 'Invoke-SprintEndLifecycle')) { $parameters.SharedVSCodeWorktreePath=$script:fixtureRoot }
    if ($FunctionName -eq 'Set-SprintBoundaryContext') { $parameters.Boundary='End' }
    if ($FunctionName -eq 'Invoke-SprintEndLifecycle') {
      $parameters.PlanningRoot=$script:fixtureRoot
      $parameters.WorktreePaths=@((Join-Path $script:fixtureRoot 'Ace-wt-45-Sprint-0015-work-items'))
    }
    { & $FunctionName @parameters } | Should -Throw '*non-null six-field*'
    Should -Invoke Get-SprintEndHostContext -Times 0 -Exactly
    Should -Invoke Test-SprintEndEnvironmentVariablePresent -Times 0 -Exactly
    Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 0 -Exactly
    Should -Invoke Get-SecretATAP -Times 0 -Exactly
    Should -Invoke git -Times 0 -Exactly
  }
}

Describe 'ExpectedAbsent boundary rejects known invalid modes before effects' {
  BeforeEach {
    $script:policy = New-TestDisposition
    Mock Write-PSFMessage {}
    Mock Get-SprintEndHostContext { [PSCustomObject]@{ HostName='UTAT01'; Identity='UTAT01\whertzing'; IsElevated=$true } }
    Mock Set-SprintLoginScheduledTaskTarget { throw 'No task calls permitted.' }
  }
  It 'rejects an unelevated absence declaration before boundary work' {
    Mock Get-SprintEndHostContext { [PSCustomObject]@{ HostName='UTAT01'; Identity='UTAT01\whertzing'; IsElevated=$false } }
    { Set-SprintBoundaryContext -Boundary End -GitRoot $script:fixtureRoot -SharedVSCodeWorktreePath $script:fixtureRoot -HostDisposition $script:policy -Confirm:$false } | Should -Throw '*requires an elevated*'
    Should -Invoke Write-PSFMessage -Times 0 -Exactly -ParameterFilter { $FunctionName -eq 'Set-SprintBoundaryContext' }
    Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 0 -Exactly
  }
  It 'rejects a conflicting script override before boundary work' {
    { Set-SprintBoundaryContext -Boundary End -GitRoot $script:fixtureRoot -SharedVSCodeWorktreePath $script:fixtureRoot -HostDisposition $script:policy -LoginScriptPath 'C:\fixture.ps1' -Confirm:$false } | Should -Throw '*does not permit a LoginScriptPath*'
    Should -Invoke Write-PSFMessage -Times 0 -Exactly -ParameterFilter { $FunctionName -eq 'Set-SprintBoundaryContext' }
    Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 0 -Exactly
  }
  It 'rejects absence at SprintStart before boundary work' {
    { Set-SprintBoundaryContext -Boundary Start -GitRoot $script:fixtureRoot -SharedVSCodeWorktreePath $script:fixtureRoot -HostDisposition $script:policy -Confirm:$false } | Should -Throw '*End-boundary disposition*'
    Should -Invoke Write-PSFMessage -Times 0 -Exactly -ParameterFilter { $FunctionName -eq 'Set-SprintBoundaryContext' }
    Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 0 -Exactly
  }
}
