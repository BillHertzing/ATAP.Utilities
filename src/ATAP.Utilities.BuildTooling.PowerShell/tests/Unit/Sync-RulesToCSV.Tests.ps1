BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  function global:Get-RepositoryRoot { param([string]$StartPath) (Get-Location).Path }

  function New-TestDataTable {
    param(
      [string[]]$Columns,
      [object[]]$Rows
    )

    $table = [System.Data.DataTable]::new()
    foreach ($column in $Columns) {
      [void]$table.Columns.Add($column)
    }

    foreach ($row in $Rows) {
      $dataRow = $table.NewRow()
      foreach ($column in $Columns) {
        $dataRow[$column] = $row[$column]
      }
      [void]$table.Rows.Add($dataRow)
    }

    return , $table
  }

  . "$PSScriptRoot\..\..\private\BuildToolingSql.Helpers.ps1"
  . "$PSScriptRoot\..\..\public\Sync-RulesToCSV.ps1"
}

Describe 'Sync-RulesToCSV [public]' {
  BeforeEach {
    $script:outputPath = Join-Path ([System.IO.Path]::GetTempPath()) "sync-rules-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:outputPath -Force | Out-Null
    $script:dataTableCall = 0

    Mock -CommandName Resolve-BuildToolingDatabaseSqlConnection -MockWith {
      [PSCustomObject]@{
        DataSource = 'mock-sql'
        Database   = 'ATAPUtilities'
      }
    }

    Mock -CommandName Invoke-BuildToolingSqlQuery -MockWith {
      param($SqlConnection, $Query, $Parameters, $As)

      if ($As -eq 'Scalar') {
        return 1
      }

      $script:dataTableCall++
      if ($script:dataTableCall -eq 1) {
        return New-TestDataTable `
          -Columns @('PhiloteId', 'Comment') `
          -Rows @(@{ PhiloteId = 'rule-philote-1'; Comment = 'Rule One' })
      }

      if ($script:dataTableCall -eq 2) {
        return New-TestDataTable `
          -Columns @('PhiloteId', 'PrimitiveLanguageKindId', 'Name', 'Purpose', 'SourceFileReference') `
          -Rows @(@{
            PhiloteId               = 'rule-philote-1'
            PrimitiveLanguageKindId = 1
            Name                    = 'RuleOne'
            Purpose                 = 'Purpose one'
            SourceFileReference     = 'src/rule-one.ps1'
          })
      }

      return New-TestDataTable -Columns @('Empty') -Rows @()
    }
  }

  AfterEach {
    Remove-Item -LiteralPath $script:outputPath -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'uses the shared resolver and exports rule CSV files from mocked data' {
    $result = Sync-RulesToCSV `
      -DBConnectionStringSecretName 'rules-db' `
      -LanguageKind 'CSharp' `
      -TableType 'Rules' `
      -OutputPath $script:outputPath `
      -Force `
      -Confirm:$false

    Should -Invoke -CommandName Resolve-BuildToolingDatabaseSqlConnection -Times 1 -Exactly -ParameterFilter {
      $DBConnectionStringSecretName -eq 'rules-db'
    }

    Should -Invoke -CommandName Invoke-BuildToolingSqlQuery -Times 3 -Exactly

    $ruleFile = Join-Path $script:outputPath 'CSharp_Rules.csv'
    $philoteFile = Join-Path $script:outputPath 'CSharp_Philote_Rules.csv'

    Test-Path -LiteralPath $ruleFile | Should -BeTrue
    Test-Path -LiteralPath $philoteFile | Should -BeTrue

    $rules = Import-Csv -LiteralPath $ruleFile
    $rules[0].Name | Should -Be 'RuleOne'
    $result.TotalRows | Should -Be 2
  }
}
