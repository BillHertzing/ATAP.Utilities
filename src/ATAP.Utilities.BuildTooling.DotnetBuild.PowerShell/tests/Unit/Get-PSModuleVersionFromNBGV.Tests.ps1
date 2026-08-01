# tests/Unit/Get-PSModuleVersionFromNBGV.Tests.ps1
#
# Pester 5+ unit tests for Get-PSModuleVersionFromNBGV. Because `nbgv` is not
# guaranteed to be present on the build agent (and because we want to control
# its output regardless), the external call is mocked with canned strings.

#Requires -Module Pester

BeforeAll {
  # Dot-source the function under test so we can mock its internal calls
  # without pulling in the whole module.
  $script:publicDir = Join-Path $PSScriptRoot '..\..\public' | Resolve-Path
  . (Join-Path $script:publicDir 'Get-PSModuleVersionFromNBGV.ps1')

  # Ensure PSFramework is available for Write-PSFMessage calls; fall back to a stub.
  if (-not (Get-Module -ListAvailable -Name PSFramework)) {
    function Write-PSFMessage { param( [Parameter(ValueFromRemainingArguments = $true)] $rest ) }
  } else {
    Import-Module PSFramework -ErrorAction SilentlyContinue
  }

  # Pester cannot Mock a command that does not already exist, so define a stub
  # 'nbgv' function that each test context overrides via Mock. The body is
  # intentionally harmless — Mock will replace it for the happy-path contexts.
  function global:nbgv { param([Parameter(ValueFromRemainingArguments = $true)]$args) '0.0.0-Stub.0' }

  # Fake module root — use TEMP because the function validates the directory exists.
  $script:fakeModuleRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('nbgvtest-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:fakeModuleRoot -Force | Out-Null
}

AfterAll {
  if (Test-Path -LiteralPath $script:fakeModuleRoot) {
    Remove-Item -LiteralPath $script:fakeModuleRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
  Remove-Item Function:\nbgv -ErrorAction SilentlyContinue
}

Describe 'Get-PSModuleVersionFromNBGV' {

  Context 'When nbgv is not installed' {
    BeforeAll {
      Mock -CommandName Get-Command -MockWith { $null } -ParameterFilter { $Name -eq 'nbgv' }
    }
    It 'Throws an error that mentions dotnet tool install -g nbgv' {
      { Get-PSModuleVersionFromNBGV -ModuleRoot $script:fakeModuleRoot } |
        Should -Throw -ExpectedMessage '*dotnet tool install -g nbgv*'
    }
  }

  Context 'When ModuleRoot does not exist' {
    It 'Throws a clear error' {
      { Get-PSModuleVersionFromNBGV -ModuleRoot 'Z:\definitely\not\a\real\path\ever' } |
        Should -Throw -ExpectedMessage '*does not exist*'
    }
  }

  Context 'When nbgv returns a Sprint prerelease (T1)' {
    BeforeAll {
      Mock -CommandName Get-Command -MockWith { [PSCustomObject]@{ Name = 'nbgv' } } -ParameterFilter { $Name -eq 'nbgv' }
      # Replace the external nbgv invocation with a function-scoped alias / stub
      Mock -CommandName 'nbgv' -MockWith { '0.1.0-Sprint.1'; $global:LASTEXITCODE = 0 }
    }
    It 'Returns ModuleVersion 0.1.0 and zero-padded Prerelease "Sprint001"' {
      $r = Get-PSModuleVersionFromNBGV -ModuleRoot $script:fakeModuleRoot
      $r.ModuleVersion | Should -Be ([System.Version]'0.1.0')
      $r.Prerelease | Should -BeExactly 'Sprint001'
      $r.FullNuGetVersion | Should -BeExactly '0.1.0-Sprint.1'
    }
  }

  Context 'When nbgv returns an Alpha prerelease (T2)' {
    BeforeAll {
      Mock -CommandName 'nbgv' -MockWith { '0.1.0-Alpha.6'; $global:LASTEXITCODE = 0 }
    }
    It 'Returns Prerelease "Alpha006" matching ^[A-Za-z0-9]+$' {
      $r = Get-PSModuleVersionFromNBGV -ModuleRoot $script:fakeModuleRoot
      $r.ModuleVersion | Should -Be ([System.Version]'0.1.0')
      $r.Prerelease | Should -BeExactly 'Alpha006'
      $r.Prerelease | Should -Match '^[A-Za-z0-9]+$'
    }
  }

  Context 'When nbgv returns a Beta prerelease (T3)' {
    BeforeAll {
      Mock -CommandName 'nbgv' -MockWith { '0.1.0-Beta.3'; $global:LASTEXITCODE = 0 }
    }
    It 'Returns Prerelease "Beta003"' {
      $r = Get-PSModuleVersionFromNBGV -ModuleRoot $script:fakeModuleRoot
      $r.Prerelease | Should -BeExactly 'Beta003'
      $r.ModuleVersion | Should -Be ([System.Version]'0.1.0')
    }
  }

  Context 'When nbgv returns a QA prerelease (T4)' {
    BeforeAll {
      Mock -CommandName 'nbgv' -MockWith { '0.1.0-QA.2'; $global:LASTEXITCODE = 0 }
    }
    It 'Returns Prerelease "QA002"' {
      $r = Get-PSModuleVersionFromNBGV -ModuleRoot $script:fakeModuleRoot
      $r.Prerelease | Should -BeExactly 'QA002'
      $r.ModuleVersion | Should -Be ([System.Version]'0.1.0')
    }
  }

  Context 'When nbgv returns a stable version (T5)' {
    BeforeAll {
      Mock -CommandName 'nbgv' -MockWith { '0.1.0'; $global:LASTEXITCODE = 0 }
    }
    It 'Returns an empty Prerelease' {
      $r = Get-PSModuleVersionFromNBGV -ModuleRoot $script:fakeModuleRoot
      $r.ModuleVersion | Should -Be ([System.Version]'0.1.0')
      $r.Prerelease | Should -BeExactly ''
    }
  }

  Context 'When nbgv returns a malformed version string' {
    BeforeAll {
      Mock -CommandName 'nbgv' -MockWith { 'not-a-version'; $global:LASTEXITCODE = 0 }
    }
    It 'Throws a clear parse error' {
      { Get-PSModuleVersionFromNBGV -ModuleRoot $script:fakeModuleRoot } |
        Should -Throw -ExpectedMessage '*does not match*'
    }
  }
}
