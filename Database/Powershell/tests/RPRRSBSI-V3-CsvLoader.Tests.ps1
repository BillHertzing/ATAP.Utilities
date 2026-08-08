#Requires -Version 7.0
#Requires -Module Pester

BeforeAll {
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
  $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
  $dataDirectory = Join-Path $repoRoot 'Database\Flyway\Data'

  $loaderToCsv = [ordered]@{
    'V00020__Load_RPRRSBSI_V3_Philote.sql'            = 'Philote.csv'
    'V00030__Load_RPRRSBSI_V3_TimeBlock.sql'          = 'TimeBlock.csv'
    'V00040__Load_RPRRSBSI_V3_RuleKind.sql'           = 'RuleKind.csv'
    'V00050__Load_RPRRSBSI_V3_RulePrimitive.sql'      = 'RulePrimitive.csv'
    'V00060__Load_RPRRSBSI_V3_RulePrimitiveInput.sql' = 'RulePrimitiveInput.csv'
    'V00070__Load_RPRRSBSI_V3_Rule.sql'               = 'Rule.csv'
    'V00080__Load_RPRRSBSI_V3_RuleSet.sql'            = 'RuleSet.csv'
    'V00090__Load_RPRRSBSI_V3_RuleSetRule.sql'        = 'RuleSetRule.csv'
    'V00100__Load_RPRRSBSI_V3_BuildSet.sql'           = 'BuildSet.csv'
    'V00110__Load_RPRRSBSI_V3_BuildSetRuleSet.sql'    = 'BuildSetRuleSet.csv'
    'V00120__Load_RPRRSBSI_V3_Instantiation.sql'      = 'Instantiation.csv'
  }

  function Get-NormalizedSqlNvarcharHash {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory)]
      [string] $Path
    )

    $content = [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false))
    if ($content.Length -gt 0 -and $content[0] -eq [char]0xFEFF) {
      $content = $content.Substring(1)
    }
    $normalized = $content.Replace("`r`n", "`n")
    $bytes = [Text.Encoding]::Unicode.GetBytes($normalized)
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
  }
}

Describe 'RPRRSBSI V3 CSV loader source contract' {
  It 'keeps one loader for each of the eleven approved CSV sources' {
    $actualLoaders = @(Get-ChildItem -LiteralPath $sqlDirectory -Filter 'V*__Load_RPRRSBSI_V3_*.sql' -File)
    $actualLoaders.Count | Should -Be 11
    @($actualLoaders.Name | Sort-Object) | Should -Be @($loaderToCsv.Keys | Sort-Object)
  }

  It 'does not bulk insert into temporary tables' {
    foreach ($loaderName in $loaderToCsv.Keys) {
      $sql = Get-Content -LiteralPath (Join-Path $sqlDirectory $loaderName) -Raw
      $sql | Should -Not -Match '(?im)^\s*BULK\s+INSERT\s+#{1,2}' -Because $loaderName
    }
  }

  It 'pins each normalized CSV source and retains the exact-value validation path' {
    foreach ($entry in $loaderToCsv.GetEnumerator()) {
      $sql = Get-Content -LiteralPath (Join-Path $sqlDirectory $entry.Key) -Raw
      $hash = Get-NormalizedSqlNvarcharHash -Path (Join-Path $dataDirectory $entry.Value)

      $sql | Should -Match "(?i)HASHBYTES\('SHA2_256',\s*CONVERT\(varbinary\(max\),\s*@SourceFile\)\)"
      $sql | Should -Match "(?i)0x$hash" -Because "$($entry.Key) must pin $($entry.Value)"
      $sql | Should -Match '(?i)SINGLE_CLOB'
      $sql | Should -Match '(?i)CREATE\s+TABLE\s+#\w+Seed'
      $sql | Should -Match '(?i)(differs from|must contain only).*approved|approved.*(source|catalog|registry|ordering|seed|row)'
    }
  }

  It 'does not add a persistent staging table to the approved schema' {
    foreach ($loaderName in $loaderToCsv.Keys) {
      $sql = Get-Content -LiteralPath (Join-Path $sqlDirectory $loaderName) -Raw
      $sql | Should -Not -Match '(?im)^\s*CREATE\s+TABLE\s+(?!#)' -Because $loaderName
    }
  }
}
