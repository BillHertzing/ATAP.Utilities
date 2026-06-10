BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $publicDir = Join-Path $moduleRoot 'public'
  $privateDir = Join-Path $moduleRoot 'private'

  . (Join-Path $privateDir 'DatabaseSqlCommand.Helpers.ps1')
  . (Join-Path $publicDir 'Resolve-DatabaseSqlConnection.ps1')
  . (Join-Path $publicDir 'Export-RuleToTextFile.ps1')

  function New-RuleExportDataSet {
    $dataSet = [System.Data.DataSet]::new()

    $ruleTable = [System.Data.DataTable]::new('RuleInfo')
    foreach ($column in @('PhiloteId', 'RuleName', 'PrimitiveLanguageKind', 'CreatedAt', 'SourceFileReference', 'Purpose')) {
      [void] $ruleTable.Columns.Add($column)
    }
    $ruleRow = $ruleTable.NewRow()
    $ruleRow['PhiloteId'] = 'rule-philote-1'
    $ruleRow['RuleName'] = 'RuleOne'
    $ruleRow['PrimitiveLanguageKind'] = 'CSharp'
    $ruleRow['CreatedAt'] = '2026-01-01'
    $ruleRow['SourceFileReference'] = 'src/rule-one.cs'
    $ruleRow['Purpose'] = 'Purpose one'
    [void] $ruleTable.Rows.Add($ruleRow)
    [void] $dataSet.Tables.Add($ruleTable)

    $compositionTable = [System.Data.DataTable]::new('Composition')
    foreach ($column in @('SequenceKey', 'PrimitiveName', 'PrimitiveDescription', 'BnfDefinition', 'BoundInputsJson', 'Notes', 'PrimitiveAttribution')) {
      [void] $compositionTable.Columns.Add($column)
    }
    $compositionRow = $compositionTable.NewRow()
    $compositionRow['SequenceKey'] = '001'
    $compositionRow['PrimitiveName'] = 'PrimitiveOne'
    $compositionRow['PrimitiveDescription'] = 'Primitive description'
    $compositionRow['BnfDefinition'] = '<rule> ::= value'
    $compositionRow['BoundInputsJson'] = '{}'
    $compositionRow['Notes'] = 'Composition note'
    $compositionRow['PrimitiveAttribution'] = 'ATAP'
    [void] $compositionTable.Rows.Add($compositionRow)
    [void] $dataSet.Tables.Add($compositionTable)

    [void] $dataSet.Tables.Add([System.Data.DataTable]::new('AdditionalIds'))
    [void] $dataSet.Tables.Add([System.Data.DataTable]::new('TimeBlocks'))

    return , $dataSet
  }
}

Describe 'Export-RuleToTextFile' -Tag 'Unit' {
  BeforeEach {
    $script:outputFile = Join-Path ([System.IO.Path]::GetTempPath()) "rule-export-$([guid]::NewGuid().ToString('N')).txt"

    Mock Resolve-DatabaseSqlConnection {
      $connection = [PSCustomObject]@{
        DataSource        = 'mock-sql'
        Database          = 'ATAPUtilities'
        ConnectionString  = 'Server=mock-sql;Database=ATAPUtilities;Integrated Security=True;'
      }
      $connection | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
      $connection | Add-Member -MemberType ScriptMethod -Name Close -Value { }
      [pscustomobject]@{ Connection = $connection; IsCallerOwned = $false }
    }

    Mock Invoke-DatabaseSqlDataSet {
      New-RuleExportDataSet
    }
  }

  AfterEach {
    Remove-Item -LiteralPath $script:outputFile -Force -ErrorAction SilentlyContinue
  }

  It 'uses the shared resolver and writes the rule export file' {
    $result = Export-RuleToTextFile `
      -RuleName 'RuleOne' `
      -LanguageKind 'CSharp' `
      -DBConnectionStringSecretName 'rules-db' `
      -OutputPath $script:outputFile

    $result | Should -Be $script:outputFile
    Test-Path -LiteralPath $script:outputFile | Should -BeTrue
    Get-Content -LiteralPath $script:outputFile -Raw | Should -Match 'RuleOne'

    Should -Invoke -CommandName Resolve-DatabaseSqlConnection -Times 1 -Exactly -ParameterFilter {
      $DBConnectionStringSecretName -eq 'rules-db'
    }
    Should -Invoke -CommandName Invoke-DatabaseSqlDataSet -Times 1 -Exactly -ParameterFilter {
      $CommandText -eq 'dbo.GetRuleByName' -and
      $CommandType -eq [System.Data.CommandType]::StoredProcedure -and
      $Parameters['RuleName'] -eq 'RuleOne' -and
      $Parameters['LanguageKindName'] -eq 'CSharp'
    }
  }
}
