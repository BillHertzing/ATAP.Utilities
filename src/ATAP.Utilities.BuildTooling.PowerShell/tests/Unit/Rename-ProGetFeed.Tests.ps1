#Requires -Version 7.0
# Pester 5+ unit tests for Rename-ProGetFeed.
# All REST and settings access are mocked / stubbed; no network calls are made.

# ── 0 ▸ Locate & load optional test-data files ──────────────────────────────
# No separate DataForTests file exists for this cmdlet.

BeforeAll {
  # Dot-source the function under test.
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Rename-ProGetFeed.ps1')

  # Stub Write-PSFMessage so test output stays clean.
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param([Parameter(ValueFromRemainingArguments = $true)]$rest)
    }
  }

  # Stub Get-PVal: if the parameter was supplied on the cmdline, return it;
  # otherwise return -DefaultValue.  This simulates an empty $global:settings
  # without requiring the full module infrastructure.
  if (-not (Get-Command Get-PVal -ErrorAction SilentlyContinue)) {
    function global:Get-PVal {
      param(
        [string]$ParameterName,
        [hashtable]$originalPSBoundParameters,
        [string]$dottedPath,
        $DefaultValue
      )
      if ($null -ne $originalPSBoundParameters -and
        $originalPSBoundParameters.ContainsKey($ParameterName)) {
        return $originalPSBoundParameters[$ParameterName]
      }
      return $DefaultValue
    }
  }
}

AfterAll {
  Remove-Item Function:\Get-PVal -ErrorAction SilentlyContinue
  Remove-Item Function:\Write-PSFMessage -ErrorAction SilentlyContinue
}

# ── 1 ▸ Static tests (no data required) ─────────────────────────────────────
Describe 'Rename-ProGetFeed — static' {

  BeforeEach {
    Mock Invoke-RestMethod { [PSCustomObject]@{} }
    Mock Write-PSFMessage { }
    # Ensure global fallback values are clear for each test.
    $global:ProGetBaseUrl = $null
    $env:PROGET_BASE_URL = $null
    $env:PROGET_API_KEY = $null
  }

  Context 'Happy path — explicit parameters' {

    It 'Returns a PSCustomObject with Success = $true' {
      $result = Rename-ProGetFeed `
        -OldFeedName 'old-feed' `
        -NewFeedName 'new-feed' `
        -ProGetBaseUrl 'http://proget.test' `
        -ApiKey 'test-key'

      $result | Should -Not -BeNullOrEmpty
      $result.Success | Should -BeTrue
      $result.OldFeedName | Should -Be 'old-feed'
      $result.NewFeedName | Should -Be 'new-feed'
    }

    It 'Returns the Response from Invoke-RestMethod' {
      $fakeResponse = [PSCustomObject]@{ feedName = 'new-feed' }
      Mock Invoke-RestMethod { $fakeResponse }

      $result = Rename-ProGetFeed `
        -OldFeedName 'old-feed' `
        -NewFeedName 'new-feed' `
        -ProGetBaseUrl 'http://proget.test' `
        -ApiKey 'test-key'

      $result.Response | Should -Be $fakeResponse
    }

    It 'Calls Invoke-RestMethod with the correct update URI' {
      Rename-ProGetFeed `
        -OldFeedName 'my-feed' `
        -NewFeedName 'renamed-feed' `
        -ProGetBaseUrl 'http://proget.test' `
        -ApiKey 'test-key'

      Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
        $Uri -eq 'http://proget.test/api/management/feeds/update/my-feed' -and
        $Method -eq 'Post'
      }
    }

    It 'Strips a trailing slash from ProGetBaseUrl' {
      Rename-ProGetFeed `
        -OldFeedName 'feed1' `
        -NewFeedName 'feed2' `
        -ProGetBaseUrl 'http://proget.test/' `
        -ApiKey 'key'

      Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
        $Uri -eq 'http://proget.test/api/management/feeds/update/feed1'
      }
    }

    It 'Sends the X-ApiKey header with the provided key' {
      Rename-ProGetFeed `
        -OldFeedName 'a' `
        -NewFeedName 'b' `
        -ProGetBaseUrl 'http://proget.test' `
        -ApiKey 'secret-key'

      Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
        $Headers['X-ApiKey'] -eq 'secret-key'
      }
    }

    It 'Sends a JSON body containing the new feed name' {
      Rename-ProGetFeed `
        -OldFeedName 'source' `
        -NewFeedName 'target' `
        -ProGetBaseUrl 'http://proget.test' `
        -ApiKey 'k'

      Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
        ($Body | ConvertFrom-Json).name -eq 'target'
      }
    }

    It 'URL-encodes a feed name that contains special characters' {
      Rename-ProGetFeed `
        -OldFeedName 'feed with spaces' `
        -NewFeedName 'no-spaces' `
        -ProGetBaseUrl 'http://proget.test' `
        -ApiKey 'k'

      Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
        $Uri -eq 'http://proget.test/api/management/feeds/update/feed%20with%20spaces'
      }
    }
  }

  Context '-WhatIf suppresses REST call' {

    It 'Does not call Invoke-RestMethod when -WhatIf is specified' {
      $result = Rename-ProGetFeed `
        -OldFeedName 'old' `
        -NewFeedName 'new' `
        -ProGetBaseUrl 'http://proget.test' `
        -ApiKey 'k' `
        -WhatIf

      Should -Invoke Invoke-RestMethod -Times 0
    }

    It 'Returns Success = $false when -WhatIf is specified' {
      $result = Rename-ProGetFeed `
        -OldFeedName 'old' `
        -NewFeedName 'new' `
        -ProGetBaseUrl 'http://proget.test' `
        -ApiKey 'k' `
        -WhatIf

      $result.Success | Should -BeFalse
      $result.Response | Should -BeNullOrEmpty
    }
  }

  Context 'Error handling' {

    It 'Re-throws when Invoke-RestMethod fails' {
      Mock Invoke-RestMethod { throw 'ProGet API returned 500' }

      {
        Rename-ProGetFeed `
          -OldFeedName 'bad' `
          -NewFeedName 'worse' `
          -ProGetBaseUrl 'http://proget.test' `
          -ApiKey 'k'
      } | Should -Throw
    }

    It 'Throws when ProGetBaseUrl cannot be resolved' {
      # Paranoia clear — ensure none of the fallbacks are populated.
      $global:ProGetBaseUrl = $null
      $env:PROGET_BASE_URL = $null

      { Rename-ProGetFeed -OldFeedName 'a' -NewFeedName 'b' -ApiKey 'k' } | Should -Throw -Because 'ProGetBaseUrl has no source'
    }

    It 'Throws when ApiKey cannot be resolved' {
      $env:PROGET_API_KEY = $null

      { Rename-ProGetFeed -OldFeedName 'a' -NewFeedName 'b' -ProGetBaseUrl 'http://proget.test' } | Should -Throw -Because 'ApiKey has no source'
    }
  }

  Context 'Global ProGetBaseUrl fallback' {

    It 'Resolves ProGetBaseUrl from $global:ProGetBaseUrl when parameter omitted' {
      $global:ProGetBaseUrl = 'http://global-proget.test'
      $env:PROGET_API_KEY = $null      # ensure env fallback not used for ApiKey
      $env:PROGET_BASE_URL = $null

      Rename-ProGetFeed -OldFeedName 'x' -NewFeedName 'y' -ApiKey 'k'

      Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
        $Uri -like 'http://global-proget.test/*'
      }

      $global:ProGetBaseUrl = $null   # restore
    }
  }
}

# ── 2 ▸ Data-driven tests (run for every object in $TestCases) ──────────────
Describe 'Rename-ProGetFeed — data-driven' {

  BeforeAll {
    Mock Invoke-RestMethod { [PSCustomObject]@{} }
    Mock Write-PSFMessage { }
    $global:ProGetBaseUrl = $null
    $env:PROGET_BASE_URL = $null
    $env:PROGET_API_KEY = $null
  }

  $TestCases = @(
    @{ OldFeedName = 'nuget-sprint'; NewFeedName = 'nuget-experimental' }
    @{ OldFeedName = 'powershellget-alpha'; NewFeedName = 'powershellget-development' }
    @{ OldFeedName = 'nuget-beta'; NewFeedName = 'nuget-integration' }
    @{ OldFeedName = 'my-feed'; NewFeedName = 'my-renamed-feed' }
  )

  It "Renames '<OldFeedName>' to '<NewFeedName>' successfully" -TestCases $TestCases {
    param($OldFeedName, $NewFeedName)

    $result = Rename-ProGetFeed `
      -OldFeedName $OldFeedName `
      -NewFeedName $NewFeedName `
      -ProGetBaseUrl 'http://proget.test' `
      -ApiKey 'test-api-key'

    $result.Success | Should -BeTrue
    $result.OldFeedName | Should -Be $OldFeedName
    $result.NewFeedName | Should -Be $NewFeedName

    Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
      $Uri -like "*/api/management/feeds/update/$([uri]::EscapeDataString($OldFeedName))" -and
      $Method -eq 'Post'
    }
  }
}
