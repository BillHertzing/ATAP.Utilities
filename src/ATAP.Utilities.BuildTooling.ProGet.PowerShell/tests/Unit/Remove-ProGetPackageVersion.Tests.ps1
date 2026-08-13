#Requires -Version 7.0

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  . (Join-Path $moduleRoot 'public' 'Remove-ProGetPackageVersion.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
}

Describe 'Remove-ProGetPackageVersion' -Tag 'Unit' {
  BeforeEach {
    Mock Write-PSFMessage { }
    Mock Resolve-HostSuffixedSecretName { 'ProGet.Admin.API.Key.proget-host' }
    Mock Get-SecretATAP { 'unit-test-secret-value' }
    Mock Invoke-RestMethod { [PSCustomObject]@{ status = 'deleted' } }
  }

  It 'uses the exact official Package API POST with escaped path and query values' {
    $global:removeProGetCapturedRequest = $null
    Mock Invoke-RestMethod {
      param($Uri, $Method, $Headers, $ConnectionTimeoutSeconds, $OperationTimeoutSeconds)
      $global:removeProGetCapturedRequest = [PSCustomObject]@{
        Uri                    = if ($Uri -is [uri]) { $Uri.OriginalString } else { [string]$Uri }
        Method                 = [string]$Method
        ConnectionTimeoutSec   = $ConnectionTimeoutSeconds
        OperationTimeoutSec    = $OperationTimeoutSeconds
        ApiKey                 = $Headers['X-ApiKey']
      }
      [PSCustomObject]@{ status = 'deleted' }
    }

    try {
      $result = Remove-ProGetPackageVersion `
        -FeedName 'database qa' `
        -PackageId 'Package/With Space' `
        -PackageVersion '1.0.0+build/7' `
        -ProGetBaseUrl 'https://proget.example.invalid/' `
        -ProGetApiKeySecretName 'ProGet.Admin.API.Key.test' `
        -Confirm:$false

      $result.Deleted | Should -BeTrue
      $result.PostVerificationState | Should -Be 'RequiresIndependentVerification'
      Should -Invoke Invoke-RestMethod -Times 1 -Exactly
      $global:removeProGetCapturedRequest.Uri | Should -Be 'https://proget.example.invalid/api/packages/database%20qa/delete?name=Package%2FWith%20Space&version=1.0.0%2Bbuild%2F7'
      $global:removeProGetCapturedRequest.Method | Should -Be 'Post'
      $global:removeProGetCapturedRequest.ConnectionTimeoutSec | Should -Be 30
      $global:removeProGetCapturedRequest.OperationTimeoutSec | Should -Be 30
      $global:removeProGetCapturedRequest.ApiKey | Should -Be 'unit-test-secret-value'
    } finally {
      Remove-Variable removeProGetCapturedRequest -Scope Global -ErrorAction SilentlyContinue
    }
  }

  It 'performs no host-suffix, secret, or REST work under WhatIf' {
    $result = Remove-ProGetPackageVersion `
      -FeedName 'database-experimental' `
      -PackageId 'ATAPUtilities.Database' `
      -PackageVersion '0.1.3' `
      -ProGetBaseUrl 'https://proget.example.invalid' `
      -WhatIf

    $result.DeletionAttempted | Should -BeFalse
    $result.PostVerificationState | Should -Be 'NotPerformed'
    Should -Invoke Resolve-HostSuffixedSecretName -Times 0
    Should -Invoke Get-SecretATAP -Times 0
    Should -Invoke Invoke-RestMethod -Times 0
  }

  It 'returns a redacted structured result after successful deletion' {
    $result = Remove-ProGetPackageVersion `
      -FeedName 'database-development' `
      -PackageId 'ATAPUtilities.Database' `
      -PackageVersion '0.1.3' `
      -ProGetBaseUrl 'https://proget.example.invalid' `
      -ProGetApiKeySecretName 'ProGet.Admin.API.Key.test' `
      -Confirm:$false

    $result.FeedName | Should -Be 'database-development'
    $result.PackageId | Should -Be 'ATAPUtilities.Database'
    $result.PackageVersion | Should -Be '0.1.3'
    $result.DeletionAttempted | Should -BeTrue
    $result.Deleted | Should -BeTrue
    ($result | ConvertTo-Json -Compress) | Should -Not -Match 'unit-test-secret-value|X-ApiKey|Headers'
  }

  It 'treats HTTP 404 as an idempotent already-absent outcome' {
    Mock Invoke-RestMethod {
      $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound)
      throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('sensitive upstream response', $response)
    }

    $result = Remove-ProGetPackageVersion `
      -FeedName 'database-integration' `
      -PackageId 'ATAPUtilities.Database' `
      -PackageVersion '0.1.3' `
      -ProGetBaseUrl 'https://proget.example.invalid' `
      -ProGetApiKeySecretName 'ProGet.Admin.API.Key.test' `
      -Confirm:$false

    $result.AlreadyAbsent | Should -BeTrue
    $result.Deleted | Should -BeFalse
    $result.PostVerificationState | Should -Be 'AbsentByDeleteResponse'
  }

  It 'fails closed without calling REST when secret resolution fails' {
    Mock Get-SecretATAP { throw 'sensitive vault detail' }

    {
      Remove-ProGetPackageVersion `
        -FeedName 'database-qa' `
        -PackageId 'ATAPUtilities.Database' `
        -PackageVersion '0.1.3' `
        -ProGetBaseUrl 'https://proget.example.invalid' `
        -ProGetApiKeySecretName 'ProGet.Admin.API.Key.test' `
        -Confirm:$false
    } | Should -Throw '*Unable to resolve the ProGet administration credential*'

    Should -Invoke Invoke-RestMethod -Times 0
  }

  It 'reports authorization failure without exposing the secret or upstream message' {
    Mock Invoke-RestMethod {
      $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Forbidden)
      throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('unit-test-secret-value upstream detail', $response)
    }

    $caughtMessage = $null
    try {
      Remove-ProGetPackageVersion `
        -FeedName 'database-stable' `
        -PackageId 'ATAPUtilities.Database' `
        -PackageVersion '0.1.0' `
        -ProGetBaseUrl 'https://proget.example.invalid' `
        -ProGetApiKeySecretName 'ProGet.Admin.API.Key.test' `
        -Confirm:$false
    } catch {
      $caughtMessage = $_.Exception.Message
    }

    $caughtMessage | Should -Be 'ProGet rejected authorization for exact package-version deletion (HTTP 403).'
    $caughtMessage | Should -Not -Match 'unit-test-secret-value|upstream detail'
  }

  It 'derives a host-suffixed SecretName only after approval when unbound' {
    $null = Remove-ProGetPackageVersion `
      -FeedName 'database-stable' `
      -PackageId 'ATAPUtilities.Database' `
      -PackageVersion '0.1.3' `
      -ProGetBaseUrl 'https://proget.example.invalid' `
      -Confirm:$false

    Should -Invoke Resolve-HostSuffixedSecretName -Times 1 -Exactly -ParameterFilter {
      $BaseName -eq 'ProGet.Admin.API.Key' -and
      $ServiceName -eq 'ProGet' -and
      $SettingName -eq 'ProGetAdminApiKeySecretName'
    }
    Should -Invoke Get-SecretATAP -Times 1 -Exactly -ParameterFilter {
      $SecretName -eq 'ProGet.Admin.API.Key.proget-host' -and
      $SecretStoreType -eq 'BitwardenSecretsManager'
    }
  }
}
