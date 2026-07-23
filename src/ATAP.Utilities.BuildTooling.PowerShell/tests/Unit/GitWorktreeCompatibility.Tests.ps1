BeforeAll {
  $moduleRoot = Join-Path $PSScriptRoot '..\..'
  $manifest = Import-PowerShellDataFile (Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.PowerShell.psd1')
  $script:expectedFunctions = @($manifest.FunctionsToExport | Sort-Object -Unique)

  Remove-Module ATAP.Utilities.BuildTooling.PowerShell -Force -ErrorAction SilentlyContinue
  Import-Module (Join-Path $moduleRoot '..\ATAP.Utilities.BuildTooling.GitWorktree.PowerShell\ATAP.Utilities.BuildTooling.GitWorktree.PowerShell.psd1') -Force
  $script:childParameterContracts = @{}
  foreach ($command in @(Get-Command -Module ATAP.Utilities.BuildTooling.GitWorktree.PowerShell -CommandType Function)) {
    $script:childParameterContracts[$command.Name] = @($command.Parameters.Keys | Sort-Object)
  }
  Import-Module (Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.PowerShell.psd1') -Force
}

Describe 'GitWorktree compatibility parent rewire' {
  It 'preserves the complete frozen parent function surface' {
    $actual = @(Get-Command -Module ATAP.Utilities.BuildTooling.PowerShell -CommandType Function |
        Select-Object -ExpandProperty Name | Sort-Object -Unique)

    $actual | Should -Be $script:expectedFunctions
    $actual.Count | Should -Be 200
  }

  It 're-exports every legacy GitWorktree command with its parameter contract' {
    $gitFunctions = @(Import-PowerShellDataFile (
        Join-Path $moduleRoot '..\ATAP.Utilities.BuildTooling.GitWorktree.PowerShell\ATAP.Utilities.BuildTooling.GitWorktree.PowerShell.psd1'
      )).FunctionsToExport

    foreach ($name in @($gitFunctions | Where-Object { $_ -in $script:expectedFunctions })) {
      $parentCommand = Get-Command $name -Module ATAP.Utilities.BuildTooling.PowerShell
      $parentCommand | Should -Not -BeNullOrEmpty
      @($parentCommand.Parameters.Keys | Sort-Object) |
        Should -Be $script:childParameterContracts[$name]
    }
  }

  It 'declares all extracted children at their immutable minimum versions' {
    $manifest = Import-PowerShellDataFile (Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.PowerShell.psd1')
    $requirements = @($manifest.RequiredModules)

    ($requirements | Where-Object ModuleName -eq 'ATAP.Utilities.BuildTooling.PesterScaffolding.PowerShell').ModuleVersion |
      Should -Be '0.1.1'
    ($requirements | Where-Object ModuleName -eq 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell').ModuleVersion |
      Should -Be '0.1.3'
    ($requirements | Where-Object ModuleName -eq 'ATAP.Utilities.BuildTooling.PlanningSession.PowerShell').ModuleVersion |
      Should -Be '0.1.2'
  }
}
