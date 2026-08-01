function New-ProGetConnector {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [hashtable]$connector,
    [Parameter(Mandatory = $false)]
    [ValidateSet('http', 'https')]
    [string]$proGetBaseScheme,
    [Parameter(Mandatory = $false)]
    [string]$proGetBaseHost,
    [Parameter(Mandatory = $false)]
    [int]$proGetBasePort,
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

    Write-PSFMessage -Level Verbose -Message 'Entering function: New-ProGetConnector' -Tag 'New-ProGetConnector', 'Trace'
    # ToDo: Remove this when packaging works
    #  if (-not (Get-Command -Name 'List-ProGetConnectors' -CommandType Function -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\List-ProGetConnectors.ps1"
    # }
    if (-not (Get-Command -Name 'Convert-ProGetFeedType' -CommandType Function -ErrorAction SilentlyContinue)) {
      . "$PSScriptRoot\..\private\Convert-ProGetFeedType.ps1"
    }

    # if not passed, get from the environment variable. If not an environment variable fall back to the $global: value
    if ([string]::IsNullOrWhiteSpace($proGetBaseScheme)) {
      if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminUriSchemeConfigRootKey'], 'Process')) ) {
        if ([string]::IsNullOrWhiteSpace($global:Settings[$global:configRootKeys['ProGetAdminUriSchemeConfigRootKey']])) {
          $errorMessage = 'ProGetAdminUriScheme is not available.'
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
        $proGetBaseHost = [Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminUriHostConfigRootKey'], 'Process')
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

    # The Page for the command to create connectors in ProGet
    # ToDo: Move the page for the command to create feeds into configroot and settings
    $progetApiKeysCreatePage = 'api/management/connectors/create'
    $proGetAPIpage = $progetApiKeysCreatePage
    # Construct the API endpoint URL to create connectors
    $apiEndPoint = [UriBuilder]::new($proGetBaseScheme, $proGetBaseHost, $proGetBasePort, $proGetAPIpage, $null ).URI

    $connectorCreationResults = $null

  }

  Process {
    if (-not $PSCmdlet.ShouldProcess("ProGet Connector [$($connector.name)]", "Create connector with URL $($connector.url)")) {
      return
    }

    # ProGet connector names must be unique. Query only after the mutation gate so
    # -WhatIf performs no secret resolution and no REST calls.
    $currentConnectors = List-ProGetConnectors -proGetBaseScheme $proGetBaseScheme -proGetBaseHost $proGetBaseHost -proGetBasePort $proGetBasePort -ProGetApiKeySecretName $ProGetApiKeySecretName

    # Create the connector defined for the specific feedname unless a connector by that name already exists
    if ($currentConnectors | Where-Object { $_.name -eq $connector.name }) {
      Write-PSFMessage -Level Warning -Message "A connector with the name $($connector.name) already exists. Skipping creation of connector." -Tag 'New-ProGetConnector', 'Trace', 'Warning'
      return
    }

    # ToDo: look into supporting different hosts for different feeds. Would need to store a $ProGetBaseScheme/Host/Port for each host

    $body = @{
      name        = $connector.name
      feedType    = Convert-ProGetFeedType -FeedType $connector.feedType
      Url         = $connector.url
      enabled     = $connector.enabled
      description = $connector.description
    }

    try {
      if (-not (Get-Command Get-SecretATAP -ErrorAction SilentlyContinue)) { throw 'Get-SecretATAP is required for ProGet authentication.' }
      $adminApiKey = [string](Get-SecretATAP -SecretName $ProGetApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop)
      if ([string]::IsNullOrWhiteSpace($adminApiKey)) { throw "Secret '$ProGetApiKeySecretName' did not resolve to a ProGet API key." }
      $headers = @{ Accept = 'application/json'; 'X-ApiKey' = $adminApiKey }
      Write-PSFMessage -Level Verbose -Message "Attempting to Create Connector $($connector.name) of feedType $($body.feedType) with URL $($connector.url)" -Tag 'New-ProGetConnector', 'Trace'
      $connectorCreationResults = Invoke-RestMethod -Uri $apiEndPoint.AbsoluteUri -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 3) -ContentType 'application/json'
      Write-PSFMessage -Level Verbose -Message "Successfully created Connector $($connector.name)" -Tag 'New-ProGetConnector', 'Trace'
    }
    catch {
      $errorMessage = "Failed to create connector $($connector.name). Verify connectivity and the configured SecretName."
      Write-PSFMessage -Level Error -Message $errorMessage -Tag 'New-ProGetConnector', 'Trace', 'Error'
      throw $errorMessage
    }
  }

  End {
    Write-PSFMessage -Level Verbose -Message 'Leaving function: New-ProGetConnector' -Tag 'New-ProGetConnector', 'Trace'
  }
}
