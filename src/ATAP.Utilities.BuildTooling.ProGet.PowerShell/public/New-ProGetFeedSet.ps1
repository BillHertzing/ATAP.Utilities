function New-ProGetFeedSet {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('http', 'https')]
    [string]$proGetBaseScheme,
    [Parameter(Mandatory = $false)]
    [string]$proGetBaseHost,
    [Parameter(Mandatory = $false)]
    [int]$proGetBasePort,
    [Parameter(Mandatory = $false)]
    [string[]]$FeedNameFilter,
    [ValidateNotNullOrEmpty()]
    [string]$ProGetApiKeySecretName = 'ProGet.Admin.API.Key'
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
    # ToDo: Remove this when packaging works
    #  if (-not (Get-Command -Name 'List-ProGetFeeds' -CommandType Function -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\List-ProGetFeeds.ps1"
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
        $proGetBaseHost = [Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminUriHostConfigRootKey'], 'Process')
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

    if (-not $PSBoundParameters.ContainsKey('ProGetApiKeySecretName') -and $global:configRootKeys -and $global:Settings) {
      $settingName = $global:configRootKeys['ProGetAdminApiKeySecretNameConfigRootKey']
      if ($settingName -and $global:Settings[$settingName]) { $ProGetApiKeySecretName = [string]$global:Settings[$settingName] }
    }

    # The Page for the command to list all API keys in ProGet
    # ToDo: Move the page for the command to create feeds into configroot and settings
    $progetFeedCreatePage = 'api/management/feeds/create'
    $proGetAPIpage = $progetFeedCreatePage
    # Construct the API endpoint URL to list all API keys
    $apiEndPoint = [UriBuilder]::new($proGetBaseScheme, $proGetBaseHost, $proGetBasePort, $proGetAPIpage, $null ).URI

    $existingFeedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    # Discovery is authenticated. Suppress it under -WhatIf so preview mode has
    # no secret access or network activity.
    if (-not $WhatIfPreference) {
      try {
        $currentFeeds = @(List-ProGetFeeds -proGetBaseScheme $proGetBaseScheme -proGetBaseHost $proGetBaseHost -proGetBasePort $proGetBasePort -ProGetApiKeySecretName $ProGetApiKeySecretName)
        foreach ($currentFeed in $currentFeeds) {
          if ($null -ne $currentFeed.Name -and -not [string]::IsNullOrWhiteSpace([string]$currentFeed.Name)) {
            [void]$existingFeedNames.Add([string]$currentFeed.Name)
          }
        }
      }
      catch {
        $errorMessage = 'Failed to query existing ProGet feeds before creating feed set. Verify connectivity and the configured SecretName.'
        Write-PSFMessage -Level Error -Message $errorMessage -Tag 'New-ProGetFeedSet', 'Trace', 'Error'
        throw $errorMessage
      }
    }

    $processedCounter = 0
    $createdCounter = 0
    $skippedCounter = 0
  }

  Process {

    # Iterate over all feeds in the ProGetFeedCollection (5 NuGet + 5 PowerShellGet = 10 permanent feeds).
    # Each entry is a hashtable with keys: FeedName, FeedType, Tier, ApiKeyName, Uri, NuGetV3Uri,
    #   Connectors, RetentionPolicy.
    [string[]]$feedKeys = $global:settings[$global:ConfigRootKeys['ProGetFeedCollectionConfigRootKey']].keys

    for ($feedKeysIndex = 0; $feedKeysIndex -lt $feedKeys.Count; $feedKeysIndex++) {
      $feedKey = $feedKeys[$feedKeysIndex]
      $feed = $global:settings[$global:ConfigRootKeys['ProGetFeedCollectionConfigRootKey']][$feedKey]
      $feedApiKeyName = $feed.ApiKeyName

      if ($FeedNameFilter -and -not ($FeedNameFilter | Where-Object { $feed.FeedName -like $_ })) {
        Write-PSFMessage -Level Debug -Message "Skipping feed '$($feed.FeedName)' because it does not match FeedNameFilter." -Tag 'New-ProGetFeedSet', 'Trace'
        continue
      }

      $processedCounter++

      if ($existingFeedNames.Contains([string]$feed.FeedName)) {
        Write-PSFMessage -Level Verbose -Message "Feed '$($feed.FeedName)' already exists in ProGet. Skipping creation." -Tag 'New-ProGetFeedSet', 'Trace'
        $skippedCounter++
        [PSCustomObject]@{
          FeedName              = $feed.FeedName
          Created               = $false
          SkippedExisting       = $true
          FeedCreationResult    = $null
          APIKeyCreationResults = $null
        }
        continue
      }

      $proGetFeedType = Convert-ProGetFeedType -FeedType $feed.FeedType

      # If this feed has connectors, create them before the feed
      if ($feed.Connectors) {
        foreach ($connector in $feed.Connectors) {
          Write-PSFMessage -Level Verbose -Message "Creating connector '$($connector.Name)' for feed '$($feed.FeedName)'" -Tag 'New-ProGetFeedSet', 'Trace'
          # if New-ProGetConnector fails, it will throw
          New-ProGetConnector -proGetBaseScheme $proGetBaseScheme -proGetBaseHost $proGetBaseHost -proGetBasePort $proGetBasePort -Connector $connector -ProGetApiKeySecretName $ProGetApiKeySecretName
        }
      }

      # Build retention rules from the RetentionPolicy metadata
      $retentionRules = @()
      if ($feed.RetentionPolicy -and $feed.RetentionPolicy.DaysToKeep) {
        $retentionRules = @(
          @{
            deleteCachedPackages    = $true
            deleteOlderVersions     = $true
            triggerDaysOld          = [int]$feed.RetentionPolicy.DaysToKeep
            keepVersionsCount       = 0
            keepLatestVersionCount  = 0
            triggerDownloadCount    = 0
          }
        )
      }

      $alternateNames = @()
      $body = @{
        name                      = $feed.FeedName
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
        retentionRules            = $retentionRules
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
      $APIKeyCreationResults = $null
      $created = $false

      if ($PSCmdlet.ShouldProcess("ProGet Feed [$($feed.FeedName)]", "Create on port $ProGetBasePort as type $proGetFeedType" )) {
        # Make the API Call

        try {
          if (-not (Get-Command Get-SecretATAP -ErrorAction SilentlyContinue)) { throw 'Get-SecretATAP is required for ProGet authentication.' }
          $adminApiKey = [string](Get-SecretATAP -SecretName $ProGetApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop)
          if ([string]::IsNullOrWhiteSpace($adminApiKey)) { throw "Secret '$ProGetApiKeySecretName' did not resolve to a ProGet API key." }
          $headers = @{ Accept = 'application/json'; 'X-ApiKey' = $adminApiKey }
          Write-PSFMessage -Level Verbose -Message "Attempting to create feed '$($feed.FeedName)' of type '$proGetFeedType' on port $ProGetBasePort" -Tag 'New-ProGetFeedSet', 'Trace'
          # ToDo: accumulate the results for each feed, and pass them on down the pipeline
          $feedCreationResults = Invoke-RestMethod -Uri $apiEndPoint.AbsoluteUri -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 3) -ContentType 'application/json'
          Write-PSFMessage -Level Verbose -Message "Successfully created feed '$($feed.FeedName)' on port $ProGetBasePort as type '$proGetFeedType'" -Tag 'New-ProGetFeedSet', 'Trace'
          [void]$existingFeedNames.Add([string]$feed.FeedName)
          $created = $true
          $createdCounter++
        }
        catch {
          $errorMessage = "Failed to create feed $($feed.FeedName) on port $ProGetBasePort. Verify connectivity and the configured SecretName."
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'New-ProGetFeedSet', 'Trace', 'Error'
          throw $errorMessage
        }
        try {
          # Protect the new feed by creating a new Api Key for the feed and assigning the key certain permissions
          $APIKeyCreationResults = New-ProGetApiKey -ApiKeyName $feedApiKeyName -FeedName $feed.FeedName -PackagePermissions @('view', 'add', 'delete') -ProGetBaseScheme $proGetBaseScheme -ProGetBaseHost $ProGetBaseHost -ProGetBasePort $ProGetBasePort -ProGetApiKeySecretName $ProGetApiKeySecretName
        }
        catch {
          $errorMessage = "Failed to create API-key metadata $feedApiKeyName for feed $($feed.FeedName) on port $ProGetBasePort. Verify connectivity and the configured SecretName."
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'New-ProGetFeedSet', 'Trace', 'Error'
          throw $errorMessage
        }
      }
      [PSCustomObject]@{
        FeedName              = $feed.FeedName
        Created               = $created
        SkippedExisting       = $false
        FeedCreationResult    = $feedCreationResults
        APIKeyCreationResults = $APIKeyCreationResults
      }
    }
  }
  End {
    Write-PSFMessage -Level Verbose -Message "Processed $processedCounter feed definitions. Created $createdCounter feeds; skipped $skippedCounter existing feeds." -Tag 'New-ProGetFeedSet', 'Trace'
    if ($processedCounter -eq 0) {
      Write-PSFMessage -Level Warning -Message 'No feed definitions matched the input parameters.' -Tag 'New-ProGetFeedSet', 'Trace'
    }
    elseif ($createdCounter -eq 0 -and $skippedCounter -gt 0) {
      Write-PSFMessage -Level Verbose -Message 'No feeds were created because all matching feeds already existed.' -Tag 'New-ProGetFeedSet', 'Trace'
    }
    else {
      Write-PSFMessage -Level Verbose -Message "Created $createdCounter feeds successfully." -Tag 'New-ProGetFeedSet', 'Trace'
    }
    Write-PSFMessage -Level Verbose -Message 'Leaving function: New-ProGetFeedSet' -Tag 'New-ProGetFeedSet', 'Trace'
  }
}
