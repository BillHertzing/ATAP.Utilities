function Test-CoordPackageAttestation {
  <#
  .SYNOPSIS
    Verifies a Coordination-package-attestation-v1 against an installed module root, a policy and a nupkg.
  .DESCRIPTION
    Fails closed. Returns a typed result with a single ReasonCode: Valid, or one distinct code per
    failure. Any unexpected exception returns UnexpectedError. Checks run in this order: policy shape
    (anchored regexes), attestation schema, module identity and version, downgrade, minimum version,
    schema hashes and semantic revision derived from the installed package, archive digest, Production
    receipt binding, required attested files, exact installed inventory, then Authenticode and signer.

    The installed state, request and result schema hashes are computed here from the installed
    schemas folder, and the installed semantic revision is read from
    Resources\Coordination\CoordinationSemanticRevision.json. Each must equal BOTH the attestation and the
    policy. Nothing is accepted on the attestation's word alone.

    The attestation's productionReceiptBinding must name the archive SHA256 and module version the
    Production tests ran against. The verifier requires those to equal the supplied nupkg and the installed
    module version, and the binding digest to equal finalProductionTestReceiptSha256.

    The attestation is not signed; the verifier's checks do not depend on signing.
  .PARAMETER ModuleRoot
    Installed module root that contains the psd1 manifest.
  .PARAMETER AttestationPath
    Path to the attestation JSON file.
  .PARAMETER Policy
    Object or hashtable with signer, minVersion, semanticRevision and schemaHashes{state,request,result}.
  .PARAMETER NupkgPath
    Path to the nupkg whose SHA256 must equal archiveSha256.
  .PARAMETER CurrentVersion
    Installed package version. Mandatory in the Upgrade parameter set. The attested version must be
    strictly greater; a lower version is Downgrade and an equal version is SameVersionRefused.
  .PARAMETER FirstAdmission
    Selects the FirstAdmission parameter set for a package with no installed predecessor. It bypasses
    only the downgrade and same-version checks. Every other check still applies.
  .OUTPUTS
    PSCustomObject with PSTypeName ATAP.CoordPackageAttestationResult.
  .EXAMPLE
    Test-CoordPackageAttestation -ModuleRoot $root -AttestationPath $att -Policy $policy -NupkgPath $nupkg
  #>
  [CmdletBinding(DefaultParameterSetName = 'Upgrade')]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ModuleRoot,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$AttestationPath,
    [Parameter(Mandatory)][ValidateNotNull()]$Policy,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$NupkgPath,
    [Parameter(Mandatory, ParameterSetName = 'Upgrade')][ValidateNotNullOrEmpty()][string]$CurrentVersion,
    [Parameter(ParameterSetName = 'FirstAdmission')][switch]$FirstAdmission
  )
  begin {
    $fn = 'Test-CoordPackageAttestation'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $null = Get-Command Test-Json -ErrorAction Stop
    $null = Get-Command Get-AuthenticodeSignature -ErrorAction Stop
    $null = Get-Command Get-CoordHash -ErrorAction Stop
    $null = Get-Command Test-CoordDescendant -ErrorAction Stop
    $null = Get-Command Write-PSFMessage -ErrorAction Stop
    $knownCodes = @(
      'PolicyInvalid', 'AttestationUnreadable', 'AttestationSchemaInvalid', 'ModuleManifestMissing', 'ModuleManifestUnreadable',
      'ModuleNameMismatch', 'ModuleVersionMismatch', 'Downgrade', 'SameVersionRefused', 'CurrentVersionInvalid', 'VersionBelowMinimum',
      'SchemaFileMissing', 'StateSchemaHashMismatch', 'RequestSchemaHashMismatch', 'ResultSchemaHashMismatch',
      'SemanticRevisionFileMissing', 'SemanticRevisionFileMalformed', 'SemanticRevisionMismatch',
      'SignerMismatch', 'ArchiveMissing', 'ArchiveSha256Mismatch', 'ReceiptBindingMismatch', 'RequiredFileNotAttested',
      'InventoryMissingFile', 'InventoryExtraFile', 'InventoryHashMismatch', 'InventorySizeMismatch',
      'InventoryPathInvalid', 'SignatureInvalid')
    $scriptExtensions = @('.ps1', '.psm1', '.psd1')
    $inventoryExtensions = @('.ps1', '.psm1', '.psd1', '.json')
    $moduleName = $mn
    # Same schema-root resolution as Complete-CoordOperation: source keeps schemas beside private/.
    $schemaRoot = if ((Split-Path $PSScriptRoot -Leaf) -ieq 'private') { Split-Path $PSScriptRoot -Parent } else { $PSScriptRoot }
    # Installed-package paths (relative to the module root) that every attestation must carry.
    $schemaNames = @('state', 'request', 'result')
    $revisionRelative = 'Resources/Coordination/CoordinationSemanticRevision.json'
    $requiredAttested = @('schemas/state-v1.schema.json', 'schemas/request-v1.schema.json', 'schemas/result-v1.schema.json', $revisionRelative)
  }
  process {
    $reason = 'UnexpectedError'
    $detail = $null
    $installedVersion = $null
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Verifying attestation $AttestationPath against $ModuleRoot"

      # 1. Policy shape. Anchored with \A and \z so a trailing newline cannot pass.
      $p = [pscustomobject]$Policy
      $policyNames = @($p.PSObject.Properties.Name)
      foreach ($n in @('signer', 'minVersion', 'semanticRevision', 'schemaHashes')) {
        if ($policyNames -cnotcontains $n) { throw "PolicyInvalid|missing $n" }
      }
      $policySigner = [string]$p.signer
      if ($policySigner -notmatch '\A[0-9A-Fa-f]{40}\z') { throw 'PolicyInvalid|signer' }
      $policySigner = $policySigner.ToUpperInvariant()
      $minVersion = $null
      if (-not [version]::TryParse([string]$p.minVersion, [ref]$minVersion)) { throw 'PolicyInvalid|minVersion' }
      if ([string]::IsNullOrWhiteSpace([string]$p.semanticRevision)) { throw 'PolicyInvalid|semanticRevision' }
      $ph = [pscustomobject]$p.schemaHashes
      $phNames = @($ph.PSObject.Properties.Name)
      foreach ($n in $schemaNames) {
        if ($phNames -cnotcontains $n -or [string]$ph.$n -notmatch '\A[0-9A-Fa-f]{64}\z') { throw "PolicyInvalid|schemaHashes.$n" }
      }

      # 2. Attestation read and schema.
      $attText = try {
        [Text.UTF8Encoding]::new($false, $true).GetString([IO.File]::ReadAllBytes($AttestationPath))
      } catch {
        throw "AttestationUnreadable|$($_.Exception.Message)"
      }
      $att = try {
        $attText | ConvertFrom-Json -Depth 100 -ErrorAction Stop
      } catch {
        throw "AttestationUnreadable|$($_.Exception.Message)"
      }
      $attSchema = Get-Content -LiteralPath (Join-Path $schemaRoot 'schemas/package-attestation-v1.schema.json') -Raw -ErrorAction Stop
      if (-not (Test-Json -Json $attText -Schema $attSchema -ErrorAction SilentlyContinue)) { throw 'AttestationSchemaInvalid|package-attestation-v1' }

      # 3. Module identity and version.
      if ([string]$att.moduleName -cne $moduleName) { throw 'ModuleNameMismatch' }
      $manifestPath = Join-Path $ModuleRoot ($moduleName + '.psd1')
      if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'ModuleManifestMissing' }
      $manifest = try {
        Import-PowerShellDataFile -LiteralPath $manifestPath -ErrorAction Stop
      } catch {
        throw "ModuleManifestUnreadable|$($_.Exception.Message)"
      }
      $installedVersion = [string]$manifest.ModuleVersion
      if ([string]::IsNullOrWhiteSpace($installedVersion)) { throw 'ModuleManifestUnreadable|no ModuleVersion' }
      if ([string]$att.moduleVersion -cne $installedVersion) { throw "ModuleVersionMismatch|attested $($att.moduleVersion) installed $installedVersion" }
      $attVersion = [version]([string]$att.moduleVersion)

      # 4. Upgrade-only admission. CurrentVersion is mandatory unless -FirstAdmission selected the
      #    FirstAdmission set; that set bypasses only these two version comparisons.
      if ($PSCmdlet.ParameterSetName -ceq 'Upgrade') {
        $currentParsed = $null
        if (-not [version]::TryParse($CurrentVersion, [ref]$currentParsed)) { throw "CurrentVersionInvalid|$CurrentVersion" }
        if ($attVersion -lt $currentParsed) { throw "Downgrade|attested $attVersion below current $currentParsed" }
        if ($attVersion -eq $currentParsed) { throw "SameVersionRefused|attested $attVersion equals current" }
      }
      if ($attVersion -lt $minVersion) { throw "VersionBelowMinimum|attested $attVersion minimum $minVersion" }

      # 5. Schema hashes DERIVED from the installed schemas. Installed, attestation and policy must all be equal.
      $schemaCodes = @{ state = 'StateSchemaHashMismatch'; request = 'RequestSchemaHashMismatch'; result = 'ResultSchemaHashMismatch' }
      $attSchemaField = @{ state = 'stateSchemaSha256'; request = 'requestSchemaSha256'; result = 'resultSchemaSha256' }
      foreach ($name in $schemaNames) {
        $installedSchema = Join-Path $ModuleRoot "schemas/$name-v1.schema.json"
        if (-not (Test-Path -LiteralPath $installedSchema -PathType Leaf)) { throw "SchemaFileMissing|$name" }
        $installedHash = (Get-CoordHash ([IO.File]::ReadAllBytes($installedSchema))).ToLowerInvariant()
        $attHash = ([string]$att.($attSchemaField[$name])).ToLowerInvariant()
        $policyHash = ([string]$ph.$name).ToLowerInvariant()
        if ($installedHash -cne $attHash) { throw "$($schemaCodes[$name])|installed $name schema differs from attestation" }
        if ($installedHash -cne $policyHash) { throw "$($schemaCodes[$name])|installed $name schema differs from policy" }
        if ($attHash -cne $policyHash) { throw "$($schemaCodes[$name])|attestation $name schema differs from policy" }
      }

      # 5b. Semantic revision DERIVED from the installed Resources\Coordination file. Installed, attestation and policy must all be equal.
      $revisionPath = Join-Path $ModuleRoot 'Resources/Coordination/CoordinationSemanticRevision.json'
      if (-not (Test-Path -LiteralPath $revisionPath -PathType Leaf)) { throw 'SemanticRevisionFileMissing' }
      $revisionDocument = try {
        Get-Content -LiteralPath $revisionPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
      } catch {
        throw 'SemanticRevisionFileMalformed'
      }
      if ($null -eq $revisionDocument -or $revisionDocument -isnot [pscustomobject]) { throw 'SemanticRevisionFileMalformed' }
      $revisionNames = @($revisionDocument.PSObject.Properties.Name)
      if ($revisionNames -cnotcontains 'kind' -or $revisionDocument.kind -isnot [string] -or $revisionDocument.kind -cne 'CoordinationSemanticRevision-v1' -or
          $revisionNames -cnotcontains 'coordinationSemanticRevision' -or $revisionDocument.coordinationSemanticRevision -isnot [string] -or
          [string]::IsNullOrWhiteSpace($revisionDocument.coordinationSemanticRevision)) {
        throw 'SemanticRevisionFileMalformed'
      }
      $installedRevision = [string]$revisionDocument.coordinationSemanticRevision
      if ([string]$att.coordinationSemanticRevision -cne $installedRevision) { throw 'SemanticRevisionMismatch|installed differs from attestation' }
      if ([string]$p.semanticRevision -cne $installedRevision) { throw 'SemanticRevisionMismatch|installed differs from policy' }

      # 6. Declared signer equals the policy signer.
      if (([string]$att.signerThumbprint).ToUpperInvariant() -cne $policySigner) { throw 'SignerMismatch|attestation declares a different signer' }

      # 7. Archive digest equals the supplied nupkg.
      if (-not (Test-Path -LiteralPath $NupkgPath -PathType Leaf)) { throw 'ArchiveMissing' }
      $archiveHash = (Get-FileHash -LiteralPath $NupkgPath -Algorithm SHA256).Hash.ToLowerInvariant()
      if ($archiveHash -cne ([string]$att.archiveSha256).ToLowerInvariant()) { throw 'ArchiveSha256Mismatch' }

      # 7b. Production receipt binding: the tests ran against this archive and this version, and the binding
      #     names the same receipt digest the attestation records.
      $binding = $att.productionReceiptBinding
      if (([string]$binding.archiveSha256).ToLowerInvariant() -cne $archiveHash) { throw 'ReceiptBindingMismatch|archive' }
      if ([string]$binding.moduleVersion -cne $installedVersion) { throw 'ReceiptBindingMismatch|module version' }
      if (([string]$binding.receiptSha256).ToLowerInvariant() -cne ([string]$att.finalProductionTestReceiptSha256).ToLowerInvariant()) { throw 'ReceiptBindingMismatch|receipt digest' }

      # 8. Installed inventory exactly equals the attestation. Same rule as Assert-CoordPackageInventory.
      $testRoot = Join-Path $ModuleRoot 'tests'
      $installedMap = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
      foreach ($f in @(Get-ChildItem -LiteralPath $ModuleRoot -File -Recurse | Where-Object {
          $_.Extension -in $inventoryExtensions -and -not (Test-CoordDescendant $_.FullName $testRoot) })) {
        $installedMap[[IO.Path]::GetRelativePath($ModuleRoot, $f.FullName).Replace('\', '/')] = $f
      }
      $attMap = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
      foreach ($entry in @($att.files)) {
        $path = [string]$entry.path
        if ($attMap.ContainsKey($path)) { throw "InventoryPathInvalid|duplicate $path" }
        $attMap[$path] = $entry
      }
      foreach ($req in $requiredAttested) { if (-not $attMap.ContainsKey($req)) { throw "RequiredFileNotAttested|$req" } }
      foreach ($rel in $attMap.Keys) { if (-not $installedMap.ContainsKey($rel)) { throw "InventoryMissingFile|$rel" } }
      foreach ($rel in $installedMap.Keys) { if (-not $attMap.ContainsKey($rel)) { throw "InventoryExtraFile|$rel" } }
      foreach ($rel in $attMap.Keys) {
        $f = $installedMap[$rel]
        $e = $attMap[$rel]
        if ($f.LinkType) { throw "InventoryPathInvalid|linked $rel" }
        $bytes = [IO.File]::ReadAllBytes($f.FullName)
        if ((Get-CoordHash $bytes) -cne ([string]$e.sha256).ToLowerInvariant()) { throw "InventoryHashMismatch|$rel" }
        if ([int64]$e.size -ne [int64]$bytes.LongLength) { throw "InventorySizeMismatch|$rel" }
      }

      # 9. Authenticode Valid and signer equal to policy, on every script file in the inventory.
      # JSON files are covered by the exact hash and size check above; they carry no signature.
      foreach ($rel in $attMap.Keys) {
        if ([IO.Path]::GetExtension($rel) -notin $scriptExtensions) { continue }
        $sig = Get-AuthenticodeSignature -LiteralPath $installedMap[$rel].FullName
        if ([string]$sig.Status -cne 'Valid') { throw "SignatureInvalid|$rel status $($sig.Status)" }
        $thumb = if ($null -ne $sig.SignerCertificate) { ([string]$sig.SignerCertificate.Thumbprint).ToUpperInvariant() } else { '' }
        if ($thumb -cne $policySigner) { throw "SignerMismatch|$rel" }
      }

      $reason = 'Valid'
    } catch {
      $message = [string]$_.Exception.Message
      $code = $message.Split('|')[0]
      if ($knownCodes -ccontains $code) {
        $reason = $code
      } else {
        $reason = 'UnexpectedError'
      }
      $detail = $message
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Attestation rejected: $reason $detail"
    }

    [pscustomobject]@{
      PSTypeName = 'ATAP.CoordPackageAttestationResult'
      Valid = ($reason -ceq 'Valid')
      ReasonCode = $reason
      Detail = $detail
      InstalledModuleVersion = $installedVersion
      AttestationPath = $AttestationPath
    }
  }
  end {
  }
}
