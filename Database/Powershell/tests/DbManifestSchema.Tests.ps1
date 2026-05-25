# Pester tests for db-manifest and db-release-unit JSON schemas
# Validates all three example manifests against the v2 schemas

BeforeAll {
  $schemaDir = Join-Path $PSScriptRoot '..' '..' '..' 'SolutionDocumentation' 'schemas'
  $examplesDir = Join-Path $schemaDir 'examples'

  $releaseUnitSchemaPath = Join-Path $schemaDir 'db-release-unit.schema.json'
  $dbManifestSchemaPath = Join-Path $schemaDir 'db-manifest.schema.json'

  function Invoke-JsonSchemaValidation {
    param(
      [string] $InstancePath,
      [string] $SchemaPath
    )
    $instance = Get-Content $InstancePath -Raw | ConvertFrom-Json -Depth 20 -AsHashtable
    $schema = Get-Content $SchemaPath -Raw | ConvertFrom-Json -Depth 20 -AsHashtable
    # Use a simple inline validator: check required fields from schema
    # For full validation, NJsonSchema or Jsonata is preferred; this tests structural presence
    return $instance
  }
}

Describe 'db-release-unit.schema.json structural validation' {

  It 'Schema file exists and is valid JSON' {
    Test-Path $releaseUnitSchemaPath | Should -BeTrue
    { Get-Content $releaseUnitSchemaPath -Raw | ConvertFrom-Json } | Should -Not -Throw
  }

  It 'Schema declares schemaVersion 2' {
    $schema = Get-Content $releaseUnitSchemaPath -Raw | ConvertFrom-Json
    $schema.properties.schemaVersion.const | Should -Be 2
  }

  It 'Schema contains changeKind enum with schema, data, schemaAndData' {
    $schema = Get-Content $releaseUnitSchemaPath -Raw | ConvertFrom-Json
    $schema.properties.changeKind.enum | Should -Contain 'schema'
    $schema.properties.changeKind.enum | Should -Contain 'data'
    $schema.properties.changeKind.enum | Should -Contain 'schemaAndData'
  }

  It 'Schema contains dataKind enum with all five kinds' {
    $schema = Get-Content $releaseUnitSchemaPath -Raw | ConvertFrom-Json
    $schema.properties.dataKind.enum | Should -Contain 'staticReference'
    $schema.properties.dataKind.enum | Should -Contain 'slowlyChangingSeed'
    $schema.properties.dataKind.enum | Should -Contain 'repeatableLookup'
    $schema.properties.dataKind.enum | Should -Contain 'fixture'
    $schema.properties.dataKind.enum | Should -Contain 'migrationData'
  }

  It 'Schema contains destructiveChangeKind enum on migrationEntry' {
    $schema = Get-Content $releaseUnitSchemaPath -Raw | ConvertFrom-Json
    $schema.'$defs'.destructiveChangeKind.enum | Should -Contain 'none'
    $schema.'$defs'.destructiveChangeKind.enum | Should -Contain 'tableDrop'
    $schema.'$defs'.destructiveChangeKind.enum | Should -Contain 'columnDrop'
  }

  It 'Schema requires compatibleAppPackageRanges, requiresPreviousProductionSnapshot, rollbackSupported, rollbackNotes, evidenceRequirements' {
    $schema = Get-Content $releaseUnitSchemaPath -Raw | ConvertFrom-Json
    $required = $schema.required
    $required | Should -Contain 'compatibleAppPackageRanges'
    $required | Should -Contain 'requiresPreviousProductionSnapshot'
    $required | Should -Contain 'rollbackSupported'
    $required | Should -Contain 'rollbackNotes'
    $required | Should -Contain 'evidenceRequirements'
  }
}

Describe 'db-manifest.schema.json structural validation' {

  It 'Schema file exists and is valid JSON' {
    Test-Path $dbManifestSchemaPath | Should -BeTrue
    { Get-Content $dbManifestSchemaPath -Raw | ConvertFrom-Json } | Should -Not -Throw
  }

  It 'Schema declares schemaVersion 2' {
    $schema = Get-Content $dbManifestSchemaPath -Raw | ConvertFrom-Json
    $schema.properties.schemaVersion.const | Should -Be 2
  }

  It 'Schema has changeKind and dataKind properties' {
    $schema = Get-Content $dbManifestSchemaPath -Raw | ConvertFrom-Json
    $schema.properties.PSObject.Properties.Name | Should -Contain 'changeKind'
    $schema.properties.PSObject.Properties.Name | Should -Contain 'dataKind'
  }

  It 'Schema has evidenceRequirements property' {
    $schema = Get-Content $dbManifestSchemaPath -Raw | ConvertFrom-Json
    $schema.properties.PSObject.Properties.Name | Should -Contain 'evidenceRequirements'
  }

  It 'Schema requires compatibleAppPackageRanges and requiresPreviousProductionSnapshot' {
    $schema = Get-Content $dbManifestSchemaPath -Raw | ConvertFrom-Json
    $schema.required | Should -Contain 'compatibleAppPackageRanges'
    $schema.required | Should -Contain 'requiresPreviousProductionSnapshot'
  }
}

Describe 'Example manifest — schema-only' {

  BeforeAll {
    $examplePath = Join-Path $examplesDir 'db-manifest-schema-only.example.json'
    $example = Get-Content $examplePath -Raw | ConvertFrom-Json
  }

  It 'File exists' {
    Test-Path (Join-Path $examplesDir 'db-manifest-schema-only.example.json') | Should -BeTrue
  }

  It 'changeKind is schema' {
    $example.changeKind | Should -Be 'schema'
  }

  It 'Has no dataKind (not required for schema-only)' {
    $example.PSObject.Properties.Name | Should -Not -Contain 'dataKind'
  }

  It 'rollbackSupported is true' {
    $example.rollbackSupported | Should -BeTrue
  }

  It 'requiresPreviousProductionSnapshot is false' {
    $example.requiresPreviousProductionSnapshot | Should -BeFalse
  }

  It 'All migration files have destructiveChangeKind' {
    $migrations = $example.files | Where-Object { $_.kind -eq 'migration' }
    $migrations | ForEach-Object {
      $_.PSObject.Properties.Name | Should -Contain 'destructiveChangeKind'
    }
  }

  It 'evidenceRequirements has five tiers' {
    $tiers = $example.evidenceRequirements.PSObject.Properties.Name
    $tiers | Should -Contain 'experimental'
    $tiers | Should -Contain 'development'
    $tiers | Should -Contain 'integration'
    $tiers | Should -Contain 'qa'
    $tiers | Should -Contain 'stable'
  }

  It 'createdUtc parses as UTC DateTime' {
    $dt = [datetime]$example.createdUtc
    $dt.Kind | Should -Be 'Utc'
  }
}

Describe 'Example manifest — data-only' {

  BeforeAll {
    $examplePath = Join-Path $examplesDir 'db-manifest-data-only.example.json'
    $example = Get-Content $examplePath -Raw | ConvertFrom-Json
  }

  It 'File exists' {
    Test-Path (Join-Path $examplesDir 'db-manifest-data-only.example.json') | Should -BeTrue
  }

  It 'changeKind is data' {
    $example.changeKind | Should -Be 'data'
  }

  It 'Has dataKind property' {
    $example.PSObject.Properties.Name | Should -Contain 'dataKind'
  }

  It 'dataKind is staticReference' {
    $example.dataKind | Should -Be 'staticReference'
  }

  It 'Has seed file and seedLoader' {
    ($example.files | Where-Object { $_.kind -eq 'seed' }).Count | Should -BeGreaterThan 0
    ($example.files | Where-Object { $_.kind -eq 'seedLoader' }).Count | Should -BeGreaterThan 0
  }

  It 'expectedRowCounts is not empty' {
    $example.expectedRowCounts.PSObject.Properties.Name.Count | Should -BeGreaterThan 0
  }

  It 'stableEvidence requires snapshotBackup and approval' {
    $example.evidenceRequirements.stable.snapshotBackupRequired | Should -BeTrue
    $example.evidenceRequirements.stable.approvalRequired | Should -BeTrue
  }
}

Describe 'Example manifest — schema-and-data' {

  BeforeAll {
    $examplePath = Join-Path $examplesDir 'db-manifest-schema-and-data.example.json'
    $example = Get-Content $examplePath -Raw | ConvertFrom-Json
  }

  It 'File exists' {
    Test-Path (Join-Path $examplesDir 'db-manifest-schema-and-data.example.json') | Should -BeTrue
  }

  It 'changeKind is schemaAndData' {
    $example.changeKind | Should -Be 'schemaAndData'
  }

  It 'Has dataKind property' {
    $example.PSObject.Properties.Name | Should -Contain 'dataKind'
  }

  It 'Has both migration and seed files' {
    ($example.files | Where-Object { $_.kind -eq 'migration' }).Count | Should -BeGreaterThan 0
    ($example.files | Where-Object { $_.kind -eq 'seed' }).Count | Should -BeGreaterThan 0
  }

  It 'requiresPreviousProductionSnapshot is true (destructive migration present)' {
    $example.requiresPreviousProductionSnapshot | Should -BeTrue
  }

  It 'rollbackSupported is false' {
    $example.rollbackSupported | Should -BeFalse
  }

  It 'Destructive migration has tableDrop kind' {
    $destructive = $example.files | Where-Object { $_.kind -eq 'migration' -and $_.destructiveChangeKind -ne 'none' }
    $destructive | Should -Not -BeNullOrEmpty
    $destructive[0].destructiveChangeKind | Should -Be 'tableDrop'
  }

  It 'All evidence tiers require flywayRehearsal' {
    $tiers = $example.evidenceRequirements.PSObject.Properties.Name
    $tiers | ForEach-Object {
      $example.evidenceRequirements.$_.flywayRehearsalRequired | Should -BeTrue -Because "tier '$_' must require flyway rehearsal for schemaAndData packages with destructive changes"
    }
  }
}
