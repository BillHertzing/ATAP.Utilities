#Requires -Version 7.0

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Set-FloatingPackagePins.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
  if (-not (Get-Command Get-SecretATAP -ErrorAction SilentlyContinue)) {
    function global:Get-SecretATAP { param($SecretName, $SecretStoreType) 'test-proget-key' }
  }

  # Build a Directory.Packages.props fixture with a mix of floating ATAP.*,
  # pinned ATAP.*, and floating third-party entries.
  function New-PropsFixture {
    param([string]$Path)
    $content = @'
<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
    <CentralPackageFloatingVersionsEnabled>true</CentralPackageFloatingVersionsEnabled>
  </PropertyGroup>
  <ItemGroup Label="ATAP.Utilities (floating)">
    <PackageVersion Include="ATAP.Utilities.Philote" Version="0.*-*" />
    <PackageVersion Include="ATAP.Utilities.ETW" Version="0.*-*" />
  </ItemGroup>
  <ItemGroup Label="ATAP.Utilities (already pinned)">
    <PackageVersion Include="ATAP.Utilities.Configuration" Version="0.1.0-Alpha-009" />
  </ItemGroup>
  <ItemGroup Label="Third party (floating, must be ignored)">
    <PackageVersion Include="Syncfusion.Blazor" Version="32.*" />
  </ItemGroup>
</Project>
'@
    Set-Content -LiteralPath $Path -Value $content -Encoding UTF8
  }
}

Describe 'Set-FloatingPackagePins' {
  BeforeEach {
    Mock -CommandName Get-SecretATAP -MockWith { 'test-proget-key' }
    $script:propsPath = Join-Path -Path $TestDrive -ChildPath 'Directory.Packages.props'
    New-PropsFixture -Path $script:propsPath
  }

  Context 'pinning floating ATAP.* entries' {
    BeforeEach {
      Mock -CommandName Invoke-RestMethod -MockWith {
        param($Uri)
        if ($Uri -match 'atap\.utilities\.philote') {
          return [pscustomobject]@{ versions = @('0.1.0-Sprint.40', '0.1.0-Sprint.42', '0.1.0-Alpha-009') }
        }
        if ($Uri -match 'atap\.utilities\.etw') {
          return [pscustomobject]@{ versions = @('0.2.0', '0.1.0-Sprint.99') }
        }
        throw "Unexpected package query: $Uri"
      }
    }

    It 'rewrites floating ATAP.* versions to the highest concrete version' {
      $result = Set-FloatingPackagePins -PackagePropsPath $script:propsPath -ProGetUrl 'http://proget.local:50000'

      $result.PackagesPinned['ATAP.Utilities.Philote'] | Should -Be '0.1.0-Sprint.42'
      # Stable 0.2.0 outranks any prerelease for ETW
      $result.PackagesPinned['ATAP.Utilities.ETW'] | Should -Be '0.2.0'

      [xml]$rewritten = Get-Content -LiteralPath $script:propsPath -Raw
      $philote = $rewritten.SelectSingleNode("//PackageVersion[@Include='ATAP.Utilities.Philote']")
      $philote.Version | Should -Be '0.1.0-Sprint.42'
    }

    It 'leaves already-pinned ATAP.* entries untouched' {
      Set-FloatingPackagePins -PackagePropsPath $script:propsPath -ProGetUrl 'http://proget.local:50000' | Out-Null

      [xml]$rewritten = Get-Content -LiteralPath $script:propsPath -Raw
      $config = $rewritten.SelectSingleNode("//PackageVersion[@Include='ATAP.Utilities.Configuration']")
      $config.Version | Should -Be '0.1.0-Alpha-009'
    }

    It 'ignores floating third-party entries that do not match the prefix' {
      $result = Set-FloatingPackagePins -PackagePropsPath $script:propsPath -ProGetUrl 'http://proget.local:50000'

      $result.PackagesPinned.Keys | Should -Not -Contain 'Syncfusion.Blazor'
      [xml]$rewritten = Get-Content -LiteralPath $script:propsPath -Raw
      $syncfusion = $rewritten.SelectSingleNode("//PackageVersion[@Include='Syncfusion.Blazor']")
      $syncfusion.Version | Should -Be '32.*'
    }

    It 'honors a custom -PackageIdPrefix' {
      $result = Set-FloatingPackagePins -PackagePropsPath $script:propsPath -ProGetUrl 'http://proget.local:50000' -PackageIdPrefix 'ATAP.Utilities.ETW'

      $result.PackagesPinned.Keys | Should -Be 'ATAP.Utilities.ETW'
      $result.PackagesPinned.Keys | Should -Not -Contain 'ATAP.Utilities.Philote'
    }

    It 'does not write the file under -WhatIf' {
      $before = Get-Content -LiteralPath $script:propsPath -Raw
      Set-FloatingPackagePins -PackagePropsPath $script:propsPath -ProGetUrl 'http://proget.local:50000' -WhatIf | Out-Null
      $after = Get-Content -LiteralPath $script:propsPath -Raw
      $after | Should -Be $before
      Assert-MockCalled -CommandName Get-SecretATAP -Times 0 -Exactly -Scope It
      Assert-MockCalled -CommandName Invoke-RestMethod -Times 0 -Exactly -Scope It
    }
  }

  Context 'when a package is missing from the feed' {
    BeforeEach {
      Mock -CommandName Invoke-RestMethod -MockWith {
        param($Uri)
        if ($Uri -match 'atap\.utilities\.philote') {
          return [pscustomobject]@{ versions = @('0.1.0-Sprint.42') }
        }
        # ETW (and anything else) is absent -> simulate a 404
        throw [System.Net.WebException]::new('404 Not Found')
      }
    }

    It 'records the package in PackagesSkipped and pins the rest' {
      $result = Set-FloatingPackagePins -PackagePropsPath $script:propsPath -ProGetUrl 'http://proget.local:50000'

      $result.PackagesSkipped | Should -Contain 'ATAP.Utilities.ETW'
      $result.PackagesPinned['ATAP.Utilities.Philote'] | Should -Be '0.1.0-Sprint.42'
    }
  }

  Context 'error handling' {
    It 'throws when the props file does not exist' {
      $missing = Join-Path -Path $TestDrive -ChildPath 'DoesNotExist.props'
      { Set-FloatingPackagePins -PackagePropsPath $missing -ProGetUrl 'http://proget.local:50000' } |
        Should -Throw '*not found*'
    }

    It 'tolerates a trailing slash on -ProGetUrl' {
      Mock -CommandName Invoke-RestMethod -MockWith {
        param($Uri)
        # A double slash would mean the base URL was not normalized.
        $Uri | Should -Not -Match '50000//nuget'
        return [pscustomobject]@{ versions = @('0.1.0-Sprint.42') }
      }

      { Set-FloatingPackagePins -PackagePropsPath $script:propsPath -ProGetUrl 'http://proget.local:50000/' } |
        Should -Not -Throw
    }
  }
}
