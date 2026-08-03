function Assert-ProGetPowerShellPackageSignature {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Name,
    [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Version,
    [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Feed,
    [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $ProGetBaseUrl,
    [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $ProGetApiKeySecretName,
    [string] $EvidenceRoot
  )
  begin { $fn = 'Assert-ProGetPowerShellPackageSignature'; $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell' }
  process {
    $parsedBaseUrl = [uri]$ProGetBaseUrl
    if (-not $parsedBaseUrl.IsAbsoluteUri -or $parsedBaseUrl.Scheme -ne 'https') {
      throw 'ProGetBaseUrl must be an absolute HTTPS URI. Cleartext package retrieval is not allowed.'
    }
    if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
      $repoRoot = if (Get-Command Get-RepositoryRoot -ErrorAction SilentlyContinue) {
        Get-RepositoryRoot
      } else {
        (Get-Location).Path
      }
      $EvidenceRoot = Join-Path $repoRoot '_generated\promotion-signature-verification'
    }
    New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null

    $apiKey = [string](Get-SecretATAP -SecretName $ProGetApiKeySecretName `
      -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop)
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
      throw "The ProGet secret named '$ProGetApiKeySecretName' resolved to an empty value."
    }

    $packageUri = '{0}/nuget/{1}/package/{2}/{3}' -f `
      $ProGetBaseUrl.TrimEnd('/'), $Feed, [uri]::EscapeDataString($Name), [uri]::EscapeDataString($Version)
    $packagePath = Join-Path $EvidenceRoot ("{0}.{1}.{2}.nupkg" -f $Name, $Version, [guid]::NewGuid().ToString('N'))
    try {
      Invoke-WebRequest -Uri $packageUri -Headers @{ 'X-ApiKey' = $apiKey; Accept = 'application/zip' } `
        -OutFile $packagePath -UseBasicParsing -ErrorAction Stop | Out-Null
      Test-PSModulePackageSignature -NupkgPath $packagePath `
        -ResultsPath (Join-Path $EvidenceRoot 'reports') -RequireTimestamp -ErrorAction Stop
    } finally {
      if (Test-Path -LiteralPath $packagePath) {
        Remove-Item -LiteralPath $packagePath -Force -ErrorAction SilentlyContinue
      }
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Verified signed package '$Name' '$Version' in '$Feed'." -Tag 'Trace'
  }
}
