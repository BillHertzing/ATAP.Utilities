#Requires -Version 7.0

BeforeAll {
  $moduleRoot = Join-Path $PSScriptRoot '..\..'
  . (Join-Path $moduleRoot 'public\Invoke-SprintEndInfrastructureCleanup.ps1')

  function Set-SprintLoginScheduledTaskTarget {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Boundary, [string]$GitRoot, [string[]]$WorktreePaths,
      [AllowNull()][AllowEmptyString()][string]$LoginScriptPath, [switch]$CheckOnly)
    throw 'Login helper fixture requires an isolated mock.'
  }
  function Test-SprintInfrastructureHealth { param([string]$BuildMasterAdminApiKeySecretName) }
  function Remove-SprintDatabases {
    [CmdletBinding(SupportsShouldProcess)]
    param([string[]]$DeveloperNames, [switch]$Force)
  }
  function Clear-BuildMasterSprintVariables { [CmdletBinding(SupportsShouldProcess)] param() }
  function Get-DbaDatabase {
    [CmdletBinding()]
    param([string]$SqlInstance, [string]$Database, [switch]$EnableException)
    throw 'Database absence verification requires an isolated mock.'
  }
  function Set-SprintBoundaryContext {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Boundary, [string]$SharedVSCodeWorktreePath, [string]$GitRoot,
      [string[]]$WorktreePaths, [switch]$SkipLoginScheduledTasks, [string]$ProfiledRemotingPolicy)
  }
  function Write-PSFMessage { param([string]$FunctionName, [string]$ModuleName, [string]$Level, [string]$Message) }
}

Describe 'Task 15.208 public cleanup entrypoint gates' -Tag 'Unit' {
  BeforeEach {
    $script:root = Join-Path $TestDrive 'gitroot'
    New-Item -ItemType Directory -Path $script:root -Force | Out-Null
    $script:removedRoots = @(Join-Path $script:root 'ATAP.Utilities-wt-137-Sprint-0015-work-items')
    $script:override = Join-Path $script:root 'development\LoginScript.ps1'
    $script:callOrder = [Collections.Generic.List[string]]::new()
    $script:loginBoundParameters = $null
    Mock Write-PSFMessage { }
    Mock Set-SprintLoginScheduledTaskTarget {
      $script:callOrder.Add('login')
      $script:loginBoundParameters = $PesterBoundParameters
      [pscustomobject]@{ Ok = $true; Planned = [bool]$WhatIfPreference; Changed = $false; Tasks = @(); Failures = @() }
    }
    Mock Test-SprintInfrastructureHealth {
      $script:callOrder.Add('health')
      [pscustomobject]@{ AllOk = $true; Failures = @() }
    }
    Mock Remove-SprintDatabases {
      $script:callOrder.Add('database')
      foreach ($developer in $DeveloperNames) {
        foreach ($instance in @("Dev$developer", "Exp$developer")) {
          foreach ($database in @('ATAPUtilities', 'AceCommander')) {
            [pscustomobject]@{ instanceName = $instance; database = $database; instanceReady = $true;
              dropped = $true; skipped = $false; dryRun = $false; error = $null }
          }
        }
      }
    }
    Mock Get-DbaDatabase { }
    Mock Clear-BuildMasterSprintVariables {
      $script:callOrder.Add('buildmaster')
      [pscustomobject]@{ variablesCleared = @(); errors = @() }
    }
    Mock Set-SprintBoundaryContext { $script:callOrder.Add('boundary'); [pscustomobject]@{ Errors = @() } }
    $script:invokeParameters = @{ GitRoot = $script:root; BuildMasterAdminApiKeySecretName = 'fixture'; Confirm = $false }
  }

  It 'checks both selected End bindings before health and all cleanup effects' {
    $result = Invoke-SprintEndInfrastructureCleanup @script:invokeParameters -WorktreePaths $script:removedRoots -Apply

    $result.Ok | Should -BeTrue
    $result.Applied | Should -BeTrue
    $script:callOrder.ToArray() | Should -Be @('login', 'health', 'database', 'buildmaster', 'boundary')
    Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 1 -Exactly -ParameterFilter {
      $Boundary -eq 'End' -and $GitRoot -eq $script:root -and $CheckOnly -and $WorktreePaths[0] -eq $script:removedRoots[0]
    }
    Should -Invoke Set-SprintBoundaryContext -Times 1 -Exactly -ParameterFilter {
      $GitRoot -eq $script:root -and $SkipLoginScheduledTasks -and $Boundary -eq 'End'
    }
  }

  It 'returns failed audit evidence before health when selected current bindings are stale' {
    Mock Set-SprintLoginScheduledTaskTarget { [pscustomobject]@{ Ok = $false; Failures = @('StaleBinding'); Tasks = @() } }
    $result = Invoke-SprintEndInfrastructureCleanup @script:invokeParameters -Apply

    $result.Ok | Should -BeFalse
    $result.Applied | Should -BeFalse
    $result.LoginScheduledTasks.Failures | Should -Contain 'StaleBinding'
    $result.Failures | Should -Contain 'LoginScheduledTasks'
    Should -Invoke Test-SprintInfrastructureHealth -Times 0
    Should -Invoke Remove-SprintDatabases -Times 0
    Should -Invoke Clear-BuildMasterSprintVariables -Times 0
    Should -Invoke Set-SprintBoundaryContext -Times 0
  }

  It 'fails closed before health on a null helper result' {
    Mock Set-SprintLoginScheduledTaskTarget { $null }
    $result = Invoke-SprintEndInfrastructureCleanup @script:invokeParameters -Apply

    $result.Ok | Should -BeFalse
    $result.Health | Should -BeNullOrEmpty
    Should -Invoke Test-SprintInfrastructureHealth -Times 0
    Should -Invoke Remove-SprintDatabases -Times 0
  }

  It 'returns structured helper exceptions before health or cleanup' {
    Mock Set-SprintLoginScheduledTaskTarget { throw 'fixture helper failure' }
    $result = Invoke-SprintEndInfrastructureCleanup @script:invokeParameters -Apply

    $result.Ok | Should -BeFalse
    $result.Failures[0] | Should -Match 'fixture helper failure'
    Should -Invoke Test-SprintInfrastructureHealth -Times 0
    Should -Invoke Clear-BuildMasterSprintVariables -Times 0
  }

  It 'audits before the health-only entrypoint without applying cleanup' {
    $result = Invoke-SprintEndInfrastructureCleanup @script:invokeParameters

    $result.Ok | Should -BeTrue
    $result.Applied | Should -BeFalse
    $script:callOrder.ToArray() | Should -Be @('login', 'health')
    Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 1 -ParameterFilter { $CheckOnly }
    Should -Invoke Remove-SprintDatabases -Times 0
  }

  It 'forwards an explicit development selection for the audit without resetting it in the boundary' {
    $result = Invoke-SprintEndInfrastructureCleanup @script:invokeParameters -LoginScriptPath $script:override -WorktreePaths $script:removedRoots -Apply

    $result.Ok | Should -BeTrue
    $script:loginBoundParameters.ContainsKey('LoginScriptPath') | Should -BeTrue
    Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 1 -Exactly -ParameterFilter {
      $LoginScriptPath -eq $script:override -and $CheckOnly -and $WorktreePaths[0] -eq $script:removedRoots[0]
    }
    Should -Invoke Set-SprintBoundaryContext -Times 1 -Exactly -ParameterFilter { $SkipLoginScheduledTasks }
  }

  It 'does not manufacture an explicit override when the caller omits it' {
    Invoke-SprintEndInfrastructureCleanup @script:invokeParameters | Out-Null

    $script:loginBoundParameters.ContainsKey('LoginScriptPath') | Should -BeFalse
  }

  It 'passes an explicitly empty override to validation instead of silently selecting stable' {
    Mock Set-SprintLoginScheduledTaskTarget {
      if ($PesterBoundParameters.ContainsKey('LoginScriptPath') -and [string]::IsNullOrWhiteSpace($LoginScriptPath)) {
        [pscustomobject]@{ Ok = $false; Failures = @('EmptyOverride') }
      } else { [pscustomobject]@{ Ok = $true; Failures = @() } }
    }
    $result = Invoke-SprintEndInfrastructureCleanup @script:invokeParameters -LoginScriptPath '' -Apply

    $result.Ok | Should -BeFalse
    $result.LoginScheduledTasks.Failures | Should -Contain 'EmptyOverride'
    Should -Invoke Test-SprintInfrastructureHealth -Times 0
  }

  It 'plans the pair under Apply WhatIf instead of rejecting unchanged sprint bindings' {
    Mock Set-SprintLoginScheduledTaskTarget {
      if ($CheckOnly) { [pscustomobject]@{ Ok = $false; Failures = @('StillSprintBinding') } }
      else { [pscustomobject]@{ Ok = $true; Planned = [bool]$WhatIfPreference; Failures = @() } }
    }
    $result = Invoke-SprintEndInfrastructureCleanup @script:invokeParameters -Apply -WhatIf

    $result.Ok | Should -BeTrue
    $result.Planned | Should -BeTrue
    $result.Applied | Should -BeFalse
    $result.LoginScheduledTasks.Planned | Should -BeTrue
    Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 1 -Exactly -ParameterFilter { -not $CheckOnly -and $WhatIf }
    Should -Invoke Remove-SprintDatabases -Times 0
    Should -Invoke Clear-BuildMasterSprintVariables -Times 0
    Should -Invoke Set-SprintBoundaryContext -Times 0
  }

  It 'reports boundary errors as a failed cleanup rather than successful application' {
    Mock Set-SprintBoundaryContext { [pscustomobject]@{ Errors = @('fixture boundary error') } }
    $result = Invoke-SprintEndInfrastructureCleanup @script:invokeParameters -Apply

    $result.Ok | Should -BeFalse
    $result.Applied | Should -BeFalse
    $result.Failures | Should -Contain 'BoundaryReset'
    $result.BoundaryResult.Errors | Should -Contain 'fixture boundary error'
  }

  It 'reports null boundary results as a failure' {
    Mock Set-SprintBoundaryContext { $null }
    $result = Invoke-SprintEndInfrastructureCleanup @script:invokeParameters -Apply

    $result.Ok | Should -BeFalse
    $result.Failures | Should -Contain 'BoundaryReset'
  }

  It 'reports boundary exceptions as structured failures' {
    Mock Set-SprintBoundaryContext { throw 'fixture boundary exception' }
    $result = Invoke-SprintEndInfrastructureCleanup @script:invokeParameters -Apply

    $result.Ok | Should -BeFalse
    $result.Failures[0] | Should -Match 'fixture boundary exception'
  }
}

Describe 'Task 15.208 Stage1 global concern ownership' -Tag 'Unit' {
  It 'skips login-task maintenance in every Planning-only boundary call' {
    $tokens = $null
    $parseErrors = $null
    $stage1Path = Join-Path $PSScriptRoot '..\..\public\New-SprintStage1.ps1'
    $ast = [Management.Automation.Language.Parser]::ParseFile($stage1Path, [ref]$tokens, [ref]$parseErrors)
    $commands = @($ast.FindAll({ param($node)
          $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Set-SprintBoundaryContext'
        }, $true))

    $parseErrors | Should -BeNullOrEmpty
    $commands.Count | Should -Be 1
    $commands[0].CommandElements.ParameterName | Should -Contain 'SkipLoginScheduledTasks'
  }
}
