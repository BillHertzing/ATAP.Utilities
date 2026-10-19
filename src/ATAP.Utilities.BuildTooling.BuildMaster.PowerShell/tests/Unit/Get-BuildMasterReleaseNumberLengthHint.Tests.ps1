#Requires -Version 7.0
# Pester 5+ tests for the non-exported Get-BuildMasterReleaseNumberLengthHint helper (SC-0360).

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Start-BuildMasterPackagePipeline.ps1')
}

Describe 'Get-BuildMasterReleaseNumberLengthHint' -Tag 'Unit' {
  It 'returns an empty string for a release number exactly at the limit' {
    Get-BuildMasterReleaseNumberLengthHint -ReleaseNumber ('x' * 50) | Should -BeExactly ''
  }

  It 'returns an empty string for a release number well under the limit' {
    Get-BuildMasterReleaseNumberLengthHint -ReleaseNumber '1.0.0' | Should -BeExactly ''
  }

  It 'returns an empty string for an empty or null release number' {
    Get-BuildMasterReleaseNumberLengthHint -ReleaseNumber '' | Should -BeExactly ''
    Get-BuildMasterReleaseNumberLengthHint -ReleaseNumber $null | Should -BeExactly ''
  }

  It 'names the length, the limit, and the bounded alternative for a release number one over the limit' {
    $hint = Get-BuildMasterReleaseNumberLengthHint -ReleaseNumber ('x' * 51)
    $hint | Should -Match '^ '
    $hint | Should -BeLike '*is 51 characters, longer than the 50-character workspace release-number bound*'
    $hint | Should -BeLike '*ConvertTo-BuildMasterBoundedReleaseNumber*'
    $hint | Should -BeLike '*SC-0360*'
  }

  It 'honours a non-default maximum length' {
    Get-BuildMasterReleaseNumberLengthHint -ReleaseNumber ('x' * 30) -MaximumLength 20 | Should -BeLike '*is 30 characters, longer than the 20-character workspace release-number bound*'
  }
}
