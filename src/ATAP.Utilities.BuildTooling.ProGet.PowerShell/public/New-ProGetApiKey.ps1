function New-ProGetApiKey {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory)]
    [string]$ApiKeyName,

    [Parameter(Mandatory)]
    [string]$FeedName,

    [Parameter(Mandatory)]
    [ValidateSet('view', 'add', 'delete', 'promote')]
    [string[]]$PackagePermissions ,

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

    Write-PSFMessage -Level Verbose -Message "Entering function: New-ProGetApiKey" -Tag 'New-ProGetApiKey', 'Trace'
    # if not passed, get from the environment variable. If not an environment variable fall back to the $global: value
    if ([string]::IsNullOrWhiteSpace($proGetBaseScheme)) {
      if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminUriSchemeConfigRootKey'], 'Process')) ) {
        if ([string]::IsNullOrWhiteSpace($global:Settings[$global:configRootKeys['ProGetAdminUriSchemeConfigRootKey']])) {
          $errorMessage = 'ProGetBaseScheme is not available.'
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'New-ProGetApiKey', 'Trace', 'Error'
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
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'New-ProGetApiKey', 'Trace', 'Error'
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
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'New-ProGetApiKey', 'Trace', 'Error'
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
    $progetApiKeysCreatePage = 'api/api-keys/create'
    $proGetAPIpage = $progetApiKeysCreatePage
    # Construct the API endpoint URL to list all API keys
    $apiEndPoint = [UriBuilder]::new($proGetBaseScheme, $proGetBaseHost, $proGetBasePort, $proGetAPIpage, $null ).URI
  }
  Process {

    $body = @{
      type               = 'Feed'
      keyName            = $ApiKeyName
      displayName        = $ApiKeyName
      description        = "API key for $FeedName"
      feed               = $FeedName
      feedGroup          = $null
      packagePermissions = $PackagePermissions
    }
    if ($PSCmdlet.ShouldProcess("ProGet", "Create API key '$ApiKeyName' for feed '$FeedName'")) {
      try {
        if (-not (Get-Command Get-SecretATAP -ErrorAction SilentlyContinue)) { throw 'Get-SecretATAP is required for ProGet authentication.' }
        $adminApiKey = [string](Get-SecretATAP -SecretName $ProGetApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop)
        if ([string]::IsNullOrWhiteSpace($adminApiKey)) { throw "Secret '$ProGetApiKeySecretName' did not resolve to a ProGet API key." }
        $headers = @{ Accept = 'application/json'; 'X-ApiKey' = $adminApiKey }
        Write-PSFMessage -Level Verbose -Message "Calling ProGet API to create API key '$ApiKeyName' on port $ProGetBasePort" -Tag 'New-ProGetApiKey', 'Trace'
        $response = Invoke-RestMethod -Uri $apiEndPoint.AbsoluteUri -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 3) -ContentType "application/json"
        Write-PSFMessage -Level Important -Message "Successfully created API key '$ApiKeyName' for feed '$FeedName'" -Tag 'New-ProGetApiKey', 'Trace'
      }
      catch {
        $errorMessage = "Failed to create API key '$ApiKeyName'. Verify connectivity and the configured SecretName."
        Write-PSFMessage -Level Error -Message $errorMessage
        throw $errorMessage
      }
      Write-PSFMessage -Level Verbose -Message "Leaving function: New-ProGetApiKey" -Tag 'New-ProGetApiKey', 'Trace'
      [PSCustomObject]@{ ApiKeyName = $ApiKeyName; FeedName = $FeedName; Created = $true }
    }
  }
  End {
    Write-PSFMessage -Level Verbose -Message 'Leaving function: New-ProGetApiKey' -Tag 'New-ProGetApiKey', 'Trace'
  }
}
