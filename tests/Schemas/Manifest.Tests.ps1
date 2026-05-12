Describe 'Release Bundle manifest schema' -Tag 'Unit', 'Schemas' {
  BeforeAll {
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:SchemaPath = Join-Path $script:RepoRoot 'SolutionDocumentation/schemas/manifest.schema.json'
    $script:DocPath = Join-Path $script:RepoRoot 'SolutionDocumentation/Release-Branch-and-Manifest.md'

    $docText = Get-Content -LiteralPath $script:DocPath -Raw
    $manifestExample = [regex]::Match(
      $docText,
      '(?ms)^## 3\. The manifest schema.*?```json\s*(?<json>.*?)\s*```'
    )

    if (-not $manifestExample.Success) {
      throw 'Could not find the section 3 manifest JSON example.'
    }

    $script:ExampleJson = $manifestExample.Groups['json'].Value.Trim()

    function Invoke-ManifestSchemaValidation {
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
    $schema.'$id' | Should -Be 'https://atap.example.com/schemas/manifest/v1.json'
  }

  It 'validates the embedded manifest example from section 3' {
    $result = Invoke-ManifestSchemaValidation -Json $script:ExampleJson

    $result.IsValid | Should -BeTrue
  }

  It 'rejects a deliberately malformed manifest' {
    $manifest = $script:ExampleJson | ConvertFrom-Json
    $manifest.PSObject.Properties.Remove('sourceCommit')
    $manifest.schemaVersion = 2
    $manifest.databasePackageIncluded = $false
    $manifest.checksums.'installer/Install-Application.ps1' = 'not-a-sha256'
    $malformedJson = $manifest | ConvertTo-Json -Depth 20

    $result = Invoke-ManifestSchemaValidation -Json $malformedJson

    $result.IsValid | Should -BeFalse
  }
}
