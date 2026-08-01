#Requires -Version 7.0

BeforeAll {
  . "$PSScriptRoot\..\..\private\Resolve-BWSReadOnlyBootstrapIdentity.ps1"
  $script:localHostName = $env:COMPUTERNAME
}

Describe 'BWS ReadOnly bootstrap policy adversarial contract' -Tag 'Unit', 'BWS', 'Policy' {
  It 'normalizes approved local account forms and fixes project and token purpose' -ForEach @(
    @{ InputName = 'SvcBuildMaster'; ExpectedSam = 'SvcBuildMaster' }
    @{ InputName = '.\svcproget'; ExpectedSam = 'SvcProGet' }
    @{ InputName = "$env:COMPUTERNAME\SVCSQLSERVER"; ExpectedSam = 'SvcSQLServer' }
  ) {
    $result = Resolve-BWSReadOnlyBootstrapIdentity -AccountName $InputName

    $result.AccountName | Should -Be "$script:localHostName\$ExpectedSam"
    $result.SamAccountName | Should -Be $ExpectedSam
    $result.ProjectName | Should -Be 'CI-Shared'
    $result.TokenPurpose | Should -Be 'ReadOnly'
  }

  It 'rejects identities outside the exact three-account allowlist' -ForEach @(
    'SvcSeq'
    'SvcParityAudit'
    'ansibleAdmin'
    'whertzing'
    'SvcBuildMaster-Backup'
  ) {
    { Resolve-BWSReadOnlyBootstrapIdentity -AccountName $_ } |
      Should -Throw '*not approved*'
  }

  It 'rejects foreign, domain-qualified, and malformed local-account names' -ForEach @(
    'UTAT999\SvcBuildMaster'
    'ATAP\SvcProGet'
    'UTAT999\nested\SvcSQLServer'
  ) {
    { Resolve-BWSReadOnlyBootstrapIdentity -AccountName $_ } |
      Should -Throw
  }

  It 'rejects attempts to select CI-Common because project input is not an exposed policy seam' {
    {
      Resolve-BWSReadOnlyBootstrapIdentity `
        -AccountName 'SvcBuildMaster' `
        -ProjectName 'CI-Common'
    } | Should -Throw '*ProjectName*'
  }

  It 'rejects attempts to elevate the bootstrap token purpose to ReadWrite' {
    {
      Resolve-BWSReadOnlyBootstrapIdentity `
        -AccountName 'SvcBuildMaster' `
        -TokenPurpose 'ReadWrite'
    } | Should -Throw '*TokenPurpose*'
  }

  It 'rejects empty or whitespace-only account input before returning policy metadata' -ForEach @('', '   ') {
    { Resolve-BWSReadOnlyBootstrapIdentity -AccountName $_ } |
      Should -Throw
  }
}
