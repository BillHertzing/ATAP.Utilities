# public/Get-NuSpecFromManifest.Tests.ps1

# Requires Pester module to run the tests
# Install-Module -Name Pester -Force -SkipPublisherCheck

Describe 'Get-NuSpecFromManifest' {
  # Mock the functions used within Get-NuSpecFromManifest
  Mock -CommandName Test-Path -MockWith { return $true }
  Mock -CommandName Test-ModuleManifest -MockWith { return @{ Name = 'TestModule'; Description = 'Test Description'; Version = '1.0.0'; Author = 'Test Author'; CompanyName = 'Test Company'; Copyright = 'Test Copyright'; ModuleBase = 'C:\TestModule' } }
  Mock -CommandName Get-Content -MockWith { return @{} }
  Mock -CommandName Set-Content -MockWith { return $null }
  Mock -CommandName Remove-Item -MockWith { return $null }
  Mock -CommandName Write-PSFMessage -MockWith { return $null }

  Context 'Function Exists' {
    It 'Should exist' {
      Get-Command -Name Get-NuSpecFromManifest | Should -Not -BeNullOrEmpty
    }
  }

  Context 'Parameter Validation' {
    It 'Should throw an error if ManifestPath is missing' {
      { Get-NuSpecFromManifest -ProviderName 'NuGet' } | Should -Throw
    }

    It 'Should throw an error if ProviderName is missing' {
      { Get-NuSpecFromManifest -ManifestPath 'C:\TestModule\TestModule.psd1' } | Should -Throw
    }

    It 'Should validate ManifestPath parameter' {
      { Get-NuSpecFromManifest -ManifestPath 'C:\TestModule\TestModule.psd1' -ProviderName 'NuGet' } | Should -Not -Throw
    }

    It 'Should validate DestinationFolder parameter' {
      { Get-NuSpecFromManifest -ManifestPath 'C:\TestModule\TestModule.psd1' -ProviderName 'NuGet' -DestinationFolder 'C:\Output' } | Should -Not -Throw
    }
  }

  Context 'Functionality' {
    It 'Should generate a .nuspec file correctly' {
      $result = Get-NuSpecFromManifest -ManifestPath 'C:\TestModule\TestModule.psd1' -ProviderName 'NuGet' -DestinationFolder 'C:\Output'
      $result | Should -Be 'C:\Output\TestModule.nuspec'
    }

    It 'Should handle errors when .nuspec file cannot be created' {
      Mock -CommandName Set-Content -MockWith { throw 'Failed to create .nuspec file' }
      { Get-NuSpecFromManifest -ManifestPath 'C:\TestModule\TestModule.psd1' -ProviderName 'NuGet' -DestinationFolder 'C:\Output' } | Should -Throw
    }
  }
}
