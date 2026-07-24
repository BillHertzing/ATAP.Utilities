#Requires -Module Pester

BeforeAll {
  $script:moduleRoot = (Join-Path $PSScriptRoot '..\..' | Resolve-Path).Path
  $script:manifestPath = Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell.psd1'
  $script:expectedCommands = @(
    'Build-ImageFromPlantUML'
    'Build-PSModuleManifest'
    'Build-PSModulePsm1'
    'Clear-NuGetCaches'
    'Compress-PSModuleArtifacts'
    'Get-BuildContext'
    'Get-PSModuleVersionFromNBGV'
    'Invoke-DotnetBuildWithRetry'
    'Invoke-DotnetNuGetPush'
    'Invoke-ModuleBuildWithRetry'
    'Invoke-MSBuildWithLists'
    'Invoke-PSModulePSScriptAnalyzer'
    'New-PSModuleNupkg'
    'Parse-MSBuildFile'
    'Resolve-FeatureSlug'
    'Resolve-PSModuleMetadata'
  )

  Remove-Module 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell' -Force -ErrorAction SilentlyContinue
  $script:module = Import-Module -Name $script:manifestPath -Force -PassThru -ErrorAction Stop
}

Describe 'DotnetBuild child module contract' -Tag 'Unit', 'Contract' {
  It 'exports exactly the frozen child-public surface' {
    $actual = @(Get-Command -Module $script:module.Name -CommandType Function |
        Select-Object -ExpandProperty Name |
        Sort-Object)
    Compare-Object ($script:expectedCommands | Sort-Object) $actual | Should -BeNullOrEmpty
  }

  It 'declares accepted immutable dependency floors' {
    $manifest = Import-PowerShellDataFile -LiteralPath $script:manifestPath
    $dependencies = @{}
    foreach ($requiredModule in $manifest.RequiredModules) {
      $dependencies[$requiredModule.ModuleName] = [string] $requiredModule.ModuleVersion
    }

    $dependencies['ATAP.Utilities.BuildTooling.Common.PowerShell'] | Should -BeExactly '0.1.7'
    $dependencies['ATAP.Utilities.BuildTooling.ProGet.PowerShell'] | Should -BeExactly '0.1.1'
  }

  It 'has no parse errors, top-level executable statements, Write-Host, or Invoke-Expression in function files' {
    $functionFiles = @(
      Get-ChildItem -LiteralPath (Join-Path $script:moduleRoot 'public') -File -Filter '*.ps1'
      Get-ChildItem -LiteralPath (Join-Path $script:moduleRoot 'private') -File -Filter '*.ps1'
    )
    foreach ($file in $functionFiles) {
      $tokens = $null
      $errors = $null
      $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref] $tokens,
        [ref] $errors
      )
      @($errors).Count | Should -Be 0 -Because $file.FullName

      $commands = @($ast.FindAll(
          { param($node) $node -is [System.Management.Automation.Language.CommandAst] },
          $true
        ) | ForEach-Object { $_.GetCommandName() })
      $commands | Should -Not -Contain 'Write-Host' -Because $file.FullName
      $commands | Should -Not -Contain 'Invoke-Expression' -Because $file.FullName

      if ($file.FullName -match '[\\/](public|private)[\\/]') {
        $topLevelExecutable = @($ast.EndBlock.Statements | Where-Object {
            $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $_ -isnot [System.Management.Automation.Language.UsingStatementAst]
          })
        $topLevelExecutable.Count | Should -Be 0 -Because $file.FullName
      }
    }
  }

  It 'parses MSBuild assembly metadata' {
    $projectPath = Join-Path $TestDrive 'Sample.csproj'
    @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <AssemblyName>ATAP.Sample</AssemblyName>
    <Description>Sample package</Description>
  </PropertyGroup>
</Project>
'@ | Set-Content -LiteralPath $projectPath

    $result = Parse-MSBuildFile -FilePath $projectPath -RelativePath 'src/Sample.csproj' -Confirm:$false
    $result.Name | Should -BeExactly 'ATAP.Sample'
    $result.Purpose | Should -BeExactly 'Sample package'
  }

  It 'does not invoke dotnet for a NuGet push under WhatIf' {
    $result = Invoke-DotnetNuGetPush `
      -NupkgPath (Join-Path $TestDrive 'sample.1.0.0.nupkg') `
      -FeedUri 'https://example.invalid/v3/index.json' `
      -ApiKey 'not-a-secret' `
      -WhatIf

    $result.ExitCode | Should -Be 0
    $result.WhatIf | Should -BeTrue
  }

  It 'expands one MSBuild combination under WhatIf without invoking dotnet' {
    $result = Invoke-MSBuildWithLists `
      -Path $TestDrive `
      -RuntimeTargetList 'win-x64' `
      -ConfigurationList 'Release' `
      -TargetFrameworkList 'net8.0' `
      -WhatIf

    $result.ExitCode | Should -Be 0
    $result.WhatIf | Should -BeTrue
    $result.Arguments -join ' ' | Should -Match 'dotnet|build'
  }
}
