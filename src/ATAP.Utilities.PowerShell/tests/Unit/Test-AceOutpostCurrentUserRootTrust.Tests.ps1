#Requires -Module Pester

BeforeAll {
  . (Join-Path $PSScriptRoot '..\..\private\Test-AceOutpostCurrentUserRootTrust.ps1')
  if (-not (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments)]$Rest) }
  }
  $script:rawCertificate = [byte[]](1, 2, 3, 4, 5)
  $script:certificateSha256 = [Convert]::ToHexString(
    [System.Security.Cryptography.SHA256]::HashData($script:rawCertificate))
  $script:thumbprint = '0123456789ABCDEF0123456789ABCDEF01234567'
}

Describe 'Test-AceOutpostCurrentUserRootTrust' -Tag 'Unit' {
  It 'accepts only a candidate matching both thumbprint and complete-certificate SHA-256' {
    Mock Get-ChildItem {
      [pscustomobject]@{ Thumbprint = $script:thumbprint; RawData = $script:rawCertificate }
    }

    Test-AceOutpostCurrentUserRootTrust `
      -Thumbprint $script:thumbprint `
      -CertificateSha256 $script:certificateSha256 | Should -BeTrue
  }

  It 'rejects a thumbprint match whose complete certificate bytes differ' {
    Mock Get-ChildItem {
      [pscustomobject]@{ Thumbprint = $script:thumbprint; RawData = [byte[]](9, 8, 7) }
    }

    Test-AceOutpostCurrentUserRootTrust `
      -Thumbprint $script:thumbprint `
      -CertificateSha256 $script:certificateSha256 | Should -BeFalse
  }

  It 'reads only the current user Trusted Root store' {
    Mock Get-ChildItem { @() }

    Test-AceOutpostCurrentUserRootTrust `
      -Thumbprint $script:thumbprint `
      -CertificateSha256 $script:certificateSha256 | Should -BeFalse
    Should -Invoke Get-ChildItem -Times 1 -Exactly -ParameterFilter {
      $LiteralPath -eq 'Cert:\CurrentUser\Root'
    }
  }
}
