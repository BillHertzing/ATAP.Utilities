function New-ProGetFeedSet {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (  )

  Write-PSFMessage -Level Verbose -Message 'Entering function: New-ProGetFeedSet'
  # ToDo: Remove this when packaging works
  #  if (-not (Get-Command -Name 'New-ProGetApiKey' -CommandType Function -ErrorAction SilentlyContinue)) {
  . "$PSScriptRoot\New-ProGetApiKey.ps1"
  # }
  # ToDo: Remove this when packaging works
  #  if (-not (Get-Command -Name 'Convert-ProGetFeedType' -CommandType Function -ErrorAction SilentlyContinue)) {
  . "$PSScriptRoot\..\private\Convert-ProGetFeedType.ps1"
  # }
  # ToDo: Remove this when packaging works
  #  if (-not (Get-Command -Name 'Build-ProGetFeedEndpointURL' -CommandType Function -ErrorAction SilentlyContinue)) {
  . "$PSScriptRoot\..\private\Build-ProGetFeedEndpointURL.ps1"
  # }


  # $adminApiKey is used to authenticate an admin role to ProGet
  # ToDo: Fetch from Secrets vault instead of environment variable
  # ToDo: consider allowing this function to setup feeds on multiple proget hosts, would need a $adminApiKey in the settings for each
  $adminApiKey = [Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminApiKeyConfigRootKey'], 'Process')
  if (-not $adminApiKey) {
    $errorMessage = 'ProGet admin API key is not available in environment variable.'
    Write-PSFMessage -Level Error -Message $errorMessage
    throw $errorMessage
  }

  # ToDo: consider allowing this function to setup feeds on multiple proget hosts, would need a $ProGetBasePort in the settings for each
  $ProGetBasePort = $global:Settings[$global:configRootKeys['ProGetAdminApiKeyUriPortConfigRootKey']]


  # A RegEx Pattern that will break apart the NameKey into its components for creating the endpointURL
  # first component is 'Released' or 'Prerelease'
  # second component is 'PSResourceGet' or 'ChocolateyGet' or 'NuGet'
  # third component is 'Production' or 'QualityAssurance'

  # ToDO: Rethink this: now it uses the actual language-specific feed name - figure out how to use the universal key instead
  $regExPattern = '^PackageRepository(?<LocationType>Internal|External)(?<VersionType>Released|Prerelease)(?<PackageProviderName>PSResourceGet|ChocolateyGet|NuGet)(?<PackageType>Production|QualityAssurance)'

  # Setup all the internal non-Filesystem feeds specified in the PackageRepositoryCollection
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
    # Parse the endpoint Uri of the feed, as defined in the settings, into a structured Uri object
    $feedApiKeyName = $feed.ApiKeyName

    # ToDo: look into supporting different hosts for different feeds. Would need to store a $ProGetBasePort for each host
    # This is the URI for creating feeds in ProGet
    $feedAdministrationUri = "http://$($feed.Uri.host):$ProGetBasePort/api/management/feeds/create"

    $endpointUrl = Build-ProGetFeedEndpointURL $feed.ShortName 'http' $feed.Uri.host $feed.Uri.port $proGetFeedType $VersionType $PackageType


    $body = @{
      name                      = $feed.ShortName
      alternateNames            = @()
      feedType                  = $proGetFeedType
      useApiV3                  = $true
      active                    = $true
      cacheConnectors           = $true
      symbolServerEnabled       = $false
      stripSymbols              = $false
      stripSource               = $false
      endpointUrl               = ''
      connectors                = @()
      retentionRules            = @()
      variables                 = @{}
      canPublish                = $true
      packageStatisticsEnabled  = $false
      restrictPackageStatistics = $false
      deploymentRecordsEnabled  = $true
      usageRecordsEnabled       = $true
      vulnerabilitiesEnabled    = $true
      licensesEnabled           = $true
      useWithProjects           = $true
    }

    $headers = @{ 'X-ApiKey' = $adminApiKey }

    if ($PSCmdlet.ShouldProcess("ProGet Feed [$feed.ShortName]", "Create on port $($feed.Uri.port) as type '$packageProviderName' ProgetFeedType '$proGetFeedType'")) {
      try {
        Write-PSFMessage -Level Verbose -Message "Attempting to create feed '$feed.ShortName' of type '$packageProviderName' on port $($feed.Uri.port)"
        # ToDo: accumulate the results for each feed, and pass them on down the pipeline
        $feedCreationResults = Invoke-RestMethod -Uri $feedAdministrationUri -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 3) -ContentType 'application/json'
        Write-PSFMessage -Level Verbose -Message "Successfully created feed '$feed.ShortName' on port $($feed.Uri.port) as type '$packageProviderName' ProgetFeedType '$proGetFeedType'"
      }
      catch {
        $errorMessage = "Failed to create feed '$feed.ShortName' on port $($feed.Uri.port). Exception: $($_.Exception.Message)"
        Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
        throw $_
      }
      try {
        # Protect the new feed by creating a new Api Key for the feed and assigning the key certain permissions

        $APIKeyCreationResults = New-ProGetApiKey -ApiKeyName $feedApiKeyName -FeedName $feed.ShortName -PackagePermissions @('view', 'add', 'delete') -ProGetBasePort $ProGetBasePort -ProGetHost $($feed.Uri.host)
        # ToDo: Assign it to a process environment variable
        [Environment]::SetEnvironmentVariable( $feedApiKeyName, $APIKeyCreationResults.key, [EnvironmentVariableTarget]::User)
        # ToDo: Store it in a secrets vault
        # ToDo: Store the APIKey in a secrets vault keyed by the feed name
      }
      catch {
        $errorMessage = "Failed to create and assign APIKey  $feedApiKeyName  to feed '$feed.ShortName' on port $($feed.Uri.port). Exception: $($_.Exception.Message)"
        Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
        throw $_
      }
    }
    [PSCustomObject]@{
      FeedName              = $feed.ShortName
      FeedCreationResult    = $feedCreationResults
      APIKeyCreationResults = $APIKeyCreationResults
    }
    $counter++
  }

  Write-PSFMessage -Level Verbose -Message 'Exiting function: New-ProGetFeedSet'
}
