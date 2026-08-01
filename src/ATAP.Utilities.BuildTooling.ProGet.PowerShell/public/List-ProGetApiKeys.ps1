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

    if (-not $PSBoundParameters.ContainsKey('ProGetApiKeySecretName') -and $global:configRootKeys -and $global:Settings) {
      $settingName = $global:configRootKeys['ProGetAdminApiKeySecretNameConfigRootKey']
      if ($settingName -and $global:Settings[$settingName]) { $ProGetApiKeySecretName = [string]$global:Settings[$settingName] }
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
    if (-not $PSCmdlet.ShouldProcess($apiEndPoint.AbsoluteUri, 'List ProGet API-key metadata')) {
      return
    }
    # Make the Api Call
    try {
      if (-not (Get-Command Get-SecretATAP -ErrorAction SilentlyContinue)) { throw 'Get-SecretATAP is required for ProGet authentication.' }
      $adminApiKey = [string](Get-SecretATAP -SecretName $ProGetApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop)
      if ([string]::IsNullOrWhiteSpace($adminApiKey)) { throw "Secret '$ProGetApiKeySecretName' did not resolve to a ProGet API key." }
      $headers = @{ Accept = 'application/json'; 'X-ApiKey' = $adminApiKey }
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
      $errorMessage = "Failed to retrieve API-key metadata from ProGet at $($apiEndpoint.AbsoluteUri). Verify connectivity and the configured SecretName."
      Write-PSFMessage -Level Error -Message $errorMessage -Tag 'List-ProGetApiKeys', 'Trace', 'Error'
      throw $errorMessage
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
    Write-PSFMessage -Level Verbose -Message 'Leaving function: List-ProGetApiKeys' -Tag 'List-ProGetApiKeys', 'Trace'
    return $results
  }
}
