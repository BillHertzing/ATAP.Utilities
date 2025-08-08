function New-ProGetFeedSet {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('http', 'https')]
    [string]$proGetBaseScheme,
    [Parameter(Mandatory = $false)]
    [string]$proGetBaseHost,
    [Parameter(Mandatory = $false)]
    [int]$proGetBasePort
  )
  Begin {
    Write-PSFMessage -Level Verbose -Message 'Entering function: New-ProGetFeedSet' -Tag 'New-ProGetFeedSet', 'Trace'
    # ToDo: Remove this when packaging works
    #  if (-not (Get-Command -Name 'New-ProGetApiKey' -CommandType Function -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\New-ProGetApiKey.ps1"
    # }
    # ToDo: Remove this when packaging works
    #  if (-not (Get-Command -Name 'Convert-ProGetFeedType' -CommandType Function -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\..\private\Convert-ProGetFeedType.ps1"
    # }
    # ToDo: Remove this when packaging works
    #  if (-not (Get-Command -Name 'New-ProGetApiKey' -CommandType Function -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\New-ProGetConnector.ps1"
    # }

    # if not passed, get from the environment variable. If not an environment variable fall back to the $global: value
    if ([string]::IsNullOrWhiteSpace($proGetBaseScheme)) {
      if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminUriSchemeConfigRootKey'], 'Process')) ) {
        if ([string]::IsNullOrWhiteSpace($global:Settings[$global:configRootKeys['ProGetAdminUriSchemeConfigRootKey']])) {
          $errorMessage = 'ProGetBaseScheme is not available.'
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'New-ProGetFeedSet', 'Trace', 'Error'
          throw $errorMessage
        }
        else {
          $progetBaseScheme = $global:Settings[$global:configRootKeys['ProGetAdminUriSchemeConfigRootKey']]
        }
      }
      else {
        $progetBaseScheme = [Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminUriSchemeConfigRootKey'], 'Process')
      }
    }

    # if not passed, get from the environment variable. If not an environment variable fall back to the $global: value
    if ([string]::IsNullOrWhiteSpace($proGetBaseHost)) {
      if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminUriHostConfigRootKey'], 'Process')) ) {
        if ([string]::IsNullOrWhiteSpace($global:Settings[$global:configRootKeys['ProGetAdminUriHostConfigRootKey']])) {
          $errorMessage = 'proGetBaseHost is not available.'
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'New-ProGetFeedSet', 'Trace', 'Error'
          throw $errorMessage
        }
        else {
          $proGetBaseHost = $global:Settings[$global:configRootKeys['ProGetAdminUriHostConfigRootKey']]
        }
      }
      else {
        $proGetBaseHost = [Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminUriSchemeConfigRootKey'], 'Process')
      }
    }

    # if not passed, get from the environment variable. If not an environment variable fall back to the $global: value
    if (-not $PSBoundParameters.ContainsKey('proGetBasePort')) {
      if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminUriPortConfigRootKey'], 'Process')) ) {
        if ([string]::IsNullOrWhiteSpace($global:Settings[$global:configRootKeys['ProGetAdminUriPortConfigRootKey']])) {
          $errorMessage = 'proGetBasePort is not available.'
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'New-ProGetFeedSet', 'Trace', 'Error'
          throw $errorMessage
        }
        else {
          $proGetBasePort = $global:Settings[$global:configRootKeys['ProGetAdminUriPortConfigRootKey']]
        }
      }
      else {
        $proGetBasePort = [Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminUriPortConfigRootKey'], 'Process')
      }
    }

    # $adminApiKey is used to authenticate an admin role to ProGet
    # ToDo: Fetch from Secrets vault instead of environment variable
    # ToDo: consider allowing this function to setup feeds on multiple proget hosts, would need a $adminApiKey in the settings for each
    $adminApiKey = [Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminApiKeyConfigRootKey'], 'Process')
    if (-not $adminApiKey) {
      $errorMessage = 'ProGet adminAPI key is not available in environment variable.'
      Write-PSFMessage -Level Error -Message $errorMessage -Tag 'New-ProGetFeedSet', 'Trace', 'Error'
      throw $errorMessage
    }
    # The elements of the requests's headers are constant, so define them here
    $headers = @{
      'Accept'   = 'application/json'
      "X-ApiKey" = $adminApiKey
    }

    # The Page for the command to list all API keys in ProGet
    # ToDo: Move the page for the command to create feeds into configroot and settings
    $progetFeedCreatePage = 'api/management/feeds/create'
    $proGetAPIpage = $progetFeedCreatePage
    # Construct the API endpoint URL to list all API keys
    $apiEndPoint = [UriBuilder]::new($proGetBaseScheme, $proGetBaseHost, $proGetBasePort, $proGetAPIpage, $null ).URI

  }

  Process {

    # A RegEx Pattern that will break apart the NameKey into its components for creating the endpointURL
    # first component is 'Internal' or 'External'
    # second component is 'Released' or 'Prerelease'
    # third component is 'PSResourceGet' or 'ChocolateyGet' or 'NuGet'
    # fourth component is 'Production' or 'QualityAssurance'
    # fifth component is 'Push' or 'Pull'

    # ToDO: Rethink this: now it uses the actual language-specific feed name - figure out how to use the universal key instead
    # ToDo: put this someplace common where it can be used by other functions
    $regExPattern = '^PackageRepository(?<LocationType>Internal|External)(?<VersionType>Released|Prerelease)(?<PackageProviderName>PSResourceGet|ChocolateyGet|NuGet)(?<PackageType>Production|QualityAssurance)(?<PushPullType>Pull|Push)?'
    # Get all of the feed names from the global setting 'PackageRepositoriesCollection'
    [string[]]$feedNames = $global:settings[$global:ConfigRootKeys['PackageRepositoriesCollectionConfigRootKey']].keys # | Where-Object { ($_ -match 'PackageRepositoryInternal' ) -and ($_ -notmatch 'Filesystem' ) }

    for ($feedNamesIndex = 0; $feedNamesIndex -lt $feedNames.Count; $feedNamesIndex++) {
      $feedName = $feedNames[$feedNamesIndex]
      # use $regExPattern to pull apart the $feedName into its components
      if ($feedName -notmatch $regExPattern) {
        $errorMessage = "Feed name key '$feedName' does not match expected pattern."
        Write-PSFMessage -Level Error -Message $errorMessage -Tag 'New-ProGetFeedSet', 'Trace', 'Error'
        throw $errorMessage
      }
      # $locationType = $matches['LocationType'] # LocationType is ignored, because the prior where clause discarded the external and filesystem feed
      $versionType = $matches['VersionType']
      $packageProviderName = $matches['PackageProviderName']
      $packageType = $matches['PackageType']
      $proGetFeedType = Convert-ProGetFeedType $packageProviderName
      $pushPullType = $matches['PushPullType']
      $feed = $($global:settings[$global:ConfigRootKeys['PackageRepositoriesCollectionConfigRootKey']][$feedName])
      # Parse the endpoint Uri of the feed, as defined in the settings, into a structured Uri object
      $feedApiKeyName = $feed.ApiKeyName

      # If this feed has a connecter, it must be created before the feed is created
      if ($feed.Connectors) {
        foreach ($connector in $feed.Connectors) {
          Write-PSFMessage -Level Verbose -Message "Creating connector '$($connector.Name)' for feed '$($feed.ShortName)'" -Tag 'New-ProGetFeedSet', 'Trace'
          # if New-ProGetConnector fails, it will throw
          New-ProGetConnector -proGetBaseScheme $proGetBaseScheme -proGetBaseHost $proGetBaseHost -proGetBasePort $proGetBasePort -Connector $connector
        }
      }
      $alternateNames = @()
      $body = @{
        name                      = $feed.ShortName
        alternateNames            = $alternateNames
        feedType                  = $proGetFeedType
        useApiV3                  = $true
        active                    = $true
        cacheConnectors           = $true
        symbolServerEnabled       = $false
        stripSymbols              = $false
        stripSource               = $false
        endpointUrl               = ''
        # Should be a array of already-created connector names. Force an array even if there is only one, else empty array
        connectors                = $feed.connectors.count? (, $feed.Connectors.name) : @()
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

      $feedCreationResults = $null
      $apiKeyCreationResult = $null

      if ($PSCmdlet.ShouldProcess("ProGet Feed [$($feed.ShortName)]", "Create on port $ProGetBasePort as type $packageProviderName ProgetFeedType $proGetFeedType" )) {
        # Make the API Call

        try {
          Write-PSFMessage -Level Verbose -Message "Attempting to create feed '$($feed.ShortName)' of type '$packageProviderName' on port $ProGetBasePort" -Tag 'New-ProGetFeedSet', 'Trace'
          # ToDo: accumulate the results for each feed, and pass them on down the pipeline
          $feedCreationResults = Invoke-RestMethod -Uri $apiEndPoint.AbsoluteUri -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 3) -ContentType 'application/json'
          Write-PSFMessage -Level Verbose -Message "Successfully created feed '$($feed.ShortName)' on port $ProGetBasePort as type '$packageProviderName' ProgetFeedType '$proGetFeedType'" -Tag 'New-ProGetFeedSet', 'Trace'
        }
        catch {
          $errorMessage = "Failed to create feed $($feed.ShortName) on port $ProGetBasePort. Exception: $($_.Exception.Message)"
          Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception -Tag 'New-ProGetFeedSet', 'Trace', 'Error'
          throw $_
        }
        try {
          # Protect the new feed by creating a new Api Key for the feed and assigning the key certain permissions
          $APIKeyCreationResults = New-ProGetApiKey -ApiKeyName $feedApiKeyName -FeedName $feed.ShortName -PackagePermissions @('view', 'add', 'delete') -ProGetBaseScheme $proGetBaseScheme -ProGetBaseHost $ProGetBaseHost -ProGetBasePort $ProGetBasePort
          # ToDo: Assign it to a process environment variable
          [Environment]::SetEnvironmentVariable( $feedApiKeyName, $APIKeyCreationResults.key, [EnvironmentVariableTarget]::User)
          # ToDo: Store it in a secrets vault
          # ToDo: Store the APIKey in a secrets vault keyed by the feed name
        }
        catch {
          $errorMessage = "Failed to create and assign APIKey $feedApiKeyName to feed $($feed.ShortName) on port $ProGetBasePort. Exception: $($_.Exception.Message)"
          Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception -Tag 'New-ProGetFeedSet', 'Trace', 'Error'
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
  }
  End {
    Write-PSFMessage -Level Verbose -Message "Created $counter feeds." -Tag 'New-ProGetFeedSet', 'Trace'
    if ($counter -eq 0) {
      Write-PSFMessage -Level Warning -Message 'No feeds were created. Check the input parameters and the ProGet server status.' -Tag 'New-ProGetFeedSet', 'Trace'
    }
    else {
      Write-PSFMessage -Level Verbose -Message "Created $counter feeds successfully." -Tag 'New-ProGetFeedSet', 'Trace'
    }
    Write-PSFMessage -Level Verbose -Message 'Exiting function: New-ProGetFeedSet' -Tag 'New-ProGetFeedSet', 'Trace'
  }
}
