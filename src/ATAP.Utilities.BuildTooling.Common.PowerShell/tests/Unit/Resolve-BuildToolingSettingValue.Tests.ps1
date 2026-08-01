#Requires -Version 7.0

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $manifestPath = Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.Common.PowerShell.psd1'
  $promotedManifest = [System.Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
  Remove-Module -Name 'ATAP.Utilities.BuildTooling.Common.PowerShell' -Force -ErrorAction SilentlyContinue
  Import-Module -Name $(if ([string]::IsNullOrWhiteSpace($promotedManifest)) { $manifestPath } else { $promotedManifest }) -Force -ErrorAction Stop
}

Describe 'Resolve-BuildToolingSettingValue' -Tag 'Unit' {
  BeforeEach {
    $script:oldConfigRootKeys = $global:configRootKeys
    $script:oldSettings = $global:Settings
    $global:configRootKeys = @{}
    $global:Settings = @{}
  }

  AfterEach {
    $global:configRootKeys = $script:oldConfigRootKeys
    $global:Settings = $script:oldSettings
  }

  It 'returns a direct setting before mapped candidates' {
    $global:configRootKeys['ExampleConfigRootKey'] = 'MappedExample'
    $global:Settings['Example'] = 'direct-value'
    $global:Settings['MappedExample'] = 'mapped-value'

    Resolve-BuildToolingSettingValue -Name 'Example' | Should -Be 'direct-value'
  }

  It 'resolves a setting through its ConfigRootKey mapping' {
    $global:configRootKeys['ProGetAdminUriHostConfigRootKey'] = 'ConfiguredProGetHost'
    $global:Settings['ConfiguredProGetHost'] = 'proget.example.test'

    Resolve-BuildToolingSettingValue -Name 'ProGetAdminUriHost' | Should -Be 'proget.example.test'
  }

  It 'preserves a non-string configured value' {
    $global:Settings['ProGetAdminUriPort'] = 8624

    $result = Resolve-BuildToolingSettingValue -Name 'ProGetAdminUriPort'

    $result | Should -BeOfType ([int])
    $result | Should -Be 8624
  }

  It 'throws when settings have not been initialized' {
    $global:Settings = $null

    { Resolve-BuildToolingSettingValue -Name 'Example' } |
      Should -Throw -ExpectedMessage '*$global:Settings is not initialized*'
  }

  It 'throws when no non-empty candidate can be resolved' {
    $global:configRootKeys['ExampleConfigRootKey'] = 'MappedExample'
    $global:Settings['MappedExample'] = ' '

    { Resolve-BuildToolingSettingValue -Name 'Example' } |
      Should -Throw -ExpectedMessage "*Setting 'Example' could not be resolved*"
  }
}
