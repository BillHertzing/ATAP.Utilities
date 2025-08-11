function List-ProGetConnectors {
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
    Write-PSFMessage -Level Verbose -Message 'Entering function: List-ProGetConnectors' -Tag 'List-ProGetConnectors', 'Trace'

    # if not passed, get from the environment variable. If not an environment variable fall back to the $global: value
    if ([string]::IsNullOrWhiteSpace($proGetBaseScheme)) {
      if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminUriSchemeConfigRootKey'], 'Process')) ) {
        if ([string]::IsNullOrWhiteSpace($global:Settings[$global:configRootKeys['ProGetAdminUriSchemeConfigRootKey']])) {
          $errorMessage = 'ProGetBaseScheme is not available.'
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'List-ProGetConnectors', 'Trace', 'Error'
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
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'List-ProGetConnectors', 'Trace', 'Error'
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
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'List-ProGetConnectors', 'Trace', 'Error'
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
      Write-PSFMessage -Level Error -Message $errorMessage -Tag 'List-ProGetConnectors', 'Trace', 'Error'
      throw $errorMessage
    }
    # The elements of the requests's headers are constant, so define them here
    $headers = @{
      'Accept'   = 'application/json'
      "X-ApiKey" = $adminApiKey
    }

    # The Page for the command to list all Connectors in ProGet
    # ToDo: Move the page for the command to list all Connectors into configroot and settings
    $progetListConnectorsPage = '/api/management/connectors/list'
    $proGetApipage = $progetListConnectorsPage
    # Construct the Api endpoint URL
    $apiEndPoint = [UriBuilder]::new($proGetBaseScheme, $proGetBaseHost, $proGetBasePort, $proGetApipage, $null ).URI

    $response = $null
    $results = @()
  }

  Process {
    # Make the Api Call
    try {
      Write-PSFMessage -Level Verbose -Message "Attempting to get the list of Connectors" -Tag 'List-ProGetConnectors', 'Trace'
      $response = Invoke-RestMethod -Uri $apiEndPoint.AbsoluteUri -Headers $headers -Method Get
      if ($response.count -eq 0) {
        Write-PSFMessage -Level Warning -Message "No Connectors found at ProGet endpoint: $($apiEndpoint.AbsoluteUri )" -Tag 'List-ProGetConnectors', 'Trace', 'Warning'
      }
      else {
        foreach ($connector in $response) {
          Write-PSFMessage -Level Verbose -Message "Found connector $($connector.Name)" -Tag 'List-ProGetConnectors', 'Trace'
          $results += $connector
        }
      }
    }
    catch {
      $errorMessage = "Failed to retrieve Connectors from ProGet at $($apiEndpoint.AbsoluteUri ). Exception: $($_.Exception.Message)"
      Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception -Tag 'List-ProGetConnectors', 'Trace', 'Error'
      throw $_
    }
  }

  End {
    # either return the list of all Connectors, or just the ones assigned to the feedset
    if ($useFeedSet) {
      # get a list of distinct connector names from the PackageRepositoriesCollection in global settings
      $uniqueConnectors = @($global:settings[$global:ConfigRootKeys['PackageRepositoriesCollectionConfigRootKey']].Values | forEach-Object { $_['connectors'] }) | Sort-Object name -Unique
      # Get just the Proget Connector information ($results) that matches the connectors in the feedset,
      #   where the name of the proget connector is the same as the name of the connector in the feedset
      $uniqueConnectorNames = $uniqueConnectors | ForEach-Object { $_.name }
      $results = $results | Where-Object {
        $connectorName = $_.name
        $uniqueConnectorNames -contains $connectorName
      }
    }
    Write-PSFMessage -Level Verbose -Message 'Leaving function: List-ProGetConnectors' -Tag 'List-ProGetConnectors', 'Trace'
    return $results
  }
}
