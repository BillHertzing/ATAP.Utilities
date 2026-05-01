# AI assisted using Powershell.instructions.md as guidelines

BeforeAll {
  # Dot-source only the function under test — avoids full-module import failures
  # caused by unrelated functions (ConvertFrom-MboxFile, Get-SecureEnvVar, etc.)
  $functionFile = Join-Path $PSScriptRoot '..\..\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
  if (-not (Test-Path $functionFile)) {
    throw "Function file not found: $functionFile"
  }
  . $functionFile

  # PSFramework is used by the test infrastructure for logging; import if available
  if (Get-Module -ListAvailable -Name PSFramework) {
    Import-Module PSFramework -ErrorAction SilentlyContinue
  }
}

Describe 'Get-ParameterValueFromNeoConfigurationRoot' {

  Context 'Function availability' {
    It 'Function is defined' {
      Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function |
        Should -Not -BeNullOrEmpty
    }

    It 'Alias Get-PVal is defined' {
      Get-Alias -Name 'Get-PVal' -ErrorAction SilentlyContinue |
        Should -Not -BeNullOrEmpty
    }
  }

  Context 'Priority 1 — PSBoundParameters resolution' {
    It 'Returns value from originalPSBoundParameters when present' {
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'MyParam' `
        -originalPSBoundParameters @{ MyParam = 'FromBoundParams' }
      $result | Should -Be 'FromBoundParams'
    }

    It 'PSBoundParameters takes priority over Settings' {
      $settings = @{ MyParam = 'FromSettings' }
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'MyParam' `
        -originalPSBoundParameters @{ MyParam = 'FromBoundParams' } `
        -Settings $settings
      $result | Should -Be 'FromBoundParams'
    }
  }

  Context 'Priority 2 — Environment variable resolution' {
    BeforeEach {
      $env:PVAL_TEST_UNIQUE_ENVVAR = 'EnvVarValue'
    }
    AfterEach {
      Remove-Item -Path 'Env:PVAL_TEST_UNIQUE_ENVVAR' -ErrorAction SilentlyContinue
    }

    It 'Returns env var value when param not in PSBoundParameters' {
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'PVAL_TEST_UNIQUE_ENVVAR' `
        -originalPSBoundParameters @{}
      $result | Should -Be 'EnvVarValue'
    }

    It 'Env var takes priority over Settings' {
      $settings = @{ PVAL_TEST_UNIQUE_ENVVAR = 'FromSettings' }
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'PVAL_TEST_UNIQUE_ENVVAR' `
        -originalPSBoundParameters @{} `
        -Settings $settings
      $result | Should -Be 'EnvVarValue'
    }
  }

  Context 'Priority 3 — Settings resolution via dottedPath' {
    It 'Resolves flat key from hashtable settings' {
      $settings = @{ Database = 'MyDB' }
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'Database' `
        -originalPSBoundParameters @{} `
        -Settings $settings
      $result | Should -Be 'MyDB'
    }

    It 'Uses ParameterName as dottedPath when dottedPath not provided' {
      $settings = @{ MyKey = 'MyValue' }
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'MyKey' `
        -originalPSBoundParameters @{} `
        -Settings $settings
      $result | Should -Be 'MyValue'
    }

    It 'Resolves nested dotted path from hashtable settings' {
      # ParameterName uses prefix to avoid collision with system env vars (e.g. HOST)
      $settings = @{ Database = @{ PvalDbHost = 'localhost' } }
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'PvalDbHost' `
        -originalPSBoundParameters @{} `
        -dottedPath 'Database.PvalDbHost' `
        -Settings $settings
      $result | Should -Be 'localhost'
    }

    It 'Resolves three-level nested dotted path from hashtable settings' {
      $settings = @{ App = @{ Database = @{ Port = '5432' } } }
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'Port' `
        -originalPSBoundParameters @{} `
        -dottedPath 'App.Database.Port' `
        -Settings $settings
      $result | Should -Be '5432'
    }

    It 'Resolves nested path from PSCustomObject settings' {
      $settings = @{ Database = [PSCustomObject]@{ Port = 5432 } }
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'Port' `
        -originalPSBoundParameters @{} `
        -dottedPath 'Database.Port' `
        -Settings $settings
      $result | Should -Be 5432
    }
  }

  Context 'Priority 4 — DefaultValue fallback' {
    It 'Returns DefaultValue when nothing else resolves' {
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'NoSuchParam' `
        -originalPSBoundParameters @{} `
        -Settings @{} `
        -DefaultValue 'FallbackValue'
      $result | Should -Be 'FallbackValue'
    }

    It 'DefaultValue is not used when settings resolves the key' {
      $settings = @{ MyKey = 'FromSettings' }
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'MyKey' `
        -originalPSBoundParameters @{} `
        -Settings $settings `
        -DefaultValue 'ShouldNotBeUsed'
      $result | Should -Be 'FromSettings'
    }
  }

  Context 'AllowMissing behavior' {
    It 'Returns null when -AllowMissing and nothing found' {
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'NoSuchParam' `
        -originalPSBoundParameters @{} `
        -Settings @{} `
        -AllowMissing
      $result | Should -BeNullOrEmpty
    }

    It 'Throws when -AllowMissing is not set and nothing found' {
      {
        Get-ParameterValueFromNeoConfigurationRoot `
          -ParameterName 'NoSuchParam' `
          -originalPSBoundParameters @{} `
          -Settings @{}
      } | Should -Throw
    }
  }

  Context 'ValidValues validation' {
    It 'Returns correctly-cased value when resolved matches a ValidValue (case-insensitive)' {
      $settings = @{ Environment = 'production' }
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'Environment' `
        -originalPSBoundParameters @{} `
        -Settings $settings `
        -ValidValues @('Development', 'Staging', 'Production')
      $result | Should -Be 'Production'
    }

    It 'ValidValues match is case-insensitive for uppercase input' {
      # ParameterName uses prefix to avoid collision with system env vars (e.g. ENVIRONMENT)
      $settings = @{ PvalDeployEnv = 'STAGING' }
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'PvalDeployEnv' `
        -originalPSBoundParameters @{} `
        -Settings $settings `
        -ValidValues @('Development', 'Staging', 'Production')
      $result | Should -Be 'Staging'
    }

    It 'Throws when resolved value is not in ValidValues' {
      $settings = @{ PvalDeployEnv = 'unknown' }
      {
        Get-ParameterValueFromNeoConfigurationRoot `
          -ParameterName 'PvalDeployEnv' `
          -originalPSBoundParameters @{} `
          -Settings $settings `
          -ValidValues @('Development', 'Staging', 'Production')
      } | Should -Throw
    }
  }

  Context 'AsType coercion (applied uniformly regardless of resolution source)' {
    It 'Coerces string to int from Settings (priority 3)' {
      $settings = @{ PvalPort = '8080' }
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'PvalPort' `
        -originalPSBoundParameters @{} `
        -Settings $settings `
        -AsType ([int])
      $result | Should -Be 8080
      $result | Should -BeOfType [int]
    }

    It 'Coerces string to int from PSBoundParameters (priority 1) — bug fix validation' {
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'PvalPort' `
        -originalPSBoundParameters @{ PvalPort = '9090' } `
        -AsType ([int])
      $result | Should -Be 9090
      $result | Should -BeOfType [int]
    }

    It 'Coerces "yes" to bool true from Settings' {
      $settings = @{ PvalFeature = 'yes' }
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'PvalFeature' `
        -originalPSBoundParameters @{} `
        -Settings $settings `
        -AsType ([bool])
      $result | Should -Be $true
    }

    It 'Coerces "no" to bool false from Settings' {
      $settings = @{ PvalFeature = 'no' }
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'PvalFeature' `
        -originalPSBoundParameters @{} `
        -Settings $settings `
        -AsType ([bool])
      $result | Should -Be $false
    }

    It 'Coerces "1" to bool true' {
      $settings = @{ PvalFlag = '1' }
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'PvalFlag' `
        -originalPSBoundParameters @{} `
        -Settings $settings `
        -AsType ([bool])
      $result | Should -Be $true
    }

    It 'Coerces "0" to bool false' {
      $settings = @{ PvalFlag = '0' }
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'PvalFlag' `
        -originalPSBoundParameters @{} `
        -Settings $settings `
        -AsType ([bool])
      $result | Should -Be $false
    }

    It 'Coerces "true" to bool true' {
      $settings = @{ PvalFlag = 'true' }
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'PvalFlag' `
        -originalPSBoundParameters @{} `
        -Settings $settings `
        -AsType ([bool])
      $result | Should -Be $true
    }

    It 'Coerces "false" to bool false' {
      $settings = @{ PvalFlag = 'false' }
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'PvalFlag' `
        -originalPSBoundParameters @{} `
        -Settings $settings `
        -AsType ([bool])
      $result | Should -Be $false
    }

    It 'Coerces "yes" to bool true from PSBoundParameters (priority 1) — bug fix validation' {
      $result = Get-ParameterValueFromNeoConfigurationRoot `
        -ParameterName 'PvalFeature' `
        -originalPSBoundParameters @{ PvalFeature = 'yes' } `
        -AsType ([bool])
      $result | Should -Be $true
    }
  }
}
