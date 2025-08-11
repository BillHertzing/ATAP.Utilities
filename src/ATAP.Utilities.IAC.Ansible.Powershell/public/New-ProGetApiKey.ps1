function New-ProGetApiKey {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory)]
    [string]$ApiKeyName,

    [Parameter(Mandatory)]
    [string]$FeedName,

    [Parameter(Mandatory)]
    [ValidateSet("view", "add", "delete", "promote")]
    [string[]]$PackagePermissions ,
    # If present, use it, but if not, let ProGet generate an API key
    [Parameter(Mandatory = $false)]
    [string]$apiKey,

    [Parameter(Mandatory = $false)]
    [ValidateSet('http', 'https')]
    [string]$proGetBaseScheme,
    [Parameter(Mandatory = $false)]
    [string]$proGetBaseHost,
    [Parameter(Mandatory = $false)]
    [int]$proGetBasePort
  )

  Begin {
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


    # ToDo: Fetch from Secrets vault instead of environment variable
    # TODo: Set and expiration date, and ensure a policy that rotates the key value before they expire
    $adminApiKey = [Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminApiKeyConfigRootKey'], 'Process')
    if (-not $adminApiKey) {
      $errorMessage = "ProGet admin API key is not available in environment variable."
      Write-PSFMessage -Level Error -Message $errorMessage -Tag 'New-ProGetApiKey', 'Trace', 'Error'
      throw $errorMessage
    }
    # The elements of the requests's headers are constant, so define them here
    $headers = @{
      'Accept'   = 'application/json'
      "X-ApiKey" = $adminApiKey
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
    if ($null -ne $apiKey) {
      $body.key = $apiKey
    }

    if ($PSCmdlet.ShouldProcess("ProGet", "Create API key '$ApiKeyName' for feed '$FeedName'")) {
      try {
        Write-PSFMessage -Level Verbose -Message "Calling ProGet API to create API key '$ApiKeyName' on port $ProGetBasePort" -Tag 'New-ProGetApiKey', 'Trace'
        $response = Invoke-RestMethod -Uri $apiEndPoint.AbsoluteUri -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 3) -ContentType "application/json"
        Write-PSFMessage -Level Important -Message "Successfully created API key '$ApiKeyName' for feed '$FeedName'" -Tag 'New-ProGetApiKey', 'Trace'
      }
      catch {
        $errorMessage = "Failed to create API key '$ApiKeyName'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
        throw $_
      }
      Write-PSFMessage -Level Verbose -Message "Leaving function: New-ProGetApiKey" -Tag 'New-ProGetApiKey', 'Trace'
      $response
    }
  }
  End {
    Write-PSFMessage -Level Verbose -Message 'Leaving function: New-ProGetApiKey' -Tag 'New-ProGetApiKey', 'Trace'
  }
}
