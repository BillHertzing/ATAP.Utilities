#Requires -Module Pester

BeforeAll {
  $script:moduleRoot = (Join-Path $PSScriptRoot '..\..' | Resolve-Path).Path
  $script:manifestPath = Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell.psd1'
  $script:promotedManifest = [System.Environment]::GetEnvironmentVariable(
    'ATAP_PROMOTED_MODULE_MANIFEST',
    'Process'
  )
  $script:moduleToTest = if ([string]::IsNullOrWhiteSpace($script:promotedManifest)) {
    $script:manifestPath
  } else {
    $script:promotedManifest
  }
  $script:versionJsonPath = Join-Path $script:moduleRoot 'version.json'
  $script:releaseNotesPath = Join-Path $script:moduleRoot 'ReleaseNotes.md'

  function Get-StableBaseVersionForContract {
    param(
      [Parameter(Mandatory)]
      [AllowEmptyString()]
      [string] $Version
    )

    $semanticVersionPattern = '^(?<stable>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*))(?:-(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$'
    if ($Version -cnotmatch $semanticVersionPattern) {
      throw "Version '$Version' is not a complete semantic version."
    }

    return $Matches['stable']
  }

  $script:expectedCommands = @(
    'Build-ImageFromPlantUML'
    'Build-PSModuleManifest'
    'Build-PSModulePsm1'
    'Clear-NuGetCaches'
    'Compress-PSModuleArtifacts'
    'Get-BuildContext'
    'Get-PSModuleVersionFromNBGV'
    'Install-DabGlobalTool'
    'Initialize-DabMcpConfiguration'
    'Initialize-DabMcpServer'
    'Add-DabMcpEntity'
    'Invoke-DotnetBuildWithRetry'
    'Invoke-DotnetNuGetPush'
    'Invoke-ModuleBuildWithRetry'
    'Invoke-MSBuildWithLists'
    'Invoke-PSModulePSScriptAnalyzer'
    'New-PSModuleNupkg'
    'Parse-MSBuildFile'
    'Resolve-FeatureSlug'
    'Resolve-PSModuleMetadata'
    'Start-DabMcpServer'
    'Stop-ZombieMcpServerProcess'
    'Test-DabInstallation'
    'Test-DabMcpConfiguration'
  )

  Remove-Module 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell' -Force -ErrorAction SilentlyContinue
  $script:module = Import-Module -Name $script:moduleToTest -Force -PassThru -ErrorAction Stop
}

Describe 'DotnetBuild child module contract' -Tag 'Unit', 'Contract' {
  It 'exports exactly the frozen child-public surface' {
    $actual = @($script:module.ExportedFunctions.Keys | Sort-Object)
    Compare-Object ($script:expectedCommands | Sort-Object) $actual | Should -BeNullOrEmpty
  }

  It 'aligns the manifest and release notes with the adjacent stable version' {
    $manifest = Import-PowerShellDataFile -LiteralPath $script:manifestPath
    $versionDocument = Get-Content -LiteralPath $script:versionJsonPath -Raw | ConvertFrom-Json
    $stableBaseVersion = Get-StableBaseVersionForContract -Version ([string] $versionDocument.version)
    $releaseNotes = Get-Content -LiteralPath $script:releaseNotesPath -Raw
    $releaseHeading = [regex]::Match($releaseNotes, '(?m)^## (?<version>\S+)$')

    [string] $manifest.ModuleVersion | Should -BeExactly $stableBaseVersion
    $releaseHeading.Success | Should -BeTrue
    $releaseHeading.Groups['version'].Value | Should -BeExactly $stableBaseVersion
  }

  It 'derives stable base <Expected> from valid version <Version>' -ForEach @(
    @{ Version = '0.1.6'; Expected = '0.1.6' }
    @{ Version = '0.1.6-rc.2'; Expected = '0.1.6' }
    @{ Version = '10.20.30-alpha.1+build.5'; Expected = '10.20.30' }
  ) {
    Get-StableBaseVersionForContract -Version $Version | Should -BeExactly $Expected
  }

  It 'rejects malformed version <Version>' -ForEach @(
    @{ Version = '' }
    @{ Version = '0.1' }
    @{ Version = '01.1.6' }
    @{ Version = '0.01.6' }
    @{ Version = '0.1.06' }
    @{ Version = '0.1.6-01' }
    @{ Version = '0.1.6-' }
    @{ Version = '0.1.6+' }
  ) {
    { Get-StableBaseVersionForContract -Version $Version } | Should -Throw '*not a complete semantic version*'
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
