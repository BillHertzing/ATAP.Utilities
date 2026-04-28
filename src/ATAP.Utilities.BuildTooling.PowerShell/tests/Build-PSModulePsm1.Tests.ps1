#Requires -Module Pester

<#
.SYNOPSIS
  Pester 5+ tests for Build-PSModulePsm1.
.NOTES
  AI assisted using Powershell.instructions.md as guidelines
#>

Describe 'Build-PSModulePsm1' {

  BeforeAll {
    $script:CmdletPath = Join-Path -Path $PSScriptRoot -ChildPath '..\public\Build-PSModulePsm1.ps1'
    $script:CmdletPath = (Resolve-Path -Path $script:CmdletPath).ProviderPath
    . $script:CmdletPath

    # Ensure PSFramework logging does not fail the dot-sourced script
    if (-not (Get-Module -Name PSFramework -ListAvailable)) {
      function Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$args) }
    }

    function New-TempModuleRoot {
      $tmp = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.IO.Path]::GetRandomFileName())
      New-Item -ItemType Directory -Path $tmp -Force | Out-Null
      return $tmp
    }
  }

  Context 'empty module (no .ps1 files)' {
    BeforeEach {
      $script:ModuleRoot = New-TempModuleRoot
      New-Item -ItemType Directory -Path (Join-Path $script:ModuleRoot 'public') -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $script:ModuleRoot 'private') -Force | Out-Null
      $script:OutputPath = Join-Path $script:ModuleRoot 'Out\Empty.psm1'
    }

    AfterEach {
      if (Test-Path $script:ModuleRoot) {
        Remove-Item -Path $script:ModuleRoot -Recurse -Force -ErrorAction SilentlyContinue
      }
    }

    It 'writes an empty .psm1 without throwing' {
      { Build-PSModulePsm1 -ModuleRoot $script:ModuleRoot -OutputPath $script:OutputPath -Confirm:$false } |
        Should -Not -Throw
      Test-Path -Path $script:OutputPath | Should -BeTrue
      # utf8BOM preamble (3 bytes) plus Set-Content trailing line terminator; <= 5 bytes total.
      (Get-Item -LiteralPath $script:OutputPath).Length | Should -BeLessOrEqual 5
      $rawContent = Get-Content -Path $script:OutputPath -Raw
      ([string]::IsNullOrWhiteSpace($rawContent)) | Should -BeTrue
    }
  }

  Context 'module with using statements in two different files' {
    BeforeEach {
      $script:ModuleRoot = New-TempModuleRoot
      $publicDir = Join-Path $script:ModuleRoot 'public'
      New-Item -ItemType Directory -Path $publicDir -Force | Out-Null

      $fileA = Join-Path $publicDir 'A.ps1'
      $fileB = Join-Path $publicDir 'B.ps1'
      @'
using namespace System.Collections.Generic
using namespace System.IO

function Invoke-A { 'A' }
'@ | Set-Content -Path $fileA -Encoding utf8

      @'
using namespace System.IO
using namespace System.Text

function Invoke-B { 'B' }
'@ | Set-Content -Path $fileB -Encoding utf8

      $script:OutputPath = Join-Path $script:ModuleRoot 'Out\WithUsings.psm1'
    }

    AfterEach {
      if (Test-Path $script:ModuleRoot) {
        Remove-Item -Path $script:ModuleRoot -Recurse -Force -ErrorAction SilentlyContinue
      }
    }

    It 'deduplicates and hoists using statements to the top' {
      Build-PSModulePsm1 -ModuleRoot $script:ModuleRoot -OutputPath $script:OutputPath -Confirm:$false | Out-Null
      $content = Get-Content -Path $script:OutputPath -Raw

      # Unique using statements present
      ($content | Select-String -Pattern 'using namespace System\.Collections\.Generic').Count | Should -Be 1
      ($content | Select-String -Pattern 'using namespace System\.IO').Count | Should -Be 1
      ($content | Select-String -Pattern 'using namespace System\.Text').Count | Should -Be 1

      # All using lines appear before the first file header comment
      $firstHeaderIdx = $content.IndexOf('# A.ps1')
      $lastUsingIdx = ($content | Select-String -Pattern 'using namespace' -AllMatches).Matches |
        ForEach-Object { $_.Index } | Sort-Object -Descending | Select-Object -First 1
      $lastUsingIdx | Should -BeLessThan $firstHeaderIdx

      # Using statements are NOT still present inside the file bodies
      $bodyRegion = $content.Substring($firstHeaderIdx)
      $bodyRegion | Should -Not -Match 'using\s+namespace'
    }
  }

  Context 'module with only private functions' {
    BeforeEach {
      $script:ModuleRoot = New-TempModuleRoot
      New-Item -ItemType Directory -Path (Join-Path $script:ModuleRoot 'public') -Force | Out-Null
      $privateDir = Join-Path $script:ModuleRoot 'private'
      New-Item -ItemType Directory -Path $privateDir -Force | Out-Null

      @'
function Get-PrivateFoo {
  'foo-private'
}
'@ | Set-Content -Path (Join-Path $privateDir 'Get-PrivateFoo.ps1') -Encoding utf8

      @'
function Get-PrivateBar {
  'bar-private'
}
'@ | Set-Content -Path (Join-Path $privateDir 'Get-PrivateBar.ps1') -Encoding utf8

      $script:OutputPath = Join-Path $script:ModuleRoot 'Out\PrivateOnly.psm1'
    }

    AfterEach {
      if (Test-Path $script:ModuleRoot) {
        Remove-Item -Path $script:ModuleRoot -Recurse -Force -ErrorAction SilentlyContinue
      }
    }

    It 'concatenates private files and produces a .psm1 with both functions' {
      Build-PSModulePsm1 -ModuleRoot $script:ModuleRoot -OutputPath $script:OutputPath -Confirm:$false | Out-Null
      $content = Get-Content -Path $script:OutputPath -Raw

      $content | Should -Match '# Get-PrivateFoo\.ps1'
      $content | Should -Match '# Get-PrivateBar\.ps1'
      $content | Should -Match 'function Get-PrivateFoo'
      $content | Should -Match 'function Get-PrivateBar'
    }
  }
}
