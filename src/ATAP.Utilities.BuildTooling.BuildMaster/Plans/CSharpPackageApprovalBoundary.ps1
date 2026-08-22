function Write-CSharpPackageApprovalJsonOnce {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateNotNull()][object]$InputObject,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path
  )

  $resolvedPath = [System.IO.Path]::GetFullPath($Path)
  [System.IO.Directory]::CreateDirectory((Split-Path -Parent $resolvedPath)) | Out-Null
  $json = $InputObject | ConvertTo-Json -Depth 20
  $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($json + [Environment]::NewLine)

  if (Test-Path -LiteralPath $resolvedPath -PathType Leaf) {
    $existingBytes = [System.IO.File]::ReadAllBytes($resolvedPath)
    if ([Convert]::ToBase64String($existingBytes) -cne [Convert]::ToBase64String($bytes)) {
      throw "Immutable approval-boundary record already exists with different bytes: '$resolvedPath'."
    }
    return Get-Item -LiteralPath $resolvedPath
  }

  $stream = [System.IO.FileStream]::new($resolvedPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
  try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
  return Get-Item -LiteralPath $resolvedPath
}

function Get-CSharpPackageApprovalFileSha256 {
  [CmdletBinding()]
  [OutputType([string])]
  param([Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$Path)

  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-CSharpPackageApprovalPathContained {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ArtifactsPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$CandidatePath
  )

  $root = [System.IO.Path]::GetFullPath($ArtifactsPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
  $candidate = [System.IO.Path]::GetFullPath($CandidatePath)
  if (-not $candidate.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Approval-boundary path '$candidate' must remain beneath ArtifactsPath '$root'."
  }
  return $candidate
}

function New-CSharpPackagePreparedManifest {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ArtifactsPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ManifestPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string[]]$NupkgPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$BuildMasterBuildId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SourceCommit,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageVersion
  )

  $resolvedArtifactsPath = [System.IO.Path]::GetFullPath($ArtifactsPath)
  $resolvedManifestPath = Assert-CSharpPackageApprovalPathContained -ArtifactsPath $resolvedArtifactsPath -CandidatePath $ManifestPath
  $packageRecords = @(
    foreach ($path in $NupkgPath) {
      $resolvedPackagePath = Assert-CSharpPackageApprovalPathContained -ArtifactsPath $resolvedArtifactsPath -CandidatePath $path
      if (-not (Test-Path -LiteralPath $resolvedPackagePath -PathType Leaf)) {
        throw "Prepared package does not exist: '$resolvedPackagePath'."
      }
      $item = Get-Item -LiteralPath $resolvedPackagePath
      [pscustomobject][ordered]@{
        Name         = $item.Name
        RelativePath = [System.IO.Path]::GetRelativePath($resolvedArtifactsPath, $item.FullName).Replace('\', '/')
        Length       = $item.Length
        SHA256       = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
      }
    }
  ) | Sort-Object -Property Name

  if ($packageRecords.Count -eq 0) { throw 'At least one .nupkg is required to prepare publication.' }
  if (@($packageRecords.Name | Sort-Object -Unique).Count -ne $packageRecords.Count) {
    throw 'Prepared package names must be unique.'
  }

  $manifest = [pscustomobject][ordered]@{
    SchemaVersion      = '15.181.h.s2.prepared-v1'
    BuildMasterBuildId = $BuildMasterBuildId
    SourceCommit       = $SourceCommit
    PackageVersion     = $PackageVersion
    ArtifactsPath      = $resolvedArtifactsPath
    Packages           = $packageRecords
  }
  Write-CSharpPackageApprovalJsonOnce -InputObject $manifest -Path $resolvedManifestPath | Out-Null

  return [pscustomobject]@{
    ManifestPath           = $resolvedManifestPath
    PreparedManifestSha256 = Get-CSharpPackageApprovalFileSha256 -Path $resolvedManifestPath
    Manifest               = $manifest
  }
}

function Get-CSharpPackagePreparedManifestInspection {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param([Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$ManifestPath)

  $resolvedManifestPath = [System.IO.Path]::GetFullPath($ManifestPath)
  $manifest = Get-Content -LiteralPath $resolvedManifestPath -Raw | ConvertFrom-Json -Depth 20
  if ($manifest.SchemaVersion -cne '15.181.h.s2.prepared-v1') {
    throw "Unsupported prepared-manifest schema '$($manifest.SchemaVersion)'."
  }

  $resolvedArtifactsPath = [System.IO.Path]::GetFullPath([string]$manifest.ArtifactsPath)
  $packageResults = @(
    foreach ($package in $manifest.Packages) {
      $packagePath = Assert-CSharpPackageApprovalPathContained -ArtifactsPath $resolvedArtifactsPath -CandidatePath (Join-Path $resolvedArtifactsPath ([string]$package.RelativePath))
      if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
        throw "Prepared package is missing: '$packagePath'."
      }
      $actualHash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant()
      $actualLength = (Get-Item -LiteralPath $packagePath).Length
      if ($actualHash -cne [string]$package.SHA256 -or $actualLength -ne [long]$package.Length) {
        throw "Prepared package changed after inspection: '$packagePath'."
      }
      [pscustomobject]@{ Name = [string]$package.Name; Path = $packagePath; SHA256 = $actualHash; Length = $actualLength }
    }
  )

  return [pscustomobject]@{
    ManifestPath           = $resolvedManifestPath
    PreparedManifestSha256 = Get-CSharpPackageApprovalFileSha256 -Path $resolvedManifestPath
    Manifest               = $manifest
    Packages               = $packageResults
  }
}

function Approve-CSharpPackagePreparedManifest {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ManifestPath,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedPreparedManifestSha256,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApprovedBy,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApprovalPath
  )

  $inspection = Get-CSharpPackagePreparedManifestInspection -ManifestPath $ManifestPath
  $expectedSha = $ExpectedPreparedManifestSha256.ToLowerInvariant()
  if ($inspection.PreparedManifestSha256 -cne $expectedSha) {
    throw "Prepared-manifest SHA mismatch. Expected '$expectedSha'; actual '$($inspection.PreparedManifestSha256)'."
  }
  $resolvedApprovalPath = Assert-CSharpPackageApprovalPathContained -ArtifactsPath ([string]$inspection.Manifest.ArtifactsPath) -CandidatePath $ApprovalPath
  $approval = [pscustomobject][ordered]@{
    SchemaVersion          = '15.181.h.s2.approved-v1'
    PreparedManifestPath   = $inspection.ManifestPath
    PreparedManifestSha256 = $inspection.PreparedManifestSha256
    ApprovedBy             = $ApprovedBy
    ApprovedAtUtc          = [DateTime]::UtcNow.ToString('o')
  }
  Write-CSharpPackageApprovalJsonOnce -InputObject $approval -Path $resolvedApprovalPath | Out-Null

  return [pscustomobject]@{
    ApprovalPath   = $resolvedApprovalPath
    ApprovalSha256 = Get-CSharpPackageApprovalFileSha256 -Path $resolvedApprovalPath
    Approval       = $approval
  }
}

function Assert-CSharpPackagePublicationAuthorized {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ManifestPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApprovalPath
  )

  $inspection = Get-CSharpPackagePreparedManifestInspection -ManifestPath $ManifestPath
  if (-not (Test-Path -LiteralPath $ApprovalPath -PathType Leaf)) {
    throw "Publication is not authorized because approval record is missing: '$ApprovalPath'."
  }
  $approval = Get-Content -LiteralPath $ApprovalPath -Raw | ConvertFrom-Json -Depth 10
  if ($approval.SchemaVersion -cne '15.181.h.s2.approved-v1') {
    throw "Unsupported approval schema '$($approval.SchemaVersion)'."
  }
  if ([string]$approval.PreparedManifestSha256 -cne $inspection.PreparedManifestSha256) {
    throw "Publication is not authorized: approved SHA '$($approval.PreparedManifestSha256)' does not match prepared SHA '$($inspection.PreparedManifestSha256)'."
  }
  if ([System.IO.Path]::GetFullPath([string]$approval.PreparedManifestPath) -cne $inspection.ManifestPath) {
    throw 'Publication is not authorized: approval record names a different prepared manifest.'
  }

  return [pscustomobject]@{
    Authorized             = $true
    ApprovedBy             = [string]$approval.ApprovedBy
    PreparedManifestSha256 = $inspection.PreparedManifestSha256
    Packages               = $inspection.Packages
    Manifest               = $inspection.Manifest
  }
}
