function List-ProGetFeeds {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('http', 'https')]
    [string]$proGetBaseScheme,
    [Parameter(Mandatory = $false)]
    [string]$proGetBaseHost,
    [Parameter(Mandatory = $false)]
    [int]$proGetBasePort,
    [switch] $useFeedSet,
    [ValidateNotNullOrEmpty()]
    [string]$ProGetApiKeySecretName = 'ProGet.Admin.API.Key'
  )
  Begin {
    # SC-0288 / Task 13.66.b: the SecretName host suffix is derived from the service placement
    # host, never hard-coded. Resolution order is the authoritative host setting,
    # then the placement map; an unknown placement host fails closed.
    if (-not $PSBoundParameters.ContainsKey('ProGetApiKeySecretName')) {
      if (-not (Get-Command -Name 'Resolve-HostSuffixedSecretName' -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.Common.PowerShell' 'public' 'Resolve-HostSuffixedSecretName.ps1')
      }
      $ProGetApiKeySecretName = Resolve-HostSuffixedSecretName `
        -BaseName $ProGetApiKeySecretName -ServiceName 'ProGet' -SettingName 'ProGetAdminApiKeySecretName'
    }

    Write-PSFMessage -Level Verbose -Message 'Entering function: List-ProGetFeeds'
    if (-not (Get-Command -Name 'ConvertTo-ProGetFeedNameAlternateForm' -CommandType Function -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot 'ConvertTo-ProGetFeedNameAlternateForm.ps1')
    }

    # if not passed, get from the environment variable. If not an environment variable fall back to the $global: value
    if ([string]::IsNullOrWhiteSpace($proGetBaseScheme)) {
      if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminUriSchemeConfigRootKey'], 'Process')) ) {
        if ([string]::IsNullOrWhiteSpace($global:Settings[$global:configRootKeys['ProGetAdminUriSchemeConfigRootKey']])) {
          $errorMessage = 'ProGetBaseScheme is not available.'
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'List-ProGetFeeds', 'Trace', 'Error'
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
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'List-ProGetFeeds', 'Trace', 'Error'
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
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'List-ProGetFeeds', 'Trace', 'Error'
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

    # The Page for the command to list all feeds in ProGet
    # ToDo: Move the page for the command to list all feeds into configroot and settings
    $progetListFeedsPage = 'api/management/feeds/list'
    $proGetAPIpage = $progetListFeedsPage
    # Construct the API endpoint URL
    $apiEndPoint = [UriBuilder]::new($proGetBaseScheme, $proGetBaseHost, $proGetBasePort, $proGetAPIpage, $null ).URI

    $response = $null
    $results = @()
  }


  Process {
    if (-not $PSCmdlet.ShouldProcess($apiEndPoint.AbsoluteUri, 'List ProGet feeds')) {
      return
    }
    # Make the API Call
    try {
      if (-not (Get-Command Get-SecretATAP -ErrorAction SilentlyContinue)) { throw 'Get-SecretATAP is required for ProGet authentication.' }
      $adminApiKey = [string](Get-SecretATAP -SecretName $ProGetApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop)
      if ([string]::IsNullOrWhiteSpace($adminApiKey)) { throw "Secret '$ProGetApiKeySecretName' did not resolve to a ProGet API key." }
      $headers = @{ Accept = 'application/json'; 'X-ApiKey' = $adminApiKey }
      Write-PSFMessage -Level Verbose -Message "Attempting to get the list of Feeds" -Tag 'List-ProGetFeeds', 'Trace'
      $response = Invoke-RestMethod -Uri $apiEndPoint.AbsoluteUri -Headers $headers -Method Get
      if ($response.count -eq 0) {
        Write-PSFMessage -Level Warning -Message "No feeds found at ProGet endpoint: $($apiEndpoint.AbsoluteUri )" -Tag 'List-ProGetFeeds', 'Trace', 'Warning'
      }
      else {
        foreach ($proGetFeed in $response) {
          Write-PSFMessage -Level Verbose -Message "Found proGetFeed $($proGetFeed.Name)" -Tag 'List-ProGetFeeds', 'Trace'
          $results += $proGetFeed
        }
      }
    }
    catch {
      $errorMessage = "Failed to retrieve feeds from ProGet at $($apiEndpoint.AbsoluteUri). Verify connectivity and the configured SecretName."
      Write-PSFMessage -Level Error -Message $errorMessage -Tag 'List-ProGetFeeds', 'Trace', 'Error'
      throw $errorMessage
    }
  }

  End {
    # If the $useFeedSet switch is set, return just the feeds that belong to Proget Package repository implementation
    if ($useFeedSet) {
      Write-PSFMessage -Level Verbose -Message 'Returning feeds as a set'
      $feedSet = $global:Settings[$global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']]
      $feedShortNames = @($feedSet.Values | ForEach-Object {
          if ($_ -is [System.Collections.IDictionary]) { $_['FeedName'] } else { $_.FeedName }
        })
      $proGetFeeds = @{}
      foreach ($feed in $results) {
        if ($feedShortNames -contains $feed.Name) {
          $feedLongName = (ConvertTo-ProGetFeedNameAlternateForm -shortName $feed.Name).LongName
          Write-PSFMessage -Level Verbose -Message "Adding feed $feedLongName to output" -Tag 'List-ProGetFeeds', 'Trace'
          $proGetFeeds[$feedLongName] = $feed
        }
        else {
          Write-PSFMessage -Level Verbose -Message "$feed.Name is not in the feedSet, skipping" -Tag 'List-ProGetFeeds', 'Trace'
        }
      }
    }
    Write-PSFMessage -Level Verbose -Message 'Leaving function: List-ProGetFeeds' -Tag 'List-ProGetFeeds', 'Trace'
    return $useFeedSet ? $proGetFeeds : $results
  }
}

