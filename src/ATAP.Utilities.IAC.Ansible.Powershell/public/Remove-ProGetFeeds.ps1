# if called with the global preference variable 'ErrorActionPreference" set to 'SilentlyContinue', the
# code will keep trying to delete all Id in the parameter (array or pipeline)
#   otherwise it will throw if an error occurs when calling the apiEndPoint to delete
# if the global preference variable 'ErrorActionPreference" NOT set to 'SilentlyContinue'
#   the code will will throw if an error occurs when calling the apiEndPoint to delete
# ToDo: consider adding 'PassThrough' so that the function can return the objects passed into its pipeline
function Remove-ProGetFeeds {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    # ── BY-NAME PARAMETER SET ────────────────────────────────────────────
    [Parameter(
      ParameterSetName = 'ByName',
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      Mandatory = $true             # ← required only in ByName
    )]
    [Parameter(
      ParameterSetName = 'ByFeedSet',
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      Mandatory = $false            # ← optional when -UseFeedSet
    )]
    [string[]] $Name,

    # Common, optional connection details (available in both sets)
    [Parameter(ParameterSetName = 'ByName')]
    [Parameter(ParameterSetName = 'ByFeedSet')]
    [ValidateSet('http', 'https')]
    [string] $ProGetBaseScheme,

    [Parameter(ParameterSetName = 'ByName')]
    [Parameter(ParameterSetName = 'ByFeedSet')]
    [string]  $ProGetBaseHost,

    [Parameter(ParameterSetName = 'ByName')]
    [Parameter(ParameterSetName = 'ByFeedSet')]
    [int]     $ProGetBasePort,

    # ── BY-FEEDSET PARAMETER SET ─────────────────────────────────────────
    [Parameter(
      ParameterSetName = 'ByFeedSet',
      Mandatory = $true                # must be present to select this set
    )]
    [switch] $UseFeedSet
  )
  Begin {
    Write-PSFMessage -Level Verbose -Message 'Entering function: Remove-ProGetFeeds' -Tag 'Remove-ProGetFeeds', 'Trace'
    # if not passed, get from the environment variable. If not an environment variable fall back to the $global: value
    if ([string]::IsNullOrWhiteSpace($proGetBaseScheme)) {
      if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminUriSchemeConfigRootKey'], 'Process')) ) {
        if ([string]::IsNullOrWhiteSpace($global:Settings[$global:configRootKeys['ProGetAdminUriSchemeConfigRootKey']])) {
          $errorMessage = 'ProGetBaseScheme is not available.'
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Remove-ProGetFeeds', 'Trace', 'Error'
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
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Remove-ProGetFeeds', 'Trace', 'Error'
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
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Remove-ProGetFeeds', 'Trace', 'Error'
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
    # ToDo: consider allowing this function to administer multiple ProGet hosts, would need a $adminApiKey in the settings for each
    $adminApiKey = [Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminApiKeyConfigRootKey'], 'Process')
    if (-not $adminApiKey) {
      $errorMessage = 'ProGet adminAPI key is not available in environment variable.'
      Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Remove-ProGetFeeds', 'Trace', 'Error'
      throw $errorMessage
    }
    # The elements of the requests's headers are constant, so define them here
    $headers = @{
      'Accept'   = 'application/json'
      "X-ApiKey" = $adminApiKey
    }
    # The preamble to the page for the command to delete one feed in ProGet
    # ToDo: Move the constant portion of the page Uri  to list all ApiKeys into configroot and settings

    $proGetFeedDeletePagePreamble = 'api/management/feeds/delete'
    # Each call to ProGet API can only delete one feed at a time, and the api expects the feed's name as a part of the URi's Page,
    #  so the APIEndPoint will be constructed with the name inside the Process block

    $response = $null
    $DeletedNames = @{}

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

    # Define the function that deletes one feed
    function DeleteOneFeed {
      param (
        [string]$feedShortName
      )
      # The Page for the command to delete feeds in ProGet
      # ToDo: look into supporting different hosts for different feeds. Would need  to store a $ProGetBasePort for each host
      # ToDo: Move the constant part of the page for the command to create feeds into configroot and settings
      $proGetFeedDeletePage = "$proGetFeedDeletePagePreamble/$feedShortName"
      $proGetAPIpage = $proGetFeedDeletePage
      # Construct the API endpoint URL to delete a specific feed
      $apiEndPointBuilder = [UriBuilder]::new($proGetBaseScheme, $proGetBaseHost, $proGetBasePort, $proGetAPIpage, $null )
      $apiEndPoint = $apiEndPointBuilder.URI

      $body = @{
        feed = $feedShortName
      }
      if ($PSCmdlet.ShouldProcess("ProGet Feed [$feedShortName]", "Delete feed $feedShortName at $($apiEndPoint.AbsoluteUri)")) {

        # Make the API Call
        try {
          Write-PSFMessage -Level Verbose -Message "Calling ProGet API to delete feed '$feedShortName' " -Tag 'Remove-ProGetFeeds', 'Trace'
          $response = Invoke-RestMethod -Uri $apiEndPoint.AbsoluteUri -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 3) -ContentType "application/json"
          $DeletedNames[$feedShortName] = $true
          Write-PSFMessage -Level Verbose -Message "Successfully deleted feed '$feedShortName'" -Tag 'Remove-ProGetFeeds', 'Trace'
        }
        catch {
          $DeletedNames[$feedShortName] = $false
          if ($ErrorActionPreference -eq 'SilentlyContinue') {
            Write-PSFMessage -Level Verbose -Message "Failed to delete feed '$feedShortName'. Exception: $($_.Exception.Message)" -Tag 'Remove-ProGetFeeds', 'Trace', 'Error'
            continue
          }
          $errorMessage = "Failed to delete feed '$feedShortName'. Exception: $($_.Exception.Message)"
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Remove-ProGetFeeds', 'Trace', 'Error'
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
    # Either use the feed names defined in the global packageRepository, or use feed names from the pipeline
    if ($useFeedSet) {
      # If the UseFeedSet switch is set, get the feed names to delete from the global packageRepository
      Write-PSFMessage -Level Verbose -Message 'Using feed set to delete feeds' -Tag 'Remove-ProGetFeeds', 'Trace'
      $feedSetShortNames = @($global:settings[$global:ConfigRootKeys['PackageRepositoriesCollectionConfigRootKey']].Values | forEach-Object { $_['shortName'] })
      foreach ($feedShortName in $feedSetShortNames) {
        # Call the internal function to delete a single feed
        DeleteOneFeed $feedShortName
      }
    }
    else {
      Write-PSFMessage -Level Verbose -Message 'Using pipeline input to delete feeds'
      # Loop over the names specified in the input
      foreach ($feedShortName in $name) {
        # Call the internal function to delete a single feed
        DeleteOneFeed $feedShortName
      }
    }
  }

  End {
    if ($null -ne $savedErrorActionPreference) {
      $ErrorActionPreference = $savedErrorActionPreference
    }
    Write-PSFMessage -Level Verbose -Message 'Exiting function: Remove-ProGetFeeds' -Tag 'Remove-ProGetFeeds', 'Trace'
    return $DeletedNames
  }
}
