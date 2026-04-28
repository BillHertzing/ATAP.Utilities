# Requires -Version 7.0
# Pester 5+ tests for Publish-PSModuleToProGetFeed (task T-19).
# All external I/O, secret stores, and PSResourceGet cmdlets are mocked.

BeforeAll {
  # Dot-source the function under test.
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Publish-PSModuleToProGetFeed.ps1')

  # Suppress PSFramework noise in tests.
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }

  # Ensure stand-in definitions exist for PSResourceGet cmdlets so Mock can replace them.
  foreach ($cmd in @('Get-PSResourceRepository', 'Register-PSResourceRepository', 'Set-PSResourceRepository', 'Publish-PSResource')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
      $scriptBody = "function global:$cmd { param([Parameter(ValueFromRemainingArguments=`$true)]`$args) }"
      Invoke-Expression $scriptBody
    }
  }

  # Create a fake .nupkg file we can point the cmdlet at.
  $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('PubPSModTest_' + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
  $script:fakeNupkg = Join-Path $script:tempRoot 'FakeModule.1.0.0.nupkg'
  Set-Content -LiteralPath $script:fakeNupkg -Value 'not a real nupkg' -Encoding Ascii

  # Seed all tier env vars so Get-PSModuleFeedUri succeeds.
  # Set User-scope env vars for every tier (the cmdlet reads via [Environment]::GetEnvironmentVariable(...,'User')).
  $script:tierFeedEnvVars = @{
    'PROGET_POWERSHELLGET_FEED_URI_SPRINT'     = 'https://proget.example.test/nuget/PowershellGet-experimental/'
    'PROGET_POWERSHELLGET_FEED_URI_ALPHA'      = 'https://proget.example.test/nuget/PowershellGet-development/'
    'PROGET_POWERSHELLGET_FEED_URI_BETA'       = 'https://proget.example.test/nuget/PowershellGet-integration/'
    'PROGET_POWERSHELLGET_FEED_URI_QA'         = 'https://proget.example.test/nuget/PowershellGet-qa/'
    'PROGET_POWERSHELLGET_FEED_URI_PRODUCTION' = 'https://proget.example.test/nuget/PowershellGet-stable/'
  }
  $script:savedFeedEnv = @{}
  foreach ($k in $script:tierFeedEnvVars.Keys) {
    $script:savedFeedEnv[$k] = [Environment]::GetEnvironmentVariable($k, 'User')
    [Environment]::SetEnvironmentVariable($k, $script:tierFeedEnvVars[$k], 'User')
  }
}

AfterAll {
  if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
    Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
  if ($script:tierFeedEnvVars) {
    foreach ($k in $script:tierFeedEnvVars.Keys) {
      [Environment]::SetEnvironmentVariable($k, $script:savedFeedEnv[$k], 'User')
    }
  }
}

Describe 'Publish-PSModuleToProGetFeed' {

  BeforeEach {
    Mock Get-PSResourceRepository { $null }
    Mock Register-PSResourceRepository { }
    Mock Set-PSResourceRepository { }
    Mock Publish-PSResource { [PSCustomObject]@{ Status = 'OK' } }
  }

  Context 'Tier-to-feed mapping' {
    $tierCases = @(
      @{ Tier = 'Sprint'; Expected = 'PowershellGet-experimental' }
      @{ Tier = 'Alpha'; Expected = 'PowershellGet-development' }
      @{ Tier = 'Beta'; Expected = 'PowershellGet-integration' }
      @{ Tier = 'QA'; Expected = 'PowershellGet-qa' }
      @{ Tier = 'Production'; Expected = 'PowershellGet-stable' }
    )

    It "Resolves tier '<Tier>' to feed name '<Expected>'" -TestCases $tierCases {
      param($Tier, $Expected)

      # Inject API key via Bitwarden helper override (function-scope; visible through Get-Command).
      function global:Get-BitWardenSecret { param([string]$SecretName) return 'dummy-key' }
      try {
        $result = Publish-PSModuleToProGetFeed -NupkgPath $script:fakeNupkg -Tier $Tier
        $result.FeedName | Should -Be $Expected
        $result.Published | Should -BeTrue
        Assert-MockCalled Publish-PSResource -Times 1 -Exactly -Scope It
      } finally {
        Remove-Item Function:\Get-BitWardenSecret -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'API key sourcing' {
    It 'Uses Get-BitWardenSecret when available' {
      $script:bwCalls = 0
      function global:Get-BitWardenSecret {
        param([string]$SecretName)
        $script:bwCalls++
        return 'bw-secret-value'
      }
      try {
        $result = Publish-PSModuleToProGetFeed -NupkgPath $script:fakeNupkg -Tier Alpha
        $result.Published | Should -BeTrue
        $script:bwCalls | Should -BeGreaterOrEqual 1
      } finally {
        Remove-Item Function:\Get-BitWardenSecret -ErrorAction SilentlyContinue
      }
    }

    It 'Falls back to env var when Get-BitWardenSecret is absent' {
      # Ensure Get-BitWardenSecret is not defined.
      Remove-Item Function:\Get-BitWardenSecret -ErrorAction SilentlyContinue

      # Monkey-patch [Environment]::GetEnvironmentVariable via a wrapper function isn't possible,
      # so instead override Get-Command so the cmdlet skips the BW path, and seed a Process env var
      # that the User-scope getter won't see. That means we need another shim: override the whole
      # API key resolution by providing Get-BitWardenSecret that returns an empty string first,
      # then the cmdlet falls through to env var. To make the env var visible at User scope we
      # temporarily set it.
      $envName = 'PROGET_POWERSHELLGET_APIKEY_Beta'
      [Environment]::SetEnvironmentVariable($envName, 'env-api-key', 'User')
      try {
        $result = Publish-PSModuleToProGetFeed -NupkgPath $script:fakeNupkg -Tier Beta
        $result.Published | Should -BeTrue
        $result.FeedName | Should -Be 'PowershellGet-integration'
      } finally {
        [Environment]::SetEnvironmentVariable($envName, $null, 'User')
      }
    }

    It 'Throws when neither Bitwarden nor env var provides a key' {
      Remove-Item Function:\Get-BitWardenSecret -ErrorAction SilentlyContinue
      $envName = 'PROGET_POWERSHELLGET_APIKEY_QA'
      [Environment]::SetEnvironmentVariable($envName, $null, 'User')

      { Publish-PSModuleToProGetFeed -NupkgPath $script:fakeNupkg -Tier QA } |
        Should -Throw -ExpectedMessage '*Unable to resolve ProGet API key*'
    }
  }

  Context 'WhatIf short-circuit' {
    It 'Does not call Publish-PSResource when -WhatIf is supplied' {
      function global:Get-BitWardenSecret { param([string]$SecretName) return 'dummy' }
      try {
        $result = Publish-PSModuleToProGetFeed -NupkgPath $script:fakeNupkg -Tier Sprint -WhatIf
        $result.Published | Should -BeFalse
        $result.FeedName | Should -Be 'PowershellGet-experimental'
        $result.ResponseSummary | Should -Match 'WhatIf'
        Assert-MockCalled Publish-PSResource -Times 0 -Exactly -Scope It
      } finally {
        Remove-Item Function:\Get-BitWardenSecret -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'PSResourceRepository registration' {
    It 'Registers the repository when missing' {
      function global:Get-BitWardenSecret { param([string]$SecretName) return 'dummy' }
      Mock Get-PSResourceRepository { $null }
      try {
        Publish-PSModuleToProGetFeed -NupkgPath $script:fakeNupkg -Tier Alpha | Out-Null
        Assert-MockCalled Register-PSResourceRepository -Times 1 -Exactly -Scope It
        Assert-MockCalled Set-PSResourceRepository -Times 0 -Exactly -Scope It
      } finally {
        Remove-Item Function:\Get-BitWardenSecret -ErrorAction SilentlyContinue
      }
    }

    It 'Updates the repository when URI differs' {
      function global:Get-BitWardenSecret { param([string]$SecretName) return 'dummy' }
      Mock Get-PSResourceRepository { [PSCustomObject]@{ Name = 'PowershellGet-development'; Uri = 'https://old.example/' } }
      try {
        Publish-PSModuleToProGetFeed -NupkgPath $script:fakeNupkg -Tier Alpha | Out-Null
        Assert-MockCalled Set-PSResourceRepository -Times 1 -Exactly -Scope It
        Assert-MockCalled Register-PSResourceRepository -Times 0 -Exactly -Scope It
      } finally {
        Remove-Item Function:\Get-BitWardenSecret -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'Validation' {
    It 'Throws when NupkgPath does not exist' {
      function global:Get-BitWardenSecret { param([string]$SecretName) return 'dummy' }
      try {
        { Publish-PSModuleToProGetFeed -NupkgPath 'C:/does/not/exist.nupkg' -Tier Alpha } |
          Should -Throw -ExpectedMessage '*does not exist*'
      } finally {
        Remove-Item Function:\Get-BitWardenSecret -ErrorAction SilentlyContinue
      }
    }

    It 'Throws when NupkgPath is not a .nupkg' {
      function global:Get-BitWardenSecret { param([string]$SecretName) return 'dummy' }
      $wrongExt = Join-Path $script:tempRoot 'NotANupkg.zip'
      Set-Content -LiteralPath $wrongExt -Value 'x' -Encoding Ascii
      try {
        { Publish-PSModuleToProGetFeed -NupkgPath $wrongExt -Tier Alpha } |
          Should -Throw -ExpectedMessage '*.nupkg extension*'
      } finally {
        Remove-Item Function:\Get-BitWardenSecret -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $wrongExt -Force -ErrorAction SilentlyContinue
      }
    }
  }
}
