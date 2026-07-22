#Requires -Module Pester

Describe 'BuildTooling parent PesterScaffolding compatibility surface' {
  BeforeAll {
    $script:ChildModuleName = 'ATAP.Utilities.BuildTooling.PesterScaffolding.PowerShell'
    $script:ParentModuleName = 'ATAP.Utilities.BuildTooling.PowerShell'
    $script:ChildRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $script:ParentRoot = (Resolve-Path (Join-Path $script:ChildRoot '..\ATAP.Utilities.BuildTooling.PowerShell')).Path
    $script:ChildManifestPath = Join-Path $script:ChildRoot "$script:ChildModuleName.psd1"
    $script:ParentManifestPath = Join-Path $script:ParentRoot "$script:ParentModuleName.psd1"
    $script:ChildExports = @((Import-PowerShellDataFile -LiteralPath $script:ChildManifestPath).FunctionsToExport)

    Remove-Module -Name $script:ParentModuleName, $script:ChildModuleName -Force -ErrorAction SilentlyContinue
    Import-Module -Name $script:ChildManifestPath -Force -ErrorAction Stop
    $script:ChildParameterNames = @{}
    foreach ($commandName in $script:ChildExports) {
      $childCommand = Get-Command -Name $commandName -Module $script:ChildModuleName -CommandType Function
      $script:ChildParameterNames[$commandName] = @($childCommand.Parameters.Keys | Sort-Object)
    }
    Import-Module -Name $script:ParentManifestPath -Force -ErrorAction Stop
  }

  AfterAll {
    Remove-Module -Name $script:ParentModuleName, $script:ChildModuleName -Force -ErrorAction SilentlyContinue
  }

  It 're-exports every child command with identical parameter metadata' {
    foreach ($commandName in $script:ChildExports) {
      $parentCommand = Get-Command -Name $commandName -Module $script:ParentModuleName -CommandType Function

      $parentCommand | Should -Not -BeNullOrEmpty
      @($parentCommand.Parameters.Keys | Sort-Object) |
        Should -Be $script:ChildParameterNames[$commandName]
    }
  }

  It 'forwards named arguments to the child implementation' {
    $result = ATAP.Utilities.BuildTooling.PowerShell\New-PesterItBlock `
      -Name 'returns the generated model' `
      -Body '$true | Should -BeTrue'

    $result.Name | Should -Be 'returns the generated model'
    $result.Body | Should -Be '$true | Should -BeTrue'
  }
}
