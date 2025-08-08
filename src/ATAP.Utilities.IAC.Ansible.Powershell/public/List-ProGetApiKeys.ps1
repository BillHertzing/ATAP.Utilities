function List-ProGetApiKeys {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('http', 'https')]
    [string]$proGetBaseScheme,
    [Parameter(Mandatory = $false)]
    [string]$proGetBaseHost,
    [Parameter(Mandatory = $false)]
    [int]$proGetBasePort,
    [switch] $useFeedSet
  )
  Begin {
    Write-PSFMessage -Level Verbose -Message 'Entering function: List-ProGetApiKeys' -Tag 'List-ProGetApiKeys', 'Trace'

    # if not passed, get from the environment variable. If not an environment variable fall back to the $global: value
    if ([string]::IsNullOrWhiteSpace($proGetBaseScheme)) {
      if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminUriSchemeConfigRootKey'], 'Process')) ) {
        if ([string]::IsNullOrWhiteSpace($global:Settings[$global:configRootKeys['ProGetAdminUriSchemeConfigRootKey']])) {
          $errorMessage = 'ProGetBaseScheme is not available.'
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'List-ProGetApiKeys', 'Trace', 'Error'
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
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'List-ProGetApiKeys', 'Trace', 'Error'
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
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'List-ProGetApiKeys', 'Trace', 'Error'
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
    # ToDo: Set an expiration date, and ensure the organization implements a policy that rotates the key value before they expire
    # ToDo: consider allowing this function to setup feeds on multiple proget hosts, would need a $adminApiKey in the settings for each
    $adminApiKey = [Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminApiKeyConfigRootKey'], 'Process')
    if (-not $adminApiKey) {
      $errorMessage = 'ProGet adminApiKey is not available in environment variable.'
      Write-PSFMessage -Level Error -Message $errorMessage -Tag 'List-ProGetApiKeys', 'Trace', 'Error'
      throw $errorMessage
    }
    # The elements of the requests's headers are constant, so define them here
    $headers = @{
      'Accept'   = 'application/json'
      "X-ApiKey" = $adminApiKey
    }

    # The Page for the command to list all ApiKeys in ProGet
    # ToDo: Move the page for the command to list all ApiKeys into configroot and settings
    $progetListApisPage = 'api/api-keys/list'
    $proGetApipage = $progetListApisPage
    # Construct the Api endpoint URL
    $apiEndPoint = [UriBuilder]::new($proGetBaseScheme, $proGetBaseHost, $proGetBasePort, $proGetApipage, $null ).URI

    $response = $null
    $results = @()
  }

  Process {
    # Make the Api Call
    try {
      Write-PSFMessage -Level Verbose -Message "Attempting to get the list of ApiKeys" -Tag 'List-ProGetApiKeys', 'Trace'
      $response = Invoke-RestMethod -Uri $apiEndPoint.AbsoluteUri -Headers $headers -Method Get
      if ($response.count -eq 0) {
        Write-PSFMessage -Level Warning -Message "No ApiKeys found at ProGet endpoint: $($apiEndpoint.AbsoluteUri )" -Tag 'List-ProGetApiKeys', 'Trace', 'Warning'
      }
      else {
        foreach ($apiKey in $response) {
          Write-PSFMessage -Level Verbose -Message "Found apiKey $($apiKey.Name)" -Tag 'List-ProGetApiKeys', 'Trace'
          $results += $feed
        }
      }
    }
    catch {
      $errorMessage = "Failed to retrieve ApiKeys from ProGet at $($apiEndpoint.AbsoluteUri ). Exception: $($_.Exception.Message)"
      Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception -Tag 'List-ProGetApiKeys', 'Trace', 'Error'
      throw $_
    }
  }

  End {
    # either return the list of all ApiKeys, or just the ones assigned to the feedset
    if ($useFeedSet) {
      $shortNames = @($global:settings[$global:ConfigRootKeys['PackageRepositoriesCollectionConfigRootKey']].Values | forEach-Object { $_['shortName'] })
      $results = $response | Where-Object {
        $lastWord = ($_."description" -split '\s+')[-1]
        $shortNames -contains $lastWord
      }
    }
    else {
      $results = $response
    }
    Write-PSFMessage -Level Verbose -Message 'Exiting function: List-ProGetApiKeys' -Tag 'List-ProGetApiKeys', 'Trace'
    return $results
  }
}
