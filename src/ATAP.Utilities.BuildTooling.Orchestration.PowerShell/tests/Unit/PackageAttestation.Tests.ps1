BeforeAll {
  $script:SourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  $script:ModuleName = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
  $script:Thumb = '3B5E16C0A1B2C3D4E5F60718293A4B5C6D7E8F90'
  $script:OtherThumb = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
  # Fixed schema texts. Their SHA-256 values are computed after the helpers load, so the policy and the
  # attestation carry the real hashes of the installed schema files.
  $script:SchemaText = @{
    state = '{ "type": "object", "x": "state" }'
    request = '{ "type": "object", "x": "request" }'
    result = '{ "type": "object", "x": "result" }'
  }
  $script:RevisionRelative = 'Resources/Coordination/CoordinationSemanticRevision.json'
  $script:ExpectedFiles = @(
    "$($script:ModuleName).psd1"
    "$($script:ModuleName).psm1"
    'version.json'
    'private/One.ps1'
    'public/Two.ps1'
    'schemas/state-v1.schema.json'
    'schemas/request-v1.schema.json'
    'schemas/result-v1.schema.json'
    $script:RevisionRelative
  )

  # Helpers used by the function under test. Same hash and descendant rules as CoordProducer.ps1.
  . (Join-Path $script:SourceRoot 'private/CoordProducerJson.ps1')
  . (Join-Path $script:SourceRoot 'private/CoordProducer.ps1')
  . (Join-Path $script:SourceRoot 'private/Test-CoordPackageAttestation.ps1')
  Import-Module PSFramework -MinimumVersion 1.14.457 -ErrorAction Stop
  $script:Hex64 = @{}
  foreach ($k in @('state', 'request', 'result')) {
    $script:Hex64[$k] = (Get-CoordHash ([Text.UTF8Encoding]::new($false).GetBytes($script:SchemaText[$k]))).ToLowerInvariant()
  }

  function New-PackageFixture {
    param([Parameter(Mandatory)][string]$Root)
    foreach ($d in @('private', 'public', 'schemas', 'tests/Unit')) {
      $null = New-Item -ItemType Directory -Path (Join-Path $Root $d) -Force
    }
    Set-Content -LiteralPath (Join-Path $Root "$($script:ModuleName).psd1") -Value "@{ RootModule = '$($script:ModuleName).psm1'; ModuleVersion = '0.1.16'; GUID = '01131809-7fd2-4b6d-8a34-f584b55ad4fa' }" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $Root "$($script:ModuleName).psm1") -Value '# fixture module root' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $Root 'version.json') -Value '{ "version": "0.1.16" }' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $Root 'private/One.ps1') -Value 'function One { 1 }' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $Root 'public/Two.ps1') -Value 'function Two { 2 }' -Encoding utf8
    foreach ($name in @('state', 'request', 'result')) {
      [IO.File]::WriteAllText((Join-Path $Root "schemas/$name-v1.schema.json"), $script:SchemaText[$name], [Text.UTF8Encoding]::new($false))
    }
    $null = New-Item -ItemType Directory -Path (Join-Path $Root 'Resources/Coordination') -Force
    Set-Content -LiteralPath (Join-Path $Root $script:RevisionRelative) -Encoding utf8 -Value (@{ kind = 'CoordinationSemanticRevision-v1'; coordinationSemanticRevision = 'SR-0117-TEST' } | ConvertTo-Json)
    # Test files are outside the inventory by rule; a README is not an inventory extension.
    Set-Content -LiteralPath (Join-Path $Root 'tests/Unit/Ignored.Tests.ps1') -Value 'throw "never executed"' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $Root 'README.md') -Value 'not inventoried' -Encoding utf8
  }

  function New-Case {
    $id = [guid]::NewGuid().ToString('N')
    $root = Join-Path $TestDrive "mod-$id"
    $nupkg = Join-Path $TestDrive "pkg-$id.nupkg"
    New-PackageFixture -Root $root
    [IO.File]::WriteAllBytes($nupkg, [Text.Encoding]::ASCII.GetBytes("nupkg-$id"))
    $case = [pscustomobject]@{ Root = $root; Nupkg = $nupkg; Att = (Join-Path $TestDrive "att-$id.json") }
    Write-Attestation -Case $case
    $case
  }

  function Write-Attestation {
    param([Parameter(Mandatory)]$Case, [hashtable]$Override = @{})
    $files = foreach ($rel in $script:ExpectedFiles) {
      $bytes = [IO.File]::ReadAllBytes((Join-Path $Case.Root $rel))
      [ordered]@{ path = $rel; sha256 = (Get-CoordHash $bytes); size = $bytes.Length }
    }
    $att = [ordered]@{
      kind = 'Coordination-package-attestation-v1'
      moduleName = $script:ModuleName
      moduleVersion = '0.1.16'
      archiveSha256 = (Get-FileHash -LiteralPath $Case.Nupkg -Algorithm SHA256).Hash.ToLowerInvariant()
      files = @($files)
      signerThumbprint = $script:Thumb
      stateSchemaSha256 = $script:Hex64.state
      requestSchemaSha256 = $script:Hex64.request
      resultSchemaSha256 = $script:Hex64.result
      coordinationSemanticRevision = 'SR-0117-TEST'
      buildId = 'build-test-1'
      executionIds = @('exec-test-1')
      finalProductionTestReceiptSha256 = ('4' * 64)
      tierReceiptSha256 = [ordered]@{ Production = ('5' * 64) }
      productionReceiptBinding = [ordered]@{
        archiveSha256 = (Get-FileHash -LiteralPath $Case.Nupkg -Algorithm SHA256).Hash.ToLowerInvariant()
        moduleVersion = '0.1.16'
        receiptSha256 = ('4' * 64)
      }
      createdUtc = '2026-11-13T00:00:00Z'
    }
    foreach ($k in $Override.Keys) {
      if ($k -ceq '__remove') { foreach ($r in @($Override[$k])) { $null = $att.Remove($r) } } else { $att[$k] = $Override[$k] }
    }
    $att | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Case.Att -Encoding utf8
  }

  function New-Policy {
    @{
      signer = $script:Thumb
      minVersion = '0.1.10'
      semanticRevision = 'SR-0117-TEST'
      schemaHashes = @{ state = $script:Hex64.state; request = $script:Hex64.request; result = $script:Hex64.result }
    }
  }

  function Invoke-Verify {
    # Default is an upgrade from 0.1.15 to the fixture's 0.1.16. Pass -FirstAdmission for a first package.
    param([Parameter(Mandatory)]$Case, $Policy = (New-Policy), [string]$CurrentVersion = '0.1.15', [switch]$FirstAdmission)
    $splat = @{ ModuleRoot = $Case.Root; AttestationPath = $Case.Att; Policy = $Policy; NupkgPath = $Case.Nupkg }
    if ($FirstAdmission) { $splat.FirstAdmission = $true } else { $splat.CurrentVersion = $CurrentVersion }
    Test-CoordPackageAttestation @splat
  }
}

Describe 'Test-CoordPackageAttestation' -Tag 'Unit' {
  BeforeEach {
    # Mock every signature. The certificate stores are never touched.
    Mock Get-AuthenticodeSignature {
      [pscustomobject]@{ Status = 'Valid'; SignerCertificate = [pscustomobject]@{ Thumbprint = '3B5E16C0A1B2C3D4E5F60718293A4B5C6D7E8F90' } }
    }
  }

  Context 'valid package' {
    It 'returns Valid for an exact match and reports the installed version' {
      $case = New-Case
      $r = Invoke-Verify -Case $case
      $r.ReasonCode | Should -Be 'Valid'
      $r.Valid | Should -BeTrue
      $r.InstalledModuleVersion | Should -Be '0.1.16'
      $r.PSObject.TypeNames | Should -Contain 'ATAP.CoordPackageAttestationResult'
    }

    It 'ignores files under tests/ and non-inventory extensions' {
      $case = New-Case
      Set-Content -LiteralPath (Join-Path $case.Root 'tests/Unit/Ignored.Tests.ps1') -Value 'changed' -Encoding utf8
      Set-Content -LiteralPath (Join-Path $case.Root 'README.md') -Value 'changed' -Encoding utf8
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'Valid'
    }
  }

  Context 'installed inventory tamper' {
    It 'rejects an altered file with InventoryHashMismatch' {
      $case = New-Case
      Set-Content -LiteralPath (Join-Path $case.Root 'private/One.ps1') -Value 'function One { 999 }' -Encoding utf8
      $r = Invoke-Verify -Case $case
      $r.ReasonCode | Should -Be 'InventoryHashMismatch'
      $r.Valid | Should -BeFalse
      $r.Detail | Should -Match 'private/One.ps1'
    }

    It 'rejects an extra inventory file with InventoryExtraFile' {
      $case = New-Case
      Set-Content -LiteralPath (Join-Path $case.Root 'private/Extra.ps1') -Value 'function Extra { }' -Encoding utf8
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'InventoryExtraFile'
    }

    It 'rejects a missing inventory file with InventoryMissingFile' {
      $case = New-Case
      Remove-Item -LiteralPath (Join-Path $case.Root 'public/Two.ps1')
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'InventoryMissingFile'
    }

    It 'rejects a size-only change with InventorySizeMismatch' {
      $case = New-Case
      $att = Get-Content -LiteralPath $case.Att -Raw | ConvertFrom-Json -Depth 100
      $entry = @($att.files | Where-Object { $_.path -ceq 'version.json' })[0]
      $entry.size = [int64]$entry.size + 1
      $att | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $case.Att -Encoding utf8
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'InventorySizeMismatch'
    }

    It 'rejects a duplicate attested path with InventoryPathInvalid' {
      $case = New-Case
      $att = Get-Content -LiteralPath $case.Att -Raw | ConvertFrom-Json -Depth 100
      $att.files = @($att.files) + @($att.files[0])
      $att | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $case.Att -Encoding utf8
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'InventoryPathInvalid'
    }
  }

  Context 'Authenticode and signer' {
    It 'rejects a script whose signer differs from the policy with SignerMismatch' {
      $case = New-Case
      Mock Get-AuthenticodeSignature -ParameterFilter { $LiteralPath -like '*One.ps1' } {
        [pscustomobject]@{ Status = 'Valid'; SignerCertificate = [pscustomobject]@{ Thumbprint = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF' } }
      }
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'SignerMismatch'
    }

    It 'rejects a script whose Authenticode status is not Valid with SignatureInvalid' {
      $case = New-Case
      Mock Get-AuthenticodeSignature -ParameterFilter { $LiteralPath -like '*.psm1' } {
        [pscustomobject]@{ Status = 'HashMismatch'; SignerCertificate = $null }
      }
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'SignatureInvalid'
    }

    It 'rejects an unsigned script with SignatureInvalid' {
      $case = New-Case
      Mock Get-AuthenticodeSignature -ParameterFilter { $LiteralPath -like '*Two.ps1' } {
        [pscustomobject]@{ Status = 'NotSigned'; SignerCertificate = $null }
      }
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'SignatureInvalid'
    }

    It 'rejects an attestation that declares a different signer with SignerMismatch' {
      $case = New-Case
      Write-Attestation -Case $case -Override @{ signerThumbprint = $script:OtherThumb }
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'SignerMismatch'
    }

    It 'does not call Get-AuthenticodeSignature on JSON files' {
      $case = New-Case
      $null = Invoke-Verify -Case $case
      Should -Invoke Get-AuthenticodeSignature -Times 4 -Exactly
    }
  }

  Context 'downgrade and version' {
    It 'rejects a downgrade below the current package with Downgrade' {
      $case = New-Case
      (Invoke-Verify -Case $case -CurrentVersion '0.1.17').ReasonCode | Should -Be 'Downgrade'
    }

    It 'refuses an equal current version (no re-admission of the same version)' {
      $case = New-Case
      (Invoke-Verify -Case $case -CurrentVersion '0.1.16').ReasonCode | Should -Be 'SameVersionRefused'
    }

    It 'rejects an unparseable current version with CurrentVersionInvalid' {
      $case = New-Case
      (Invoke-Verify -Case $case -CurrentVersion 'not-a-version').ReasonCode | Should -Be 'CurrentVersionInvalid'
    }
  }

  Context 'admission rules: CurrentVersion mandatory, FirstAdmission explicit' {
    It 'declares CurrentVersion mandatory in the Upgrade set and FirstAdmission only in its own set' {
      $cmd = Get-Command Test-CoordPackageAttestation
      @($cmd.ParameterSets.Where({ $_.IsDefault }).Name) | Should -Be @('Upgrade')
      $cmd.Parameters['CurrentVersion'].ParameterSets['Upgrade'].IsMandatory | Should -BeTrue
      $cmd.Parameters['CurrentVersion'].ParameterSets.ContainsKey('FirstAdmission') | Should -BeFalse
      $cmd.Parameters['FirstAdmission'].ParameterSets.ContainsKey('FirstAdmission') | Should -BeTrue
      $cmd.Parameters['FirstAdmission'].ParameterSets.ContainsKey('Upgrade') | Should -BeFalse
    }

    It 'refuses to run without CurrentVersion or -FirstAdmission in a non-interactive child process' {
      $case = New-Case
      $fn = Join-Path $script:SourceRoot 'private/Test-CoordPackageAttestation.ps1'
      $json = Join-Path $script:SourceRoot 'private/CoordProducerJson.ps1'
      $prod = Join-Path $script:SourceRoot 'private/CoordProducer.ps1'
      $policy = "@{ signer='$($script:Thumb)'; minVersion='0.1.10'; semanticRevision='SR-0117-TEST'; schemaHashes=@{ state='$($script:Hex64.state)'; request='$($script:Hex64.request)'; result='$($script:Hex64.result)' } }"
      $command = ". '$json'; . '$prod'; . '$fn'; Test-CoordPackageAttestation -ModuleRoot '$($case.Root)' -AttestationPath '$($case.Att)' -Policy $policy -NupkgPath '$($case.Nupkg)'"
      $output = & pwsh -NonInteractive -Command $command 2>&1
      $LASTEXITCODE | Should -Not -Be 0
      ($output -join "`n") | Should -Match 'CurrentVersion'
    }

    It 'refuses both CurrentVersion and -FirstAdmission together' {
      $case = New-Case
      { Test-CoordPackageAttestation -ModuleRoot $case.Root -AttestationPath $case.Att -Policy (New-Policy) -NupkgPath $case.Nupkg -CurrentVersion '0.1.15' -FirstAdmission } | Should -Throw
    }

    It 'FirstAdmission accepts a valid first package without any current version' {
      $case = New-Case
      (Invoke-Verify -Case $case -FirstAdmission).ReasonCode | Should -Be 'Valid'
    }

    It 'FirstAdmission still enforces the policy minimum version' {
      $case = New-Case
      $policy = New-Policy
      $policy.minVersion = '0.1.17'
      (Invoke-Verify -Case $case -Policy $policy -FirstAdmission).ReasonCode | Should -Be 'VersionBelowMinimum'
    }

    It 'FirstAdmission still rejects an inventory tamper' {
      $case = New-Case
      Set-Content -LiteralPath (Join-Path $case.Root 'private/One.ps1') -Value 'function One { 999 }' -Encoding utf8
      (Invoke-Verify -Case $case -FirstAdmission).ReasonCode | Should -Be 'InventoryHashMismatch'
    }

    It 'FirstAdmission still rejects a schema hash mismatch' {
      $case = New-Case
      Write-Attestation -Case $case -Override @{ requestSchemaSha256 = ('9' * 64) }
      (Invoke-Verify -Case $case -FirstAdmission).ReasonCode | Should -Be 'RequestSchemaHashMismatch'
    }

    It 'FirstAdmission still rejects a wrong signer' {
      $case = New-Case
      Mock Get-AuthenticodeSignature -ParameterFilter { $LiteralPath -like '*One.ps1' } {
        [pscustomobject]@{ Status = 'Valid'; SignerCertificate = [pscustomobject]@{ Thumbprint = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF' } }
      }
      (Invoke-Verify -Case $case -FirstAdmission).ReasonCode | Should -Be 'SignerMismatch'
    }

    It 'rejects a version below the policy minimum with VersionBelowMinimum' {
      $case = New-Case
      $policy = New-Policy
      $policy.minVersion = '0.1.17'
      (Invoke-Verify -Case $case -Policy $policy).ReasonCode | Should -Be 'VersionBelowMinimum'
    }

    It 'rejects an attested version that differs from the installed manifest with ModuleVersionMismatch' {
      $case = New-Case
      Write-Attestation -Case $case -Override @{ moduleVersion = '0.1.15' }
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'ModuleVersionMismatch'
    }
  }

  Context 'schema hashes and semantic revision' {
    It 'rejects <Reason> when <Field> differs from the policy' -ForEach @(
      @{ Field = 'stateSchemaSha256'; Reason = 'StateSchemaHashMismatch' }
      @{ Field = 'requestSchemaSha256'; Reason = 'RequestSchemaHashMismatch' }
      @{ Field = 'resultSchemaSha256'; Reason = 'ResultSchemaHashMismatch' }
    ) {
      $case = New-Case
      Write-Attestation -Case $case -Override @{ $Field = ('9' * 64) }
      (Invoke-Verify -Case $case).ReasonCode | Should -Be $Reason
    }

    It 'rejects a semantic revision that differs from the policy with SemanticRevisionMismatch' {
      $case = New-Case
      $policy = New-Policy
      $policy.semanticRevision = 'SR-OTHER'
      (Invoke-Verify -Case $case -Policy $policy).ReasonCode | Should -Be 'SemanticRevisionMismatch'
    }
  }

  Context 'archive binding' {
    It 'rejects an archive whose bytes changed with ArchiveSha256Mismatch' {
      $case = New-Case
      [IO.File]::WriteAllBytes($case.Nupkg, [Text.Encoding]::ASCII.GetBytes('tampered-archive'))
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'ArchiveSha256Mismatch'
    }

    It 'rejects a missing archive with ArchiveMissing' {
      $case = New-Case
      Remove-Item -LiteralPath $case.Nupkg
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'ArchiveMissing'
    }
  }

  Context 'attestation document' {
    It 'rejects a file that is not JSON with AttestationUnreadable' {
      $case = New-Case
      Set-Content -LiteralPath $case.Att -Value 'not json {' -Encoding utf8
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'AttestationUnreadable'
    }

    It 'rejects a missing attestation file with AttestationUnreadable' {
      $case = New-Case
      Remove-Item -LiteralPath $case.Att
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'AttestationUnreadable'
    }

    It 'rejects a required field that is missing with AttestationSchemaInvalid' {
      $case = New-Case
      Write-Attestation -Case $case -Override @{ __remove = @('buildId') }
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'AttestationSchemaInvalid'
    }

    It 'rejects a traversal path in files[] with AttestationSchemaInvalid' {
      $case = New-Case
      $att = Get-Content -LiteralPath $case.Att -Raw | ConvertFrom-Json -Depth 100
      $att.files[0].path = '../escape.ps1'
      $att | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $case.Att -Encoding utf8
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'AttestationSchemaInvalid'
    }

    It 'rejects an unknown extra field with AttestationSchemaInvalid' {
      $case = New-Case
      Write-Attestation -Case $case -Override @{ unexpectedField = 'x' }
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'AttestationSchemaInvalid'
    }
  }

  Context 'policy and failure containment' {
    It 'rejects a malformed signer in the policy with PolicyInvalid' {
      $case = New-Case
      $policy = New-Policy
      $policy.signer = 'NOT-A-THUMBPRINT'
      (Invoke-Verify -Case $case -Policy $policy).ReasonCode | Should -Be 'PolicyInvalid'
    }

    It 'fails closed with ModuleManifestUnreadable when the manifest cannot be parsed' {
      $case = New-Case
      Set-Content -LiteralPath (Join-Path $case.Root "$($script:ModuleName).psd1") -Value 'throw "boom"' -Encoding utf8
      $r = Invoke-Verify -Case $case
      $r.ReasonCode | Should -Be 'ModuleManifestUnreadable'
      $r.Valid | Should -BeFalse
    }

    It 'fails closed with UnexpectedError when an unexpected exception escapes a check' {
      $case = New-Case
      Mock Get-FileHash { throw 'simulated IO failure' }
      $r = Invoke-Verify -Case $case
      $r.ReasonCode | Should -Be 'UnexpectedError'
      $r.Valid | Should -BeFalse
    }

    It 'rejects a missing manifest with ModuleManifestMissing' {
      $case = New-Case
      Remove-Item -LiteralPath (Join-Path $case.Root "$($script:ModuleName).psd1")
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'ModuleManifestMissing'
    }
  }

  Context 'installed schema and semantic revision are derived, not trusted' {
    It 'rejects a request schema that attestation and policy agree on when the installed file differs' {
      $case = New-Case
      $bad = '9' * 64
      Write-Attestation -Case $case -Override @{ requestSchemaSha256 = $bad }
      $policy = New-Policy
      $policy.schemaHashes.request = $bad
      $r = Invoke-Verify -Case $case -Policy $policy
      $r.ReasonCode | Should -Be 'RequestSchemaHashMismatch'
      $r.Detail | Should -Match 'installed request schema differs from attestation'
    }

    It 'rejects a state schema that the policy disagrees with even when the attestation matches the installed file' {
      $case = New-Case
      $policy = New-Policy
      $policy.schemaHashes.state = ('9' * 64)
      (Invoke-Verify -Case $case -Policy $policy).ReasonCode | Should -Be 'StateSchemaHashMismatch'
    }

    It 'rejects a missing installed schema file with SchemaFileMissing' {
      $case = New-Case
      Remove-Item -LiteralPath (Join-Path $case.Root 'schemas/result-v1.schema.json')
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'SchemaFileMissing'
    }

    It 'rejects a semantic revision that attestation and policy agree on when the installed file differs' {
      $case = New-Case
      Write-Attestation -Case $case -Override @{ coordinationSemanticRevision = 'SR-OTHER' }
      $policy = New-Policy
      $policy.semanticRevision = 'SR-OTHER'
      $r = Invoke-Verify -Case $case -Policy $policy
      $r.ReasonCode | Should -Be 'SemanticRevisionMismatch'
      $r.Detail | Should -Match 'installed differs from attestation'
    }

    It 'rejects a missing installed semantic revision file with SemanticRevisionFileMissing' {
      $case = New-Case
      Remove-Item -LiteralPath (Join-Path $case.Root $script:RevisionRelative)
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'SemanticRevisionFileMissing'
    }

    It 'rejects a malformed installed semantic revision file with SemanticRevisionFileMalformed' {
      $case = New-Case
      Set-Content -LiteralPath (Join-Path $case.Root $script:RevisionRelative) -Value '{ "kind": ' -Encoding utf8
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'SemanticRevisionFileMalformed'
    }

    It 'rejects an installed semantic revision file of the wrong kind with SemanticRevisionFileMalformed' {
      $case = New-Case
      Set-Content -LiteralPath (Join-Path $case.Root $script:RevisionRelative) -Value (@{ kind = 'Other-v1'; coordinationSemanticRevision = 'SR-0117-TEST' } | ConvertTo-Json) -Encoding utf8
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'SemanticRevisionFileMalformed'
    }

    It 'rejects an attestation that does not carry the installed semantic revision file with RequiredFileNotAttested' {
      $case = New-Case
      $att = Get-Content -LiteralPath $case.Att -Raw | ConvertFrom-Json -Depth 100
      $att.files = @($att.files | Where-Object { $_.path -cne $script:RevisionRelative })
      $att | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $case.Att -Encoding utf8
      $r = Invoke-Verify -Case $case
      $r.ReasonCode | Should -Be 'RequiredFileNotAttested'
      $r.Detail | Should -Match 'CoordinationSemanticRevision.json'
    }
  }

  Context 'Production receipt binding' {
    It 'rejects a binding made for a different archive with ReceiptBindingMismatch' {
      $case = New-Case
      Write-Attestation -Case $case -Override @{ productionReceiptBinding = [ordered]@{ archiveSha256 = ('8' * 64); moduleVersion = '0.1.16'; receiptSha256 = ('4' * 64) } }
      $r = Invoke-Verify -Case $case
      $r.ReasonCode | Should -Be 'ReceiptBindingMismatch'
      $r.Detail | Should -Match 'archive'
    }

    It 'rejects a binding made for another module version with ReceiptBindingMismatch' {
      $case = New-Case
      Write-Attestation -Case $case -Override @{ productionReceiptBinding = [ordered]@{ archiveSha256 = (Get-FileHash -LiteralPath $case.Nupkg -Algorithm SHA256).Hash.ToLowerInvariant(); moduleVersion = '0.1.15'; receiptSha256 = ('4' * 64) } }
      $r = Invoke-Verify -Case $case
      $r.ReasonCode | Should -Be 'ReceiptBindingMismatch'
      $r.Detail | Should -Match 'module version'
    }

    It 'rejects a binding whose receipt digest differs from finalProductionTestReceiptSha256 with ReceiptBindingMismatch' {
      $case = New-Case
      Write-Attestation -Case $case -Override @{ productionReceiptBinding = [ordered]@{ archiveSha256 = (Get-FileHash -LiteralPath $case.Nupkg -Algorithm SHA256).Hash.ToLowerInvariant(); moduleVersion = '0.1.16'; receiptSha256 = ('7' * 64) } }
      $r = Invoke-Verify -Case $case
      $r.ReasonCode | Should -Be 'ReceiptBindingMismatch'
      $r.Detail | Should -Match 'receipt digest'
    }

    It 'rejects an attestation without productionReceiptBinding with AttestationSchemaInvalid' {
      $case = New-Case
      Write-Attestation -Case $case -Override @{ __remove = @('productionReceiptBinding') }
      (Invoke-Verify -Case $case).ReasonCode | Should -Be 'AttestationSchemaInvalid'
    }
  }

  Context 'anchored policy regexes' {
    It 'rejects a policy signer with a trailing newline with PolicyInvalid' {
      $case = New-Case
      $policy = New-Policy
      $policy.signer = "$($script:Thumb)`n"
      (Invoke-Verify -Case $case -Policy $policy).ReasonCode | Should -Be 'PolicyInvalid'
    }

    It 'rejects a policy schema hash with a trailing newline with PolicyInvalid' {
      $case = New-Case
      $policy = New-Policy
      $policy.schemaHashes.state = "$($script:Hex64.state)`n"
      (Invoke-Verify -Case $case -Policy $policy).ReasonCode | Should -Be 'PolicyInvalid'
    }
  }
}
