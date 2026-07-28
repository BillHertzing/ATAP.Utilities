#Requires -Version 7.0

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $publicDir = Join-Path $moduleRoot 'public'

  . (Join-Path $publicDir 'Get-InstantiationVersionRuleGraph.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }

  $script:testConnection = [pscustomobject]@{
    Closed  = $false
    Disposed = $false
  }
  Add-Member -InputObject $script:testConnection -MemberType ScriptMethod -Name Close -Value { $this.Closed = $true }
  Add-Member -InputObject $script:testConnection -MemberType ScriptMethod -Name Dispose -Value { $this.Disposed = $true }

  Mock Resolve-DatabaseSqlConnection {
    [pscustomobject]@{ Connection = $script:testConnection; IsCallerOwned = $false }
  }
}

AfterAll {
  Remove-Variable -Name testConnection -Scope Script -ErrorAction SilentlyContinue
}

Describe 'Get-InstantiationVersionRuleGraph' -Tag 'Unit' {
  It 'orders BuildSetVersion, RuleSetVersion, and RuleVersion rows by sort order' {
    Mock Invoke-DatabaseSqlQuery {
      @(
        [pscustomobject]@{
          BuildSetVersionPhiloteId      = '11111111-1111-1111-1111-111111111111'
          BuildSetSortOrder             = '2'
          RuleSetMembershipSortOrder    = '20'
          RuleSetVersionPhiloteId       = '33333333-3333-3333-3333-333333333333'
          RuleSetVersionSortOrder       = '4'
          RuleVersionMembershipSortOrder = '21'
          RuleVersionPhiloteId          = '55555555-5555-5555-5555-555555555555'
          RuleVersionSortOrder          = '1'
        }
        [pscustomobject]@{
          BuildSetVersionPhiloteId      = '22222222-2222-2222-2222-222222222222'
          BuildSetSortOrder             = '1'
          RuleSetMembershipSortOrder    = '10'
          RuleSetVersionPhiloteId       = '44444444-4444-4444-4444-444444444444'
          RuleSetVersionSortOrder       = '3'
          RuleVersionMembershipSortOrder = '11'
          RuleVersionPhiloteId          = '66666666-6666-6666-6666-666666666666'
          RuleVersionSortOrder          = '2'
        }
      )
    }

    $result = Get-InstantiationVersionRuleGraph -InstantiationVersionPhiloteId ([guid]'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')

    $result.BuildSetVersions[0].BuildSetVersionPhiloteId | Should -Be ([guid]'22222222-2222-2222-2222-222222222222')
    $result.BuildSetVersions[1].BuildSetVersionPhiloteId | Should -Be ([guid]'11111111-1111-1111-1111-111111111111')

    $ruleSet = $result.BuildSetVersions[0].RuleSetVersions[0]
    $ruleSet.RuleSetVersionPhiloteId | Should -Be ([guid]'44444444-4444-4444-4444-444444444444')
    $ruleSet.RuleVersions[0].RuleVersionPhiloteId | Should -Be ([guid]'66666666-6666-6666-6666-666666666666')
    $ruleSet.RuleVersions[0].SortOrder | Should -Be 11
  }

  It 'returns only the corrected three-level InstantiationVersion graph (BuildSetVersion/RuleSetVersion/RuleVersion)' {
    Mock Invoke-DatabaseSqlQuery {
      @(
        [pscustomobject]@{
          BuildSetVersionPhiloteId      = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
          BuildSetSortOrder             = '1'
          RuleSetMembershipSortOrder    = '10'
          RuleSetVersionPhiloteId       = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
          RuleSetVersionSortOrder       = '20'
          RuleVersionMembershipSortOrder = '30'
          RuleVersionPhiloteId          = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
          RuleVersionSortOrder          = '40'
        }
      )
    }

    $result = Get-InstantiationVersionRuleGraph -InstantiationVersionPhiloteId ([guid]'01234567-89ab-cdef-0123-456789abcdef')

    $result.PSObject.Properties.Name -contains 'BuildVersions' | Should -BeFalse
    $result.BuildSetVersions | Should -HaveCount 1
    $result.BuildSetVersions[0].RuleSetVersions | Should -HaveCount 1
    $result.BuildSetVersions[0].RuleSetVersions[0].RuleVersions | Should -HaveCount 1
  }

  It 'throws if no graph rows are found for the InstantiationVersion' {
    Mock Invoke-DatabaseSqlQuery { @() }

    { Get-InstantiationVersionRuleGraph -InstantiationVersionPhiloteId ([guid]'aaaaaaaa-1111-2222-3333-444444444444') } |
      Should -Throw -ExpectedMessage '*No BuildSetVersion-to-RuleSetVersion-to-RuleVersion graph rows found*'
  }
}
