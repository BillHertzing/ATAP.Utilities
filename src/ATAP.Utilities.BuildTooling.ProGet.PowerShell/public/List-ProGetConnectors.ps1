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

    if (-not $PSBoundParameters.ContainsKey('ProGetApiKeySecretName') -and $global:configRootKeys -and $global:Settings) {
      $settingName = $global:configRootKeys['ProGetAdminApiKeySecretNameConfigRootKey']
      if ($settingName -and $global:Settings[$settingName]) { $ProGetApiKeySecretName = [string]$global:Settings[$settingName] }
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
    if (-not $PSCmdlet.ShouldProcess($apiEndPoint.AbsoluteUri, 'List ProGet connectors')) {
      return
    }
    # Make the Api Call
    try {
      if (-not (Get-Command Get-SecretATAP -ErrorAction SilentlyContinue)) { throw 'Get-SecretATAP is required for ProGet authentication.' }
      $adminApiKey = [string](Get-SecretATAP -SecretName $ProGetApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop)
      if ([string]::IsNullOrWhiteSpace($adminApiKey)) { throw "Secret '$ProGetApiKeySecretName' did not resolve to a ProGet API key." }
      $headers = @{ Accept = 'application/json'; 'X-ApiKey' = $adminApiKey }
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
      $errorMessage = "Failed to retrieve connectors from ProGet at $($apiEndpoint.AbsoluteUri). Verify connectivity and the configured SecretName."
      Write-PSFMessage -Level Error -Message $errorMessage -Tag 'List-ProGetConnectors', 'Trace', 'Error'
      throw $errorMessage
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
