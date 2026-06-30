BeforeAll {
  $functionFile = Join-Path $PSScriptRoot '..\..\public\Get-HostSettings.ps1'
  if (-not (Test-Path -LiteralPath $functionFile -PathType Leaf)) {
    throw "Function file not found: $functionFile"
  }

  . $functionFile
}

Describe 'Get-HostSettings' -Tag 'Unit' {
  BeforeEach {
    $existingConfigRootKeys = Get-Variable -Name 'configRootKeys' -Scope Global -ErrorAction SilentlyContinue
    $script:hadPreviousConfigRootKeys = $null -ne $existingConfigRootKeys
    $script:previousConfigRootKeys = if ($script:hadPreviousConfigRootKeys) { $existingConfigRootKeys.Value } else { $null }
    $global:configRootKeys = @{
      ExampleConfigRootKey                         = 'ExampleConfig'
      BuildMasterApplicationByModuleConfigRootKey = 'BuildMasterApplicationByModule'
    }

    $script:testIacRoot = Join-Path $PSScriptRoot '_tmp_GetHostSettings_IAC'
    Remove-Item -LiteralPath $script:testIacRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -Path $script:testIacRoot -ItemType Directory -Force | Out-Null

    @'
if (-not (Get-Command -Name 'Get-ClonedAndModifiedHashtable' -CommandType Function -ErrorAction SilentlyContinue)) {
  throw 'Get-ClonedAndModifiedHashtable was not available before HostSettings.ps1 was loaded.'
}

function Get-HostSettings {
  param(
    [string] $hostName
  )

  Get-ClonedAndModifiedHashtable @{
    $global:configRootKeys['ExampleConfigRootKey'] = 'base'
    HostName = $hostName
    JoinedPath = Join-Path 'C:\Temp' 'Example'
  } @(
    @{
      $global:configRootKeys['ExampleConfigRootKey'] = 'override'
    }
  )
}
'@ | Set-Content -LiteralPath (Join-Path $script:testIacRoot 'HostSettings.ps1') -Encoding UTF8
  }

  AfterEach {
    if (-not $script:hadPreviousConfigRootKeys) {
      Remove-Variable -Name 'configRootKeys' -Scope Global -ErrorAction SilentlyContinue
    } else {
      $global:configRootKeys = $script:previousConfigRootKeys
    }

    Remove-Item -LiteralPath $script:testIacRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'returns a hashtable keyed by configRootKeys values from the resolved HostSettings script' {
    $result = Get-HostSettings -hostName 'test-host' -IACBasePath $script:testIacRoot

    $result | Should -BeOfType [hashtable]
    $result['ExampleConfig'] | Should -Be 'override'
    $result['HostName'] | Should -Be 'test-host'
    $result['JoinedPath'] | Should -Be (Join-Path 'C:\Temp' 'Example')
  }

  It 'normalizes the reviewed BuildMaster application map to include RulesManagement' {
    @'
if (-not (Get-Command -Name 'Get-ClonedAndModifiedHashtable' -CommandType Function -ErrorAction SilentlyContinue)) {
  throw 'Get-ClonedAndModifiedHashtable was not available before HostSettings.ps1 was loaded.'
}

function Get-HostSettings {
  param(
    [string] $hostName
  )

  @{
    HostName = $hostName
    $global:configRootKeys['BuildMasterApplicationByModuleConfigRootKey'] = @{
      'ATAP.Utilities.PowerShell'                    = 'ATAP.Utilities-PowerShell'
      'ATAP.Utilities.ConfigRootKeys.PowerShell'     = 'ATAP.Utilities-PowerShell'
      'ATAP.Utilities.BuildTooling.PowerShell'       = 'ATAP.Utilities-PowerShell'
      'ATAP.Utilities.DatabaseManagement.PowerShell' = 'ATAP.Utilities-PowerShell'
    }
  }
}
'@ | Set-Content -LiteralPath (Join-Path $script:testIacRoot 'HostSettings.ps1') -Encoding UTF8

    $result = Get-HostSettings -hostName 'test-host' -IACBasePath $script:testIacRoot
    $map = $result['BuildMasterApplicationByModule']

    $map.Keys.Count | Should -Be 5
    $map['ATAP.Utilities.RulesManagement.PowerShell'] | Should -Be 'ATAP.Utilities-PowerShell'
    $map['ATAP.Utilities.BuildTooling.PowerShell'] | Should -Be 'ATAP.Utilities-PowerShell'
  }

  It 'throws when a reviewed BuildMaster module mapping conflicts with the local contract' {
    @'
if (-not (Get-Command -Name 'Get-ClonedAndModifiedHashtable' -CommandType Function -ErrorAction SilentlyContinue)) {
  throw 'Get-ClonedAndModifiedHashtable was not available before HostSettings.ps1 was loaded.'
}

function Get-HostSettings {
  param(
    [string] $hostName
  )

  @{
    HostName = $hostName
    $global:configRootKeys['BuildMasterApplicationByModuleConfigRootKey'] = @{
      'ATAP.Utilities.RulesManagement.PowerShell' = 'Unexpected-App'
    }
  }
}
'@ | Set-Content -LiteralPath (Join-Path $script:testIacRoot 'HostSettings.ps1') -Encoding UTF8

    {
      Get-HostSettings -hostName 'test-host' -IACBasePath $script:testIacRoot
    } | Should -Throw '*Reviewed BuildMaster mapping conflict*'
  }
}
