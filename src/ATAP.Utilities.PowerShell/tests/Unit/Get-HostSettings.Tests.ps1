BeforeAll {
  $functionFile = Join-Path $PSScriptRoot '..\..\public\Get-HostSettings.ps1'
  if (-not (Test-Path -LiteralPath $functionFile -PathType Leaf)) {
    throw "Function file not found: $functionFile"
  }

  . $functionFile
}

Describe 'Get-HostSettings' {
  BeforeEach {
    $script:previousConfigRootKeys = $global:configRootKeys
    $global:configRootKeys = @{
      ExampleConfigRootKey = 'ExampleConfig'
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
    if ($null -eq $script:previousConfigRootKeys) {
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
}
