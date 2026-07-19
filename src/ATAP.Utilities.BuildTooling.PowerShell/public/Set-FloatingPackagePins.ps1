#Requires -Version 7.0

function Set-FloatingPackagePins {
  <#
.SYNOPSIS
    Pins floating package versions in a Directory.Packages.props file to the
    highest concrete version available in a ProGet NuGet feed.

.DESCRIPTION
    Reads a Central Package Management `Directory.Packages.props`, finds every
    `<PackageVersion>` element whose Include attribute starts with the configured
    package-id prefix and whose Version attribute contains a wildcard ('*'),
    queries the specified ProGet NuGet v3 flatcontainer endpoint for the highest
    available version of each package, and rewrites `Directory.Packages.props`
    with the concrete (pinned) versions.

    Rule: floating version ranges (for example `0.*-*`) are permitted only at the
    Experimental and Development tiers. At Integration, QA, and Stable/Production,
    every matched package in `Directory.Packages.props` must be pinned to a
    concrete version before `dotnet restore`/`build` is called. This cmdlet
    enforces that rule for the CI agent workspace copy of
    `Directory.Packages.props`; the working-copy file in git retains its floating
    patterns.

    This is the generic, repository-agnostic engine that lives in BuildTooling.
    Consumers (such as AceCommander) supply their own defaults — the package-id
    prefix, target feed, and props path — and delegate here. See
    CSharp-Central-Package-Management.md §6.1 and
    Package-Pinning-Ownership-Decision.md for the full policy and the ownership
    rationale.

.PARAMETER PackagePropsPath
    Path to `Directory.Packages.props`. Defaults to `Directory.Packages.props`
    in the current working directory.

.PARAMETER ProGetUrl
    Base URL of the ProGet instance, e.g. "http://proget.local:50000".
    Must not have a trailing slash.

.PARAMETER FeedName
    NuGet feed to query for the highest available version of each package.
    Defaults to 'nuget-qa' (the QA tier feed).

.PARAMETER PackageIdPrefix
    Only `<PackageVersion>` entries whose Include attribute starts with this
    prefix are considered for pinning. Defaults to 'ATAP.' so that, by default,
    only the internal ATAP.Utilities package family is pinned and third-party
    packages are left untouched.

.PARAMETER ProGetApiKeySecretName
    Bitwarden Secrets Manager SecretName for the ProGet read key. Raw API-key
    values and environment-variable fallbacks are unsupported.

.OUTPUTS
    [pscustomobject] with properties:
        PackagePropsPath — absolute path that was rewritten
        PackageIdPrefix  — prefix used to select packages
        PackagesPinned   — ordered hashtable of { packageId → pinnedVersion }
        PackagesSkipped  — list of packageIds for which no version was found in the feed

.EXAMPLE
    Set-FloatingPackagePins -ProGetUrl 'http://proget.local:50000'

.EXAMPLE
    Set-FloatingPackagePins `
        -PackagePropsPath 'C:\src\AceCommander\Directory.Packages.props' `
        -ProGetUrl 'http://proget.local:50000' `
        -FeedName 'nuget-integration' `
        -PackageIdPrefix 'ATAP.' `
        -ProGetApiKeySecretName 'ProGet.BuildMaster.API.Key'

.LINK
    https://github.com/ATAPUtilities/ATAP.Utilities

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PackagePropsPath = 'Directory.Packages.props',

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ProGetUrl,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$FeedName = 'nuget-qa',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PackageIdPrefix = 'ATAP.',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ProGetApiKeySecretName = 'ProGet.BuildMaster.API.Key'
  )

  begin {
    $fn = 'Set-FloatingPackagePins'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    Set-StrictMode -Version Latest

    # Normalize the ProGet base URL: a trailing slash would produce a double
    # slash in the constructed flatcontainer endpoint.
    $proGetBaseUrl = $ProGetUrl.TrimEnd('/')

    # -----------------------------------------------------------------------
    # Helper: compare two NuGet version strings, return $true when $A > $B.
    # Handles the pattern MAJOR.MINOR.PATCH[-PRERELEASE].
    # Stable (no prerelease label) ranks higher than any prerelease.
    # -----------------------------------------------------------------------
    function Compare-NuGetVersionGreater {
      param([string]$A, [string]$B)

      function ConvertTo-NuGetVersionParts([string]$v) {
        if ($v -match '^(\d+)\.(\d+)\.(\d+)(?:-(.+))?$') {
          [pscustomobject]@{
            Major      = [int]$Matches[1]
            Minor      = [int]$Matches[2]
            Patch      = [int]$Matches[3]
            Prerelease = $Matches[4]  # null when stable
          }
        } else {
          [pscustomobject]@{ Major = 0; Minor = 0; Patch = 0; Prerelease = $v }
        }
      }

      $pa = ConvertTo-NuGetVersionParts $A
      $pb = ConvertTo-NuGetVersionParts $B

      if ($pa.Major -ne $pb.Major) { return $pa.Major -gt $pb.Major }
      if ($pa.Minor -ne $pb.Minor) { return $pa.Minor -gt $pb.Minor }
      if ($pa.Patch -ne $pb.Patch) { return $pa.Patch -gt $pb.Patch }

      # Stable (null prerelease) > any prerelease
      if ($null -eq $pa.Prerelease -and $null -ne $pb.Prerelease) { return $true }
      if ($null -ne $pa.Prerelease -and $null -eq $pb.Prerelease) { return $false }
      if ($null -eq $pa.Prerelease -and $null -eq $pb.Prerelease) { return $false }

      # Both have a prerelease — compare as strings (lexicographic, sufficient for
      # the Sprint/Alpha/Beta/QA label scheme used in ATAP.Utilities).
      return [string]::Compare($pa.Prerelease, $pb.Prerelease, [System.StringComparison]::OrdinalIgnoreCase) -gt 0
    }

    # -----------------------------------------------------------------------
    # Helper: resolve the highest version for a single package from ProGet.
    # Returns $null when the package is not present in the feed.
    # -----------------------------------------------------------------------
    function Get-HighestVersionFromFeed {
      param([string]$PackageId)

      # NuGet v3 flatcontainer returns every version as a JSON array.
      # Endpoint: GET {base}/nuget/{feed}/v3/flatcontainer/{packageId.toLower()}/index.json
      $packageIdLower = $PackageId.ToLower()
      $url = "$proGetBaseUrl/nuget/$FeedName/v3/flatcontainer/$packageIdLower/index.json"

      try {
        $apiKey = [string](Get-SecretATAP -SecretName $ProGetApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop)
      } catch {
        throw "Unable to resolve the ProGet API key from SecretName '$ProGetApiKeySecretName'."
      }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw "The ProGet secret named '$ProGetApiKeySecretName' resolved to an empty value."
      }
      $headers = @{ 'X-ApiKey' = $apiKey }

      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $url" -Tag 'RestCall'
        $response = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $url" -Tag 'RestCall'
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
          -Message "Package '$PackageId' not found in feed '$FeedName': $(([string]$_.Exception.Message).Replace($apiKey, '***'))"
        return $null
      }

      $versions = $response.versions
      if (-not $versions -or $versions.Count -eq 0) {
        return $null
      }

      # Find the highest version in the list. Iterate the whole collection so a
      # single-element feed response does not produce a reverse-range slice.
      $highest = $null
      foreach ($v in $versions) {
        if ($null -eq $highest -or (Compare-NuGetVersionGreater -A $v -B $highest)) {
          $highest = $v
        }
      }
      return $highest
    }
  }

  process {
    try {
      $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PackagePropsPath)

      if (-not (Test-Path -LiteralPath $resolvedPath)) {
        $errorMessage = "Directory.Packages.props not found at: $resolvedPath"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }

      if ($WhatIfPreference) {
        return [pscustomobject]@{
          PackagePropsPath = $resolvedPath
          PackageIdPrefix  = $PackageIdPrefix
          PackagesPinned   = [ordered]@{}
          PackagesSkipped  = [System.Collections.Generic.List[string]]::new()
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Pinning floating '$PackageIdPrefix*' versions in '$resolvedPath' using feed '$FeedName' at '$proGetBaseUrl'"

      [xml]$xml = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8

      $packagesPinned  = [ordered]@{}
      $packagesSkipped = [System.Collections.Generic.List[string]]::new()

      # Find all <PackageVersion> elements whose Include starts with the prefix
      # and whose Version contains a wildcard.
      $includeLikePattern = "$PackageIdPrefix*"
      $elements = $xml.SelectNodes('//PackageVersion[@Include and @Version]') |
        Where-Object {
          $_.Include -like $includeLikePattern -and $_.Version -match '\*'
        }

      if ($elements.Count -eq 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "No floating '$PackageIdPrefix*' PackageVersion entries found — nothing to pin."
      }

      foreach ($element in $elements) {
        $packageId       = $element.Include
        $floatingVersion = $element.Version

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
          -Message "Resolving '$packageId' (current: $floatingVersion) from $FeedName"

        $highest = Get-HighestVersionFromFeed -PackageId $packageId

        if ($null -eq $highest) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "SKIPPED '$packageId' — no version found in feed '$FeedName'"
          $packagesSkipped.Add($packageId)
          continue
        }

        if ($PSCmdlet.ShouldProcess($resolvedPath, "Pin '$packageId' to '$highest'")) {
          $element.Version = $highest
          $packagesPinned[$packageId] = $highest
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "Pinned '$packageId': $floatingVersion -> $highest"
        }
      }

      # Save only when at least one change was made.
      if ($packagesPinned.Count -gt 0 -and $PSCmdlet.ShouldProcess($resolvedPath, 'Save pinned Directory.Packages.props')) {
        $xml.Save($resolvedPath)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Saved '$resolvedPath' with $($packagesPinned.Count) package(s) pinned."
      }

      [pscustomobject]@{
        PackagePropsPath = $resolvedPath
        PackageIdPrefix  = $PackageIdPrefix
        PackagesPinned   = $packagesPinned
        PackagesSkipped  = $packagesSkipped
      }
    } catch {
      $errorMessage = "Set-FloatingPackagePins failed: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
