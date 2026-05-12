Describe 'DB sub-manifest schema' -Tag 'Unit', 'Schemas' {
  BeforeAll {
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:SchemaPath = Join-Path $script:RepoRoot 'SolutionDocumentation/schemas/db-manifest.schema.json'
    $script:DocPath = Join-Path $script:RepoRoot 'SolutionDocumentation/Database-Change-Unit-and-Flyway-Promotion.md'

    $docText = Get-Content -LiteralPath $script:DocPath -Raw
    $manifestExample = [regex]::Match(
      $docText,
      '(?ms)^## 8\. The DB sub-manifest format.*?```json\s*(?<json>.*?)\s*```'
    )

    if (-not $manifestExample.Success) {
      throw 'Could not find the section 8 DB sub-manifest JSON example.'
    }

    $script:ExampleJson = $manifestExample.Groups['json'].Value.Trim()

    function Invoke-DbManifestSchemaValidation {
      param(
        [Parameter(Mandatory)]
        [string] $Json
      )

      $validationErrors = $null
      $isValid = Test-Json `
        -Json $Json `
        -SchemaFile $script:SchemaPath `
        -ErrorAction SilentlyContinue `
        -ErrorVariable validationErrors

      [pscustomobject]@{
        IsValid = [bool] $isValid
        Errors = @($validationErrors)
      }
    }
  }

  It 'declares the v1 Draft 2020-12 schema identity' {
    $schema = Get-Content -LiteralPath $script:SchemaPath -Raw | ConvertFrom-Json

    $schema.'$schema' | Should -Be 'https://json-schema.org/draft/2020-12/schema'
    $schema.'$id' | Should -Be 'https://atap.example.com/schemas/db-manifest/v1.json'
  }

  It 'validates the embedded DB sub-manifest example from section 8' {
    $result = Invoke-DbManifestSchemaValidation -Json $script:ExampleJson

    $result.IsValid | Should -BeTrue
  }
}
