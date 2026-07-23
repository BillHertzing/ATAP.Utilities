#Requires -Version 7.0

Describe 'PlanningSession public contracts' -Tag 'Unit' {
  BeforeAll {
    $script:ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:ManifestPath = Join-Path $script:ModuleRoot 'ATAP.Utilities.BuildTooling.PlanningSession.PowerShell.psd1'
    Remove-Module ATAP.Utilities.BuildTooling.PlanningSession.PowerShell -Force -ErrorAction SilentlyContinue
    $script:Module = Import-Module $script:ManifestPath -Force -PassThru
  }

  AfterAll {
    Remove-Module ATAP.Utilities.BuildTooling.PlanningSession.PowerShell -Force -ErrorAction SilentlyContinue
  }

  It 'exports exactly the three frozen commands without loading the compatibility parent' {
    @(Get-Command -Module ATAP.Utilities.BuildTooling.PlanningSession.PowerShell).Name |
      Sort-Object | Should -Be @(
        'Add-ScopeCreepIdea', 'Complete-PlanningSession', 'Start-PlanningSession'
      )
    Get-Module ATAP.Utilities.BuildTooling.PowerShell | Should -BeNullOrEmpty
  }

  It 'preserves the Add-ScopeCreepIdea global contract parameters' {
    $command = Get-Command Add-ScopeCreepIdea -Module ATAP.Utilities.BuildTooling.PlanningSession.PowerShell
    foreach ($name in @('Title', 'Description', 'PlanningRoot', 'Tags', 'GitCommit')) {
      $command.Parameters.Keys | Should -Contain $name
    }
  }

  It 'preserves the planning-session lifecycle parameters' {
    $start = Get-Command Start-PlanningSession -Module ATAP.Utilities.BuildTooling.PlanningSession.PowerShell
    $complete = Get-Command Complete-PlanningSession -Module ATAP.Utilities.BuildTooling.PlanningSession.PowerShell
    foreach ($name in @('IncludeDeferred', 'SessionDate', 'SkipGitHub', 'SkipVSCode')) {
      $start.Parameters.Keys | Should -Contain $name
    }
    foreach ($name in @('SessionFile', 'SkipGitHub', 'SkipWorktreeRemove', 'SkipLockFileGuard')) {
      $complete.Parameters.Keys | Should -Contain $name
    }
  }

  It 'keeps every public source file function-only' {
    foreach ($file in Get-ChildItem (Join-Path $script:ModuleRoot 'public') -Filter '*.ps1') {
      $tokens = $null
      $errors = $null
      $ast = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
      @($errors).Count | Should -Be 0
      @($ast.EndBlock.Statements | Where-Object { $_ -isnot [Management.Automation.Language.FunctionDefinitionAst] }).Count |
        Should -Be 0
    }
  }
}
