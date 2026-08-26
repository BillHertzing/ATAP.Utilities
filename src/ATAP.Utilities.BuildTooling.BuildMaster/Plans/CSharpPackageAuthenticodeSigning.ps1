Set-StrictMode -Version Latest

function Get-CSharpPackageAuthenticodeContract {
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PackageName
  )

  $contracts = @{
    'ATAP.Utilities.ETW' = @('src/ATAP.Utilities.ETW/ATAP.Utilities.ETW.csproj', 'ATAP.Utilities.ETW', $false)
    'ATAP.Utilities.Plugin.Interfaces' = @('src/ATAP.Utilities.Plugin/Interfaces/ATAP.Utilities.Plugin.Interfaces.csproj', 'ATAP.Utilities.Plugin.Interfaces', $false)
    'ATAP.Utilities.Secrets.BitwardenSecretsManager' = @('src/ATAP.Utilities.Secrets/BitwardenSecretsManager/ATAP.Utilities.Secrets.BitwardenSecretsManager.csproj', 'ATAP.Utilities.Secrets.BitwardenSecretsManager', $false)
    'ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows' = @('src/ATAP.Utilities.Secrets/BitwardenSecretsManager/Windows/ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows.csproj', 'ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows', $true)
    'ATAP.Utilities.Secrets.Enumerations' = @('src/ATAP.Utilities.Secrets/Enumerations/ATAP.Utilities.Secrets.Enumerations.csproj', 'ATAP.Utilities.Secrets.Enumerations', $false)
    'ATAP.Utilities.Secrets.Interfaces' = @('src/ATAP.Utilities.Secrets/Interfaces/ATAP.Utilities.Secrets.Interfaces.csproj', 'ATAP.Utilities.Secrets.Interfaces', $false)
    'ATAP.Utilities.Secrets.Model' = @('src/ATAP.Utilities.Secrets/Model/ATAP.Utilities.Secrets.Model.csproj', 'ATAP.Utilities.Secrets.Model', $false)
    'ATAP.Utilities.Secrets.StringConstants' = @('src/ATAP.Utilities.Secrets/StringConstants/ATAP.Utilities.Secrets.StringConstants.csproj', 'ATAP.Utilities.Secrets.StringConstants', $false)
  }

  if (-not $contracts.ContainsKey($PackageName)) {
    return $null
  }

  $entry = $contracts[$PackageName]
  $windowsTarget = [bool]$entry[2]
  $assets = foreach ($version in 8, 9, 10) {
    [pscustomobject]@{
      BuildTargetFramework = if ($windowsTarget) { "net$version.0-windows" } else { "net$version.0" }
      PackageTargetFramework = if ($windowsTarget) { "net$version.0-windows7.0" } else { "net$version.0" }
    }
  }

  return [pscustomobject]@{
    PackageName = $PackageName
    ProjectPath = [string]$entry[0]
    AssemblyName = [string]$entry[1]
    Assets = @($assets)
  }
}

function Get-CSharpPackageAuthenticodeReleasePackageNames {
  [CmdletBinding()]
  [OutputType([string[]])]
  param()

  return @(
    'ATAP.Utilities.ETW'
    'ATAP.Utilities.Plugin.Interfaces'
    'ATAP.Utilities.Secrets.BitwardenSecretsManager'
    'ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows'
    'ATAP.Utilities.Secrets.Enumerations'
    'ATAP.Utilities.Secrets.Interfaces'
    'ATAP.Utilities.Secrets.Model'
    'ATAP.Utilities.Secrets.StringConstants'
  )
}

function Get-CSharpPackageAuthenticodeReleaseContract {
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param()

  $packages = @(Get-CSharpPackageAuthenticodeReleasePackageNames | ForEach-Object {
      Get-CSharpPackageAuthenticodeContract -PackageName $_
    })
  $assets = @($packages | ForEach-Object {
      $package = $_
      $_.Assets | ForEach-Object {
        [pscustomobject]@{
          PackageName = $package.PackageName
          ProjectPath = $package.ProjectPath
          AssemblyName = $package.AssemblyName
          BuildTargetFramework = $_.BuildTargetFramework
          PackageTargetFramework = $_.PackageTargetFramework
        }
      }
    })
  if ($packages.Count -ne 8 -or $assets.Count -ne 24) {
    throw "The F03 release contract must contain exactly eight packages and 24 shipping DLL assets; found $($packages.Count) packages and $($assets.Count) assets."
  }
  return [pscustomobject]@{ Packages = $packages; Assets = $assets }
}

function Invoke-CSharpPackageAuthenticodeProcess {
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$FilePath,
    [Parameter(Mandatory)][string[]]$ArgumentList
  )

  $startInfo = [Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $FilePath
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  foreach ($argument in $ArgumentList) {
    [void]$startInfo.ArgumentList.Add($argument)
  }

  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  try {
    if (-not $process.Start()) {
      throw "Failed to start external process '$FilePath'."
    }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    [void]$process.WaitForExitAsync().GetAwaiter().GetResult()
    return [pscustomobject]@{
      ExitCode = $process.ExitCode
      StandardOutput = $stdoutTask.GetAwaiter().GetResult()
      StandardError = $stderrTask.GetAwaiter().GetResult()
    }
  }
  finally {
    $process.Dispose()
  }
}

function Get-CSharpPackageAuthenticodeApproval {
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApprovalPath
  )

  if (-not (Test-Path -LiteralPath $ApprovalPath -PathType Leaf)) {
    throw "F03 private-key use is denied: approval record '$ApprovalPath' is missing."
  }
  $approval = Get-Content -LiteralPath $ApprovalPath -Raw -ErrorAction Stop | ConvertFrom-Json -Depth 20
  $expectedPackages = @(Get-CSharpPackageAuthenticodeReleasePackageNames | Sort-Object)
  $approvedPackages = @($approval.scope.packageIds | ForEach-Object { [string]$_ } | Sort-Object)
  $requiredText = @(
    [string]$approval.taskId,
    [string]$approval.decision,
    [string]$approval.approvedBy,
    [string]$approval.approvedAt,
    [string]$approval.publisher,
    [string]$approval.certificate.subject,
    [string]$approval.certificate.issuer,
    [string]$approval.certificate.notBefore,
    [string]$approval.certificate.notAfter,
    [string]$approval.certificate.sha1Thumbprint,
    [string]$approval.certificate.sha256Fingerprint,
    [string]$approval.certificate.rootSha1Thumbprint,
    [string]$approval.certificate.provider,
    [string]$approval.certificate.custodianPrincipal,
    [string]$approval.tool.productVersion,
    [string]$approval.tool.signToolSha256,
    [string]$approval.timestampAuthority.uri,
    [string]$approval.execution.computerName,
    [string]$approval.execution.identity
  )
  if ($requiredText | Where-Object { [string]::IsNullOrWhiteSpace($_) }) {
    throw 'F03 private-key use is denied: the approval record is missing required signer, custodian, tool, timestamp, executor, or approver data.'
  }
  if (
    [string]$approval.taskId -cne '15.182.F03' -or
    [string]$approval.decision -cne 'Approved' -or
    [string]$approval.publisher -cne 'ATAP Foundation' -or
    -not [bool]$approval.privateKeyUseApproved -or
    [int]$approval.scope.expectedPackageCount -ne 8 -or
    [int]$approval.scope.expectedAssetCount -ne 24 -or
    ($approvedPackages -join "`n") -cne ($expectedPackages -join "`n") -or
    [string]$approval.certificate.ekuOid -cne '1.3.6.1.5.5.7.3.3' -or
    [string]$approval.timestampAuthority.protocol -cne 'RFC3161' -or
    [bool]$approval.certificate.privateKeyExportAllowed
  ) {
    throw 'F03 private-key use is denied: the approval does not bind the exact ATAP Foundation eight-package/24-asset release slice.'
  }
  foreach ($hash in @(
      [string]$approval.certificate.sha1Thumbprint,
      [string]$approval.certificate.rootSha1Thumbprint
    )) {
    if ($hash -notmatch '^[0-9A-Fa-f]{40}$') { throw 'F03 approval contains an invalid SHA-1 certificate fingerprint.' }
  }
  foreach ($hash in @(
      [string]$approval.certificate.sha256Fingerprint,
      [string]$approval.tool.signToolSha256
    )) {
    if ($hash -notmatch '^[0-9A-Fa-f]{64}$') { throw 'F03 approval contains an invalid SHA-256 fingerprint.' }
  }
  if (-not [uri]::IsWellFormedUriString([string]$approval.timestampAuthority.uri, [UriKind]::Absolute)) {
    throw 'F03 approval contains an invalid RFC 3161 timestamp URI.'
  }
  $notBefore = [DateTimeOffset]::MinValue
  $notAfter = [DateTimeOffset]::MinValue
  if (-not [DateTimeOffset]::TryParse([string]$approval.certificate.notBefore, [ref]$notBefore) -or
    -not [DateTimeOffset]::TryParse([string]$approval.certificate.notAfter, [ref]$notAfter) -or
    $notAfter -le $notBefore) {
    throw 'F03 approval contains an invalid certificate validity interval.'
  }
  return $approval
}

function Assert-CSharpPackageAuthenticodeExecutionBoundary {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][pscustomobject]$Approval,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SignToolPath
  )

  $computerName = [Environment]::MachineName
  $identity = [Environment]::UserDomainName + '\' + [Environment]::UserName
  if ($computerName -cne [string]$Approval.execution.computerName -or
    $identity -cne [string]$Approval.execution.identity) {
    throw "F03 signing executor '$computerName/$identity' does not match the approved bounded execution identity."
  }
  if (-not (Test-Path -LiteralPath $SignToolPath -PathType Leaf) -or
    [IO.Path]::GetFileName($SignToolPath) -cne 'signtool.exe') {
    throw 'The supplied F03 signing tool is not an existing signtool.exe.'
  }
  $toolSha256 = (Get-FileHash -LiteralPath $SignToolPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
  if ($toolSha256 -cne ([string]$Approval.tool.signToolSha256).ToUpperInvariant()) {
    throw 'The supplied SignTool SHA-256 does not match the approved F03 tool.'
  }
  $productVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($SignToolPath).ProductVersion
  if ($productVersion -cne [string]$Approval.tool.productVersion) {
    throw "The supplied SignTool product version '$productVersion' does not match the approved F03 tool version."
  }
}

function Get-CSharpPackageAuthenticodeCertificate {
  [CmdletBinding()]
  [OutputType([Security.Cryptography.X509Certificates.X509Certificate2])]
  param(
    [Parameter(Mandatory)][pscustomobject]$Approval
  )

  $sha1 = ([string]$Approval.certificate.sha1Thumbprint).ToUpperInvariant()
  $certificate = Get-ChildItem -LiteralPath "Cert:\LocalMachine\My\$sha1" -ErrorAction Stop
  $ekuValues = @($certificate.Extensions |
      Where-Object { $_.Oid.Value -eq '2.5.29.37' } |
      ForEach-Object { $_.EnhancedKeyUsages | ForEach-Object Value })
  if (
    $certificate.Thumbprint.ToUpperInvariant() -cne $sha1 -or
    $certificate.GetCertHashString([Security.Cryptography.HashAlgorithmName]::SHA256).ToUpperInvariant() -cne ([string]$Approval.certificate.sha256Fingerprint).ToUpperInvariant() -or
    $certificate.Subject -cne [string]$Approval.certificate.subject -or
    $certificate.Issuer -cne [string]$Approval.certificate.issuer -or
    $certificate.NotBefore.ToUniversalTime() -ne ([DateTimeOffset]::Parse([string]$Approval.certificate.notBefore)).UtcDateTime -or
    $certificate.NotAfter.ToUniversalTime() -ne ([DateTimeOffset]::Parse([string]$Approval.certificate.notAfter)).UtcDateTime -or
    -not $certificate.HasPrivateKey -or
    $ekuValues -notcontains '1.3.6.1.5.5.7.3.3' -or
    [DateTime]::UtcNow -lt $certificate.NotBefore.ToUniversalTime() -or
    [DateTime]::UtcNow -gt $certificate.NotAfter.ToUniversalTime()
  ) {
    throw 'The machine-store certificate does not match the approved ATAP Foundation signing identity.'
  }

  $chain = [Security.Cryptography.X509Certificates.X509Chain]::new()
  try {
    $chain.ChainPolicy.RevocationMode = [Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
    $chain.ChainPolicy.VerificationFlags = [Security.Cryptography.X509Certificates.X509VerificationFlags]::NoFlag
    if (-not $chain.Build($certificate)) { throw 'The approved ATAP Foundation certificate chain did not build.' }
    $root = $chain.ChainElements[$chain.ChainElements.Count - 1].Certificate
    if ($root.Thumbprint.ToUpperInvariant() -cne ([string]$Approval.certificate.rootSha1Thumbprint).ToUpperInvariant()) {
      throw 'The approved ATAP Foundation root certificate did not terminate the chain.'
    }
  }
  finally {
    $chain.Dispose()
  }
  return $certificate
}

function Get-CSharpPackageAuthenticodeSignatureRecord {
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path)

  $signature = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
  return [pscustomobject]@{
    Status = [string]$signature.Status
    SignerSha1 = if ($null -ne $signature.SignerCertificate) { $signature.SignerCertificate.Thumbprint.ToUpperInvariant() } else { $null }
    SignerSha256 = if ($null -ne $signature.SignerCertificate) { $signature.SignerCertificate.GetCertHashString([Security.Cryptography.HashAlgorithmName]::SHA256).ToUpperInvariant() } else { $null }
    TimeStamperPresent = $null -ne $signature.TimeStamperCertificate
  }
}

function Assert-CSharpPackageAuthenticodeSignatureValid {
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$SignToolPath,
    [Parameter(Mandatory)][pscustomobject]$Approval
  )

  $verification = Invoke-CSharpPackageAuthenticodeProcess -FilePath $SignToolPath -ArgumentList @('verify', '/pa', '/all', '/v', $Path)
  if ($verification.ExitCode -ne 0) { throw "SignTool policy verification failed for '$Path'." }
  $signature = Get-CSharpPackageAuthenticodeSignatureRecord -Path $Path
  if (
    $signature.Status -cne 'Valid' -or
    $signature.SignerSha1 -cne ([string]$Approval.certificate.sha1Thumbprint).ToUpperInvariant() -or
    $signature.SignerSha256 -cne ([string]$Approval.certificate.sha256Fingerprint).ToUpperInvariant() -or
    -not $signature.TimeStamperPresent
  ) {
    throw "Authenticode signer or timestamp verification failed for '$Path'."
  }
  return $signature
}

function Resolve-CSharpPackageAuthenticodeTargetPath {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)][string]$DotNetPath,
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$TargetFramework,
    [Parameter(Mandatory)][string]$Configuration,
    [Parameter(Mandatory)][string]$ArtifactsPath
  )

  $result = Invoke-CSharpPackageAuthenticodeProcess -FilePath $DotNetPath -ArgumentList @(
    'msbuild', $ProjectPath, '-getProperty:TargetPath', "-p:TargetFramework=$TargetFramework",
    "-p:Configuration=$Configuration", "-p:ArtifactsPath=$ArtifactsPath"
  )
  if ($result.ExitCode -ne 0) { throw "Could not resolve TargetPath for '$ProjectPath' / '$TargetFramework'." }
  $candidate = @($result.StandardOutput -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })[-1].Trim()
  if (-not [IO.Path]::IsPathRooted($candidate) -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
    throw "Resolved TargetPath '$candidate' for '$TargetFramework' is missing or not absolute."
  }
  return [IO.Path]::GetFullPath($candidate)
}

function Invoke-CSharpPackageAuthenticodeStageSigning {
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory)][pscustomobject]$Contract,
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$Configuration,
    [Parameter(Mandatory)][string]$ArtifactsPath,
    [Parameter(Mandatory)][string]$ApprovalPath,
    [Parameter(Mandatory)][string]$SignToolPath,
    [Parameter(Mandatory)][string]$EvidencePath
  )

  $approval = Get-CSharpPackageAuthenticodeApproval -ApprovalPath $ApprovalPath
  Assert-CSharpPackageAuthenticodeExecutionBoundary -Approval $approval -SignToolPath $SignToolPath
  $expectedProject = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))) $Contract.ProjectPath))
  if ([IO.Path]::GetFullPath($ProjectPath) -cne $expectedProject) {
    throw "Package '$($Contract.PackageName)' is bound to '$expectedProject', not '$ProjectPath'."
  }
  if (-not $PSCmdlet.ShouldProcess($Contract.PackageName, 'Authenticode-sign the exact three staged shipping DLLs')) {
    return [pscustomobject]@{ Outcome = 'WhatIf'; PackageName = $Contract.PackageName }
  }

  [void](Get-CSharpPackageAuthenticodeCertificate -Approval $approval)
  $dotnetPath = (Get-Command dotnet -ErrorAction Stop).Source
  $records = foreach ($asset in $Contract.Assets) {
    $targetPath = Resolve-CSharpPackageAuthenticodeTargetPath -DotNetPath $dotnetPath -ProjectPath $ProjectPath `
      -TargetFramework $asset.BuildTargetFramework -Configuration $Configuration -ArtifactsPath $ArtifactsPath
    if ([IO.Path]::GetFileName($targetPath) -cne "$($Contract.AssemblyName).dll") {
      throw "Resolved signing target '$targetPath' is not the exact package assembly."
    }
    $before = Get-CSharpPackageAuthenticodeSignatureRecord -Path $targetPath
    if ($before.Status -cne 'NotSigned') { throw "Signing target '$targetPath' was not an unsigned deterministic build output." }
    $sign = Invoke-CSharpPackageAuthenticodeProcess -FilePath $SignToolPath -ArgumentList @(
      'sign', '/sm', '/sha1', ([string]$approval.certificate.sha1Thumbprint), '/fd', 'SHA256',
      '/tr', ([string]$approval.timestampAuthority.uri), '/td', 'SHA256', '/v', $targetPath
    )
    if ($sign.ExitCode -ne 0) { throw "SignTool signing failed for '$targetPath'." }
    $signature = Assert-CSharpPackageAuthenticodeSignatureValid -Path $targetPath -SignToolPath $SignToolPath -Approval $approval
    [pscustomobject]@{
      BuildTargetFramework = $asset.BuildTargetFramework
      PackageTargetFramework = $asset.PackageTargetFramework
      Path = $targetPath
      Sha256 = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash.ToLowerInvariant()
      Bytes = (Get-Item -LiteralPath $targetPath).Length
      Status = $signature.Status
      SignerSha1 = $signature.SignerSha1
      SignerSha256 = $signature.SignerSha256
      TimestampPresent = $signature.TimeStamperPresent
    }
  }
  if (@($records).Count -ne 3) { throw 'F03 must sign exactly three staged DLL assets per package.' }
  New-Item -ItemType Directory -Path $EvidencePath -Force | Out-Null
  $recordPath = Join-Path $EvidencePath "$($Contract.PackageName).signed-staging.json"
  [ordered]@{
    schemaVersion = '1.0.0'
    taskId = '15.182.F03'
    packageName = $Contract.PackageName
    approvalSha256 = (Get-FileHash -LiteralPath $ApprovalPath -Algorithm SHA256).Hash.ToLowerInvariant()
    assets = @($records)
  } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $recordPath -Encoding utf8NoBOM
  return [pscustomobject]@{ Approval = $approval; Contract = $Contract; Assets = @($records); EvidencePath = $recordPath }
}

function Assert-CSharpPackageAuthenticodeNupkg {
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory)][string]$NupkgPath,
    [Parameter(Mandatory)][pscustomobject]$SigningResult,
    [Parameter(Mandatory)][string]$SignToolPath,
    [Parameter(Mandatory)][string]$ScratchRoot
  )

  $extractPath = Join-Path $ScratchRoot ([guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
  try {
    [IO.Compression.ZipFile]::ExtractToDirectory($NupkgPath, $extractPath)
    $allPackageDlls = @(Get-ChildItem -LiteralPath $extractPath -Filter '*.dll' -File -Recurse)
    $expectedRelativePaths = @($SigningResult.Assets | ForEach-Object {
        "lib/$($_.PackageTargetFramework)/$($SigningResult.Contract.AssemblyName).dll"
      } | Sort-Object)
    $expected = foreach ($asset in $SigningResult.Assets) {
      $relativePath = "lib/$($asset.PackageTargetFramework)/$($SigningResult.Contract.AssemblyName).dll"
      $path = Join-Path $extractPath ($relativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
      if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Signed package asset '$relativePath' is missing." }
      if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $asset.Sha256) {
        throw "Signed package asset '$relativePath' differs from the already-signed staging tree."
      }
      $signature = Assert-CSharpPackageAuthenticodeSignatureValid -Path $path -SignToolPath $SignToolPath -Approval $SigningResult.Approval
      [pscustomobject]@{ RelativePath = $relativePath; Sha256 = $asset.Sha256; Status = $signature.Status; TimestampPresent = $signature.TimeStamperPresent }
    }
    if ($allPackageDlls.Count -ne 3) {
      throw "Package '$NupkgPath' contains $($allPackageDlls.Count) DLL assets; F03 permits exactly the three first-party shipping DLLs and no vendor binaries."
    }
    $actualRelativePaths = @($allPackageDlls | ForEach-Object {
        [IO.Path]::GetRelativePath($extractPath, $_.FullName).Replace('\', '/')
      } | Sort-Object)
    if (($actualRelativePaths -join "`n") -cne ($expectedRelativePaths -join "`n")) {
      throw "Package '$NupkgPath' contains a vendor or unexpected DLL; F03 permits only the exact three first-party lib/ TFM assets."
    }
    return [pscustomobject]@{ PackagePath = $NupkgPath; PackageSha256 = (Get-FileHash -LiteralPath $NupkgPath -Algorithm SHA256).Hash.ToLowerInvariant(); Assets = @($expected) }
  }
  finally {
    if (Test-Path -LiteralPath $extractPath) { Remove-Item -LiteralPath $extractPath -Recurse -Force }
  }
}

function Test-CSharpPackageAuthenticodeTamperNegative {
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$SignToolPath,
    [Parameter(Mandatory)][string]$ScratchRoot
  )

  $tamperPath = Join-Path $ScratchRoot ('tamper-' + [guid]::NewGuid().ToString('N') + '.dll')
  Copy-Item -LiteralPath $SourcePath -Destination $tamperPath
  try {
    $originalSha256 = (Get-FileHash -LiteralPath $tamperPath -Algorithm SHA256).Hash
    $bytes = [IO.File]::ReadAllBytes($tamperPath)
    if ($bytes.Length -lt 2) { throw 'The selected F03 tamper-negative target is unexpectedly empty.' }
    $index = [Math]::Floor($bytes.Length / 2)
    $bytes[$index] = $bytes[$index] -bxor 1
    [IO.File]::WriteAllBytes($tamperPath, $bytes)
    $tamperedSha256 = (Get-FileHash -LiteralPath $tamperPath -Algorithm SHA256).Hash
    $toolResult = Invoke-CSharpPackageAuthenticodeProcess -FilePath $SignToolPath -ArgumentList @('verify', '/pa', '/all', '/v', $tamperPath)
    $signature = Get-CSharpPackageAuthenticodeSignatureRecord -Path $tamperPath
    if ($originalSha256 -ceq $tamperedSha256 -or $toolResult.ExitCode -eq 0 -or $signature.Status -ceq 'Valid') {
      throw 'The F03 one-byte tamper negative was not rejected by both verification surfaces.'
    }
    return [pscustomobject]@{ OriginalSha256 = $originalSha256; TamperedSha256 = $tamperedSha256; SignToolRejected = $true; AuthenticodeRejected = $true }
  }
  finally {
    if (Test-Path -LiteralPath $tamperPath) { Remove-Item -LiteralPath $tamperPath -Force }
  }
}
