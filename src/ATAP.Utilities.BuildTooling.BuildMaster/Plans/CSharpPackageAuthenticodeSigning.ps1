Set-StrictMode -Version Latest

function Get-CSharpPackageAuthenticodeContractRows {
  [CmdletBinding()]
  [OutputType([string[]])]
  param()

  return @(
    'ATAP.Utilities.Collection.Extensions|src/ATAP.Utilities.Collection.Extensions/ATAP.Utilities.Collection.Extensions.csproj|ATAP.Utilities.Collection.Extensions|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Configuration|src/ATAP.Utilities.Configuration/ATAP.Utilities.Configuration.csproj|ATAP.Utilities.Configuration|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Configuration.Extensions|src/ATAP.Utilities.Configuration/Extensions/ATAP.Utilities.Configuration.Extensions.csproj|ATAP.Utilities.Configuration.Extensions|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Configuration.Secrets|src/ATAP.Utilities.Configuration/Secrets/ATAP.Utilities.Configuration.Secrets.csproj|ATAP.Utilities.Configuration.Secrets|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Configuration.Secrets.Shims|src/ATAP.Utilities.Configuration/Secrets/Shims/ATAP.Utilities.Configuration.Secrets.Shims.csproj|ATAP.Utilities.Configuration.Secrets.Shims|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Configuration.Secrets.Shims.Interfaces|src/ATAP.Utilities.Configuration/Secrets/Shims/Interfaces/ATAP.Utilities.Configuration.Secrets.Shims.Interfaces.csproj|ATAP.Utilities.Configuration.Secrets.Shims.Interfaces|net8.0;net9.0;net10.0'
    'ATAP.Utilities.DatabaseManagement|src/ATAP.Utilities.DatabaseManagement/ATAP.Utilities.DatabaseManagement.csproj|ATAP.Utilities.DatabaseManagement|net8.0;net9.0;net10.0'
    'ATAP.Utilities.DateTime|src/ATAP.Utilities.DateTime/ATAP.Utilities.DateTime.csproj|ATAP.Utilities.DateTime|net8.0;net9.0;net10.0'
    'ATAP.Utilities.ETW|src/ATAP.Utilities.ETW/ATAP.Utilities.ETW.csproj|ATAP.Utilities.ETW|net8.0;net9.0;net10.0'
    'ATAP.Utilities.FileIO|src/ATAP.Utilities.FIleIO/ATAP.Utilities.FileIO.csproj|ATAP.Utilities.FileIO|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Loader|src/ATAP.Utilities.Loader/ATAP.Utilities.Loader.csproj|ATAP.Utilities.Loader|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Loader.Interfaces|src/ATAP.Utilities.Loader/Interfaces/ATAP.Utilities.Loader.Interfaces.csproj|ATAP.Utilities.Loader.Interfaces|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Loader.Model|src/ATAP.Utilities.Loader/Model/ATAP.Utilities.Loader.Model.csproj|ATAP.Utilities.Loader.Model|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Loader.StringConstants|src/ATAP.Utilities.Loader/StringConstants/ATAP.Utilities.Loader.StringConstants.csproj|ATAP.Utilities.Loader.StringConstants|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Logging|src/ATAP.Utilities.Logging/ATAP.Utilities.Logging.csproj|ATAP.Utilities.Logging|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Philote|src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.csproj|ATAP.Utilities.Philote|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Philote.DefaultConfiguration|src/ATAP.Utilities.Philote/DefaultConfiguration/ATAP.Utilities.Philote.DefaultConfiguration.csproj|ATAP.Utilities.Philote.DefaultConfiguration|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Philote.Interfaces|src/ATAP.Utilities.Philote/Interfaces/ATAP.Utilities.Philote.Interfaces.csproj|ATAP.Utilities.Philote.Interfaces|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson|src/ATAP.Utilities.Philote/JsonConverter.Shim.SystemTextJson/ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson.csproj|ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Philote.Models|src/ATAP.Utilities.Philote/Models/ATAP.Utilities.Philote.Models.csproj|ATAP.Utilities.Philote.Models|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Plugin.Interfaces|src/ATAP.Utilities.Plugin/Interfaces/ATAP.Utilities.Plugin.Interfaces.csproj|ATAP.Utilities.Plugin.Interfaces|net8.0;net9.0;net10.0'
    'ATAP.Utilities.RRSBS.Contracts|src/ATAP.Utilities.RRSBS.Contracts/ATAP.Utilities.RRSBS.Contracts.csproj|ATAP.Utilities.RRSBS.Contracts|net10.0'
    'ATAP.Utilities.RRSBS.Domain|src/ATAP.Utilities.RRSBS.Domain/ATAP.Utilities.RRSBS.Domain.csproj|ATAP.Utilities.RRSBS.Domain|net10.0'
    'ATAP.Utilities.Secrets|src/ATAP.Utilities.Secrets/ATAP.Utilities.Secrets.csproj|ATAP.Utilities.Secrets|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Secrets.BitwardenSecretsManager|src/ATAP.Utilities.Secrets/BitwardenSecretsManager/ATAP.Utilities.Secrets.BitwardenSecretsManager.csproj|ATAP.Utilities.Secrets.BitwardenSecretsManager|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows|src/ATAP.Utilities.Secrets/BitwardenSecretsManager/Windows/ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows.csproj|ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows|net8.0-windows;net9.0-windows;net10.0-windows'
    'ATAP.Utilities.Secrets.Enumerations|src/ATAP.Utilities.Secrets/Enumerations/ATAP.Utilities.Secrets.Enumerations.csproj|ATAP.Utilities.Secrets.Enumerations|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Secrets.Interfaces|src/ATAP.Utilities.Secrets/Interfaces/ATAP.Utilities.Secrets.Interfaces.csproj|ATAP.Utilities.Secrets.Interfaces|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Secrets.Model|src/ATAP.Utilities.Secrets/Model/ATAP.Utilities.Secrets.Model.csproj|ATAP.Utilities.Secrets.Model|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Secrets.StringConstants|src/ATAP.Utilities.Secrets/StringConstants/ATAP.Utilities.Secrets.StringConstants.csproj|ATAP.Utilities.Secrets.StringConstants|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Serializer|src/ATAP.Utilities.Serializer/ATAP.Utilities.Serializer.csproj|ATAP.Utilities.Serializer|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Serializer.Interfaces|src/ATAP.Utilities.Serializer/Interfaces/ATAP.Utilities.Serializer.Interfaces.csproj|ATAP.Utilities.Serializer.Interfaces|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Serializer.Model|src/ATAP.Utilities.Serializer/Model/ATAP.Utilities.Serializer.Model.csproj|ATAP.Utilities.Serializer.Model|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Serializer.Shim|src/ATAP.Utilities.Serializer/Shim/ATAP.Utilities.Serializer.Shim.csproj|ATAP.Utilities.Serializer.Shim|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Serializer.Shim.Newtonsoft|src/ATAP.Utilities.Serializer/Shim/Newtonsoft/ATAP.Utilities.Serializer.Shim.Newtonsoft.csproj|ATAP.Utilities.Serializer.Shim.Newtonsoft|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Serializer.Shim.SystemTextJson|src/ATAP.Utilities.Serializer/Shim/SystemTextJson/ATAP.Utilities.Serializer.Shim.SystemTextJson.csproj|ATAP.Utilities.Serializer.Shim.SystemTextJson|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Serializer.StringConstants|src/ATAP.Utilities.Serializer/StringConstants/ATAP.Utilities.Serializer.StringConstants.csproj|ATAP.Utilities.Serializer.StringConstants|net8.0;net9.0;net10.0'
    'ATAP.Utilities.StronglyTypedId.Interfaces|src/ATAP.Utilities.StronglyTypedId/Interfaces/ATAP.Utilities.StronglyTypedId.Interfaces.csproj|ATAP.Utilities.StronglyTypedId.Interfaces|net8.0;net9.0;net10.0'
    'ATAP.Utilities.StronglyTypedId.Models|src/ATAP.Utilities.StronglyTypedId/Models/ATAP.Utilities.StronglyTypedId.Models.csproj|ATAP.Utilities.StronglyTypedId.Models|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Testing|src/ATAP.Utilities.Testing/ATAP.Utilities.Testing.csproj|ATAP.Utilities.Testing|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Testing.Fixture.Serialization|src/ATAP.Utilities.Testing.Fixture.Serialization/ATAP.Utilities.Testing.Fixture.Serialization.csproj|ATAP.Utilities.Testing.Fixture.Serialization|net8.0;net9.0;net10.0'
    'ATAP.Utilities.Testing.Fixture.Serialization.Shim.SystemTextJson|src/ATAP.Utilities.Testing.Fixture.Serialization.Shim.SystemTextJson/ATAP.Utilities.Testing.Fixture.Serialization.Shim.SystemTextJson.csproj|ATAP.Utilities.Testing.Fixture.Serialization.Shim.SystemTextJson|net8.0;net9.0;net10.0'
  )
}

function Get-CSharpPackageAuthenticodeContract {
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageName)

  $row = @(Get-CSharpPackageAuthenticodeContractRows | Where-Object { ($_ -split '\|', 2)[0] -ceq $PackageName })
  if ($row.Count -ne 1) { return $null }
  $parts = $row[0] -split '\|', 4
  $assets = foreach ($targetFramework in @($parts[3] -split ';')) {
    [pscustomobject]@{
      BuildTargetFramework = $targetFramework
      PackageTargetFramework = if ($targetFramework.EndsWith('-windows', [StringComparison]::Ordinal)) { "${targetFramework}7.0" } else { $targetFramework }
    }
  }
  return [pscustomobject]@{ PackageName = $parts[0]; ProjectPath = $parts[1]; AssemblyName = $parts[2]; Assets = @($assets) }
}

function Get-CSharpPackageAuthenticodeReleasePackageNames {
  [CmdletBinding()]
  [OutputType([string[]])]
  param()
  return @(Get-CSharpPackageAuthenticodeContractRows | ForEach-Object { ($_ -split '\|', 2)[0] })
}

function Get-CSharpPackageAuthenticodeHistoricalF03PackageNames {
  [CmdletBinding()]
  [OutputType([string[]])]
  param()
  return @('ATAP.Utilities.ETW', 'ATAP.Utilities.Plugin.Interfaces', 'ATAP.Utilities.Secrets.BitwardenSecretsManager', 'ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows', 'ATAP.Utilities.Secrets.Enumerations', 'ATAP.Utilities.Secrets.Interfaces', 'ATAP.Utilities.Secrets.Model', 'ATAP.Utilities.Secrets.StringConstants')
}

function Get-CSharpPackageAuthenticodeReleaseContract {
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param()
  $packages = @(Get-CSharpPackageAuthenticodeReleasePackageNames | ForEach-Object { Get-CSharpPackageAuthenticodeContract -PackageName $_ })
  $assets = @($packages | ForEach-Object { $package = $_; $_.Assets | ForEach-Object { [pscustomobject]@{ PackageName = $package.PackageName; ProjectPath = $package.ProjectPath; AssemblyName = $package.AssemblyName; BuildTargetFramework = $_.BuildTargetFramework; PackageTargetFramework = $_.PackageTargetFramework } } })
  if ($packages.Count -ne 42 -or $assets.Count -ne 122) { throw "The current release contract must contain exactly 42 packages and 122 shipping DLL assets; found $($packages.Count) packages and $($assets.Count) assets." }
  return [pscustomobject]@{ Packages = $packages; Assets = $assets }
}

function Get-CSharpPackageAuthenticodeReleaseAssetIds {
  [CmdletBinding()]
  [OutputType([string[]])]
  param()
  return @((Get-CSharpPackageAuthenticodeReleaseContract).Assets | ForEach-Object { "$($_.PackageName)|$($_.ProjectPath)|$($_.AssemblyName)|$($_.BuildTargetFramework)|$($_.PackageTargetFramework)" } | Sort-Object)
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
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApprovalPath,
    [AllowEmptyString()][string]$PackageName = ''
  )

  if (-not (Test-Path -LiteralPath $ApprovalPath -PathType Leaf)) { throw "Authenticode private-key use is denied: approval record '$ApprovalPath' is missing." }
  $approval = Get-Content -LiteralPath $ApprovalPath -Raw -ErrorAction Stop | ConvertFrom-Json -Depth 20
  $taskId = [string]$approval.taskId
  $expectedPackages = @()
  $expectedAssetIds = @()
  $expectedPackageCount = 0
  $expectedAssetCount = 0
  $scopeName = ''
  switch ($taskId) {
    'triple-stream-csharp-signing-contract-42' {
      $expectedPackages = @(Get-CSharpPackageAuthenticodeReleasePackageNames | Sort-Object)
      $expectedAssetIds = @(Get-CSharpPackageAuthenticodeReleaseAssetIds)
      $expectedPackageCount = 42
      $expectedAssetCount = 122
      $scopeName = 'current 42-package/122-asset filter release slice'
    }
    '15.182.F03' {
      $expectedPackages = @(Get-CSharpPackageAuthenticodeHistoricalF03PackageNames | Sort-Object)
      $expectedPackageCount = 8
      $expectedAssetCount = 24
      $scopeName = 'eight-package/24-asset release slice'
    }
    default { throw "Authenticode private-key use is denied: approval task '$taskId' is not supported." }
  }
  $approvedPackages = @($approval.scope.packageIds | ForEach-Object { [string]$_ } | Sort-Object)
  $approvedAssetIds = if ($null -ne $approval.scope.PSObject.Properties['assetIds']) { @($approval.scope.assetIds | ForEach-Object { [string]$_ } | Sort-Object) } else { @() }
  $requiredText = @([string]$approval.decision, [string]$approval.approvedBy, [string]$approval.approvedAt, [string]$approval.publisher, [string]$approval.certificate.subject, [string]$approval.certificate.issuer, [string]$approval.certificate.notBefore, [string]$approval.certificate.notAfter, [string]$approval.certificate.sha1Thumbprint, [string]$approval.certificate.sha256Fingerprint, [string]$approval.certificate.rootSha1Thumbprint, [string]$approval.certificate.provider, [string]$approval.certificate.custodianPrincipal, [string]$approval.tool.productVersion, [string]$approval.tool.signToolSha256, [string]$approval.timestampAuthority.uri, [string]$approval.execution.computerName, [string]$approval.execution.identity)
  if ($requiredText | Where-Object { [string]::IsNullOrWhiteSpace($_) }) { throw 'Authenticode private-key use is denied: the approval record is missing required signer, custodian, tool, timestamp, executor, or approver data.' }
  $assetScopeMatches = $taskId -ceq '15.182.F03' -or (($approvedAssetIds -join "`n") -ceq ($expectedAssetIds -join "`n"))
  if ([string]$approval.decision -cne 'Approved' -or [string]$approval.publisher -cne 'ATAP Foundation' -or -not [bool]$approval.privateKeyUseApproved -or [int]$approval.scope.expectedPackageCount -ne $expectedPackageCount -or [int]$approval.scope.expectedAssetCount -ne $expectedAssetCount -or ($approvedPackages -join "`n") -cne ($expectedPackages -join "`n") -or -not $assetScopeMatches -or [string]$approval.certificate.ekuOid -cne '1.3.6.1.5.5.7.3.3' -or [string]$approval.timestampAuthority.protocol -cne 'RFC3161' -or [bool]$approval.certificate.privateKeyExportAllowed) { throw "Authenticode private-key use is denied: the approval does not bind the exact ATAP Foundation $scopeName." }
  if (-not [string]::IsNullOrWhiteSpace($PackageName) -and $approvedPackages -cnotcontains $PackageName) { throw "Authenticode private-key use is denied: package '$PackageName' is outside approval task '$taskId'." }
  foreach ($hash in @([string]$approval.certificate.sha1Thumbprint, [string]$approval.certificate.rootSha1Thumbprint)) { if ($hash -notmatch '^[0-9A-Fa-f]{40}$') { throw 'Authenticode approval contains an invalid SHA-1 certificate fingerprint.' } }
  foreach ($hash in @([string]$approval.certificate.sha256Fingerprint, [string]$approval.tool.signToolSha256)) { if ($hash -notmatch '^[0-9A-Fa-f]{64}$') { throw 'Authenticode approval contains an invalid SHA-256 fingerprint.' } }
  if (-not [uri]::IsWellFormedUriString([string]$approval.timestampAuthority.uri, [UriKind]::Absolute)) { throw 'Authenticode approval contains an invalid RFC 3161 timestamp URI.' }
  $notBefore = [DateTimeOffset]::MinValue; $notAfter = [DateTimeOffset]::MinValue
  if (-not [DateTimeOffset]::TryParse([string]$approval.certificate.notBefore, [ref]$notBefore) -or -not [DateTimeOffset]::TryParse([string]$approval.certificate.notAfter, [ref]$notAfter) -or $notAfter -le $notBefore) { throw 'Authenticode approval contains an invalid certificate validity interval.' }
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

  $approval = Get-CSharpPackageAuthenticodeApproval -ApprovalPath $ApprovalPath -PackageName $Contract.PackageName
  Assert-CSharpPackageAuthenticodeExecutionBoundary -Approval $approval -SignToolPath $SignToolPath
  $expectedProject = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))) $Contract.ProjectPath))
  if ([IO.Path]::GetFullPath($ProjectPath) -cne $expectedProject) {
    throw "Package '$($Contract.PackageName)' is bound to '$expectedProject', not '$ProjectPath'."
  }
  if (-not $PSCmdlet.ShouldProcess($Contract.PackageName, 'Authenticode-sign the exact contract-bound staged shipping DLL assets')) {
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
  if (@($records).Count -ne $Contract.Assets.Count) { throw "Authenticode signing must cover exactly $($Contract.Assets.Count) staged DLL asset(s) for '$($Contract.PackageName)'." }
  New-Item -ItemType Directory -Path $EvidencePath -Force | Out-Null
  $recordPath = Join-Path $EvidencePath "$($Contract.PackageName).signed-staging.json"
  [ordered]@{
    schemaVersion = '1.0.0'
    taskId = [string]$approval.taskId
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
    if ($allPackageDlls.Count -ne $expectedRelativePaths.Count) {
      throw "Package '$NupkgPath' contains $($allPackageDlls.Count) DLL assets; The contract permits exactly $($expectedRelativePaths.Count) first-party shipping DLL asset(s) and no vendor binaries."
    }
    $actualRelativePaths = @($allPackageDlls | ForEach-Object {
        [IO.Path]::GetRelativePath($extractPath, $_.FullName).Replace('\', '/')
      } | Sort-Object)
    if (($actualRelativePaths -join "`n") -cne ($expectedRelativePaths -join "`n")) {
      throw "Package '$NupkgPath' contains a vendor or unexpected DLL; The contract permits only its exact first-party lib/ TFM assets."
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
    if ($bytes.Length -lt 2) { throw 'The selected Authenticode tamper-negative target is unexpectedly empty.' }
    $index = [Math]::Floor($bytes.Length / 2)
    $bytes[$index] = $bytes[$index] -bxor 1
    [IO.File]::WriteAllBytes($tamperPath, $bytes)
    $tamperedSha256 = (Get-FileHash -LiteralPath $tamperPath -Algorithm SHA256).Hash
    $toolResult = Invoke-CSharpPackageAuthenticodeProcess -FilePath $SignToolPath -ArgumentList @('verify', '/pa', '/all', '/v', $tamperPath)
    $signature = Get-CSharpPackageAuthenticodeSignatureRecord -Path $tamperPath
    if ($originalSha256 -ceq $tamperedSha256 -or $toolResult.ExitCode -eq 0 -or $signature.Status -ceq 'Valid') {
      throw 'The Authenticode one-byte tamper negative was not rejected by both verification surfaces.'
    }
    return [pscustomobject]@{ OriginalSha256 = $originalSha256; TamperedSha256 = $tamperedSha256; SignToolRejected = $true; AuthenticodeRejected = $true }
  }
  finally {
    if (Test-Path -LiteralPath $tamperPath) { Remove-Item -LiteralPath $tamperPath -Force }
  }
}
