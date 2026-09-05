Describe 'ContentSummary isolated package surface' -Tag 'Package','Task15.60.c-f' {
  BeforeAll {
    $script:moduleName = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    $script:moduleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:repoRoot = (Resolve-Path (Join-Path $script:moduleRoot '..\..')).Path
    $script:buildFile = Join-Path $script:repoRoot 'module.build.ps1'
    $artifactParent = [Environment]::GetEnvironmentVariable('ATAP_CONTENTSUMMARY_PACKAGE_TEST_ROOT', 'Process')
    if ([string]::IsNullOrWhiteSpace($artifactParent)) {
      $artifactParent = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'ATAPArtifacts\ContentSummaryPackageTests'
    }
    if ($artifactParent -like '*Dropbox*') {
      throw 'Package-only test output must be outside Dropbox.'
    }
    $script:artifactRoot = Join-Path $artifactParent ("run-{0}-{1}" -f $PID, [guid]::NewGuid().ToString('N'))
    $script:buildRoot = Join-Path $script:artifactRoot 'build'
    $script:expandedRoot = Join-Path $script:artifactRoot 'expanded'
    [void](New-Item -ItemType Directory -Path $script:expandedRoot -Force)

    & Invoke-Build Short $script:buildFile `
      -ModuleRoot $script:moduleRoot `
      -OutputRoot $script:buildRoot `
      -Tier Sprint `
      -SkipSigning `
      -SkipPublish

    $script:packagePath = Get-ChildItem -LiteralPath (Join-Path $script:buildRoot 'packages') -Filter '*.nupkg' -File |
      Sort-Object LastWriteTimeUtc -Descending |
      Select-Object -First 1 -ExpandProperty FullName
    if ([string]::IsNullOrWhiteSpace($script:packagePath)) {
      throw 'The isolated build did not produce a package.'
    }
    [IO.Compression.ZipFile]::ExtractToDirectory($script:packagePath, $script:expandedRoot)
    $script:packageManifest = Get-ChildItem -LiteralPath $script:expandedRoot -Filter "$($script:moduleName).psd1" -File -Recurse |
      Select-Object -First 1 -ExpandProperty FullName
    $script:packageModule = Join-Path (Split-Path $script:packageManifest -Parent) "$($script:moduleName).psm1"
  }

  It 'embeds every source function in the flattened package' {
    $script:packagePath | Should -Exist
    $script:packageManifest | Should -Exist
    $script:packageModule | Should -Exist
    $packagedText = [IO.File]::ReadAllText($script:packageModule)
    $sourceFunctions = Get-ChildItem -LiteralPath $script:moduleRoot -Directory |
      Where-Object Name -In @('public','private') |
      ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter '*.ps1' -File } |
      Select-Object -ExpandProperty BaseName
    foreach ($functionName in $sourceFunctions) {
      $packagedText | Should -Match ("(?m)^function\s+{0}\s*\{{" -f [regex]::Escape($functionName))
    }
    $packagedText | Should -Match '(?m)^function\s+Assert-ContentSummaryCaptureAcknowledgement\s*\{'
    $packagedText | Should -Match '(?m)^function\s+ConvertTo-ContentSummaryCanonicalOriginUri\s*\{'
    $packagedText | Should -Not -Match 'Get-ChildItem[^\r\n]+[\\/]private'
  }

  It 'validates inventory and plans WhatIf from only the expanded package' {
    $originUri = (& git -C $script:repoRoot config --get remote.origin.url).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($originUri)) {
      throw 'Cannot establish the real repository origin for the package-only test.'
    }
    $inventoryPath = Join-Path $script:artifactRoot 'inventory.json'
    $inventory = [ordered]@{
      schemaVersion = 1
      inventoryId = '71000000-0000-0000-0000-000000000001'
      recordedAtUtc = '2026-09-05T12:00:00.0000000+00:00'
      repositories = @([ordered]@{
        repositoryId = '71000000-0000-0000-0000-000000000002'
        repositoryRootRegistrationId = '71000000-0000-0000-0000-000000000003'
        canonicalRepositoryName = 'ATAP.Utilities'
        originUri = $originUri
        originEvidence = [ordered]@{ kind='git-remote'; remoteName='origin'; observedUri=$originUri; observedAtUtc='2026-09-05T12:00:00.0000000+00:00' }
        canonicalRoot = $script:repoRoot
        rootKindCode = 'sprint'
        organizationId = '71000000-0000-0000-0000-000000000004'
        classificationPolicyId = '71000000-0000-0000-0000-000000000005'
        principalId = '71000000-0000-0000-0000-000000000006'
        evidenceEntityId = '71000000-0000-0000-0000-000000000007'
        recordedAtUtc = '2026-09-05T12:00:00.0000000+00:00'
        authorizations = @([ordered]@{
          authorizationId = '71000000-0000-0000-0000-000000000008'
          databasePrincipalName = 'ATAPContentSummaryMcpReader'
          instanceCode = 'exp'
          sourceReference = 'Sprint0015/Task15.60/package-only'
          recordedAtUtc = '2026-09-05T12:00:00.0000000+00:00'
        })
      })
    }
    [IO.File]::WriteAllText($inventoryPath, ($inventory | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
    $inventorySha = (Get-FileHash -LiteralPath $inventoryPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $functionListPath = Join-Path $script:artifactRoot 'private-functions.json'
    $privateFunctionNames = @(Get-ChildItem -LiteralPath (Join-Path $script:moduleRoot 'private') -Filter '*.ps1' -File | Select-Object -ExpandProperty BaseName)
    [IO.File]::WriteAllText($functionListPath, ($privateFunctionNames | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
    $runnerPath = Join-Path $PSScriptRoot 'Invoke-ContentSummaryPackageOnlyGate.ps1'
    $resultPath = Join-Path $script:artifactRoot 'package-only-result.json'
    $childOutput = @(& pwsh -File $runnerPath `
      -ManifestPath $script:packageManifest `
      -InventoryPath $inventoryPath `
      -InventorySha $inventorySha `
      -ResultPath $resultPath `
      -FunctionListPath $functionListPath 2>&1)
    if ($LASTEXITCODE -ne 0) {
      throw "Package-only child process failed: $($childOutput -join [Environment]::NewLine)"
    }
    $result = [IO.File]::ReadAllText($resultPath) | ConvertFrom-Json
    $result.Status | Should -BeExactly 'WhatIf'
    $result.InventorySha256 | Should -BeExactly $inventorySha
    $result.PrivateFunctionCount | Should -Be $privateFunctionNames.Count
    [IO.Path]::GetFullPath($result.ModuleBase).StartsWith([IO.Path]::GetFullPath($script:expandedRoot), [StringComparison]::OrdinalIgnoreCase) | Should -BeTrue
  }
}