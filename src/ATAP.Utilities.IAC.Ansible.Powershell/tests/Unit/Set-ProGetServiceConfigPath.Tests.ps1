Describe 'Set-ProGetServiceConfigPath' {

  BeforeAll {
    BeforeAll {
      if (-not $Env:IsCI) {
        $localScriptPath = Join-Path -Path $PSScriptRoot -ChildPath '../src/Set-ProGetServiceConfigPath.ps1'
        . $localScriptPath
      }
      else {
        # CI mode assumes functions are autoloaded or sourced via PSModulePath
        # Write-Host "Running in CI mode - assuming functions are preloaded"
      }
    }
  }

  Context 'When configuration file exists and sc.exe succeeds' {
    Mock Test-Path { $true }
    Mock Get-ItemProperty {
      [PSCustomObject]@{ ImagePath = '"C:\Program Files\ProGet\ProGet.Service.exe"' }
    }
    Mock 'sc.exe' { '[SC] ChangeServiceConfig SUCCESS' }
    Mock Write-PSFMessage {}
    Mock ShouldProcess { $true }

    It 'Should use default config path and succeed' {
      { Set-ProGetServiceConfigPath } | Should -Not -Throw
      Assert-MockCalled 'sc.exe' -Times 1 -Exactly
    }

    It 'Should accept a custom config path and succeed' {
      { Set-ProGetServiceConfigPath -ConfigPath 'C:/Custom/Path/ProGet.config' } | Should -Not -Throw
      Assert-MockCalled 'sc.exe' -Times 2
    }
  }

  Context 'When configuration file does not exist' {
    Mock Test-Path { $false }
    Mock Get-ItemProperty { [PSCustomObject]@{ ImagePath = 'fakepath' } }
    Mock Write-PSFMessage {}

    It 'Should throw an error due to missing file' {
      { Set-ProGetServiceConfigPath } | Should -Throw
      Assert-MockCalled Write-PSFMessage -ParameterFilter { $Level -eq 'Error' -and $Message -like '*does not exist*' }
    }
  }

  Context 'When sc.exe result is not successful' {
    Mock Test-Path { $true }
    Mock Get-ItemProperty {
      [PSCustomObject]@{ ImagePath = '"C:\Program Files\ProGet\ProGet.Service.exe"' }
    }
    Mock 'sc.exe' { 'failure message' }
    Mock Write-PSFMessage {}
    Mock ShouldProcess { $true }

    It 'Should throw an error due to failed service update' {
      { Set-ProGetServiceConfigPath } | Should -Throw
      Assert-MockCalled Write-PSFMessage -ParameterFilter { $Level -eq 'Error' -and $Message -like '*Failed to update service config*' }
    }
  }
}
