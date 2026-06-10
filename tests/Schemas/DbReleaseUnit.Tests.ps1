Describe 'DB release unit schema' -Tag 'Unit', 'Schemas' {
  BeforeAll {
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:SchemaPath = Join-Path $script:RepoRoot 'SolutionDocumentation/schemas/db-release-unit.schema.yaml'
    $script:DocPath = Join-Path $script:RepoRoot 'SolutionDocumentation/Database-Change-Unit-and-Flyway-Promotion.md'

    $docText = Get-Content -LiteralPath $script:DocPath -Raw
    $releaseUnitExample = [regex]::Match(
      $docText,
      '(?ms)^## 2\. Repository layout.*?```yaml\s*(?<yaml>.*?)\s*```'
    )

    if (-not $releaseUnitExample.Success) {
      throw 'Could not find the section 2 DB release-unit YAML example.'
    }

    $script:ExampleYaml = $releaseUnitExample.Groups['yaml'].Value.Trim()

    function ConvertFrom-DbReleaseUnitYaml {
      param(
        [Parameter(Mandatory)]
        [string] $Yaml
      )

      $result = [ordered]@{}
      $lines = $Yaml -split "`r?`n"
      $index = 0

      while ($index -lt $lines.Count) {
        $line = $lines[$index]
        $index++

        if ($line -match '^\s*(#.*)?$') {
          continue
        }

        if ($line -notmatch '^(?<key>[A-Za-z][A-Za-z0-9]*):(?:\s*(?<value>.*))?$') {
          throw "Unsupported YAML line: $line"
        }

        $key = $Matches['key']
        $value = $Matches['value']

        if ($value -eq '|') {
          $blockLines = [System.Collections.Generic.List[string]]::new()
          while ($index -lt $lines.Count -and $lines[$index] -match '^\s{2,}') {
            $blockLines.Add(($lines[$index] -replace '^\s{2}', ''))
            $index++
          }
          $result[$key] = ($blockLines -join "`n").TrimEnd()
          continue
        }

        if (-not [string]::IsNullOrWhiteSpace($value)) {
          $result[$key] = $value.Trim()
          continue
        }

        $items = [System.Collections.Generic.List[object]]::new()
        $map = [ordered]@{}
        $sawList = $false
        $sawMap = $false

        while ($index -lt $lines.Count -and $lines[$index] -match '^\s{2,}') {
          $child = $lines[$index]
          $index++

          if ($child -match '^\s{2}-\s*(?<item>.+)$') {
            $sawList = $true
            $items.Add($Matches['item'].Trim())
            continue
          }

          if ($child -match '^\s{2}(?<childKey>[^:]+):\s*(?<childValue>.+)$') {
            $sawMap = $true
            $childKey = $Matches['childKey'].Trim()
            $childValue = $Matches['childValue'].Trim()
            if ($childValue -match '^[0-9]+$') {
              $map[$childKey] = [int]$childValue
            }
            else {
              $map[$childKey] = $childValue
            }
            continue
          }

          throw "Unsupported YAML child line: $child"
        }

        if ($sawList -and $sawMap) {
          throw "Mixed list and map values are not supported for $key."
        }

        if ($sawList) {
          $result[$key] = @($items)
        }
        else {
          $result[$key] = [pscustomobject]$map
        }
      }

      [pscustomobject]$result
    }

    function Invoke-DbReleaseUnitSchemaValidation {
      param(
        [Parameter(Mandatory)]
        [object] $InputObject
      )

      $validationErrors = $null
      $json = $InputObject | ConvertTo-Json -Depth 20
      $isValid = Test-Json `
        -Json $json `
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
    $schema.'$id' | Should -Be 'https://atap.example.com/schemas/db-release-unit/v1.json'
  }

  It 'validates the embedded DB release-unit example from section 2' {
    $releaseUnit = ConvertFrom-DbReleaseUnitYaml -Yaml $script:ExampleYaml
    $result = Invoke-DbReleaseUnitSchemaValidation -InputObject $releaseUnit

    $result.IsValid | Should -BeTrue
  }
}
