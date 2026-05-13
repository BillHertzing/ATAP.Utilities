BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  function global:Resolve-DatabaseSqlConnection {
    param(
      $OriginalPSBoundParameters,
      $SqlConnection,
      $BitwardenSecretName,
      $DatabaseHost,
      $InstanceName,
      $DatabaseName,
      $ConnectionMethod,
      $CredentialsKey,
      $ApplicationName,
      [switch]$UseTrustedConnection,
      [switch]$IntegratedSecurity,
      $Settings
    )
  }
  function global:Invoke-BuildToolingSqlQuery {
    param($SqlConnection, $Query, $Parameters, $As)
  }
  function global:Get-RepositoryRoot { param([string]$StartPath) (Get-Location).Path }

  . "$PSScriptRoot\..\..\private\BuildToolingSql.Helpers.ps1"
  . "$PSScriptRoot\..\..\public\Read-SourceAndCreateRules.ps1"
}

Describe 'Read-SourceAndCreateRules [public]' {
  BeforeEach {
    $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "read-rules-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
    $script:sourceFile = Join-Path $script:testRoot 'Get-Example.ps1'
    @'
function Get-Example {
<#
.SYNOPSIS
Returns an example value.
#>
  'example'
}
'@ | Set-Content -LiteralPath $script:sourceFile -Encoding UTF8

    Mock -CommandName Resolve-DatabaseSqlConnection -MockWith {
      [PSCustomObject]@{
        DataSource = 'mock-sql'
        Database   = 'ATAPUtilities'
      }
    }

    Mock -CommandName Invoke-BuildToolingSqlQuery -MockWith { 1 }
  }

  AfterEach {
    Remove-Item -LiteralPath $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'does not require database connection resolution for non-database output' {
    $result = Read-SourceAndCreateRules -SourceFiles $script:sourceFile -SkipCSV

    $result.Success | Should -BeTrue
    $result.ExtractedRules | Should -Be 1
    Should -Invoke -CommandName Resolve-DatabaseSqlConnection -Times 0 -Exactly
    Should -Invoke -CommandName Invoke-BuildToolingSqlQuery -Times 0 -Exactly
  }

  It 'resolves the database connection and writes philote and rule rows when requested' {
    $result = Read-SourceAndCreateRules `
      -SourceFiles $script:sourceFile `
      -WriteToDatabase `
      -SkipCSV `
      -BitwardenSecretName 'rules-db'

    $result.Success | Should -BeTrue
    Should -Invoke -CommandName Resolve-DatabaseSqlConnection -Times 1 -Exactly -ParameterFilter {
      $BitwardenSecretName -eq 'rules-db'
    }
    Should -Invoke -CommandName Invoke-BuildToolingSqlQuery -Times 2 -Exactly
    Should -Invoke -CommandName Invoke-BuildToolingSqlQuery -Times 1 -ParameterFilter {
      $Parameters.ContainsKey('PrimitiveLanguageKindId') -and
      $Parameters['Name'] -eq 'Get-Example'
    }
  }
}
