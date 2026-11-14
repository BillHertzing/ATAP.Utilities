function New-PackageAttestation {
  <#
  .SYNOPSIS
    Emits a Coordination-package-attestation-v1 for a PowerShell module promoted to the Production ceiling.
  .DESCRIPTION
    Called by the BuildMaster PowerShell-module runner after the Production tier's tests passed and before the
    Production completion marker is written, so a refused attestation leaves the stage retryable.

    Fail closed for an attested module. The emitter:
      1. Extracts the nupkg into a fresh work folder and reads the packaged module.
      2. Requires the packaged ModuleVersion to equal the promoted version.
      3. Reads coordinationSemanticRevision from the packaged Resources\Coordination\CoordinationSemanticRevision.json
         (kind CoordinationSemanticRevision-v1). If the file is absent, the module is not an attestation subject, except
         the Orchestration module, which fails with SemanticRevisionMissing. If the file is malformed, it refuses.
      4. Requires every packaged script (.ps1, .psm1, .psd1) to be Authenticode Valid, signed by the given thumbprint.
      5. Hashes the packaged state, request and result schemas.
      6. Binds the archive SHA256 to the stable-feed copy (design guard C4.2). Feed-copy scope: the design names
         "every feed copy" but names no feed other than the stable feed, and the stable feed is the only copy this
         emitter fetches. Other feed copies are not compared (residual; documented in the handoff, not verified here).
      7. Checks every tier receipt: Experimental uses its marker file hash; each test tier must have tests, no
         failures and no errors.
      7b. Requires ProductionReceiptBinding.json beside the Production receipt (kind ProductionReceiptBinding-v1). It
         must name the archive SHA256 and module version the Production tests ran against, which must equal this
         archive and ModuleVersion, and junitSha256 must equal the SHA256 of this Production JUnit receipt. The
         binding is recorded in productionReceiptBinding. The runner writes this file after the Production Pester
         run; if it is missing, Production emission refuses with ReceiptBindingMissing.
      8. Writes the attestation to the BuildMaster artifact folder and copies it to the repo evidence folder.

    Not an attestation subject, so returns Emitted = $false without writing: CeilingTier is not Production, or the
    module has no Resources\Coordination\CoordinationSemanticRevision.json and is not the Orchestration module.

    Any refusal for an attested module throws 'PackageAttestationRefused|<ReasonCode>|<detail>' after logging the
    reason with PSFramework.

    Nothing is written inside the nupkg. The feed credential is resolved only through Get-SecretATAP by SecretName.
  .PARAMETER ModuleName
    Module name; the Orchestration module is the only current attestation subject.
  .PARAMETER PackageName
    ProGet package ID used in the stable-feed URL.
  .PARAMETER ModuleVersion
    Promoted package version; must equal the packaged psd1 ModuleVersion.
  .PARAMETER NupkgPath
    Path to the Experimental-built nupkg whose bytes were promoted.
  .PARAMETER CeilingTier
    Version ceiling of the run; the attestation is emitted only for 'Production'.
  .PARAMETER SignerThumbprint
    Expected Authenticode signer of every packaged script.
  .PARAMETER BuildId
    BuildMaster build ID.
  .PARAMETER ExecutionIds
    BuildMaster execution IDs that contributed to the build.
  .PARAMETER TierReceiptPaths
    Hashtable keyed by tier name: Experimental = completion marker file; other tiers = PesterResults.xml.
  .PARAMETER OutputDirectory
    BuildMaster artifact folder for the attestation file.
  .PARAMETER RepoEvidenceDirectory
    Repo folder, normally _generated\build-deploy-module\<Module>\<Version>\Production.
  .PARAMETER ProGetBaseUrl
    HTTPS ProGet base URL.
  .PARAMETER FeedName
    Stable feed name used to fetch the archive for the equality check.
  .PARAMETER ProGetApiKeySecretName
    SecretName resolved with Get-SecretATAP for the feed download.
  .PARAMETER CreatedUtc
    Optional fixed createdUtc for reproducible tests.
  .OUTPUTS
    PSCustomObject with PSTypeName ATAP.PackageAttestationEmission.
  .EXAMPLE
    New-PackageAttestation -ModuleName $m -PackageName $m -ModuleVersion $v -NupkgPath $n -CeilingTier Production ...
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ModuleName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ModuleVersion,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$NupkgPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$CeilingTier,
    [Parameter(Mandatory)][ValidatePattern('\A[0-9A-Fa-f]{40}\z')][string]$SignerThumbprint,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$BuildId,
    [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ExecutionIds,
    [Parameter(Mandatory)][ValidateNotNull()][hashtable]$TierReceiptPaths,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$OutputDirectory,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$RepoEvidenceDirectory,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ProGetBaseUrl,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$FeedName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ProGetApiKeySecretName,
    [string]$CreatedUtc = ''
  )
  begin {
    $fn = 'New-PackageAttestation'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    $null = Get-Command Get-SecretATAP -ErrorAction Stop
    $null = Get-Command Write-PSFMessage -ErrorAction Stop
    $orchestrationName = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $tierOrder = @('Experimental', 'Development', 'Integration', 'QA', 'Production')
    $packageExtensions = @('.ps1', '.psm1', '.psd1', '.json')
    $scriptExtensions = @('.ps1', '.psm1', '.psd1')
    # The pinned schema copy sits beside the public folder. A built module has the same layout at its root.
    $moduleRoot = if ((Split-Path $PSScriptRoot -Leaf) -in @('public', 'private')) { Split-Path $PSScriptRoot -Parent } else { $PSScriptRoot }
    $schemaPath = Join-Path $moduleRoot 'schemas\package-attestation-v1.schema.json'
  }
  process {
    $omit = {
      param([string]$Code)
      [pscustomobject]@{
        PSTypeName = 'ATAP.PackageAttestationEmission'
        Emitted = $false
        ReasonCode = $Code
        AttestationPath = $null
        RepoCopyPath = $null
        AttestationSha256 = $null
        ModuleVersion = $ModuleVersion
        ArchiveSha256 = $null
      }
    }
    $junitTotals = {
      param([string]$Path)
      try {
        $doc = [xml](Get-Content -LiteralPath $Path -Raw -ErrorAction Stop)
      } catch {
        throw 'PackageAttestationRefused|TierReceiptUnreadable'
      }
      $suites = @($doc.SelectNodes('//testsuite'))
      if ($suites.Count -eq 0) { throw 'PackageAttestationRefused|TierReceiptUnreadable' }
      [pscustomobject]@{
        Tests = [int](($suites | ForEach-Object { [int]$_.tests } | Measure-Object -Sum).Sum)
        Failures = [int](($suites | ForEach-Object { [int]$_.failures } | Measure-Object -Sum).Sum)
        Errors = [int](($suites | ForEach-Object { [int]$_.errors } | Measure-Object -Sum).Sum)
      }
    }

    $workRoot = Join-Path ([IO.Path]::GetTempPath()) ('pkgattest-' + [guid]::NewGuid().ToString('N'))
    try {
      # 0. Only the Production ceiling produces an attestation.
      if ($CeilingTier -cne 'Production') {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "No package attestation for '$ModuleName' '$ModuleVersion': ceiling '$CeilingTier' is not Production."
        return (& $omit 'CeilingNotProduction')
      }
      if (-not (Test-Path -LiteralPath $NupkgPath -PathType Leaf)) { throw 'PackageAttestationRefused|NupkgMissing' }
      if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) { throw 'PackageAttestationRefused|SchemaCopyMissing' }
      New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
      $packageDir = Join-Path $workRoot 'package'
      Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
      [IO.Compression.ZipFile]::ExtractToDirectory($NupkgPath, $packageDir)

      # 1-2. Packaged module identity and version.
      $manifests = @(Get-ChildItem -LiteralPath $packageDir -Filter "$ModuleName.psd1" -File -Recurse)
      if ($manifests.Count -ne 1) { throw 'PackageAttestationRefused|ModuleManifestMissing' }
      $packageRoot = $manifests[0].DirectoryName
      $manifest = Import-PowerShellDataFile -LiteralPath $manifests[0].FullName -ErrorAction Stop
      if ([string]$manifest.ModuleVersion -cne $ModuleVersion) { throw 'PackageAttestationRefused|ModuleVersionMismatch' }

      # 3. Semantic revision from the packaged Resources\Coordination\CoordinationSemanticRevision.json.
      #    File absent: not an attestation subject, except Orchestration (SemanticRevisionMissing).
      #    File present but malformed or of the wrong kind: refuse.
      $semanticRevision = ''
      $semanticPath = Join-Path $packageRoot 'Resources\Coordination\CoordinationSemanticRevision.json'
      if (Test-Path -LiteralPath $semanticPath -PathType Leaf) {
        try {
          $semanticDocument = Get-Content -LiteralPath $semanticPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        } catch {
          throw 'PackageAttestationRefused|SemanticRevisionFileMalformed'
        }
        if ($null -eq $semanticDocument) { throw 'PackageAttestationRefused|SemanticRevisionFileMalformed' }
        $semanticNames = @($semanticDocument.PSObject.Properties.Name)
        if ($semanticNames -cnotcontains 'kind' -or $semanticDocument.kind -isnot [string] -or
            $semanticDocument.kind -cne 'CoordinationSemanticRevision-v1' -or
            $semanticNames -cnotcontains 'coordinationSemanticRevision' -or
            $semanticDocument.coordinationSemanticRevision -isnot [string] -or
            [string]::IsNullOrWhiteSpace($semanticDocument.coordinationSemanticRevision)) {
          throw 'PackageAttestationRefused|SemanticRevisionFileMalformed'
        }
        $semanticRevision = [string]$semanticDocument.coordinationSemanticRevision
      }
      if ([string]::IsNullOrWhiteSpace($semanticRevision)) {
        if ($ModuleName -ceq $orchestrationName) { throw 'PackageAttestationRefused|SemanticRevisionMissing' }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "No package attestation for '$ModuleName' '$ModuleVersion': no Resources\Coordination\CoordinationSemanticRevision.json in the package."
        return (& $omit 'NoSemanticRevision')
      }

      # 4. Inventory and Authenticode. Same inventory rule as Assert-CoordPackageInventory: non-test script and json files.
      $inventory = @(Get-ChildItem -LiteralPath $packageRoot -File -Recurse | Where-Object {
          $rel = [IO.Path]::GetRelativePath($packageRoot, $_.FullName).Replace('\', '/')
          $_.Extension -in $packageExtensions -and -not $rel.StartsWith('tests/', [StringComparison]::OrdinalIgnoreCase)
        } | Sort-Object { [IO.Path]::GetRelativePath($packageRoot, $_.FullName).Replace('\', '/') } )
      if ($inventory.Count -eq 0) { throw 'PackageAttestationRefused|InventoryEmpty' }
      $thumbprint = $SignerThumbprint.ToUpperInvariant()
      foreach ($file in @($inventory | Where-Object { $_.Extension -in $scriptExtensions })) {
        $signature = Get-AuthenticodeSignature -LiteralPath $file.FullName
        if ([string]$signature.Status -cne 'Valid') { throw "PackageAttestationRefused|SignatureInvalid|$($file.Name)" }
        $signerValue = if ($null -ne $signature.SignerCertificate) { ([string]$signature.SignerCertificate.Thumbprint).ToUpperInvariant() } else { '' }
        if ($signerValue -cne $thumbprint) { throw "PackageAttestationRefused|SignerMismatch|$($file.Name)" }
      }
      $files = @(foreach ($file in $inventory) {
          [ordered]@{
            path = [IO.Path]::GetRelativePath($packageRoot, $file.FullName).Replace('\', '/')
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            size = [int64]$file.Length
          }
        })

      # 5. Schema hashes from the packaged schemas.
      $schemaHashes = @{}
      foreach ($schemaName in @('state', 'request', 'result')) {
        $schemaFile = Join-Path $packageRoot "schemas\$schemaName-v1.schema.json"
        if (-not (Test-Path -LiteralPath $schemaFile -PathType Leaf)) { throw "PackageAttestationRefused|SchemaFileMissing|$schemaName" }
        $schemaHashes[$schemaName] = (Get-FileHash -LiteralPath $schemaFile -Algorithm SHA256).Hash.ToLowerInvariant()
      }

      # 6. Archive equality with the stable-feed copy (design guard C4.2). HTTPS only, credential by SecretName.
      $archiveSha256 = (Get-FileHash -LiteralPath $NupkgPath -Algorithm SHA256).Hash.ToLowerInvariant()
      if ($ProGetBaseUrl -notmatch '^https://') { throw 'PackageAttestationRefused|CleartextFeedRefused' }
      $apiKey = [string](Get-SecretATAP -SecretName $ProGetApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop)
      if ([string]::IsNullOrWhiteSpace($apiKey)) { throw 'PackageAttestationRefused|FeedCredentialEmpty' }
      $feedUri = '{0}/nuget/{1}/package/{2}/{3}' -f $ProGetBaseUrl.TrimEnd('/'), $FeedName,
        [uri]::EscapeDataString($PackageName), [uri]::EscapeDataString($ModuleVersion)
      $feedCopy = Join-Path $workRoot 'feed-copy.nupkg'
      try {
        Invoke-WebRequest -Uri $feedUri -Headers @{ 'X-ApiKey' = $apiKey; Accept = 'application/zip' } `
          -OutFile $feedCopy -UseBasicParsing -ErrorAction Stop | Out-Null
      } catch {
        throw "PackageAttestationRefused|ArchiveFeedUnavailable|$($_.Exception.Message)"
      } finally {
        $apiKey = $null
      }
      if (-not (Test-Path -LiteralPath $feedCopy -PathType Leaf)) { throw 'PackageAttestationRefused|ArchiveFeedUnavailable' }
      $feedSha256 = (Get-FileHash -LiteralPath $feedCopy -Algorithm SHA256).Hash.ToLowerInvariant()
      if ($feedSha256 -cne $archiveSha256) { throw 'PackageAttestationRefused|ArchiveFeedMismatch' }

      # 7. Tier receipts. Experimental: marker file hash (D3). Test tiers: JUnit totals must show tests and no failures.
      $tierReceipts = [ordered]@{}
      foreach ($tier in $tierOrder) {
        if (-not $TierReceiptPaths.ContainsKey($tier)) { throw "PackageAttestationRefused|TierReceiptMissing|$tier" }
        $receiptPath = [string]$TierReceiptPaths[$tier]
        if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) { throw "PackageAttestationRefused|TierReceiptMissing|$tier" }
        if ($tier -cne 'Experimental') {
          $totals = & $junitTotals $receiptPath
          if ($totals.Tests -le 0 -or $totals.Failures -ne 0 -or $totals.Errors -ne 0) {
            throw "PackageAttestationRefused|TierTestsFailed|$tier"
          }
        }
        $tierReceipts[$tier] = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
      }

      # 7b. Production receipt binding. The runner writes ProductionReceiptBinding.json beside the Production receipt.
      $bindingPath = Join-Path (Split-Path -Parent ([string]$TierReceiptPaths['Production'])) 'ProductionReceiptBinding.json'
      if (-not (Test-Path -LiteralPath $bindingPath -PathType Leaf)) { throw 'PackageAttestationRefused|ReceiptBindingMissing' }
      $binding = try {
        Get-Content -LiteralPath $bindingPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
      } catch {
        throw 'PackageAttestationRefused|ReceiptBindingMismatch|unreadable'
      }
      if ($null -eq $binding -or $binding -isnot [pscustomobject] -or [string]$binding.kind -cne 'ProductionReceiptBinding-v1' -or
          ([string]$binding.archiveSha256).ToLowerInvariant() -cne $archiveSha256 -or [string]$binding.moduleVersion -cne $ModuleVersion -or
          ([string]$binding.junitSha256).ToLowerInvariant() -cne $tierReceipts['Production']) {
        throw 'PackageAttestationRefused|ReceiptBindingMismatch'
      }

      # 8. Execution IDs: distinct, non-empty.
      $ids = @($ExecutionIds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
      if ($ids.Count -eq 0) { throw 'PackageAttestationRefused|ExecutionIdMissing' }

      $createdValue = if ([string]::IsNullOrWhiteSpace($CreatedUtc)) { [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ') } else { $CreatedUtc }
      $attestation = [ordered]@{
        kind = 'Coordination-package-attestation-v1'
        moduleName = $ModuleName
        moduleVersion = $ModuleVersion
        archiveSha256 = $archiveSha256
        files = $files
        signerThumbprint = $thumbprint
        stateSchemaSha256 = $schemaHashes['state']
        requestSchemaSha256 = $schemaHashes['request']
        resultSchemaSha256 = $schemaHashes['result']
        coordinationSemanticRevision = $semanticRevision
        buildId = $BuildId
        executionIds = $ids
        finalProductionTestReceiptSha256 = $tierReceipts['Production']
        tierReceiptSha256 = $tierReceipts
        productionReceiptBinding = [ordered]@{
          archiveSha256 = $archiveSha256
          moduleVersion = $ModuleVersion
          receiptSha256 = $tierReceipts['Production']
        }
        createdUtc = $createdValue
      }
      $json = $attestation | ConvertTo-Json -Depth 10
      $schemaText = Get-Content -LiteralPath $schemaPath -Raw
      if (-not (Test-Json -Json $json -Schema $schemaText -ErrorAction SilentlyContinue)) { throw 'PackageAttestationRefused|AttestationSchemaInvalid' }

      # 9. Write to the artifact folder and the repo evidence folder, then prove the copy is identical.
      New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
      New-Item -ItemType Directory -Path $RepoEvidenceDirectory -Force | Out-Null
      $attestationPath = Join-Path $OutputDirectory ("{0}.{1}.package-attestation.json" -f $ModuleName, $ModuleVersion)
      $repoCopyPath = Join-Path $RepoEvidenceDirectory 'package-attestation.json'
      Set-Content -LiteralPath $attestationPath -Value $json -Encoding utf8
      Copy-Item -LiteralPath $attestationPath -Destination $repoCopyPath -Force
      $attestationSha256 = (Get-FileHash -LiteralPath $attestationPath -Algorithm SHA256).Hash.ToLowerInvariant()
      if ((Get-FileHash -LiteralPath $repoCopyPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $attestationSha256) {
        throw 'PackageAttestationRefused|RepoCopyMismatch'
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Package attestation emitted for '$ModuleName' '$ModuleVersion' (archive $archiveSha256; sha256 $attestationSha256)."
      [pscustomobject]@{
        PSTypeName = 'ATAP.PackageAttestationEmission'
        Emitted = $true
        ReasonCode = 'Emitted'
        AttestationPath = $attestationPath
        RepoCopyPath = $repoCopyPath
        AttestationSha256 = $attestationSha256
        ModuleVersion = $ModuleVersion
        ArchiveSha256 = $archiveSha256
      }
    } catch {
      $message = [string]$_.Exception.Message
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Package attestation refused for '$ModuleName' '$ModuleVersion': $message"
      throw
    } finally {
      if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }
  }
  end {
  }
}
