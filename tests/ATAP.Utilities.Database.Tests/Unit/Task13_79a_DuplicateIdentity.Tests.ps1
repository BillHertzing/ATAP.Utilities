# AI assisted using Powershell.instructions.md as guidelines

BeforeAll {
  $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
  $DataDir = Join-Path $RepoRoot 'Database\Flyway\Data'

  function Test-UniqueLanguageNameIdentity {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory)]
      [string] $CsvPath,

      [Parameter(Mandatory)]
      [int] $ExpectedLanguageId
    )

    $rows = Import-Csv -Path $CsvPath

    $duplicates = @(
      $rows |
        Where-Object {
          -not [string]::IsNullOrWhiteSpace($_.PhiloteId) -and
          -not [string]::IsNullOrWhiteSpace($_.PrimitiveLanguageKindId) -and
          [int]$_.PrimitiveLanguageKindId -eq $ExpectedLanguageId -and
          -not [string]::IsNullOrWhiteSpace($_.Name)
        } |
        ForEach-Object {
          [PSCustomObject]@{
            LanguageKind = [int]$_.PrimitiveLanguageKindId
            Name         = $_.Name.Trim().ToUpperInvariant()
          }
        } |
        Group-Object -Property { '{0}|{1}' -f $_.LanguageKind, $_.Name } |
        Where-Object Count -gt 1
    )

    return $duplicates.Count
  }
}

Describe 'Seed identity uniqueness for path and powershell rule rows' {
  It 'requires unique (PrimitiveLanguageKindId, Name) in Path_RulePrimitives.csv' {
    $duplicateCount = Test-UniqueLanguageNameIdentity -CsvPath (Join-Path $DataDir 'Path_RulePrimitives.csv') -ExpectedLanguageId 6
    $duplicateCount | Should -Be 0
  }

  It 'requires unique (PrimitiveLanguageKindId, Name) in Path_Rules.csv' {
    $duplicateCount = Test-UniqueLanguageNameIdentity -CsvPath (Join-Path $DataDir 'Path_Rules.csv') -ExpectedLanguageId 6
    $duplicateCount | Should -Be 0
  }

  It 'requires unique (PrimitiveLanguageKindId, Name) in Powershell_RulePrimitives.csv' {
    $duplicateCount = Test-UniqueLanguageNameIdentity -CsvPath (Join-Path $DataDir 'Powershell_RulePrimitives.csv') -ExpectedLanguageId 2
    $duplicateCount | Should -Be 0
  }

  It 'requires unique (PrimitiveLanguageKindId, Name) in Powershell_Rules.csv' {
    $duplicateCount = Test-UniqueLanguageNameIdentity -CsvPath (Join-Path $DataDir 'Powershell_Rules.csv') -ExpectedLanguageId 2
    $duplicateCount | Should -Be 0
  }
}

