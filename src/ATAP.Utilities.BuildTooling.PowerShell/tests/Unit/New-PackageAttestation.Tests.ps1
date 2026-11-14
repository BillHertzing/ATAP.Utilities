BeforeAll {
  $script:OrchestrationName = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
  $script:Thumb = '3B5E16C0A1B2C3D4E5F60718293A4B5C6D7E8F90'
  $script:OtherThumb = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
  $script:FeedBytes = $null
  $script:FeedSourcePath = $null

  if (-not (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message, $Tag) }
  }
  if (-not (Get-Command -Name Get-SecretATAP -ErrorAction SilentlyContinue)) {
    function Get-SecretATAP { param($SecretName, $SecretStoreType, $ErrorAction) 'stub' }
  }
  . (Join-Path $PSScriptRoot '..\..\public\New-PackageAttestation.ps1')
  Add-Type -AssemblyName System.IO.Compression.FileSystem

  function New-Fixture {
    param(
      [string]$ModuleName = $script:OrchestrationName,
      [ValidateSet('Valid', 'Absent', 'Malformed', 'WrongKind')][string]$Semantic = 'Valid'
    )
    $root = Join-Path $TestDrive ('fx-' + [guid]::NewGuid().ToString('N'))
    $pkg = Join-Path $root 'pkg'
    foreach ($d in @('private', 'public', 'schemas', 'tests\Unit')) {
      $null = New-Item -ItemType Directory -Path (Join-Path $pkg $d) -Force
    }
    Set-Content -LiteralPath (Join-Path $pkg "$ModuleName.psd1") -Encoding utf8 -Value "@{ RootModule = '$ModuleName.psm1'; ModuleVersion = '0.1.16'; GUID = '01131809-7fd2-4b6d-8a34-f584b55ad4fa' }"
    Set-Content -LiteralPath (Join-Path $pkg "$ModuleName.psm1") -Encoding utf8 -Value '# fixture module'
    Set-Content -LiteralPath (Join-Path $pkg 'version.json') -Encoding utf8 -Value '{ "version": "0.1.16" }'
    $semanticFile = Join-Path $pkg 'Resources\Coordination\CoordinationSemanticRevision.json'
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $semanticFile) -Force
    switch ($Semantic) {
      'Valid' { Set-Content -LiteralPath $semanticFile -Encoding utf8 -Value (@{ kind = 'CoordinationSemanticRevision-v1'; coordinationSemanticRevision = 'SR-0117-TEST'; description = 'fixture' } | ConvertTo-Json) }
      'WrongKind' { Set-Content -LiteralPath $semanticFile -Encoding utf8 -Value (@{ kind = 'SomethingElse-v1'; coordinationSemanticRevision = 'SR-0117-TEST' } | ConvertTo-Json) }
      'Malformed' { Set-Content -LiteralPath $semanticFile -Encoding utf8 -Value '{ "kind": "CoordinationSemanticRevision-v1", ' }
      'Absent' { }
    }
    Set-Content -LiteralPath (Join-Path $pkg 'private\One.ps1') -Encoding utf8 -Value 'function One { 1 }'
    Set-Content -LiteralPath (Join-Path $pkg 'public\Two.ps1') -Encoding utf8 -Value 'function Two { 2 }'
    Set-Content -LiteralPath (Join-Path $pkg 'schemas\state-v1.schema.json') -Encoding utf8 -Value '{ "type": "object", "x": "state" }'
    Set-Content -LiteralPath (Join-Path $pkg 'schemas\request-v1.schema.json') -Encoding utf8 -Value '{ "type": "object", "x": "request" }'
    Set-Content -LiteralPath (Join-Path $pkg 'schemas\result-v1.schema.json') -Encoding utf8 -Value '{ "type": "object", "x": "result" }'
    # Test files are excluded from the inventory by rule.
    Set-Content -LiteralPath (Join-Path $pkg 'tests\Unit\Excluded.Tests.ps1') -Encoding utf8 -Value 'throw "never executed"'

    $nupkg = Join-Path $root 'pkg.nupkg'
    [IO.Compression.ZipFile]::CreateFromDirectory($pkg, $nupkg)
    $script:FeedSourcePath = $nupkg
    $script:FeedBytes = $null

    $receipts = [ordered]@{}
    $marker = Join-Path $root 'Experimental.completed.tmp'
    Set-Content -LiteralPath $marker -Encoding utf8 -Value (@{ Tier = 'Experimental'; PackageVersion = '0.1.16'; ExecutionId = 'exec-exp' } | ConvertTo-Json)
    $receipts['Experimental'] = $marker
    foreach ($tier in @('Development', 'Integration', 'QA', 'Production')) {
      $xml = Join-Path $root "test-results\$tier\PesterResults.xml"
      $null = New-Item -ItemType Directory -Path (Split-Path -Parent $xml) -Force
      Set-Content -LiteralPath $xml -Encoding utf8 -Value '<?xml version="1.0" encoding="utf-8"?><testsuites><testsuite name="suite" tests="5" failures="0" errors="0" skipped="0" /></testsuites>'
      $receipts[$tier] = $xml
    }
    # The runner's Production binding: the archive and version the Production tests ran against.
    $bindingFile = Join-Path (Split-Path -Parent $receipts['Production']) 'ProductionReceiptBinding.json'
    Set-Content -LiteralPath $bindingFile -Encoding utf8 -Value (@{
        kind = 'ProductionReceiptBinding-v1'
        archiveSha256 = (Get-FileHash -LiteralPath $nupkg -Algorithm SHA256).Hash.ToLowerInvariant()
        moduleVersion = '0.1.16'
        junitSha256 = (Get-FileHash -LiteralPath $receipts['Production'] -Algorithm SHA256).Hash.ToLowerInvariant()
      } | ConvertTo-Json)
    [pscustomobject]@{
      Root = $root
      Nupkg = $nupkg
      Receipts = $receipts
      Output = Join-Path $root 'artifact'
      Repo = Join-Path $root ('repo\_generated\build-deploy-module\' + $ModuleName + '\0.1.16\Production')
      Module = $ModuleName
    }
  }

  function Invoke-Emit {
    param(
      [Parameter(Mandatory)]$Fx,
      [string]$CeilingTier = 'Production',
      [string]$Thumbprint = $script:Thumb,
      [string[]]$ExecutionIds = @('exec-exp', 'exec-prod'),
      $Receipts = $Fx.Receipts,
      [string]$ModuleVersion = '0.1.16',
      [string]$BaseUrl = 'https://proget.example.test',
      [string]$Feed = 'powershellget-stable'
    )
    New-PackageAttestation -ModuleName $Fx.Module -PackageName $Fx.Module -ModuleVersion $ModuleVersion `
      -NupkgPath $Fx.Nupkg -CeilingTier $CeilingTier -SignerThumbprint $Thumbprint -BuildId 'build-1' `
      -ExecutionIds $ExecutionIds -TierReceiptPaths $Receipts -OutputDirectory $Fx.Output `
      -RepoEvidenceDirectory $Fx.Repo -ProGetBaseUrl $BaseUrl -FeedName $Feed `
      -ProGetApiKeySecretName 'ProGet.BuildMaster.API.Key.test' -CreatedUtc '2026-11-13T00:00:00Z'
  }
}

Describe 'New-PackageAttestation' {
  BeforeEach {
    Mock Get-AuthenticodeSignature {
      [pscustomobject]@{ Status = 'Valid'; SignerCertificate = [pscustomobject]@{ Thumbprint = '3B5E16C0A1B2C3D4E5F60718293A4B5C6D7E8F90' } }
    }
    Mock Get-SecretATAP { 'test-credential-placeholder' }
    Mock Invoke-WebRequest {
      param($Uri, $Headers, $OutFile, $UseBasicParsing, $ErrorAction)
      if ($null -ne $script:FeedBytes) { $bytes = $script:FeedBytes } else { $bytes = [IO.File]::ReadAllBytes($script:FeedSourcePath) }
      [IO.File]::WriteAllBytes($OutFile, $bytes)
    }
  }

  Context 'emits a validated attestation at the Production ceiling' {
    It 'writes the artifact and an identical repo copy, and the JSON validates against the pinned schema' {
      $fx = New-Fixture
      $r = Invoke-Emit -Fx $fx
      $r.Emitted | Should -BeTrue
      $r.ReasonCode | Should -Be 'Emitted'
      $r.PSObject.TypeNames | Should -Contain 'ATAP.PackageAttestationEmission'
      Test-Path -LiteralPath $r.AttestationPath -PathType Leaf | Should -BeTrue
      Test-Path -LiteralPath $r.RepoCopyPath -PathType Leaf | Should -BeTrue
      (Get-FileHash -LiteralPath $r.RepoCopyPath -Algorithm SHA256).Hash | Should -Be $r.AttestationSha256
      $schemaText = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\..\schemas\package-attestation-v1.schema.json') -Raw
      Test-Json -Json (Get-Content -LiteralPath $r.AttestationPath -Raw) -Schema $schemaText | Should -BeTrue
      $r.RepoCopyPath | Should -Match '_generated\\build-deploy-module\\ATAP\.Utilities\.BuildTooling\.Orchestration\.PowerShell\\0\.1\.16\\Production\\package-attestation\.json$'
    }

    It 'accepts the real Pester 6.2 Production results shape (testsuites root, one testsuite, 179 tests, no failures)' {
      # Trimmed copy of _generated\build-deploy-module\ATAP.Utilities.BuildTooling.ProGet.PowerShell\0.1.26\Production\PesterResults.xml.
      # Root attributes, suite attributes and the first two testcase rows are kept exactly; the other 177 rows are removed.
      $fx = New-Fixture
      $realShape = @'
<?xml version="1.0" encoding="utf-8"?>
<testsuites name="Pester" tests="179" failures="0" errors="0" skipped="0" time="14.292">
  <testsuite name="Pester" tests="179" failures="0" errors="0" skipped="0" time="14.292">
    <testcase name="Permits exactly the expected stages for label 'Sprint'" classname="version.json-as-ceiling stage matrix" status="Passed" time="0.264" />
    <testcase name="Permits exactly the expected stages for label 'FeatureSlug'" classname="version.json-as-ceiling stage matrix" status="Passed" time="0.026" />
  </testsuite>
</testsuites>
'@
      Set-Content -LiteralPath $fx.Receipts['Production'] -Encoding utf8 -Value $realShape
      # The runner rewrites the binding after the Production run; the JUnit digest must follow the new XML.
      Set-Content -LiteralPath (Join-Path (Split-Path -Parent $fx.Receipts['Production']) 'ProductionReceiptBinding.json') -Encoding utf8 -Value (@{
          kind = 'ProductionReceiptBinding-v1'
          archiveSha256 = (Get-FileHash -LiteralPath $fx.Nupkg -Algorithm SHA256).Hash.ToLowerInvariant()
          moduleVersion = '0.1.16'
          junitSha256 = (Get-FileHash -LiteralPath $fx.Receipts['Production'] -Algorithm SHA256).Hash.ToLowerInvariant()
        } | ConvertTo-Json)
      $r = Invoke-Emit -Fx $fx
      $r.Emitted | Should -BeTrue
      $doc = Get-Content -LiteralPath $r.AttestationPath -Raw | ConvertFrom-Json
      $doc.finalProductionTestReceiptSha256 | Should -Be (Get-FileHash -LiteralPath $fx.Receipts['Production'] -Algorithm SHA256).Hash.ToLowerInvariant()
    }

    It 'refuses the real Pester 6.2 shape when its testsuite reports a failure' {
      $fx = New-Fixture
      $failingShape = @'
<?xml version="1.0" encoding="utf-8"?>
<testsuites name="Pester" tests="179" failures="1" errors="0" skipped="0" time="14.292">
  <testsuite name="Pester" tests="179" failures="1" errors="0" skipped="0" time="14.292">
    <testcase name="Permits exactly the expected stages for label 'Sprint'" classname="version.json-as-ceiling stage matrix" status="Failed" time="0.264" />
  </testsuite>
</testsuites>
'@
      Set-Content -LiteralPath $fx.Receipts['Production'] -Encoding utf8 -Value $failingShape
      { Invoke-Emit -Fx $fx } | Should -Throw '*TierTestsFailed|Production*'
    }

    It 'binds archive, receipts, execution IDs, semantic revision and the inventory' {
      $fx = New-Fixture
      $r = Invoke-Emit -Fx $fx
      $doc = Get-Content -LiteralPath $r.AttestationPath -Raw | ConvertFrom-Json
      $doc.kind | Should -Be 'Coordination-package-attestation-v1'
      $doc.moduleVersion | Should -Be '0.1.16'
      $doc.archiveSha256 | Should -Be (Get-FileHash -LiteralPath $fx.Nupkg -Algorithm SHA256).Hash.ToLowerInvariant()
      $doc.signerThumbprint | Should -Be $script:Thumb
      $doc.coordinationSemanticRevision | Should -Be 'SR-0117-TEST'
      $doc.buildId | Should -Be 'build-1'
      @($doc.executionIds | Sort-Object) | Should -Be @('exec-exp', 'exec-prod')
      $doc.finalProductionTestReceiptSha256 | Should -Be (Get-FileHash -LiteralPath $fx.Receipts['Production'] -Algorithm SHA256).Hash.ToLowerInvariant()
      @($doc.tierReceiptSha256.PSObject.Properties.Name | Sort-Object) | Should -Be @('Development', 'Experimental', 'Integration', 'Production', 'QA')
      @($doc.files.path) | Should -Contain 'private/One.ps1'
      @($doc.files.path) | Should -Contain 'schemas/state-v1.schema.json'
      @($doc.files.path | Where-Object { $_ -like 'tests/*' }).Count | Should -Be 0
      @($doc.files.path) | Should -Contain 'Resources/Coordination/CoordinationSemanticRevision.json'
      $doc.files.Count | Should -Be 9
    }

    It 'records a productionReceiptBinding naming the archive, version and Production receipt' {
      $fx = New-Fixture
      $r = Invoke-Emit -Fx $fx
      $doc = Get-Content -LiteralPath $r.AttestationPath -Raw | ConvertFrom-Json
      $doc.productionReceiptBinding.archiveSha256 | Should -Be (Get-FileHash -LiteralPath $fx.Nupkg -Algorithm SHA256).Hash.ToLowerInvariant()
      $doc.productionReceiptBinding.moduleVersion | Should -Be '0.1.16'
      $doc.productionReceiptBinding.receiptSha256 | Should -Be $doc.finalProductionTestReceiptSha256
    }

    It 'checks the archive against the stable feed copy with the credential resolved by SecretName' {
      $fx = New-Fixture
      $null = Invoke-Emit -Fx $fx
      Should -Invoke Get-SecretATAP -Times 1 -Exactly -ParameterFilter { $SecretName -eq 'ProGet.BuildMaster.API.Key.test' }
      Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
        $Uri -like 'https://proget.example.test/nuget/powershellget-stable/package/*' -and $Headers['X-ApiKey'] -eq 'test-credential-placeholder'
      }
    }
  }

  Context 'omits the attestation for runs that are not attestation subjects' {
    It 'returns CeilingNotProduction and writes nothing when the ceiling is below Production' {
      $fx = New-Fixture
      $r = Invoke-Emit -Fx $fx -CeilingTier 'QA'
      $r.Emitted | Should -BeFalse
      $r.ReasonCode | Should -Be 'CeilingNotProduction'
      Test-Path -LiteralPath $fx.Output | Should -BeFalse
      Should -Invoke Invoke-WebRequest -Times 0 -Exactly
    }

    It 'omits a non-Orchestration module that has no coordinationSemanticRevision' {
      $fx = New-Fixture -ModuleName 'ATAP.Utilities.Other' -Semantic 'Absent'
      $r = Invoke-Emit -Fx $fx
      $r.Emitted | Should -BeFalse
      $r.ReasonCode | Should -Be 'NoSemanticRevision'
      Test-Path -LiteralPath $fx.Output | Should -BeFalse
    }
  }

  Context 'refuses an attested module by throwing PackageAttestationRefused' {
    It 'refuses the Orchestration module without coordinationSemanticRevision' {
      $fx = New-Fixture -Semantic 'Absent'
      { Invoke-Emit -Fx $fx } | Should -Throw '*PackageAttestationRefused|SemanticRevisionMissing*'
      Test-Path -LiteralPath $fx.Output | Should -BeFalse
    }

    It 'refuses a malformed CoordinationSemanticRevision file with SemanticRevisionFileMalformed' {
      $fx = New-Fixture -Semantic 'Malformed'
      { Invoke-Emit -Fx $fx } | Should -Throw '*PackageAttestationRefused|SemanticRevisionFileMalformed*'
      Test-Path -LiteralPath $fx.Output | Should -BeFalse
    }

    It 'refuses a CoordinationSemanticRevision file of the wrong kind with SemanticRevisionFileMalformed' {
      $fx = New-Fixture -Semantic 'WrongKind'
      { Invoke-Emit -Fx $fx } | Should -Throw '*PackageAttestationRefused|SemanticRevisionFileMalformed*'
    }

    It 'refuses when the promoted version differs from the packaged psd1' {
      $fx = New-Fixture
      { Invoke-Emit -Fx $fx -ModuleVersion '0.1.99' } | Should -Throw '*ModuleVersionMismatch*'
    }

    It 'refuses a packaged script signed by another thumbprint' {
      $fx = New-Fixture
      Mock Get-AuthenticodeSignature {
        [pscustomobject]@{ Status = 'Valid'; SignerCertificate = [pscustomobject]@{ Thumbprint = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF' } }
      }
      { Invoke-Emit -Fx $fx } | Should -Throw '*SignerMismatch*'
    }

    It 'refuses a packaged script whose Authenticode status is not Valid' {
      $fx = New-Fixture
      Mock Get-AuthenticodeSignature { [pscustomobject]@{ Status = 'NotSigned'; SignerCertificate = $null } }
      { Invoke-Emit -Fx $fx } | Should -Throw '*SignatureInvalid*'
    }

    It 'refuses when the Production tier has a failure' {
      $fx = New-Fixture
      Set-Content -LiteralPath $fx.Receipts['Production'] -Encoding utf8 -Value '<testsuites><testsuite tests="5" failures="1" errors="0" /></testsuites>'
      { Invoke-Emit -Fx $fx } | Should -Throw '*TierTestsFailed|Production*'
    }

    It 'refuses a test tier that ran zero tests' {
      $fx = New-Fixture
      Set-Content -LiteralPath $fx.Receipts['Integration'] -Encoding utf8 -Value '<testsuites><testsuite tests="0" failures="0" errors="0" /></testsuites>'
      { Invoke-Emit -Fx $fx } | Should -Throw '*TierTestsFailed|Integration*'
    }

    It 'refuses when a tier receipt is missing' {
      $fx = New-Fixture
      $receipts = @{}
      foreach ($k in $fx.Receipts.Keys) { if ($k -cne 'Integration') { $receipts[$k] = $fx.Receipts[$k] } }
      { Invoke-Emit -Fx $fx -Receipts $receipts } | Should -Throw '*TierReceiptMissing|Integration*'
    }

    It 'refuses when the stable-feed copy differs from the promoted archive' {
      $fx = New-Fixture
      $script:FeedBytes = [Text.Encoding]::ASCII.GetBytes('a different archive')
      { Invoke-Emit -Fx $fx } | Should -Throw '*ArchiveFeedMismatch*'
    }

    It 'refuses when the stable feed cannot be reached' {
      $fx = New-Fixture
      Mock Invoke-WebRequest { throw 'network unreachable' }
      { Invoke-Emit -Fx $fx } | Should -Throw '*ArchiveFeedUnavailable*'
    }

    It 'refuses a cleartext feed URL' {
      $fx = New-Fixture
      { Invoke-Emit -Fx $fx -BaseUrl 'http://proget.example.test' } | Should -Throw '*CleartextFeedRefused*'
      Should -Invoke Invoke-WebRequest -Times 0 -Exactly
    }

    It 'refuses an empty feed credential' {
      $fx = New-Fixture
      Mock Get-SecretATAP { '' }
      { Invoke-Emit -Fx $fx } | Should -Throw '*FeedCredentialEmpty*'
    }

    It 'refuses when the Production binding file is missing with ReceiptBindingMissing' {
      $fx = New-Fixture
      Remove-Item -LiteralPath (Join-Path (Split-Path -Parent $fx.Receipts['Production']) 'ProductionReceiptBinding.json')
      { Invoke-Emit -Fx $fx } | Should -Throw '*ReceiptBindingMissing*'
      Test-Path -LiteralPath $fx.Output | Should -BeFalse
    }

    It 'refuses a Production binding made for a different archive with ReceiptBindingMismatch' {
      $fx = New-Fixture
      Set-Content -LiteralPath (Join-Path (Split-Path -Parent $fx.Receipts['Production']) 'ProductionReceiptBinding.json') -Encoding utf8 -Value (@{
          kind = 'ProductionReceiptBinding-v1'; archiveSha256 = ('8' * 64); moduleVersion = '0.1.16' } | ConvertTo-Json)
      { Invoke-Emit -Fx $fx } | Should -Throw '*ReceiptBindingMismatch*'
    }

    It 'refuses a Production binding made for another module version with ReceiptBindingMismatch' {
      $fx = New-Fixture
      $bindingPath = Join-Path (Split-Path -Parent $fx.Receipts['Production']) 'ProductionReceiptBinding.json'
      $binding = Get-Content -LiteralPath $bindingPath -Raw | ConvertFrom-Json
      Set-Content -LiteralPath $bindingPath -Encoding utf8 -Value (@{
          kind = 'ProductionReceiptBinding-v1'; archiveSha256 = $binding.archiveSha256; moduleVersion = '0.1.15' } | ConvertTo-Json)
      { Invoke-Emit -Fx $fx } | Should -Throw '*ReceiptBindingMismatch*'
    }

    It 'refuses a Production binding of the wrong kind with ReceiptBindingMismatch' {
      $fx = New-Fixture
      $bindingPath = Join-Path (Split-Path -Parent $fx.Receipts['Production']) 'ProductionReceiptBinding.json'
      $binding = Get-Content -LiteralPath $bindingPath -Raw | ConvertFrom-Json
      Set-Content -LiteralPath $bindingPath -Encoding utf8 -Value (@{
          kind = 'Other-v1'; archiveSha256 = $binding.archiveSha256; moduleVersion = '0.1.16' } | ConvertTo-Json)
      { Invoke-Emit -Fx $fx } | Should -Throw '*ReceiptBindingMismatch*'
    }

    It 'refuses a Production binding whose JUnit digest is not the Production receipt with ReceiptBindingMismatch' {
      $fx = New-Fixture
      $bindingPath = Join-Path (Split-Path -Parent $fx.Receipts['Production']) 'ProductionReceiptBinding.json'
      $binding = Get-Content -LiteralPath $bindingPath -Raw | ConvertFrom-Json
      Set-Content -LiteralPath $bindingPath -Encoding utf8 -Value (@{
          kind = 'ProductionReceiptBinding-v1'; archiveSha256 = $binding.archiveSha256; moduleVersion = '0.1.16'; junitSha256 = ('6' * 64) } | ConvertTo-Json)
      { Invoke-Emit -Fx $fx } | Should -Throw '*ReceiptBindingMismatch*'
      Test-Path -LiteralPath $fx.Output | Should -BeFalse
    }

    It 'refuses a signer thumbprint with a trailing newline (anchored pattern)' {
      $fx = New-Fixture
      { Invoke-Emit -Fx $fx -Thumbprint "$($script:Thumb)`n" } | Should -Throw
    }

    It 'refuses when no execution ID is recorded anywhere' {
      $fx = New-Fixture
      Set-Content -LiteralPath $fx.Receipts['Experimental'] -Encoding utf8 -Value '{ "Tier": "Experimental" }'
      { Invoke-Emit -Fx $fx -ExecutionIds @() } | Should -Throw '*ExecutionIdMissing*'
    }
  }

  Context 'pinned schema copy' {
    It 'is byte-identical to the Orchestration module schema, so drift fails here' {
      $pinned = Join-Path $PSScriptRoot '..\..\schemas\package-attestation-v1.schema.json'
      $orchestration = Join-Path $PSScriptRoot '..\..\..\ATAP.Utilities.BuildTooling.Orchestration.PowerShell\schemas\package-attestation-v1.schema.json'
      (Get-FileHash -LiteralPath $pinned -Algorithm SHA256).Hash | Should -Be (Get-FileHash -LiteralPath $orchestration -Algorithm SHA256).Hash
    }

    It 'has the reviewed SHA-256 BBE42798577FA1DBF47DBC1AE5F469A8DDA67708E01F476B02717E24C7C1F717' {
      $pinned = Join-Path $PSScriptRoot '..\..\schemas\package-attestation-v1.schema.json'
      (Get-FileHash -LiteralPath $pinned -Algorithm SHA256).Hash | Should -Be 'BBE42798577FA1DBF47DBC1AE5F469A8DDA67708E01F476B02717E24C7C1F717'
    }
  }
}
