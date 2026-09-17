Set-StrictMode -Version Latest

# Application-release Authenticode approval boundary (Task 15.196.q / SC-0443, unit q.1).
#
# This file is the ONLY place that says which application binaries the BuildMaster service
# identity may sign, which signer leaf is admitted on which host, and which publish/bundle
# entry points produce the bytes. It is modelled on CSharpPackageAuthenticodeSigning.ps1:
# dot-sourced by the stage runner (Invoke-ApplicationBuildMasterStage.ps1, unit q.2), pure
# functions, no side effects, no secrets. Every lookup fails closed: an unknown product, an
# unknown host, or a thumbprint not admitted for that host is a throw, never a fallback.
#
# Row grammar (pipe-separated, in order):
#   ProductId | ProductRecordPath | PublishEntryPoint | BundleEntryPoint | InstallerRelativePath
#   | ArtifactKind | SignedFileNames (semicolon-separated exact leaf names under the publish root)
#
# The SignedFileNames are the ATAP-owned assemblies that the live releases actually signed
# (AceOutpost 0.1.2+3ec88850f2 on utat022, Task 15.196; AceCommander COMMANDER02, Task 15.185.f).
# Third-party assemblies in the publish root are never signed by us and are deliberately absent.
# AceCommander's product record declares only AceCommander.dll and AceCommander.Client.dll; the
# four additional owned assemblies were signed in COMMANDER02 and are kept here so that the
# boundary describes what ships, not what the record under-declares. Tests assert the record's
# declared assemblies are a subset of this list.

function Get-ApplicationReleaseAuthenticodeContractRows {
  [CmdletBinding()]
  [OutputType([string[]])]
  param()
  return @(
    'AceOutpost|AceOutpost.Windows/ApplicationRecords/AceOutpost.application.json|Build/Invoke-DeterministicApplicationPublish.ps1|AceOutpost.Windows/Deployment/New-AceOutpostReleaseBundle.ps1|AceOutpost.Windows/Deployment/Install-AceOutpostRelease.ps1|WindowsApplicationOrService|AceOutpostService.exe;AceOutpostService.dll;AceOutpost.Database.dll;AceOutpost.Instrumentation.dll;AceCommon.dll;AceETW.dll'
    'AceCommander|AceCommander/ApplicationRecords/AceCommander.application.json|Build/Invoke-DeterministicApplicationPublish.ps1|BuildTooling::New-CommanderReleaseBundle|AceCommander/Deployment/Install-AceCommanderRelease.ps1|HostedWebApplication|AceCommander.dll;AceCommander.Client.dll;AceCommander.Server.DefaultConfiguration.dll;AceCommander.Server.StringConstants.dll;AceCommander.Shared.dll;AceCommon.dll'
  )
}

function Get-ApplicationReleaseAuthenticodeProductIds {
  [CmdletBinding()]
  [OutputType([string[]])]
  param()
  return @(Get-ApplicationReleaseAuthenticodeContractRows | ForEach-Object { ($_ -split '\|', 2)[0] })
}

function Get-ApplicationReleaseAuthenticodeContract {
  <#
  .SYNOPSIS
    Returns the signing contract for one admitted product, or throws.
  .DESCRIPTION
    Case-sensitive product lookup. A product that is not in the allowlist is a throw, not a
    null: the stage runner must not be able to proceed past this call with a product the
    boundary does not describe.
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ProductId)

  $row = @(Get-ApplicationReleaseAuthenticodeContractRows | Where-Object { ($_ -split '\|', 2)[0] -ceq $ProductId })
  if ($row.Count -ne 1) {
    throw "Product '$ProductId' is not admitted by the application-release Authenticode boundary. Admitted: $((Get-ApplicationReleaseAuthenticodeProductIds) -join ', ')."
  }
  $parts = $row[0] -split '\|', 7
  if ($parts.Count -ne 7) { throw "Application-release contract row for '$ProductId' is malformed (expected 7 fields, found $($parts.Count))." }
  $signedFileNames = @($parts[6] -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  if ($signedFileNames.Count -eq 0) { throw "Application-release contract row for '$ProductId' declares no signed files." }
  foreach ($name in $signedFileNames) {
    if ($name -match '[\\/]' -or $name -notmatch '\.(dll|exe)$') {
      throw "Application-release contract row for '$ProductId' has an invalid signed file name '$name': leaf names ending in .dll or .exe only."
    }
  }
  $bundleEntryPoint = $parts[3]
  $bundleKind = if ($bundleEntryPoint -like 'BuildTooling::*') { 'BuildToolingFunction' } else { 'RepositoryScript' }
  return [pscustomobject]@{
    ProductId             = $parts[0]
    ProductRecordPath     = $parts[1]
    PublishEntryPoint     = $parts[2]
    BundleEntryPoint      = $bundleEntryPoint
    BundleEntryPointKind  = $bundleKind
    BundleFunctionName    = if ($bundleKind -eq 'BuildToolingFunction') { $bundleEntryPoint.Substring('BuildTooling::'.Length) } else { $null }
    InstallerRelativePath = $parts[4]
    ArtifactKind          = $parts[5]
    SignedFileNames       = $signedFileNames
  }
}

function Get-ApplicationReleaseSignerAdmissions {
  <#
  .SYNOPSIS
    Returns the admitted (placement host -> code-signing leaf thumbprint) pairs.
  .DESCRIPTION
    Both leaves are already admitted by the Ace install gates (Ace 2861256). The BuildMaster
    application variable supplies the thumbprint the stage signs with; this table is what
    that value is checked AGAINST, so a variable pointing at any other certificate - even a
    valid code-signing certificate - is refused. utat022's leaf is the interactive-user key
    that signed every release to date (rollback signer on utat01); utat01's leaf is custodied
    by SvcBuildMaster (Task 15.196.g) and is the reason SC-0443 exists.
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject[]])]
  param()
  return @(
    [pscustomobject]@{ HostName = 'utat022'; Thumbprint = '3B5E16C0498E1F5A92F95B9AA17FD6A40E9C406E'; Custodian = 'interactive user (whertzing)'; Role = 'legacy signer; rollback signer on utat01' }
    [pscustomobject]@{ HostName = 'utat01';  Thumbprint = 'D4C19B2224C80F19D4BAF5609BCD6255A83D3BC7'; Custodian = 'SvcBuildMaster (LocalMachine\My)'; Role = 'release signer (Task 15.196.g)' }
  )
}

function Get-ApplicationReleaseAdmittedSignerThumbprint {
  [CmdletBinding()]
  [OutputType([string])]
  param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$HostName)

  $normalizedHost = $HostName.Trim().ToLowerInvariant()
  $match = @(Get-ApplicationReleaseSignerAdmissions | Where-Object { $_.HostName -ceq $normalizedHost })
  if ($match.Count -ne 1) {
    throw "Host '$HostName' has no admitted application-release signer. Admitted hosts: $((Get-ApplicationReleaseSignerAdmissions | ForEach-Object HostName) -join ', ')."
  }
  return $match[0].Thumbprint
}

function Test-ApplicationReleaseSignerAdmitted {
  <#
  .SYNOPSIS
    Throws unless Thumbprint is exactly the leaf admitted for HostName.
  .DESCRIPTION
    Returns the normalized thumbprint on success so callers sign with the checked value, not
    the raw input. Never returns $false: an inadmissible signer is a stop, not a branch.
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$HostName,
    [Parameter(Mandatory)][ValidatePattern('^[0-9A-Fa-f]{40}$')][string]$Thumbprint
  )

  $admitted = Get-ApplicationReleaseAdmittedSignerThumbprint -HostName $HostName
  $normalized = $Thumbprint.Trim().ToUpperInvariant()
  if ($normalized -cne $admitted) {
    throw "Signer '$normalized' is not admitted for application releases on '$HostName'; the admitted leaf is '$admitted'. Refusing to sign."
  }
  return $normalized
}

function Get-ApplicationReleaseTimestampServerUri {
  [CmdletBinding()]
  [OutputType([uri])]
  param()
  # The same authority every shipped Ace release used; kept here so the stage cannot drift to a
  # different TSA silently.
  return [uri]'http://timestamp.digicert.com'
}

function Get-ApplicationReleaseSignedFileContract {
  <#
  .SYNOPSIS
    Resolves the exact files to sign under a publish root, failing closed on any absence.
  .DESCRIPTION
    Every allowlisted file must exist directly under PublishRoot (no recursion - the owned
    assemblies live at the root of a published application). A missing file is a throw,
    because signing a subset and shipping would be a partially-signed release.
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject[]])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ProductId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PublishRoot
  )

  $contract = Get-ApplicationReleaseAuthenticodeContract -ProductId $ProductId
  if (-not (Test-Path -LiteralPath $PublishRoot -PathType Container)) {
    throw "Publish root '$PublishRoot' for '$ProductId' does not exist."
  }
  $missing = [System.Collections.Generic.List[string]]::new()
  $files = foreach ($name in $contract.SignedFileNames) {
    $path = Join-Path -Path $PublishRoot -ChildPath $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $missing.Add($name); continue }
    [pscustomobject]@{ Name = $name; Path = (Get-Item -LiteralPath $path).FullName }
  }
  if ($missing.Count -gt 0) {
    throw "Publish root '$PublishRoot' for '$ProductId' is missing allowlisted signable files: $($missing -join ', ')."
  }
  return @($files)
}

function Get-ApplicationReleaseAuthenticodeReleaseContract {
  <#
  .SYNOPSIS
    The whole boundary as one object, with the fixed counts the tests pin.
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param()
  $products = @(Get-ApplicationReleaseAuthenticodeProductIds | ForEach-Object { Get-ApplicationReleaseAuthenticodeContract -ProductId $_ })
  $signedFiles = @($products | ForEach-Object { $product = $_; $_.SignedFileNames | ForEach-Object { "$($product.ProductId)|$_" } })
  if ($products.Count -ne 2 -or $signedFiles.Count -ne 12) {
    throw "The application-release boundary must contain exactly 2 products and 12 signed files; found $($products.Count) products and $($signedFiles.Count) files."
  }
  return [pscustomobject]@{
    Products    = $products
    SignedFiles = $signedFiles
    Signers     = @(Get-ApplicationReleaseSignerAdmissions)
    TimestampServerUri = Get-ApplicationReleaseTimestampServerUri
  }
}
