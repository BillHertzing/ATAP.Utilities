#Requires -Version 7.0

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  . (Join-Path $moduleRoot 'public\Get-InstantiationVersionRuleGraph.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
  if (-not (Get-Command Invoke-DatabaseSqlQuery -ErrorAction SilentlyContinue)) {
    function global:Invoke-DatabaseSqlQuery {
      param($SqlConnection, [string]$CommandText, [hashtable]$Parameters)
      throw 'Test stub must be mocked.'
    }
  }

  $script:testConnection = [pscustomobject]@{ Closed = $false; Disposed = $false }
  Add-Member -InputObject $script:testConnection -MemberType ScriptMethod -Name Close -Value { $this.Closed = $true }
  Add-Member -InputObject $script:testConnection -MemberType ScriptMethod -Name Dispose -Value { $this.Disposed = $true }
  Mock Resolve-DatabaseSqlConnection {
    [pscustomobject]@{ Connection = $script:testConnection; IsCallerOwned = $false }
  }

  $script:iv = [guid]'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  $script:instantiation = [guid]'aaaaaaaa-0000-0000-0000-000000000001'
  $script:bsv = [guid]'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
  $script:rsv = [guid]'cccccccc-cccc-cccc-cccc-cccccccccccc'
  $script:rule = [guid]'dddddddd-dddd-dddd-dddd-dddddddddddd'
  $script:rv = [guid]'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
  $script:ri = [guid]'ffffffff-ffff-ffff-ffff-ffffffffffff'
  $script:riv = [guid]'11111111-2222-3333-4444-555555555555'
  $script:primitive = [guid]'99999999-8888-7777-6666-555555555555'
}

Describe 'Get-InstantiationVersionRuleGraph' -Tag 'Unit' {
  BeforeEach {
    $script:scenario = 'valid'
    $script:bindingQuery = $null
    Mock Invoke-DatabaseSqlQuery {
      if ($CommandText -match 'Task13\.80:Graph') {
        return [pscustomobject]@{
          InstantiationPhiloteId = $script:instantiation
          InstantiationVersionNumber = 1
          InstantiationVersionLabel = 'v1'
          BuildSetVersionPhiloteId = $script:bsv
          BuildSetSortOrder = 1
          RuleSetMembershipSortOrder = 10
          RuleSetVersionPhiloteId = $script:rsv
          RuleSetVersionSortOrder = 1
          RuleVersionMembershipSortOrder = 20
          RuleVersionPhiloteId = $script:rv
          RulePhiloteId = $script:rule
          RuleVersionSortOrder = 1
          ContentSha256 = ('A' * 64)
        }
      }
      if ($CommandText -match 'Task13\.80:Snapshots') {
        $selectedRuleVersion = if ($script:scenario -eq 'out-of-graph') {
          [guid]'12121212-3434-5656-7878-909090909090'
        } else {
          $script:rv
        }
        return [pscustomobject]@{
          SortOrder = 10
          RuleInstantiationVersionPhiloteId = $script:riv
          RuleInstantiationPhiloteId = $script:ri
          RuleVersionPhiloteId = $selectedRuleVersion
          RulePhiloteId = $script:rule
          VersionNumber = 1
          VersionLabel = 'v1'
          EffectiveFrom = [datetime]'2026-01-01T00:00:00Z'
        }
      }
      if ($CommandText -match 'Task13\.80:Declarations') {
        if ($script:scenario -in @('source-line', 'source-line-missing')) {
          return @(
            [pscustomobject]@{
              RuleInstantiationVersionPhiloteId = $script:riv
              Position = 1
              PrimitivePhiloteId = $script:primitive
              PrimitiveName = 'SourceLine'
              IsOptional = $false
              Cardinality = 'OneOrMore'
              InputName = 'Ordinal'
              TypeName = 'int'
              DefaultValue = $null
              IsRequired = $true
            },
            [pscustomobject]@{
              RuleInstantiationVersionPhiloteId = $script:riv
              Position = 1
              PrimitivePhiloteId = $script:primitive
              PrimitiveName = 'SourceLine'
              IsOptional = $false
              Cardinality = 'OneOrMore'
              InputName = 'Text'
              TypeName = 'string'
              DefaultValue = $null
              IsRequired = $true
            },
            [pscustomobject]@{
              RuleInstantiationVersionPhiloteId = $script:riv
              Position = 1
              PrimitivePhiloteId = $script:primitive
              PrimitiveName = 'SourceLine'
              IsOptional = $false
              Cardinality = 'OneOrMore'
              InputName = 'LineEnding'
              TypeName = 'string'
              DefaultValue = 'CRLF'
              IsRequired = $false
            }
          )
        }
        return [pscustomobject]@{
          RuleInstantiationVersionPhiloteId = $script:riv
          Position = 1
          PrimitivePhiloteId = $script:primitive
          PrimitiveName = 'ScalarValue'
          IsOptional = $false
          Cardinality = 'One'
          InputName = 'Value'
          TypeName = 'string'
          DefaultValue = $null
          IsRequired = $true
        }
      }
      if ($CommandText -match 'Task13\.80:BindingsAsOfSnapshot') {
        $script:bindingQuery = $CommandText
        if ($script:scenario -in @('missing', 'source-line', 'source-line-missing')) { return @() }
        $rows = @(
          [pscustomobject]@{
            RuleInstantiationVersionPhiloteId = $script:riv
            InputName = 'Value'
            InputValue = 'snapshot-value'
            EffectiveFrom = [datetime]'2025-12-01T00:00:00Z'
            EffectiveTo = [datetime]'2026-02-01T00:00:00Z'
          }
        )
        if ($script:scenario -eq 'duplicate') { $rows += $rows[0].PSObject.Copy() }
        if ($script:scenario -eq 'undeclared') {
          $rows += [pscustomobject]@{
            RuleInstantiationVersionPhiloteId = $script:riv
            InputName = 'Typo'
            InputValue = 'bad'
            EffectiveFrom = [datetime]'2025-12-01T00:00:00Z'
            EffectiveTo = $null
          }
        }
        return $rows
      }
      if ($CommandText -match 'Task13\.80:SourceLines') {
        if ($script:scenario -eq 'source-line') {
          return [pscustomobject]@{
            RuleInstantiationVersionPhiloteId = $script:riv
            Ordinal = 1
            LineText = '# Documentation'
            LineEnding = 'CRLF'
          }
        }
        return @()
      }
      if ($CommandText -match 'Task13\.80:Artifacts') { return @() }
      throw "Unexpected query: $CommandText"
    }
  }

  It 'returns the corrected ordered graph without a Build layer' {
    $result = Get-InstantiationVersionRuleGraph -InstantiationVersionPhiloteId $script:iv

    $result.PSObject.Properties.Name | Should -Not -Contain 'BuildVersions'
    $result.BuildSetVersions | Should -HaveCount 1
    $result.BuildSetVersions[0].RuleSetVersions[0].RuleVersions[0].RuleVersionPhiloteId | Should -Be $script:rv
    $result.RuleInstantiations[0].Bindings[0].InputValue | Should -Be 'snapshot-value'
  }

  It 'fails when a required input is missing' {
    $script:scenario = 'missing'
    { Get-InstantiationVersionRuleGraph -InstantiationVersionPhiloteId $script:iv } |
      Should -Throw -ExpectedMessage '*missing required binding*Value*'
  }

  It 'fails when a binding is duplicated' {
    $script:scenario = 'duplicate'
    { Get-InstantiationVersionRuleGraph -InstantiationVersionPhiloteId $script:iv } |
      Should -Throw -ExpectedMessage '*duplicate binding*Value*'
  }

  It 'fails when a binding is undeclared' {
    $script:scenario = 'undeclared'
    { Get-InstantiationVersionRuleGraph -InstantiationVersionPhiloteId $script:iv } |
      Should -Throw -ExpectedMessage '*undeclared binding*Typo*'
  }

  It 'fails when a snapshot RuleVersion is outside the selected graph' {
    $script:scenario = 'out-of-graph'
    { Get-InstantiationVersionRuleGraph -InstantiationVersionPhiloteId $script:iv } |
      Should -Throw -ExpectedMessage '*out-of-graph RuleVersion*'
  }

  It 'resolves bindings at the snapshot timestamp so a later value cannot mutate a prior version' {
    $result = Get-InstantiationVersionRuleGraph -InstantiationVersionPhiloteId $script:iv

    $result.RuleInstantiations[0].Bindings[0].InputValue | Should -Be 'snapshot-value'
    $script:bindingQuery | Should -Match 'b\.EffectiveFrom <= riv\.EffectiveFrom'
    $script:bindingQuery | Should -Match 'b\.EffectiveTo IS NULL OR b\.EffectiveTo > riv\.EffectiveFrom'
  }

  It 'resolves required SourceLine inputs from immutable source-line rows rather than scalar bindings' {
    $script:scenario = 'source-line'

    $result = Get-InstantiationVersionRuleGraph -InstantiationVersionPhiloteId $script:iv

    $result.RuleInstantiations[0].DeclaredInputs | Should -HaveCount 3
    $result.RuleInstantiations[0].Bindings | Should -HaveCount 0
    $result.RuleInstantiations[0].SourceLines | Should -HaveCount 1
    $result.RuleInstantiations[0].SourceLines[0].LineText | Should -Be '# Documentation'
  }

  It 'fails when SourceLine cardinality requires source rows but none exist' {
    $script:scenario = 'source-line-missing'

    { Get-InstantiationVersionRuleGraph -InstantiationVersionPhiloteId $script:iv } |
      Should -Throw -ExpectedMessage '*violating SourceLine cardinality*OneOrMore*'
  }

  It 'throws if no graph rows are found' {
    Mock Invoke-DatabaseSqlQuery {
      if ($CommandText -match 'Task13\.80:Graph') { return @() }
      throw 'No later query should run.'
    }
    { Get-InstantiationVersionRuleGraph -InstantiationVersionPhiloteId $script:iv } |
      Should -Throw -ExpectedMessage '*No BuildSetVersion-to-RuleSetVersion-to-RuleVersion graph rows found*'
  }
}
