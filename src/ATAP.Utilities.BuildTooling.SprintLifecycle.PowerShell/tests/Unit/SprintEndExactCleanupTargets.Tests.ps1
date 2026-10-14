#Requires -Version 7.0

BeforeAll {
  . (Join-Path $PSScriptRoot '../../public/Invoke-SprintEndInfrastructureCleanup.ps1')
  function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }
  function Set-SprintLoginScheduledTaskTarget {
    [CmdletBinding(SupportsShouldProcess)]
    param($Boundary, $GitRoot, $WorktreePaths, $LoginScriptPath, [switch]$CheckOnly)
  }
  function Test-SprintInfrastructureHealth { param($BuildMasterAdminApiKeySecretName) }
  function Get-DbaDatabase { [CmdletBinding()] param($SqlInstance, $Database, [switch]$EnableException) }
  function Remove-SprintDatabases {
    [CmdletBinding(SupportsShouldProcess)]
    param([string[]]$DeveloperNames, [string[]]$InstanceNames, [string[]]$Databases, [switch]$Force)
  }
  function Clear-BuildMasterSprintVariables { [CmdletBinding(SupportsShouldProcess)] param() }
  function Set-SprintBoundaryContext {
    [CmdletBinding(SupportsShouldProcess)]
    param($Boundary, $SharedVSCodeWorktreePath, $GitRoot, $WorktreePaths, [switch]$SkipLoginScheduledTasks, $ProfiledRemotingPolicy)
  }
}

Describe 'SprintEnd exact database cleanup and failure gates' {
  BeforeEach {
    $script:parameters = @{ GitRoot = $TestDrive; BuildMasterAdminApiKeySecretName = 'fixture'; Apply = $true; Confirm = $false; DeveloperNames = @('WHERTZING') }
    Mock Write-PSFMessage {}
    Mock Set-SprintLoginScheduledTaskTarget { [pscustomobject]@{ Ok = $true } }
    Mock Test-SprintInfrastructureHealth { [pscustomobject]@{ AllOk = $true; Failures = @() } }
    Mock Get-DbaDatabase { }
    Mock Clear-BuildMasterSprintVariables { [pscustomobject]@{ variablesCleared = @('fixture'); errors = @() } }
    Mock Set-SprintBoundaryContext { [pscustomobject]@{ Errors = @() } }
    Mock Remove-SprintDatabases {
      if (-not $InstanceNames) { $InstanceNames = @('DevWHERTZING', 'ExpWHERTZING') }
      if (-not $Databases) { $Databases = @('ATAPUtilities', 'AceCommander') }
      foreach ($instance in $InstanceNames) {
        foreach ($database in $Databases) {
          [pscustomobject]@{ instanceName = $instance; database = $database; instanceReady = $true; dropped = $true; skipped = $false; dryRun = $false; error = $null }
        }
      }
    }
  }

  It 'retains the omitted Dev/Exp helper contract and checks its database results' {
    $result = Invoke-SprintEndInfrastructureCleanup @script:parameters
    $result.Ok | Should -BeTrue
    $result.Applied | Should -BeTrue
    $result.DatabaseCleanupMode | Should -Be 'SprintDatabasesOnly'
    $result.DatabaseTargetSelectionMode | Should -Be 'DeveloperDefaults'
    $result.DatabaseResults.Count | Should -Be 4
    Should -Invoke Remove-SprintDatabases -Times 1 -Exactly -ParameterFilter { $DeveloperNames[0] -eq 'WHERTZING' -and -not $InstanceNames -and -not $Databases -and $Force }
  }

  It 'drops only the exact databases in <GroupCount> authorized groups' -TestCases @(@{ GroupCount = 2 }, @{ GroupCount = 4 }) {
    param($GroupCount)
    $instances = @('EXPWHERTZING', 'DEVWHERTZING', 'Integration', 'QA')
    $targets = @(0..($GroupCount - 1) | ForEach-Object { @{ InstanceName = $instances[$_]; Databases = @("Exact$_") } })
    $result = Invoke-SprintEndInfrastructureCleanup @script:parameters -DatabaseCleanupTargets $targets
    $result.Ok | Should -BeTrue
    $result.DatabaseResults.Count | Should -Be $GroupCount
    $result.DatabaseCleanupMode | Should -Be 'SprintDatabasesOnly'
    $result.DatabaseTargetSelectionMode | Should -Be 'ExactDatabaseTargets'
    foreach ($target in $targets) {
      Should -Invoke Remove-SprintDatabases -Times 1 -Exactly -ParameterFilter { $InstanceNames.Count -eq 1 -and $InstanceNames[0] -eq $target.InstanceName -and $Databases.Count -eq 1 -and $Databases[0] -eq $target.Databases[0] -and $Force }
    }
  }

  It 'rejects <Label> before any helper effects' -TestCases @(
    @{ Label = 'null list'; Targets = $null }
    @{ Label = 'empty list'; Targets = @() }
    @{ Label = 'missing record'; Targets = @($null) }
    @{ Label = 'Production'; Targets = @(@{ InstanceName = 'Production'; Databases = @('db') }) }
    @{ Label = 'remote instance'; Targets = @(@{ InstanceName = 'host\QA'; Databases = @('db') }) }
    @{ Label = 'empty databases'; Targets = @(@{ InstanceName = 'QA'; Databases = @() }) }
    @{ Label = 'string databases'; Targets = @(@{ InstanceName = 'QA'; Databases = 'db' }) }
    @{ Label = 'empty name'; Targets = @(@{ InstanceName = 'QA'; Databases = @('') }) }
    @{ Label = 'system master'; Targets = @(@{ InstanceName = 'QA'; Databases = @('MASTER') }) }
    @{ Label = 'system model'; Targets = @(@{ InstanceName = 'QA'; Databases = @('model') }) }
    @{ Label = 'system msdb'; Targets = @(@{ InstanceName = 'QA'; Databases = @('msdb') }) }
    @{ Label = 'system tempdb'; Targets = @(@{ InstanceName = 'QA'; Databases = @('tempdb') }) }
    @{ Label = 'padded system name'; Targets = @(@{ InstanceName = 'QA'; Databases = @(' master ') }) }
    @{ Label = 'duplicate database'; Targets = @(@{ InstanceName = 'QA'; Databases = @('db', 'DB') }) }
    @{ Label = 'duplicate instance'; Targets = @(@{ InstanceName = 'QA'; Databases = @('db') }, @{ InstanceName = 'qa'; Databases = @('other') }) }
  ) {
    param($Label, $Targets)
    { Invoke-SprintEndInfrastructureCleanup @script:parameters -DatabaseCleanupTargets $Targets } | Should -Throw
    Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 0
    Should -Invoke Remove-SprintDatabases -Times 0
    Should -Invoke Clear-BuildMasterSprintVariables -Times 0
  }

  It 'fails and stops subsequent mutations for <Failure>' -TestCases @(
    @{ Failure = 'error'; Row = @{ instanceName = 'QA'; database = 'db'; instanceReady = $true; dropped = $false; skipped = $false; error = 'drop failure' } }
    @{ Failure = 'missing row'; Row = $null }
    @{ Failure = 'wrong database'; Row = @{ instanceName = 'QA'; database = 'other'; instanceReady = $true; dropped = $true } }
    @{ Failure = 'no terminal status'; Row = @{ instanceName = 'QA'; database = 'db'; instanceReady = $true; dropped = $false; skipped = $false } }
    @{ Failure = 'dry run'; Row = @{ instanceName = 'QA'; database = 'db'; instanceReady = $true; skipped = $true; dryRun = $true } }
  ) {
    param($Failure, $Row)
    $script:failureRow = $Row
    Mock Remove-SprintDatabases { if ($script:failureRow) { [pscustomobject]$script:failureRow } }
    $result = Invoke-SprintEndInfrastructureCleanup @script:parameters -DatabaseCleanupTargets @(@{ InstanceName = 'QA'; Databases = @('db') }, @{ InstanceName = 'Integration'; Databases = @('other') })
    $result.Ok | Should -BeFalse
    $result.Applied | Should -BeFalse
    $result.Failures[0] | Should -Match 'DatabaseCleanup'
    Should -Invoke Remove-SprintDatabases -Times 1 -Exactly
    Should -Invoke Clear-BuildMasterSprintVariables -Times 0
    Should -Invoke Set-SprintBoundaryContext -Times 0
  }

  It 'accepts an already absent database as idempotent success' {
    Mock Remove-SprintDatabases { [pscustomobject]@{ instanceName = 'QA'; database = 'db'; instanceReady = $true; dropped = $false; skipped = $true; dryRun = $false; error = $null } }
    $result = Invoke-SprintEndInfrastructureCleanup @script:parameters -DatabaseCleanupTargets @(@{ InstanceName = 'QA'; Databases = @('db') })
    $result.Ok | Should -BeTrue
    $result.Applied | Should -BeTrue
    Should -Invoke Get-DbaDatabase -Times 1 -Exactly -ParameterFilter { $SqlInstance -eq 'localhost\QA' -and $Database -eq 'db' -and $EnableException }
  }

  It 'fails independent verification of <Status> result when <Condition>' -TestCases @(
    @{ Status = 'skipped'; Condition = 'database still exists'; Exists = $true; Throws = $false }
    @{ Status = 'dropped'; Condition = 'database still exists'; Exists = $true; Throws = $false }
    @{ Status = 'skipped'; Condition = 'connection lookup fails'; Exists = $false; Throws = $true }
  ) {
    param($Status, $Condition, $Exists, $Throws)
    $script:verificationStatus = $Status
    $script:verificationThrows = $Throws
    Mock Remove-SprintDatabases { [pscustomobject]@{ instanceName = 'QA'; database = 'db'; instanceReady = $true; dropped = ($script:verificationStatus -eq 'dropped'); skipped = ($script:verificationStatus -eq 'skipped'); dryRun = $false; error = $null } }
    Mock Get-DbaDatabase {
      if ($script:verificationThrows) { throw 'fixture connection failed' }
      [pscustomobject]@{ Name = 'db' }
    }
    $result = Invoke-SprintEndInfrastructureCleanup @script:parameters -DatabaseCleanupTargets @(@{ InstanceName = 'QA'; Databases = @('db') })
    $result.Ok | Should -BeFalse
    $result.Applied | Should -BeFalse
    $result.Failures[0] | Should -Match 'DatabaseCleanup'
    Should -Invoke Clear-BuildMasterSprintVariables -Times 0
    Should -Invoke Set-SprintBoundaryContext -Times 0
  }

  It 'independently verifies default developer databases and blocks on failed lookup' {
    Mock Get-DbaDatabase { throw 'fixture default lookup failed' }
    $result = Invoke-SprintEndInfrastructureCleanup @script:parameters
    $result.Ok | Should -BeFalse
    $result.Applied | Should -BeFalse
    Should -Invoke Get-DbaDatabase -Times 1 -Exactly -ParameterFilter { $EnableException }
    Should -Invoke Clear-BuildMasterSprintVariables -Times 0
    Should -Invoke Set-SprintBoundaryContext -Times 0
  }

  It 'does not invoke mutation helpers under outer WhatIf' {
    $result = Invoke-SprintEndInfrastructureCleanup @script:parameters -DatabaseCleanupTargets @(@{ InstanceName = 'QA'; Databases = @('db') }) -WhatIf
    $result.Ok | Should -BeTrue
    $result.Applied | Should -BeFalse
    $result.Planned | Should -BeTrue
    Should -Invoke Remove-SprintDatabases -Times 0
    Should -Invoke Clear-BuildMasterSprintVariables -Times 0
    Should -Invoke Set-SprintBoundaryContext -Times 0
    Should -Invoke Get-DbaDatabase -Times 0
  }

  It 'blocks boundary reset when BuildMaster reports nested errors' {
    Mock Clear-BuildMasterSprintVariables { [pscustomobject]@{ variablesCleared = @(); errors = @('delete failed') } }
    $result = Invoke-SprintEndInfrastructureCleanup @script:parameters
    $result.Ok | Should -BeFalse
    $result.Failures | Should -Contain 'BuildMasterCleanup'
    Should -Invoke Set-SprintBoundaryContext -Times 0
  }
}
