BeforeAll {
  $script:moduleRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  . (Join-Path $script:moduleRoot 'public/Set-ServiceAccountGitSafeDirectory.ps1')
  . (Join-Path $script:moduleRoot 'private/Set-SprintOwnedGitSafeDirectory.ps1')
  . (Join-Path $script:moduleRoot 'public/Invoke-SprintEndInfrastructureCleanup.ps1')
  function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }
  function Get-FixtureTrust {
    @(& git config --file $script:config --get-all safe.directory 2>$null)
  }
  function Invoke-FixtureTrust {
    param($Boundary = 'Start', [switch]$WhatIf)
    Set-SprintOwnedGitSafeDirectory -Boundary $Boundary -WorktreePaths @($script:existing, $script:newPath) -GitConfigPath $script:config -Confirm:$false -WhatIf:$WhatIf
  }
}

Describe 'Task 16.55.d Start ownership and conservative End with real isolated Git config' {
  BeforeEach {
    $script:fixture = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../../../../_generated/Sprint0016/StartupRecovery/GitSafeDirectory/EndCaller/Task-16.55.d/fixtures/$([guid]::NewGuid().ToString('N'))"))
    New-Item -ItemType Directory -Path $script:fixture -Force | Out-Null
    $script:config = Join-Path $script:fixture 'user.gitconfig'
    $script:existing = (Join-Path $script:fixture 'Ace-wt-1-Sprint-0016-work-items').Replace('\', '/')
    $script:newPath = (Join-Path $script:fixture 'ATAP.Utilities-wt-2-Sprint-0016-work-items').Replace('\', '/')
    $script:unrelated = (Join-Path $script:fixture 'Other-wt-3-Sprint-0016-work-items').Replace('\', '/')
    foreach ($path in @($script:existing, $script:newPath)) {
      New-Item -ItemType Directory -Path (Join-Path $path '.git') -Force | Out-Null
    }
    & git config --file $script:config --add safe.directory $script:existing
    & git config --file $script:config --add safe.directory $script:unrelated
    $LASTEXITCODE | Should -Be 0
  }

  It 'removes only introduced exact entries and retains ownership through repeated split Start calls' {
    $first = Invoke-FixtureTrust
    $first.Added | Should -Be @($script:newPath)
    $receiptHash = (Get-FileHash $first.Receipts[0]).Hash
    (Invoke-FixtureTrust).Added | Should -BeNullOrEmpty
    (Get-FileHash $first.Receipts[0]).Hash | Should -Be $receiptHash
    $end = Invoke-FixtureTrust End
    $end.Removed | Should -Be @($script:newPath)
    Get-FixtureTrust | Should -Be @($script:existing, $script:unrelated)
    (Invoke-FixtureTrust End).Removed | Should -BeNullOrEmpty
    # A later manual re-add is not owned by the completed Start/End pair.
    & git config --file $script:config --add safe.directory $script:newPath
    (Invoke-FixtureTrust End).Removed | Should -BeNullOrEmpty
    Get-FixtureTrust | Should -Contain $script:newPath
  }

  It 'handles distinct Start calls and separate user and service configurations independently' {
    $service = Join-Path $script:fixture 'service.gitconfig'
    foreach ($path in @($script:existing, $script:newPath)) {
      Set-SprintOwnedGitSafeDirectory -Boundary Start -WorktreePaths @($path) -GitConfigPath $script:config -Confirm:$false | Out-Null
      Set-SprintOwnedGitSafeDirectory -Boundary Start -WorktreePaths @($path) -GitConfigPath $service -Confirm:$false | Out-Null
    }
    (Invoke-FixtureTrust End).Removed | Should -Be @($script:newPath)
    $end = Set-SprintOwnedGitSafeDirectory -Boundary End -WorktreePaths @($script:existing, $script:newPath) -GitConfigPath $service -Confirm:$false
    $end.Removed.Count | Should -Be 2
    @(& git config --file $service --get-all safe.directory).Count | Should -Be 0
    Get-FixtureTrust | Should -Be @($script:existing, $script:unrelated)
  }

  It 'leaves both config and receipts byte-stable under Start and End WhatIf' {
    $before = (Get-FileHash $script:config).Hash
    (Invoke-FixtureTrust -WhatIf).DryRun | Should -BeTrue
    (Get-FileHash $script:config).Hash | Should -Be $before
    @(Get-ChildItem $script:fixture -Filter '*.json' -Recurse).Count | Should -Be 0
    $start = Invoke-FixtureTrust
    $configHash = (Get-FileHash $script:config).Hash
    $receiptHash = (Get-FileHash $start.Receipts[0]).Hash
    (Invoke-FixtureTrust -Boundary End -WhatIf).Removed | Should -Be @($script:newPath)
    (Get-FileHash $script:config).Hash | Should -Be $configHash
    (Get-FileHash $start.Receipts[0]).Hash | Should -Be $receiptHash
    (Invoke-FixtureTrust End).Removed | Should -Be @($script:newPath)
  }

  It 'preserves manual recovery entries with no ownership receipt' {
    $before = (Get-FileHash $script:config).Hash
    $end = Invoke-FixtureTrust End
    $end.Removed | Should -BeNullOrEmpty
    $end.Preserved.Reason | Should -Contain 'ReceiptMissing'
    (Get-FileHash $script:config).Hash | Should -Be $before
  }

  It 'preserves trust when ownership evidence is <Kind>' -TestCases @(
    @{ Kind = 'malformed' }, @{ Kind = 'wrong path' }, @{ Kind = 'wrong config' },
    @{ Kind = 'wrong host' }, @{ Kind = 'wrong identity' }, @{ Kind = 'wrong state' }
  ) {
    param($Kind)
    $start = Invoke-FixtureTrust
    $receipt = Get-Content $start.Receipts[0] -Raw | ConvertFrom-Json
    switch ($Kind) {
      'wrong path' { $receipt.Path = $script:existing }
      'wrong config' { $receipt.GitConfigPath = 'C:/other.gitconfig' }
      'wrong host' { $receipt.HostName = 'OTHERHOST' }
      'wrong identity' { $receipt.Identity = 'someone else' }
      'wrong state' { $receipt.State = 'Unknown' }
    }
    if ($Kind -eq 'malformed') { Set-Content $start.Receipts[0] '{bad' }
    else { $receipt | ConvertTo-Json | Set-Content $start.Receipts[0] }
    $before = (Get-FileHash $script:config).Hash
    (Invoke-FixtureTrust End).Removed | Should -BeNullOrEmpty
    (Get-FileHash $script:config).Hash | Should -Be $before
  }

  It 'does not grant new trust to a nonexistent checkout or recreate its directory at End' {
    $missing = Join-Path $script:fixture 'Ace-wt-999-Sprint-0016-work-items'
    foreach ($boundary in @('Start', 'End', 'End')) {
      $result = Set-SprintOwnedGitSafeDirectory -Boundary $boundary -WorktreePaths @($missing) -GitConfigPath $script:config -Confirm:$false
      $result.Added | Should -BeNullOrEmpty
      $result.Removed | Should -BeNullOrEmpty
      Test-Path -LiteralPath $missing | Should -BeFalse
    }
  }

  It 'removes owned trust while the checkout directory remains but its Git pointer is gone' {
    $start = Invoke-FixtureTrust
    # Move the fixture pointer aside, retaining all generated evidence.
    Move-Item -LiteralPath (Join-Path $script:newPath '.git') -Destination (Join-Path $script:newPath '.git.saved')
    (Invoke-FixtureTrust End).Removed | Should -Be @($script:newPath)
  }

  It 'never creates ownership for a failed Git mutation' {
    Mock Set-ServiceAccountGitSafeDirectory { throw 'simulated Git failure' }
    { Invoke-FixtureTrust } | Should -Throw '*simulated Git failure*'
    @(Get-ChildItem $script:fixture -Filter '*.json' -Recurse).Count | Should -Be 0
    Get-FixtureTrust | Should -Be @($script:existing, $script:unrelated)
  }

  It 'never creates ownership from a helper that reports only a projected mutation' {
    Mock Set-ServiceAccountGitSafeDirectory { [pscustomobject]@{ Success = $true; DryRun = $true; Added = @($script:newPath) } }
    { Invoke-FixtureTrust } | Should -Throw '*did not confirm an applied result*'
    @(Get-ChildItem $script:fixture -Filter '*.json' -Recurse).Count | Should -Be 0
  }

  It 'preserves an introduced entry when Start cannot persist its receipt' {
    Mock Set-Content { throw 'Start receipt failed' } -ParameterFilter { $LiteralPath -like '*SprintGitTrust*' }
    { Invoke-FixtureTrust } | Should -Throw '*Start receipt failed*'
    @(Get-ChildItem $script:fixture -Filter '*.json' -Recurse).Count | Should -Be 0
    (Invoke-FixtureTrust End).Removed | Should -BeNullOrEmpty
    Get-FixtureTrust | Should -Contain $script:newPath
  }

  It 'does not mutate Git when End cannot durably retire ownership' {
    $start = Invoke-FixtureTrust
    Mock Set-Content { throw 'receipt write failed' } -ParameterFilter { $LiteralPath -eq $start.Receipts[0] }
    { Invoke-FixtureTrust End } | Should -Throw '*receipt write failed*'
    Get-FixtureTrust | Should -Contain $script:newPath
  }

  It 'surfaces a failed removal and refuses to replay retired ownership' {
    $start = Invoke-FixtureTrust
    Mock Set-ServiceAccountGitSafeDirectory { throw 'removal failed' } -ParameterFilter { $Boundary -eq 'End' }
    { Invoke-FixtureTrust End } | Should -Throw '*removal failed*'
    (Get-Content $start.Receipts[0] -Raw | ConvertFrom-Json).State | Should -Be 'Retired'
    (Invoke-FixtureTrust End).Removed | Should -BeNullOrEmpty
    Get-FixtureTrust | Should -Contain $script:newPath
    Should -Invoke Set-ServiceAccountGitSafeDirectory -Times 1 -Exactly -ParameterFilter { $Boundary -eq 'End' }
  }
}

Describe 'Task 16.55.d infrastructure caller forwards exact worktree paths' {
  BeforeAll {
    function Set-SprintLoginScheduledTaskTarget { [CmdletBinding(SupportsShouldProcess)] param($Boundary, $GitRoot, $WorktreePaths, [switch]$CheckOnly) }
    function Test-SprintInfrastructureHealth { param($BuildMasterAdminApiKeySecretName) }
    function Clear-BuildMasterSprintVariables { [CmdletBinding(SupportsShouldProcess)] param() }
    function Get-DbaDatabase { [CmdletBinding()] param($SqlInstance, $Database, [switch]$EnableException) }
    function Remove-SprintDatabases { [CmdletBinding(SupportsShouldProcess)] param($DeveloperNames, $InstanceNames, $Databases, [switch]$Force) }
    function Set-SprintBoundaryContext { [CmdletBinding(SupportsShouldProcess)] param($Boundary, $SharedVSCodeWorktreePath, $GitRoot, $WorktreePaths, [switch]$SkipLoginScheduledTasks, $ProfiledRemotingPolicy) }
  }
  It 'passes the supplied exact paths to End without rescanning' {
    Mock Set-SprintLoginScheduledTaskTarget { [pscustomobject]@{ Ok = $true } }
    Mock Test-SprintInfrastructureHealth { [pscustomobject]@{ AllOk = $true; Failures = @() } }
    Mock Clear-BuildMasterSprintVariables { [pscustomobject]@{ errors = @() } }
    Mock Get-DbaDatabase { }
    Mock Remove-SprintDatabases { [pscustomobject]@{ instanceName = 'QA'; database = 'fixture'; instanceReady = $true; dropped = $true; skipped = $false; error = $null } }
    Mock Set-SprintBoundaryContext { [pscustomobject]@{ Errors = @() } }
    $paths = @('C:/fixture/Ace-wt-1-Sprint-0016-work-items', 'C:/fixture/_Planning-wt-2-Sprint-0016-work-items')
    $result = Invoke-SprintEndInfrastructureCleanup -GitRoot $TestDrive -WorktreePaths $paths -BuildMasterAdminApiKeySecretName 'fixture' -DatabaseCleanupTargets @(@{ InstanceName = 'QA'; Databases = @('fixture') }) -Apply -Confirm:$false
    $result.Ok | Should -BeTrue
    Should -Invoke Set-SprintBoundaryContext -Times 1 -Exactly -ParameterFilter { $Boundary -eq 'End' -and $WorktreePaths.Count -eq 2 -and $WorktreePaths[0] -eq $paths[0] -and $WorktreePaths[1] -eq $paths[1] }
  }
}
