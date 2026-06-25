# AI assisted using Powershell.instructions.md as guidelines

BeforeAll {
  # Dot-source only the function under test — avoids full-module import failures
  # caused by unrelated functions in the module.
  $functionFile = Join-Path $PSScriptRoot '..\..\public\Set-GroupEnvironmentVariables.ps1'
  if (-not (Test-Path $functionFile)) {
    throw "Function file not found: $functionFile"
  }
  . $functionFile

  if (Get-Module -ListAvailable -Name PSFramework) {
    Import-Module PSFramework -ErrorAction SilentlyContinue
  }

  # Unique, namespaced env-var names so the test never collides with real environment.
  $script:fastName = 'SGEV_TEST_FAST_TEMP'
  $script:dropName = 'SGEV_TEST_DROPBOX'
  $script:emptyMapName = 'SGEV_TEST_EMPTY_NAME'

  # A ConfigRootKey -> env-var-name map and an env-var-name -> value map, mirroring the
  # real $global:configRootKeys / $global:settings shapes.
  $script:crkMap = @{
    'FastTempBasePathConfigRootKey' = $script:fastName
    'DropBoxBasePathConfigRootKey'  = $script:dropName
    'EmptyNameConfigRootKey'        = ''            # maps to an empty env-var name
    'NoValueConfigRootKey'          = 'SGEV_TEST_NO_VALUE'
  }
  $script:settingsMap = @{
    $script:fastName = 'C:\fast\tmp'
    $script:dropName = 'D:\Dropbox'
    # NoValue / EmptyName intentionally absent from settings
  }

  function Clear-SgevTestEnv {
    foreach ($n in @($script:fastName, $script:dropName, 'SGEV_TEST_NO_VALUE', 'SGEV_TEST_EMPTY_NAME')) {
      [System.Environment]::SetEnvironmentVariable($n, $null, 'Process')
    }
  }
}

Describe 'Set-GroupEnvironmentVariables' -Tag 'Unit' {

  BeforeEach { Clear-SgevTestEnv }
  AfterAll { Clear-SgevTestEnv }

  Context 'Function availability' {
    It 'Function is defined' {
      Get-Command -Name 'Set-GroupEnvironmentVariables' -CommandType Function |
        Should -Not -BeNullOrEmpty
    }
    It 'Supports ShouldProcess (-WhatIf)' {
      (Get-Command Set-GroupEnvironmentVariables).Parameters.ContainsKey('WhatIf') | Should -BeTrue
    }
  }

  Context 'Sets process environment variables from the settings value' {
    It 'Sets one variable: name from ConfigRootKeyMap, value from Settings' {
      $r = Set-GroupEnvironmentVariables -ConfigRootKeys 'FastTempBasePathConfigRootKey' `
        -ConfigRootKeyMap $script:crkMap -Settings $script:settingsMap
      [System.Environment]::GetEnvironmentVariable($script:fastName, 'Process') | Should -Be 'C:\fast\tmp'
      $r.SetCount | Should -Be 1
      $r.SkippedCount | Should -Be 0
    }

    It 'Sets multiple variables in one call' {
      $r = Set-GroupEnvironmentVariables `
        -ConfigRootKeys 'FastTempBasePathConfigRootKey', 'DropBoxBasePathConfigRootKey' `
        -ConfigRootKeyMap $script:crkMap -Settings $script:settingsMap
      [System.Environment]::GetEnvironmentVariable($script:fastName, 'Process') | Should -Be 'C:\fast\tmp'
      [System.Environment]::GetEnvironmentVariable($script:dropName, 'Process') | Should -Be 'D:\Dropbox'
      $r.SetCount | Should -Be 2
    }

    It 'Accepts ConfigRootKeys from the pipeline' {
      $r = 'FastTempBasePathConfigRootKey', 'DropBoxBasePathConfigRootKey' |
        Set-GroupEnvironmentVariables -ConfigRootKeyMap $script:crkMap -Settings $script:settingsMap
      [System.Environment]::GetEnvironmentVariable($script:dropName, 'Process') | Should -Be 'D:\Dropbox'
      $r.SetCount | Should -Be 2
    }
  }

  Context 'Skips gracefully' {
    It 'Skips a ConfigRootKey not present in the map (SkippedNoKey)' {
      $r = Set-GroupEnvironmentVariables -ConfigRootKeys 'NotAKeyConfigRootKey' `
        -ConfigRootKeyMap $script:crkMap -Settings $script:settingsMap
      $r.SetCount | Should -Be 0
      ($r.Results | Where-Object { $_.ConfigRootKey -eq 'NotAKeyConfigRootKey' }).Status | Should -Be 'SkippedNoKey'
    }

    It 'Skips when the ConfigRootKey maps to an empty env-var name (SkippedNoName)' {
      $r = Set-GroupEnvironmentVariables -ConfigRootKeys 'EmptyNameConfigRootKey' `
        -ConfigRootKeyMap $script:crkMap -Settings $script:settingsMap
      ($r.Results | Where-Object { $_.ConfigRootKey -eq 'EmptyNameConfigRootKey' }).Status | Should -Be 'SkippedNoName'
    }

    It 'Skips when settings has no value for the resolved name (SkippedNoValue) and does not set the var' {
      $r = Set-GroupEnvironmentVariables -ConfigRootKeys 'NoValueConfigRootKey' `
        -ConfigRootKeyMap $script:crkMap -Settings $script:settingsMap
      ($r.Results | Where-Object { $_.ConfigRootKey -eq 'NoValueConfigRootKey' }).Status | Should -Be 'SkippedNoValue'
      [System.Environment]::GetEnvironmentVariable('SGEV_TEST_NO_VALUE', 'Process') | Should -BeNullOrEmpty
    }
  }

  Context 'WhatIf' {
    It 'Sets nothing under -WhatIf but reports the planned target' {
      $r = Set-GroupEnvironmentVariables -ConfigRootKeys 'FastTempBasePathConfigRootKey' `
        -ConfigRootKeyMap $script:crkMap -Settings $script:settingsMap -WhatIf
      [System.Environment]::GetEnvironmentVariable($script:fastName, 'Process') | Should -BeNullOrEmpty
      $r.SetCount | Should -Be 0
      ($r.Results | Where-Object { $_.ConfigRootKey -eq 'FastTempBasePathConfigRootKey' }).Status | Should -Be 'WhatIf'
    }
  }

  Context 'Fail-loud when no configuration source is available' {
    It 'Throws when neither override nor $global:configRootKeys is present' {
      $savedCrk = Get-Variable -Name configRootKeys -Scope Global -ErrorAction SilentlyContinue
      $savedSet = Get-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue
      try {
        Remove-Variable -Name configRootKeys -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue
        { Set-GroupEnvironmentVariables -ConfigRootKeys 'FastTempBasePathConfigRootKey' } |
          Should -Throw '*configRootKeys*'
      } finally {
        if ($savedCrk) { Set-Variable -Name configRootKeys -Scope Global -Value $savedCrk.Value }
        if ($savedSet) { Set-Variable -Name settings -Scope Global -Value $savedSet.Value }
      }
    }
  }
}
