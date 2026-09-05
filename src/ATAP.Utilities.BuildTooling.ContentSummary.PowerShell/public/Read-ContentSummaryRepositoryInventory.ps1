function Read-ContentSummaryRepositoryInventory {
  <#
  .SYNOPSIS
    Reads and validates an immutable, caller-authored ContentSummary repository inventory.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Path,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-f]{64}$')]
    [string] $ExpectedSha256
  )

  begin {
    $fn = 'Read-ContentSummaryRepositoryInventory'
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'
  }

  process {
    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $bytes = [IO.File]::ReadAllBytes($resolvedPath)
    $actualSha256 = Get-ContentSummarySha256 -Bytes $bytes
    if (-not [string]::Equals($actualSha256, $ExpectedSha256, [StringComparison]::Ordinal)) {
      throw 'CS-INVENTORY-001: inventory bytes do not match the approved SHA-256.'
    }
    try {
      $json = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
      if ($json.Length -gt 0 -and $json[0] -eq [char]0xFEFF) { $json = $json.Substring(1) }
      $inventory = $json | ConvertFrom-Json -Depth 20 -DateKind String -ErrorAction Stop
    }
    catch { throw 'CS-INVENTORY-001: inventory is not well-formed UTF-8 JSON.' }

    $assertProperties = {
      param($Value,[string[]]$Expected,[string]$Location)
      if ($null -eq $Value -or ($Value.PSObject.Properties.Name -join ',') -ne ($Expected -join ',')) {
        throw "CS-INVENTORY-001: $Location does not match the frozen property order."
      }
    }
    $parseGuid = {
      param($Value,[string]$Location)
      $parsed = [guid]::Empty
      if ($Value -isnot [string] -or -not [guid]::TryParseExact([string]$Value, 'D', [ref]$parsed) -or
        $parsed -eq [guid]::Empty -or $parsed.ToString('D') -cne [string]$Value) {
        throw "CS-INVENTORY-001: $Location must be a non-empty lowercase D-format GUID."
      }
      $parsed
    }
    $parseUtc = {
      param($Value,[string]$Location)
      $parsed = [datetimeoffset]::MinValue
      if ($Value -isnot [string] -or -not [datetimeoffset]::TryParseExact([string]$Value, 'O', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed) -or $parsed.Offset -ne [timespan]::Zero) {
        throw "CS-INVENTORY-001: $Location must be an O-format UTC timestamp."
      }
      $parsed
    }

    & $assertProperties $inventory @('schemaVersion','inventoryId','recordedAtUtc','repositories') 'inventory'
    if ($inventory.schemaVersion -ne 1) { throw 'CS-INVENTORY-001: unsupported inventory schemaVersion.' }
    [void](& $parseGuid $inventory.inventoryId 'inventoryId')
    [void](& $parseUtc $inventory.recordedAtUtc 'recordedAtUtc')
    if ($null -eq $inventory.repositories -or $inventory.repositories -is [string] -or @($inventory.repositories).Count -lt 1) {
      throw 'CS-INVENTORY-001: at least one repository is required.'
    }

    $allIds = [Collections.Generic.HashSet[guid]]::new()
    $allNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $allRoots = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($repository in @($inventory.repositories)) {
      & $assertProperties $repository @('repositoryId','repositoryRootRegistrationId','canonicalRepositoryName','originUri','originEvidence','canonicalRoot','rootKindCode','organizationId','classificationPolicyId','principalId','evidenceEntityId','recordedAtUtc','authorizations') 'repository'
      foreach ($idName in @('repositoryId','repositoryRootRegistrationId','organizationId','classificationPolicyId','principalId','evidenceEntityId')) {
        $id = & $parseGuid $repository.$idName "repository.$idName"
        if ($idName -in @('repositoryId','repositoryRootRegistrationId') -and -not $allIds.Add($id)) {
          throw 'CS-INVENTORY-001: repository and root identities must be globally unique.'
        }
      }
      if ($repository.canonicalRepositoryName -isnot [string] -or $repository.canonicalRepositoryName -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,255}$' -or -not $allNames.Add([string]$repository.canonicalRepositoryName)) {
        throw 'CS-INVENTORY-001: canonical repository names must be valid and unique.'
      }
      $origin = $null
      if ($repository.originUri -isnot [string] -or -not [uri]::TryCreate([string]$repository.originUri, [UriKind]::Absolute, [ref]$origin) -or
        $origin.Scheme -ne 'https' -or -not [string]::IsNullOrEmpty($origin.UserInfo) -or $origin.Query -or $origin.Fragment) {
        throw 'CS-INVENTORY-001: originUri must be an absolute credential-free HTTPS URI.'
      }
      & $assertProperties $repository.originEvidence @('kind','remoteName','observedUri','observedAtUtc') 'originEvidence'
      if ($repository.originEvidence.kind -cne 'git-remote' -or $repository.originEvidence.remoteName -cne 'origin' -or
        $repository.originEvidence.observedUri -cne $repository.originUri) {
        throw 'CS-INVENTORY-001: origin evidence must exactly bind the origin remote URI.'
      }
      [void](& $parseUtc $repository.originEvidence.observedAtUtc 'originEvidence.observedAtUtc')

      if ($repository.canonicalRoot -isnot [string] -or -not [IO.Path]::IsPathFullyQualified([string]$repository.canonicalRoot)) {
        throw 'CS-INVENTORY-001: canonicalRoot must be an absolute path.'
      }
      $fullRoot = [IO.Path]::GetFullPath([string]$repository.canonicalRoot)
      $pathRoot = [IO.Path]::GetPathRoot($fullRoot)
      if ($fullRoot -cne [string]$repository.canonicalRoot -or ($fullRoot -cne $pathRoot -and $fullRoot.EndsWith([IO.Path]::DirectorySeparatorChar)) -or
        -not (Test-Path -LiteralPath $fullRoot -PathType Container) -or -not (Test-Path -LiteralPath (Join-Path $fullRoot '.git')) -or -not $allRoots.Add($fullRoot)) {
        throw 'CS-INVENTORY-001: canonicalRoot must be a unique existing canonical Git worktree root.'
      }
      $actualOriginUri = @(& git -C $fullRoot config --get remote.origin.url 2>$null)
      if ($LASTEXITCODE -ne 0 -or $actualOriginUri.Count -ne 1 -or $actualOriginUri[0] -cne $repository.originUri) {
        throw 'CS-INVENTORY-001: origin evidence does not match the worktree origin remote.'
      }
      if ($repository.rootKindCode -notin @('stable','sprint','mirror','scanner-sandbox')) { throw 'CS-INVENTORY-001: invalid rootKindCode.' }
      [void](& $parseUtc $repository.recordedAtUtc 'repository.recordedAtUtc')
      if ($null -eq $repository.authorizations -or $repository.authorizations -is [string]) { throw 'CS-INVENTORY-001: authorizations must be an array.' }
      foreach ($authorization in @($repository.authorizations)) {
        & $assertProperties $authorization @('authorizationId','databasePrincipalName','instanceCode','sourceReference','recordedAtUtc') 'authorization'
        $authorizationId = & $parseGuid $authorization.authorizationId 'authorization.authorizationId'
        if (-not $allIds.Add($authorizationId)) { throw 'CS-INVENTORY-001: durable identities must be globally unique.' }
        if ($authorization.databasePrincipalName -isnot [string] -or [string]::IsNullOrWhiteSpace($authorization.databasePrincipalName) -or $authorization.databasePrincipalName.Length -gt 128) { throw 'CS-INVENTORY-001: invalid databasePrincipalName.' }
        if ($authorization.instanceCode -notin @('production','qa','integration','dev','exp')) { throw 'CS-INVENTORY-001: invalid instanceCode.' }
        if ($authorization.sourceReference -isnot [string] -or [string]::IsNullOrWhiteSpace($authorization.sourceReference) -or $authorization.sourceReference.Length -gt 512) { throw 'CS-INVENTORY-001: invalid authorization sourceReference.' }
        [void](& $parseUtc $authorization.recordedAtUtc 'authorization.recordedAtUtc')
      }
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Validated inventory $actualSha256 with $(@($inventory.repositories).Count) repositories." -Tag 'Inventory'
    [pscustomobject][ordered]@{ SchemaVersion=1; InventorySha256=$actualSha256; InventoryId=[guid]$inventory.inventoryId; RecordedAtUtc=[datetimeoffset]$inventory.recordedAtUtc; Repositories=@($inventory.repositories) }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}
