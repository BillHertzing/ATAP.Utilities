Describe 'Database package ceiling schema' -Tag 'Unit', 'Schemas' {
  BeforeAll {
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:SchemaPath = Join-Path $script:RepoRoot 'SolutionDocumentation/schemas/database-package-ceiling.schema.json'
    $script:ExamplesPath = Join-Path $script:RepoRoot 'SolutionDocumentation/schemas/examples'
    $script:ExampleFiles = @(
      'database-package-ceiling-sprint.example.json',
      'database-package-ceiling-feature.example.json',
      'database-package-ceiling-integration.example.json',
      'database-package-ceiling-qa.example.json',
      'database-package-ceiling-release.example.json',
      'database-package-ceiling-hotfix.example.json'
    ) | ForEach-Object { Join-Path $script:ExamplesPath $_ }

    function Invoke-DatabasePackageCeilingSchemaValidation {
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
        Errors  = @($validationErrors)
      }
    }
  }

  It 'declares the v1 Draft 2020-12 schema identity' {
    $schema = Get-Content -LiteralPath $script:SchemaPath -Raw | ConvertFrom-Json

    $schema.'$schema' | Should -Be 'https://json-schema.org/draft/2020-12/schema'
    $schema.'$id' | Should -Be 'https://atap.example.com/schemas/database-package-ceiling/v1.json'
  }

  It 'validates every branch/lane example' {
    foreach ($exampleFile in $script:ExampleFiles) {
      $json = Get-Content -LiteralPath $exampleFile -Raw
      $result = Invoke-DatabasePackageCeilingSchemaValidation -Json $json

      $result.IsValid | Should -BeTrue -Because "example should validate: $exampleFile"
    }
  }

  It 'covers the required sprint, feature, integration, QA, release, and hotfix branch kinds' {
    $branchKinds = $script:ExampleFiles |
      ForEach-Object { Get-Content -LiteralPath $_ -Raw | ConvertFrom-Json } |
      Select-Object -ExpandProperty branchKind

    $branchKinds | Sort-Object | Should -Be @('feature', 'hotfix', 'integration', 'qa', 'release', 'sprint')
  }

  It 'rejects a maxConsumableTier and maxConsumableFeed mismatch' {
    $example = Get-Content -LiteralPath $script:ExampleFiles[0] -Raw | ConvertFrom-Json
    $example.maxConsumableTier = 'QA'
    $example.maxConsumableFeed = 'database-experimental'
    $json = $example | ConvertTo-Json -Depth 10

    $result = Invoke-DatabasePackageCeilingSchemaValidation -Json $json

    $result.IsValid | Should -BeFalse
  }

  It 'rejects a file missing maxConsumableTier' {
    $example = Get-Content -LiteralPath $script:ExampleFiles[0] -Raw | ConvertFrom-Json
    $example.PSObject.Properties.Remove('maxConsumableTier')
    $json = $example | ConvertTo-Json -Depth 10

    $result = Invoke-DatabasePackageCeilingSchemaValidation -Json $json

    $result.IsValid | Should -BeFalse
  }
}
