#Requires -Module Pester

<#
.SYNOPSIS
  Pester 5+ tests for Build-PSModuleManifest.
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
      param([string]$Root, [string]$Name = 'TempManifestModule')
      $srcDir = Join-Path $Root 'src'
      New-Item -ItemType Directory -Path $srcDir -Force | Out-Null
      $manifestPath = Join-Path $srcDir "$Name.psd1"
      # Use a script-module-less manifest (no RootModule) so the generated manifest
      # can be validated in an output directory that does not contain the .psm1 file.
      New-ModuleManifest `
        -Path $manifestPath `
        -ModuleVersion '0.0.1' `
        -Author 'test' `
        -CompanyName 'test' `
        -Description 'test fixture manifest' `
        -FunctionsToExport @('Invoke-TempNoop')
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
}
