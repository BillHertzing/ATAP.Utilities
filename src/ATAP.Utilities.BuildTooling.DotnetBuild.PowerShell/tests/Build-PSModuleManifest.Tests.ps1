#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

<#
.SYNOPSIS
  Pester 6.2+ tests for Build-PSModuleManifest.
.NOTES
  AI assisted using Powershell.instructions.md as guidelines
#>

Describe 'Build-PSModuleManifest' {

  BeforeAll {
    $script:CmdletPath = Join-Path -Path $PSScriptRoot -ChildPath '..\public\Build-PSModuleManifest.ps1'
    $script:CmdletPath = (Resolve-Path -Path $script:CmdletPath).ProviderPath
    . $script:CmdletPath

    if (-not (Get-Module -Name PSFramework -ListAvailable)) {
      function Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$args) }
    }

    function New-TempManifestRoot {
      $tmp = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.IO.Path]::GetRandomFileName())
      New-Item -ItemType Directory -Path $tmp -Force | Out-Null
      return $tmp
    }

    function New-ValidSourceManifest {
      param(
        [string]$Root,
        [string]$Name = 'TempManifestModule',
        [string]$Prerelease = ''
      )
      $srcDir = Join-Path $Root 'src'
      New-Item -ItemType Directory -Path $srcDir -Force | Out-Null
      $manifestPath = Join-Path $srcDir "$Name.psd1"
      # Use a script-module-less manifest (no RootModule) so the generated manifest
      # can be validated in an output directory that does not contain the .psm1 file.
      $manifestParameters = @{
        Path              = $manifestPath
        ModuleVersion     = '0.0.1'
        Author            = 'test'
        CompanyName       = 'test'
        Description       = 'test fixture manifest'
        FunctionsToExport = @('Invoke-TempNoop')
      }
      if (-not [string]::IsNullOrWhiteSpace($Prerelease)) {
        $manifestParameters['Prerelease'] = $Prerelease
      }
      New-ModuleManifest @manifestParameters
      return $manifestPath
    }
  }

  Context 'stable version (no Prerelease)' {
    BeforeEach {
      $script:Root = New-TempManifestRoot
      $script:Source = New-ValidSourceManifest -Root $script:Root
      $script:Output = Join-Path $script:Root 'out\Generated.psd1'
    }

    AfterEach {
      if (Test-Path $script:Root) {
        Remove-Item -Path $script:Root -Recurse -Force -ErrorAction SilentlyContinue
      }
    }

    It 'produces a manifest that passes Test-ModuleManifest' {
      $fileInfo = Build-PSModuleManifest `
        -SourceManifestPath $script:Source `
        -OutputManifestPath $script:Output `
        -ModuleVersion ([version]'1.2.3') `
        -PublicFunctions @('Invoke-TempNoop') `
        -Confirm:$false

      $fileInfo | Should -Not -BeNullOrEmpty
      Test-Path $script:Output | Should -BeTrue

      $validated = Test-ModuleManifest -Path $script:Output -ErrorAction Stop
      $validated.Version | Should -Be ([version]'1.2.3')
    }

    It 'clears a copied source prerelease when the generated version is stable' {
      $sourceWithPrerelease = New-ValidSourceManifest -Root $script:Root -Prerelease 'Alpha002'

      $fileInfo = Build-PSModuleManifest `
        -SourceManifestPath $sourceWithPrerelease `
        -OutputManifestPath $script:Output `
        -ModuleVersion ([version]'1.2.3') `
        -Prerelease '' `
        -PublicFunctions @('Invoke-TempNoop') `
        -Confirm:$false

      $fileInfo | Should -Not -BeNullOrEmpty
      { Test-ModuleManifest -Path $script:Output -ErrorAction Stop } | Should -Not -Throw

      $data = Import-PowerShellDataFile -Path $script:Output
      $data.PrivateData.PSData.Keys | Should -Not -Contain 'Prerelease'
    }

    It 'accepts a source manifest that omits RequiredModules' {
      $sourceWithoutDependencies = Join-Path $script:Root 'src\NoDependencies.psd1'
      @"
@{
  ModuleVersion = '0.0.1'
  GUID = '7d0e649e-cd04-4c97-a64d-773e2c13f67a'
  Author = 'test'
  Description = 'manifest without a RequiredModules key'
  FunctionsToExport = @()
}
"@ | Set-Content -LiteralPath $sourceWithoutDependencies -Encoding utf8

      {
        Build-PSModuleManifest `
          -SourceManifestPath $sourceWithoutDependencies `
          -OutputManifestPath $script:Output `
          -ModuleVersion ([version]'1.2.3') `
          -Confirm:$false
      } | Should -Not -Throw

      (Import-PowerShellDataFile -LiteralPath $script:Output).ContainsKey('RequiredModules') | Should -BeFalse
    }
  }

  Context 'prerelease version' {
    BeforeEach {
      $script:Root = New-TempManifestRoot
      $script:Source = New-ValidSourceManifest -Root $script:Root
      $script:Output = Join-Path $script:Root 'out\GeneratedAlpha.psd1'
    }

    AfterEach {
      if (Test-Path $script:Root) {
        Remove-Item -Path $script:Root -Recurse -Force -ErrorAction SilentlyContinue
      }
    }

    It 'produces a manifest with Prerelease set that passes Test-ModuleManifest' {
      $fileInfo = Build-PSModuleManifest `
        -SourceManifestPath $script:Source `
        -OutputManifestPath $script:Output `
        -ModuleVersion ([version]'1.2.3') `
        -Prerelease 'Alpha6' `
        -PublicFunctions @('Invoke-TempNoop') `
        -Confirm:$false

      $fileInfo | Should -Not -BeNullOrEmpty
      { Test-ModuleManifest -Path $script:Output -ErrorAction Stop } | Should -Not -Throw

      $data = Import-PowerShellDataFile -Path $script:Output
      $data.PrivateData.PSData.Prerelease | Should -Be 'Alpha6'
    }
  }

  Context 'invalid source manifest' {
    BeforeEach {
      $script:Root = New-TempManifestRoot
      $script:Output = Join-Path $script:Root 'out\NeverWritten.psd1'
    }

    AfterEach {
      if (Test-Path $script:Root) {
        Remove-Item -Path $script:Root -Recurse -Force -ErrorAction SilentlyContinue
      }
    }

    It 'throws when the source manifest path does not exist' {
      $missing = Join-Path $script:Root 'missing.psd1'
      {
        Build-PSModuleManifest `
          -SourceManifestPath $missing `
          -OutputManifestPath $script:Output `
          -ModuleVersion ([version]'1.2.3') `
          -Confirm:$false
      } | Should -Throw
    }

    It 'throws when the source manifest exists but is structurally invalid' {
      $bad = Join-Path $script:Root 'bad.psd1'
      Set-Content -Path $bad -Value 'this is not a valid manifest' -Encoding utf8
      {
        Build-PSModuleManifest `
          -SourceManifestPath $bad `
          -OutputManifestPath $script:Output `
          -ModuleVersion ([version]'1.2.3') `
          -Confirm:$false
      } | Should -Throw
    }
  }

  Context 'family module layout' {
    BeforeEach {
      $script:Root = New-TempManifestRoot
      $script:ModuleRoot = Join-Path $script:Root 'ATAP.Utilities.BuildTooling.Sample.PowerShell'
      New-Item -ItemType Directory -Path (Join-Path $script:ModuleRoot 'public') -Force | Out-Null
      "function Get-Sample { 'sample' }" | Set-Content -Path (Join-Path $script:ModuleRoot 'public\Get-Sample.ps1') -Encoding utf8
      $script:Source = Join-Path $script:ModuleRoot 'ATAP.Utilities.BuildTooling.Sample.PowerShell.psd1'
      New-ModuleManifest -Path $script:Source -RootModule 'ATAP.Utilities.BuildTooling.Sample.PowerShell.psm1' -ModuleVersion '0.1.0' -PowerShellVersion '7.0' -CompatiblePSEditions Core -FunctionsToExport @()
      $script:Output = Join-Path $script:Root 'out\Generated.psd1'
      New-Item -ItemType Directory -Path (Split-Path -Parent $script:Output) -Force | Out-Null
      Set-Content -LiteralPath (Join-Path (Split-Path -Parent $script:Output) 'ATAP.Utilities.BuildTooling.Sample.PowerShell.psm1') -Value '' -Encoding utf8
    }

    AfterEach { Remove-Item -LiteralPath $script:Root -Recurse -Force -ErrorAction SilentlyContinue }

    It 'derives explicit exports from public files when ModuleRoot is provided' {
      Build-PSModuleManifest -SourceManifestPath $script:Source -OutputManifestPath $script:Output -ModuleVersion ([version]'1.2.3') -ModuleRoot $script:ModuleRoot -Confirm:$false | Out-Null
      (Import-PowerShellDataFile $script:Output).FunctionsToExport | Should -Be @('Get-Sample')
    }

    It 'rejects a ModuleRoot whose folder name does not match the manifest BaseName' {
      $wrongRoot = Join-Path $script:Root 'WrongFolder'
      New-Item -ItemType Directory -Path $wrongRoot -Force | Out-Null
      { Build-PSModuleManifest -SourceManifestPath $script:Source -OutputManifestPath $script:Output -ModuleVersion ([version]'1.2.3') -ModuleRoot $wrongRoot -Confirm:$false } | Should -Throw
    }
  }

  Context 'family dependency composition' {
    BeforeEach {
      $script:Root = New-TempManifestRoot
      $script:Source = New-ValidSourceManifest -Root $script:Root -Name 'Composition'
      $script:Output = Join-Path $script:Root 'out/Composition.psd1'
      $script:Family = Join-Path $script:Root 'ModuleFamily.psd1'
      $script:DependencyGuid = [guid]'88888888-1111-2222-3333-444444444444'
      $script:PreviousModulePath = $env:PSModulePath
      $modules = Join-Path $script:Root 'modules'
      foreach ($name in @('Fixture.Internal', 'Fixture.Appended', 'Fixture.External')) {
        $folder = Join-Path $modules $name
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        New-ModuleManifest -Path (Join-Path $folder "$name.psd1") -ModuleVersion '3.0.0' -Guid $script:DependencyGuid
      }
      $env:PSModulePath = $modules + [IO.Path]::PathSeparator + $env:PSModulePath
      @'
@{
  Members = @(
    @{
      Name = 'Composition'
      Dependencies = @('Fixture.Internal', 'Fixture.Appended', 'FIXTURE.INTERNAL')
      MinimumVersions = @{ 'Fixture.Internal' = '2.0.0'; 'Fixture.Appended' = '1.0.0' }
    }
  )
}
'@ | Set-Content -LiteralPath $script:Family -Encoding utf8
      function Set-CompositionDependencies {
        param([object[]]$Dependencies)
        New-ModuleManifest -Path $script:Source -ModuleVersion '0.0.1' -RequiredModules $Dependencies
      }
      function Invoke-Composition {
        Build-PSModuleManifest -SourceManifestPath $script:Source -OutputManifestPath $script:Output -ModuleVersion ([version]'1.0.0') -ModuleFamilyPath $script:Family -Confirm:$false | Out-Null
        (Import-PowerShellDataFile -LiteralPath $script:Output).RequiredModules
      }
    }
    AfterEach {
      $env:PSModulePath = $script:PreviousModulePath
      # Keep generated manifests beneath evidence TEMP for independent readback.
    }

    It 'retains external exact pins first, source order and GUID while updating family floors and appending once' {
      Set-CompositionDependencies @(
        @{ ModuleName = 'Pester'; RequiredVersion = '6.2.0' }
        'Fixture.External'
        @{ ModuleName = 'fixture.internal'; ModuleVersion = '1.0.0'; GUID = $script:DependencyGuid }
      )
      $actual = @(Invoke-Composition)
      @($actual | ForEach-Object { if ($_ -is [string]) { $_ } else { $_.ModuleName } }) |
        Should -Be @('Pester', 'Fixture.External', 'fixture.internal', 'Fixture.Appended')
      $actual[0].RequiredVersion | Should -Be '6.2.0'
      $actual[1] | Should -Be 'Fixture.External'
      $actual[2].ModuleVersion | Should -Be '2.0.0'
      $actual[2].GUID | Should -Be $script:DependencyGuid
      (Test-ModuleManifest -Path $script:Output -ErrorAction Stop).Version | Should -Be ([version]'1.0.0')
    }

    It 'keeps a stronger source minimum and maximum constraint' {
      Set-CompositionDependencies @(@{ ModuleName = 'Fixture.Internal'; ModuleVersion = '3.0.0'; MaximumVersion = '3.*' })
      $actual = @(Invoke-Composition)
      $actual[0].ModuleVersion | Should -Be '3.0.0'
      $actual[0].MaximumVersion | Should -Be '3.*'
    }

    It 'preserves a compatible exact internal version without adding a conflicting minimum key' {
      Set-CompositionDependencies @(@{ ModuleName = 'Fixture.Internal'; RequiredVersion = '3.0.0'; GUID = $script:DependencyGuid })
      $actual = @(Invoke-Composition)
      $actual[0].RequiredVersion | Should -Be '3.0.0'
      $actual[0].GUID | Should -Be $script:DependencyGuid
      $actual[0].ContainsKey('ModuleVersion') | Should -BeFalse
    }

    It 'rejects an exact source version below the family floor' {
      Set-CompositionDependencies @(@{ ModuleName = 'Fixture.Internal'; RequiredVersion = '1.0.0' })
      { Invoke-Composition } | Should -Throw '*RequiredVersion*conflicts*'
    }

    It 'rejects a maximum below the effective family floor' {
      Set-CompositionDependencies @(@{ ModuleName = 'Fixture.Internal'; MaximumVersion = '1.*' })
      { Invoke-Composition } | Should -Throw '*minimum*exceeds MaximumVersion*'
    }

    It 'merges duplicate source names case-insensitively without losing the stronger minimum' {
      Set-CompositionDependencies @('Fixture.Internal', @{ ModuleName = 'FIXTURE.INTERNAL'; ModuleVersion = '3.0.0' })
      $actual = @(Invoke-Composition)
      $actual.Count | Should -Be 2
      $actual[0].ModuleName | Should -Be 'Fixture.Internal'
      $actual[0].ModuleVersion | Should -Be '3.0.0'
    }

    It 'rejects conflicting exact constraints on duplicate source names' {
      Set-CompositionDependencies @(@{ ModuleName = 'Fixture.Internal'; RequiredVersion = '3.0.0' }, @{ ModuleName = 'fixture.internal'; RequiredVersion = '2.0.0' })
      { Invoke-Composition } | Should -Throw '*Conflicting RequiredVersion*'
    }

    It 'deduplicates unconstrained external strings while preserving a valid string declaration' {
      Set-CompositionDependencies @('Fixture.External', 'FIXTURE.EXTERNAL')
      $actual = @(Invoke-Composition)
      $actual.Count | Should -Be 3
      $actual[0] | Should -Be 'Fixture.External'
    }

    It 'intersects duplicate external version bounds without relaxing either declaration' {
      Set-CompositionDependencies @(
        @{ ModuleName = 'Fixture.External'; ModuleVersion = '1.0.0'; MaximumVersion = '3.*' }
        @{ ModuleName = 'FIXTURE.EXTERNAL'; ModuleVersion = '2.0.0'; MaximumVersion = '4.*' }
      )
      $actual = @(Invoke-Composition)
      $actual.Count | Should -Be 3
      $actual[0].ModuleVersion | Should -Be '2.0.0'
      $actual[0].MaximumVersion | Should -Be '3.*'
    }

    It 'rejects conflicting GUID constraints on duplicate source names' {
      Set-CompositionDependencies @(@{ ModuleName = 'Fixture.Internal'; ModuleVersion = '1.0.0'; GUID = $script:DependencyGuid }, @{ ModuleName = 'fixture.internal'; ModuleVersion = '1.0.0'; GUID = '99999999-1111-2222-3333-444444444444' })
      { Invoke-Composition } | Should -Throw '*Conflicting GUID*'
    }

    It 'emits a valid exact specification after intersecting compatible duplicate upper bounds' {
      Set-CompositionDependencies @(
        @{ ModuleName = 'Fixture.Internal'; RequiredVersion = '3.0.0'; GUID = $script:DependencyGuid }
        @{ ModuleName = 'fixture.internal'; ModuleVersion = '2.0.0'; MaximumVersion = '3.*' }
      )
      $actual = @(Invoke-Composition)
      $actual.Count | Should -Be 2
      $actual[0].RequiredVersion | Should -Be '3.0.0'
      $actual[0].GUID | Should -Be $script:DependencyGuid
      $actual[0].ContainsKey('ModuleVersion') | Should -BeFalse
      $actual[0].ContainsKey('MaximumVersion') | Should -BeFalse
      { Test-ModuleManifest -Path $script:Output -ErrorAction Stop } | Should -Not -Throw
    }

    It 'rejects duplicate upper bounds that exclude the exact version' {
      Set-CompositionDependencies @(
        @{ ModuleName = 'Fixture.Internal'; RequiredVersion = '3.0.0' }
        @{ ModuleName = 'fixture.internal'; MaximumVersion = '2.*' }
      )
      { Invoke-Composition } | Should -Throw '*RequiredVersion*conflicts*'
    }

    It 'emits family-only dependencies in metadata order without duplicates' {
      $actual = @(Invoke-Composition)
      @($actual.ModuleName) | Should -Be @('Fixture.Internal', 'Fixture.Appended')
    }

    It 'leaves source dependency constraints and order unchanged without family metadata' {
      Set-CompositionDependencies @(@{ ModuleName = 'Pester'; RequiredVersion = '6.2.0' }, 'Fixture.External')
      Build-PSModuleManifest -SourceManifestPath $script:Source -OutputManifestPath $script:Output -ModuleVersion ([version]'1.0.0') -Confirm:$false | Out-Null
      $actual = (Import-PowerShellDataFile -LiteralPath $script:Output).RequiredModules
      $actual[0].ModuleName | Should -Be 'Pester'
      $actual[0].RequiredVersion | Should -Be '6.2.0'
      $actual[1] | Should -Be 'Fixture.External'
    }
  }

}
