# if called with the global preference variable 'ErrorActionPreference" set to 'SilentlyContinue', the
# code will keep trying to delete all Id in the parameter (array or pipeline)
#   otherwise it will throw if an error occurs when calling the apiEndPoint to delete
# if the global preference variable 'ErrorActionPreference" NOT set to 'SilentlyContinue'
#   the code will will throw if an error occurs when calling the apiEndPoint to delete
# ToDo: consider adding 'PassThrough' so that the function can return the objects passed into its pipeline
function Remove-ProGetApiKeys {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [int[]] $iD,
    [Parameter(Mandatory = $false)]
    [ValidateSet('http', 'https')]
    [string]$proGetBaseScheme,
    [Parameter(Mandatory = $false)]
    [string]$proGetBaseHost,
    [Parameter(Mandatory = $false)]
    [int]$proGetBasePort,
    [switch]$useFeedSet,
    [ValidateNotNullOrEmpty()]
    [string]$ProGetApiKeySecretName = 'ProGet.Admin.API.Key'
  )
  Begin {
    Write-PSFMessage -Level Verbose -Message 'Entering function: Remove-ProGetApiKeys' -Tag 'Remove-ProGetApiKeys', 'Trace'
    # if not passed, get from the environment variable. If not an environment variable fall back to the $global: value
    if ([string]::IsNullOrWhiteSpace($proGetBaseScheme)) {
      if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminUriSchemeConfigRootKey'], 'Process')) ) {
        if ([string]::IsNullOrWhiteSpace($global:Settings[$global:configRootKeys['ProGetAdminUriSchemeConfigRootKey']])) {
          $errorMessage = 'ProGetBaseScheme is not available.'
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Remove-ProGetApiKeys', 'Trace', 'Error'
          throw $errorMessage
        }
        else {
          $proGetBaseScheme = $global:Settings[$global:configRootKeys['ProGetAdminUriSchemeConfigRootKey']]
        }
      }
      else {
        $proGetBaseScheme = [Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminUriSchemeConfigRootKey'], 'Process')
      }
    }

    # if not passed, get from the environment variable. If not an environment variable fall back to the $global: value
    if ([string]::IsNullOrWhiteSpace($proGetBaseHost)) {
      if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminUriHostConfigRootKey'], 'Process')) ) {
        if ([string]::IsNullOrWhiteSpace($global:Settings[$global:configRootKeys['ProGetAdminUriHostConfigRootKey']])) {
          $errorMessage = 'proGetBaseHost is not available.'
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Remove-ProGetApiKeys', 'Trace', 'Error'
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
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Remove-ProGetApiKeys', 'Trace', 'Error'
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
    # The Page for the command to delete one API key in ProGet
    # ToDo: Move the constant portion of the page Uri  to list all ApiKeys into configroot and settings
    $proGetDeleteApisPage = 'api/api-keys/delete/'
    $proGetAPIpage = $proGetDeleteApisPage
    # Each call to ProGet API can only delete one API key at a time, and the api expects the ID in a query_string,
    #  so the APIEndPoint will be constructed with the ID inside the Process block

    $response = $null
    $DeletedIds = @{}

    # If the function is passed a single argument
    # If the function is passed an array
    # if the function is getting input from a pipeline
    # if the UseFeedSet switch is true, then the function will delete all the ApiKeys in the packageRepository
    # if the function is getting input from a pipeline, then the $iD parameter will be empty, and the code will delete all the ApiKeys in the packageRepository
    # if the function is passed an array, then it will delete all the ApiKeys in that array
    # if the function is passed a single argument, then it will delete that single ApiKey
    # if the
    #parameter $id is empty (means to delete all feeds), then ignore errors in the deletion
    $savedErrorActionPreference = $null
    if ($ErrorActionPreference -ne 'SilentlyContinue') {
      $savedErrorActionPreference = $ErrorActionPreference
      $ErrorActionPreference = 'SilentlyContinue'
    }

    # Define the function that deletes one ApiKey
    function DeleteOneApiKey {
      param (
        [int]$apiKeyId
      )
      # The Page for the command to delete ApiKeys in ProGet
      # ToDo: look into supporting different hosts for different feeds. Would need  to store a $ProGetBasePort for each host
      # ToDo: Move the constant part of the page for the command to create feeds into configroot and settings

      # Construct the API endpoint URL to delete the ApiKey
      $apiEndPointBuilder = [UriBuilder]::new($proGetBaseScheme, $proGetBaseHost, $proGetBasePort, $proGetAPIpage)
      $apiEndPointBuilder.Query = "id=$apiKeyId"
      $apiEndPoint = $apiEndPointBuilder.URI

      if ($PSCmdlet.ShouldProcess("ProGet ApiKey [$($apiKeyId)]", "Delete ApiKey $($apiKeyId) at $($apiEndPoint.AbsoluteUri)")) {

        # Make the API Call
        try {
          if (-not (Get-Command Get-SecretATAP -ErrorAction SilentlyContinue)) { throw 'Get-SecretATAP is required for ProGet authentication.' }
          $adminApiKey = [string](Get-SecretATAP -SecretName $ProGetApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop)
          if ([string]::IsNullOrWhiteSpace($adminApiKey)) { throw "Secret '$ProGetApiKeySecretName' did not resolve to a ProGet API key." }
          $headers = @{ Accept = 'application/json'; 'X-ApiKey' = $adminApiKey }
          Write-PSFMessage -Level Verbose -Message "Calling ProGet API to delete ApiKey '$apiKeyId'" -Tag 'Remove-ProGetApiKeys', 'Trace'
          $response = Invoke-RestMethod -Uri $apiEndPoint.AbsoluteUri -Method Delete -Headers $headers
          $DeletedIds[$apiKeyId] = $true
          Write-PSFMessage -Level Verbose -Message "Successfully deleted ApiKey '$apiKeyId'" -Tag 'Remove-ProGetApiKeys', 'Trace'
        }
        catch {
          $DeletedIds[$apiKeyId] = $false
          if ($ErrorActionPreference -eq 'SilentlyContinue') {
            Write-PSFMessage -Level Verbose -Message "Failed to delete API-key metadata $apiKeyId. Verify connectivity and the configured SecretName." -Tag 'Remove-ProGetApiKeys', 'Trace', 'Error'
            continue
          }
          $errorMessage = "Failed to delete API-key metadata '$apiKeyId'. Verify connectivity and the configured SecretName."
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Remove-ProGetApiKeys', 'Trace', 'Error'
          # ToDO: exception handling should wrap then throw, not just throw with only the error message
          throw $errorMessage
        }
        finally {
          if ($null -ne $savedErrorActionPreference) {
            $ErrorActionPreference = $savedErrorActionPreference
          }
        }
      }
    }
  }
  Process {
    # Either use the ApiKey Ids associated with the feed names defined in the global packageRepository, or use apiKeyIds from the pipeline
    if ($useFeedSet) {
      # If the UseFeedSet switch is set, return the ApiKeys as a set
      Write-PSFMessage -Level Verbose -Message 'Using feed set to delete ApiKeys' -Tag 'Remove-ProGetApiKeys', 'Trace'
      $feedsSetApiKeyIds = @($global:settings[$global:ConfigRootKeys['PackageRepositoriesCollectionConfigRootKey']].Values | forEach-Object { $_['ApiKey'] })
      foreach ($apiKeyId in $feedsSetApiKeyIds) {
        # Call the internal function to delete a single ApiKey
        DeleteOneApiKey -apiKeyId $apiKeyId
      }
    }
    else {
      Write-PSFMessage -Level Verbose -Message 'Using pipeline input to delete ApiKeys'
      # Loop over the APIKeys specified in the input
      foreach ($apiKeyId in $iD) {

        # Call the internal function to delete a single ApiKey
        DeleteOneApiKey -apiKeyId $apiKeyId
      }
    }
  }

  End {
    if ($null -ne $savedErrorActionPreference) {
      $ErrorActionPreference = $savedErrorActionPreference
    }
    Write-PSFMessage -Level Verbose -Message 'Leaving function: Remove-ProGetApiKeys' -Tag 'Remove-ProGetApiKeys', 'Trace'
    return $DeletedIds
  }
}
