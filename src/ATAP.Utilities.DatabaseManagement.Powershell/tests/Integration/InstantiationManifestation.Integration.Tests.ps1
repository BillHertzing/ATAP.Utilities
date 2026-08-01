#Requires -Version 7.0

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  . (Join-Path $moduleRoot 'private\DatabaseSqlConnection.Helpers.ps1')
  . (Join-Path $moduleRoot 'private\DatabaseSqlCommand.Helpers.ps1')
  . (Join-Path $moduleRoot 'public\Resolve-DatabaseSqlConnection.ps1')
  . (Join-Path $moduleRoot 'public\Get-InstantiationVersionRuleGraph.ps1')
  . (Join-Path $moduleRoot 'public\Export-InstantiationManifestation.ps1')
}

Describe 'Instantiation manifestation database-to-filesystem integration' -Tag 'Integration' {
  It 'renders the complete version-one tree from an ephemeral database at the frozen 13.77.e hash' -Skip:($env:ATAP_RUN_INSTANTIATION_E2E -ne '1') {
    $secretName = [string]$env:ATAP_INSTANTIATION_E2E_SECRET_NAME
    $databaseName = [string]$env:ATAP_INSTANTIATION_E2E_DATABASE
    if ([string]::IsNullOrWhiteSpace($secretName) -or [string]::IsNullOrWhiteSpace($databaseName)) {
      Set-ItResult -Skipped -Because 'ATAP_INSTANTIATION_E2E_SECRET_NAME and ATAP_INSTANTIATION_E2E_DATABASE are required.'
      return
    }
    if ($databaseName -notmatch '(?i)(rehearsal|task1380|ephemeral)') {
      throw "Refusing integration execution against non-ephemeral database name '$databaseName'."
    }

    $baseConnectionString = [string](Get-SecretATAP -SecretName $secretName -SecretField notes -SecretStoreType BitwardenSecretsManager)
    $builder = [Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new($baseConnectionString)
    $builder['Initial Catalog'] = $databaseName
    $connection = [Microsoft.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
    $targetRoot = Join-Path ([IO.Path]::GetTempPath()) "atap-instantiation-e2e-$([guid]::NewGuid().ToString('N'))"
    try {
      $connection.Open()
      $graph = Get-InstantiationVersionRuleGraph `
        -InstantiationVersionPhiloteId ([guid]'2AF23C2B-A98B-4701-8EFE-1C060C852D61') `
        -SqlConnection $connection
      $dryRun = Export-InstantiationManifestation -InstantiationGraph $graph -TargetRoot $targetRoot -DryRun
      $result = Export-InstantiationManifestation -InstantiationGraph $graph -TargetRoot $targetRoot -PersistProvenance -SqlConnection $connection
      $repeat = Export-InstantiationManifestation -InstantiationGraph $graph -TargetRoot $targetRoot -PersistProvenance -SqlConnection $connection

      $expectedPaths = @(
        'ATAP.Utilities'
        'ATAP.Utilities\src'
        'ATAP.Utilities\src\ATAP.Utilities.PowerShell'
        'ATAP.Utilities\src\ATAP.Utilities.PowerShell\public'
        'ATAP.Utilities\src\ATAP.Utilities.PowerShell\public\Write-ArrayIndented.ps1'
      )
      $dryRun.Artifacts.RelativePath | Should -Be $expectedPaths
      $actualPaths = @(
        Get-ChildItem -LiteralPath $targetRoot -Recurse -Force |
          ForEach-Object { [IO.Path]::GetRelativePath($targetRoot, $_.FullName) } |
          Sort-Object { [array]::IndexOf($expectedPaths, $_) }
      )
      $actualPaths | Should -Be $expectedPaths

      $filePath = Join-Path $targetRoot 'ATAP.Utilities\src\ATAP.Utilities.PowerShell\public\Write-ArrayIndented.ps1'
      (Get-Item -LiteralPath $filePath).Length | Should -Be 2800
      (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash |
        Should -Be '207425988293F2ACA9BAC4A9B72E7F18CA971EB3CF5AFE78FEB46130C219F63A'
      $result.Artifacts[-1].Action | Should -Be 'Written'
      $repeat.Artifacts[-1].Action | Should -Be 'Unchanged'

      $provenance = @(Invoke-DatabaseSqlQuery -SqlConnection $connection -CommandText @'
SELECT RenderPolicy, ContentSha256, ProducingRuleInstantiationVersionPhiloteId
FROM ATAPUtilities.ManifestationArtifact
WHERE InstantiationVersionPhiloteId = '2AF23C2B-A98B-4701-8EFE-1C060C852D61'
  AND RelativePath = N'ATAP.Utilities\src\ATAP.Utilities.PowerShell\public\Write-ArrayIndented.ps1'
  AND EffectiveTo IS NULL;
'@)
      $provenance | Should -HaveCount 1
      $provenance[0].RenderPolicy | Should -Be 'RenderFromModel'
      $provenance[0].ContentSha256 | Should -Be '207425988293F2ACA9BAC4A9B72E7F18CA971EB3CF5AFE78FEB46130C219F63A'
    } finally {
      if ($connection.State -ne [System.Data.ConnectionState]::Closed) { $connection.Close() }
      $connection.Dispose()
      Remove-Item -LiteralPath $targetRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}
