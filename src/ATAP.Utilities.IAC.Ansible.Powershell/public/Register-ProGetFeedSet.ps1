function Register-ProGetFeedSet {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (  )

  Write-PSFMessage -Level Verbose -Message 'Entering function: Register-ProGetFeedSet'
  # ToDo: Remove this when packaging works
  #  if (-not (Get-Command -Name 'Convert-ProGetFeedType' -CommandType Function -ErrorAction SilentlyContinue)) {
  . "$PSScriptRoot\..\private\Convert-ProGetFeedType.ps1"
  # }
  #  if (-not (Get-Command -Name 'Build-ProGetFeedEndpointURL' -CommandType Function -ErrorAction SilentlyContinue)) {
  . "$PSScriptRoot\..\private\Build-ProGetFeedEndpointURL.ps1"
  # }


  # A RegEx Pattern that will break apart the NameKey into its components for creating the endpointURL
  # first component is 'Released' or 'Prerelease'
  # second component is 'PSResourceGet' or 'ChocolateyGet' or 'NuGet'
  # third component is 'Production' or 'QualityAssurance'

  # ToDO: Rethink this: now it uses the actual language-specific feed  name - figure out how to use the universal key instead
  $regExPattern = '^PackageRepository(?<LocationType>Internal|External)(?<VersionType>Released|Prerelease)(?<PackageProviderName>PSResourceGet|ChocolateyGet|NuGet)(?<PackageType>Production|QualityAssurance)'

  # Register all the internal non-Filesystem feeds specified in the PackageRepositoryCollection
  $feedNames = $global:settings[$global:ConfigRootKeys['PackageRepositoriesCollectionConfigRootKey']].keys | Where-Object { ($_ -match 'PackageRepositoryInternal' ) -and ($_ -notmatch 'Filesystem' ) }
  for ($feedNamesIndex = 0; $feedNamesIndex -lt $feedNames.Count; $feedNamesIndex++) {
    $feedName = $feedNames[$feedNamesIndex]
    # use $regExPattern to pull apart the $feedName into its components
    if ($feedName -notmatch $regExPattern) {
      $errorMessage = "Feed name key '$feedName' does not match expected pattern."
      Write-PSFMessage -Level Error -Message $errorMessage
      throw $errorMessage
    }
    # $locationType = $matches['LocationType'] # LocationType is ignored, because the prior where clause discarded the external and filesystem feed
    $versionType = $matches['VersionType']
    $packageProviderName = $matches['PackageProviderName']
    $packageType = $matches['PackageType']
    $proGetFeedType = Convert-ProGetFeedType $packageProviderName
    $feed = $($global:settings[$global:ConfigRootKeys['PackageRepositoriesCollectionConfigRootKey']][$feedName])

    # $endpointUrl = Build-ProGetFeedEndpointURL $feed.ShortName 'http' $feed.Uri.host $feed.Uri.port $proGetFeedType $VersionType $PackageType
    $endpointUrl = Build-ProGetFeedEndpointURL  $feed.Uri.Scheme $feed.Uri.host $feed.Uri.port "nuget/$($feed.ShortName)/v3/index.json"
    # $endpointURL = 'http://' + 'utat022' + ':' + $feed.Uri.port + '/' + 'nuget' + '/' + $feed.ShortName + '/' # $feed.Uri.host

    if ($PSCmdlet.ShouldProcess("ProGet Feed [$endpointUrl]", "Register a PSRepository pull and push endpointUrl")) {
      try {
        Write-PSFMessage -Level Verbose -Message "Attempting to register $endpointUrl"
        # ToDo: accumulate the results for each feed, and pass the set on down the pipeline
        $registrationResults = Register-PSResourceRepository -Name $feed.ShortName -Uri $endpointUrl -ApiVersion 'V3' -Trusted -passthru
        Write-PSFMessage -Level Verbose -Message "Successfully registered  $endpointUrl"
      }
      catch {
        $errorMessage = "Failed to register $endpointUrl. Exception: $($_.Exception.Message)"
        Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
        throw $_
      }
    }
  }
  Write-PSFMessage -Level Verbose -Message 'Exiting function: Register-ProGetFeedSet'
}


