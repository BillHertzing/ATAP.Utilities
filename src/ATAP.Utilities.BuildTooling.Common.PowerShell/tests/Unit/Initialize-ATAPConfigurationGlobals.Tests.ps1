#Requires -Version 7.0

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $manifestPath = Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.Common.PowerShell.psd1'
  $promotedManifest = [System.Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
  Remove-Module -Name 'ATAP.Utilities.BuildTooling.Common.PowerShell' -Force -ErrorAction SilentlyContinue
  Import-Module -Name $(if ([string]::IsNullOrWhiteSpace($promotedManifest)) { $manifestPath } else { $promotedManifest }) -Force -ErrorAction Stop
}

Describe 'Initialize-ATAPConfigurationGlobals' -Tag 'Unit' {
  BeforeEach {
    $script:oldConfigRootKeys = $global:configRootKeys
    $script:oldSettings = $global:settings
    $script:oldDefaultParameterValues = $global:PSDefaultParameterValues
    $global:configRootKeys = $null
    $global:settings = $null

    $script:tempRepositoryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "common-config-bootstrap-$([guid]::NewGuid().ToString('N'))"
    $configPublicPath = Join-Path $script:tempRepositoryRoot 'src\ATAP.Utilities.ConfigRootKeys.Powershell\public'
    $powershellPublicPath = Join-Path $script:tempRepositoryRoot 'src\ATAP.Utilities.Powershell\public'
    New-Item -ItemType Directory -Path $configPublicPath -Force | Out-Null
    New-Item -ItemType Directory -Path $powershellPublicPath -Force | Out-Null

    Set-Content -LiteralPath (Join-Path $configPublicPath 'Set-GlobalConfigRootKeys.ps1') -Encoding UTF8 -Value @'
function Set-GlobalConfigRootKeys {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param()
  $global:configRootKeys = @{
    DatabasesCollectionConfigRootKey = 'DatabasesCollection'
  }
}
'@

    Set-Content -LiteralPath (Join-Path $powershellPublicPath 'Get-HostSettings.ps1') -Encoding UTF8 -Value @'
function Get-HostSettings {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [string]$hostName,
    [string]$IACBasePath
  )
  @{
    DatabasesCollection = @{
      ATAPUtilities = @{
        Development = @{}
      }
    }
    HostName = $hostName
    IACBasePath = $IACBasePath
  }
}
'@
  }

  AfterEach {
    $global:configRootKeys = $script:oldConfigRootKeys
    $global:settings = $script:oldSettings
    $global:PSDefaultParameterValues = $script:oldDefaultParameterValues
    Remove-Item -LiteralPath $script:tempRepositoryRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'loads current-worktree source and populates both globals' {
    $result = Initialize-ATAPConfigurationGlobals `
      -RepositoryRoot $script:tempRepositoryRoot `
      -IACBasePath 'C:\test\ATAP.IAC' `
      -Confirm:$false

    $result.Initialized | Should -BeTrue
    $result.DatabaseSettingsKey | Should -Be 'DatabasesCollection'
    $global:configRootKeys['DatabasesCollectionConfigRootKey'] | Should -Be 'DatabasesCollection'
    $global:settings['DatabasesCollection'].ContainsKey('ATAPUtilities') | Should -BeTrue
    $global:settings['IACBasePath'] | Should -Be 'C:\test\ATAP.IAC'
  }

  It 'is a no-op when the required globals are already ready' {
    $global:configRootKeys = @{ DatabasesCollectionConfigRootKey = 'DatabasesCollection' }
    $global:settings = @{ DatabasesCollection = @{ ATAPUtilities = @{} } }

    $result = Initialize-ATAPConfigurationGlobals `
      -RepositoryRoot $script:tempRepositoryRoot `
      -Confirm:$false

    $result.Initialized | Should -BeFalse
    $result.ConfigRootKeysCount | Should -Be 1
    $result.SettingsCount | Should -Be 1
  }

  It 'throws when host settings omit the required database collection' {
    $hostSettingsPath = Join-Path $script:tempRepositoryRoot 'src\ATAP.Utilities.Powershell\public\Get-HostSettings.ps1'
    Set-Content -LiteralPath $hostSettingsPath -Encoding UTF8 -Value @'
function Get-HostSettings {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param([string]$hostName, [string]$IACBasePath)
  @{ HostName = $hostName }
}
'@

    {
      Initialize-ATAPConfigurationGlobals `
        -RepositoryRoot $script:tempRepositoryRoot `
        -Confirm:$false
    } | Should -Throw -ExpectedMessage '*required*DatabasesCollection*'
  }
}
