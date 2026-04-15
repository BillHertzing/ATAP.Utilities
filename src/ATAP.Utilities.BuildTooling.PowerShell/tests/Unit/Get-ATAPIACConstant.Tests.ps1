# tests/Unit/Get-ATAPIACConstant.Tests.ps1
#
# Pester 5+ unit tests for Get-ATAPIACConstant.
# Uses temp-directory scaffolding to simulate the ATAP.IAC sibling repo and
# the global:settings / global:configRootKeys back-compat path.
# No actual ATAP.IAC repository is required.

#Requires -Module Pester

BeforeAll {
  $script:publicDir = Join-Path $PSScriptRoot '..\..\public' | Resolve-Path
  . (Join-Path $script:publicDir 'Get-ATAPIACConstant.ps1')

  # Stub Write-PSFMessage if PSFramework is not installed
  if (-not (Get-Module -ListAvailable -Name PSFramework)) {
    function Write-PSFMessage { param( [Parameter(ValueFromRemainingArguments = $true)] $rest ) }
  } else {
    Import-Module PSFramework -ErrorAction SilentlyContinue
  }

  # Helper: create a temp ATAP.IAC sibling layout with the given constants hashtable
  function New-TempIACLayout {
    param(
      [hashtable] $Constants,
      [string]    $PsdFileName = 'constants.psd1'
    )
    # Root temp dir acts as the 'parent of both repos'
    $tempRoot = [System.IO.Path]::GetTempPath()
    $parentDir = Join-Path $tempRoot ('IACTest_' + [System.Guid]::NewGuid().ToString('N'))
    $fakeRepo = Join-Path $parentDir 'FakeRepo'       # stands in for "this" repo root
    $iacRoot = Join-Path $parentDir 'ATAP.IAC'
    $constDir = Join-Path $iacRoot 'constants'

    New-Item -ItemType Directory -Path $fakeRepo -Force | Out-Null
    New-Item -ItemType Directory -Path $constDir -Force | Out-Null

    # Write constants as a psd1
    $lines = '@{' + [System.Environment]::NewLine
    foreach ($kv in $Constants.GetEnumerator()) {
      $val = if ($kv.Value -is [string]) { "'$($kv.Value)'" } else { "$($kv.Value)" }
      $lines += "  $($kv.Key) = $val" + [System.Environment]::NewLine
    }
    $lines += '}'
    Set-Content -Path (Join-Path $constDir $PsdFileName) -Value $lines -Encoding utf8

    # Make fakeRepo look like a git repo so rev-parse can succeed
    $gitDir = Join-Path $fakeRepo '.git'
    New-Item -ItemType Directory -Path $gitDir -Force | Out-Null

    return [PSCustomObject]@{
      ParentDir    = $parentDir
      FakeRepoRoot = $fakeRepo
      IACRoot      = $iacRoot
      ConstantsDir = $constDir
    }
  }
}

AfterAll {
  # Restore globals if tests modified them
  Remove-Variable -Name configRootKeys -Scope Global -ErrorAction SilentlyContinue
  Remove-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue
}

Describe 'Get-ATAPIACConstant' {

  Context 'Parameter validation' {
    It 'Throws when Name is null' {
      { Get-ATAPIACConstant -Name $null } | Should -Throw
    }
    It 'Throws when Name is empty string' {
      { Get-ATAPIACConstant -Name '' } | Should -Throw
    }
    It 'Throws when Name is whitespace' {
      { Get-ATAPIACConstant -Name '   ' } | Should -Throw
    }
  }

  Context 'Stage 1 — global:settings back-compat path' {
    BeforeAll {
      $global:configRootKeys = @{ PowerShellGetFeed_Alpha = 'PowerShellGetFeed_Alpha_SettingsKey' }
      $global:settings = @{ PowerShellGetFeed_Alpha_SettingsKey = 'PowershellGet-development' }
    }
    AfterAll {
      Remove-Variable -Name configRootKeys -Scope Global -ErrorAction SilentlyContinue
      Remove-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue
    }

    It 'Returns the value from global:settings when the key exists' {
      $result = Get-ATAPIACConstant -Name 'PowerShellGetFeed_Alpha'
      $result | Should -BeExactly 'PowershellGet-development'
    }

    It 'Falls through to Stage 2 when the key is not in configRootKeys' {
      # Stage 2 will fail because there is no real ATAP.IAC repo on disk;
      # what matters is that Stage 1 does not throw for a missing key.
      { Get-ATAPIACConstant -Name 'NonExistentKey_XYZ' } | Should -Throw -Because 'Stage 2 cannot find ATAP.IAC from the Pester working directory'
    }
  }

  Context 'Stage 2 — direct psd1 file load (globals absent)' {
    BeforeAll {
      Remove-Variable -Name configRootKeys -Scope Global -ErrorAction SilentlyContinue
      Remove-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue

      $script:layout = New-TempIACLayout -Constants @{
        PowerShellGetFeed_Sprint          = 'PowershellGet-experimental'
        PowerShellGetFeed_Alpha           = 'PowershellGet-development'
        PowerShellGetFeed_Beta            = 'PowershellGet-integration'
        PowerShellGetFeed_QA              = 'PowershellGet-qa'
        PowerShellGetFeed_Production      = 'PowershellGet-stable'
        PassingCodeCoveragePct_PowerShell = 70
      }

      # Redirect git rev-parse to return the fake repo root
      $script:origGit = Get-Command git -ErrorAction SilentlyContinue
      $fakeRepoRoot = $script:layout.FakeRepoRoot
      function global:git {
        param([Parameter(ValueFromRemainingArguments = $true)] $args)
        if ($args -contains '--show-toplevel') { return $fakeRepoRoot }
        & $script:origGit.Source @args
      }
    }

    AfterAll {
      Remove-Item -Path $script:layout.ParentDir -Recurse -Force -ErrorAction SilentlyContinue
      Remove-Item -Path 'Function:\git' -ErrorAction SilentlyContinue
    }

    It 'Resolves PowerShellGetFeed_Sprint from the psd1' {
      $result = Get-ATAPIACConstant -Name 'PowerShellGetFeed_Sprint'
      $result | Should -BeExactly 'PowershellGet-experimental'
    }
    It 'Resolves PowerShellGetFeed_Alpha from the psd1' {
      $result = Get-ATAPIACConstant -Name 'PowerShellGetFeed_Alpha'
      $result | Should -BeExactly 'PowershellGet-development'
    }
    It 'Resolves PowerShellGetFeed_Beta from the psd1' {
      $result = Get-ATAPIACConstant -Name 'PowerShellGetFeed_Beta'
      $result | Should -BeExactly 'PowershellGet-integration'
    }
    It 'Resolves PowerShellGetFeed_QA from the psd1' {
      $result = Get-ATAPIACConstant -Name 'PowerShellGetFeed_QA'
      $result | Should -BeExactly 'PowershellGet-qa'
    }
    It 'Resolves PowerShellGetFeed_Production from the psd1' {
      $result = Get-ATAPIACConstant -Name 'PowerShellGetFeed_Production'
      $result | Should -BeExactly 'PowershellGet-stable'
    }
    It 'Resolves PassingCodeCoveragePct_PowerShell (integer 70) from the psd1' {
      $result = Get-ATAPIACConstant -Name 'PassingCodeCoveragePct_PowerShell'
      $result | Should -Be 70
    }
    It 'Throws with a helpful message when the key is not in any psd1' {
      { Get-ATAPIACConstant -Name 'ThisKeyDoesNotExist' } |
        Should -Throw -ExpectedMessage '*ThisKeyDoesNotExist*'
    }
  }

  Context 'Error paths' {
    BeforeAll {
      Remove-Variable -Name configRootKeys -Scope Global -ErrorAction SilentlyContinue
      Remove-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue

      $script:errorLayout = New-TempIACLayout -Constants @{ SomeKey = 'SomeValue' }
      $fakeRepoRoot = $script:errorLayout.FakeRepoRoot

      function global:git {
        param([Parameter(ValueFromRemainingArguments = $true)] $args)
        if ($args -contains '--show-toplevel') { return $fakeRepoRoot }
        & $script:origGit.Source @args
      }
    }

    AfterAll {
      Remove-Item -Path $script:errorLayout.ParentDir -Recurse -Force -ErrorAction SilentlyContinue
      Remove-Item -Path 'Function:\git' -ErrorAction SilentlyContinue
    }

    It 'Throws when ATAP.IAC sibling directory does not exist' {
      # Remove the IAC root so the stage-2 path fails
      Remove-Item -Path $script:errorLayout.IACRoot -Recurse -Force -ErrorAction SilentlyContinue
      { Get-ATAPIACConstant -Name 'AnyKey' } | Should -Throw -ExpectedMessage '*ATAP.IAC*'
    }
  }
}
