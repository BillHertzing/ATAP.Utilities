Describe 'Get-CoordSetting' -Tag 'Unit' {
  BeforeAll {
    $script:originalKeys = Get-Variable -Name 'configRootKeys' -Scope Global -ErrorAction SilentlyContinue
    $script:originalSettings = Get-Variable -Name 'settings' -Scope Global -ErrorAction SilentlyContinue
    $script:hadKeys = $null -ne $script:originalKeys
    $script:hadSettings = $null -ne $script:originalSettings
    $script:savedKeys = if ($script:hadKeys) { $script:originalKeys.Value } else { $null }
    $script:savedSettings = if ($script:hadSettings) { $script:originalSettings.Value } else { $null }
    . (Join-Path $PSScriptRoot '../../private/CoordProducer.ps1')
  }

  BeforeEach {
    $global:configRootKeys = @{ ExampleConfigRootKey = 'ActualAlias' }
    $global:settings = @{ ActualAlias = 'configured' }
  }

  AfterAll {
    if ($script:hadKeys) { Set-Variable -Name 'configRootKeys' -Scope Global -Value $script:savedKeys } else { Remove-Variable -Name 'configRootKeys' -Scope Global -ErrorAction SilentlyContinue }
    if ($script:hadSettings) { Set-Variable -Name 'settings' -Scope Global -Value $script:savedSettings } else { Remove-Variable -Name 'settings' -Scope Global -ErrorAction SilentlyContinue }
  }

  It 'reports missing when configRootKeys is absent' {
    Remove-Variable -Name 'configRootKeys' -Scope Global
    { Get-CoordSetting -Name 'Example' } | Should -Throw 'Missing coordination setting: Example'
  }
  It 'reports missing when configRootKeys is null' {
    $global:configRootKeys = $null
    { Get-CoordSetting -Name 'Example' } | Should -Throw 'Missing coordination setting: Example'
  }
  It 'reports missing when settings is absent' {
    Remove-Variable -Name 'settings' -Scope Global
    { Get-CoordSetting -Name 'Example' } | Should -Throw 'Missing coordination setting: Example'
  }
  It 'reports missing when settings is null' {
    $global:settings = $null
    { Get-CoordSetting -Name 'Example' } | Should -Throw 'Missing coordination setting: Example'
  }
  It 'reports missing when the level-one mapping is absent' {
    $global:configRootKeys = @{}
    { Get-CoordSetting -Name 'Example' } | Should -Throw 'Missing coordination setting: Example'
  }
  It 'reports missing when the mapped setting is absent' {
    $global:settings = @{}
    { Get-CoordSetting -Name 'Example' } | Should -Throw 'Missing coordination setting: Example'
  }
  It 'reports missing when the mapped setting is null' {
    $global:settings = @{ ActualAlias = $null }
    { Get-CoordSetting -Name 'Example' } | Should -Throw 'Missing coordination setting: Example'
  }
  It 'returns the value of a non-name-equal alias' {
    Get-CoordSetting -Name 'Example' | Should -BeExactly 'configured'
  }
  It 'preserves a false value' {
    $global:settings.ActualAlias = $false
    Get-CoordSetting -Name 'Example' | Should -BeOfType [bool]
    Get-CoordSetting -Name 'Example' | Should -BeFalse
  }
  It 'preserves a zero value' {
    $global:settings.ActualAlias = 0
    Get-CoordSetting -Name 'Example' | Should -BeOfType [int]
    Get-CoordSetting -Name 'Example' | Should -Be 0
  }
}
