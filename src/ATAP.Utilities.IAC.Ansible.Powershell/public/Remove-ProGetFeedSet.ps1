function Remove-ProGetFeedSet {
  [CmdletBinding(SupportsShouldProcess = $true)]
  # ToDo: accept an array of strings that match the $feedNames that should be deleted.If the array is empty, delete all
  #  ToDo:  Internal, non-Filesystem feeds
  param (  )
  Write-PSFMessage -Level Verbose -Message 'Entering function: Remove-ProGetFeedSet'

  # $adminApiKey is used to authenticate an admin role to ProGet
  # ToDo: Fetch from Secrets vault instead of environment variable
  # ToDo: consider allowing this function to setup feeds on multiple proget hosts, would need a $adminApiKey in the settings for each
  $adminApiKey = [Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminApiKeyConfigRootKey'], 'Process')
  if (-not $adminApiKey) {
    $errorMessage = 'ProGet admin API key is not available in environment variable.'
    Write-PSFMessage -Level Error -Message $errorMessage
    throw $errorMessage
  }

  # ToDo: consider allowing this function to setup feeds on multiple proget hosts, would need a $ProGetBasePort in the settings for each
  $ProGetBasePort = $global:Settings[$global:configRootKeys['ProGetAdminApiKeyUriPortConfigRootKey']]

  # ToDo: When accepting an array of feed names to delete, ensure the feed names exist in the collection

  $feedNames = $global:settings[$global:ConfigRootKeys['PackageRepositoriesCollectionConfigRootKey']].keys | Where-Object { ($_ -match 'PackageRepositoryInternal' ) -and ($_ -notmatch 'Filesystem' ) }
  for ($feedNamesIndex = 0; $feedNamesIndex -lt $feedNames.Count; $feedNamesIndex++) {
    $feedName = $feedNames[$feedNamesIndex]

    $feed = $($global:settings[$global:ConfigRootKeys['PackageRepositoriesCollectionConfigRootKey']][$feedName])
    # ToDo: look into supporting different hosts for different feeds. Would need  to store a $ProGetBasePort for each host
    # This is the URI for deleting feeds in ProGet
    $feedAdministrationUri = "http://$($feed.Uri.host):$ProGetBasePort/api/management/feeds/delete/$($feed.ShortName)"
    $body = @{
      feed = $feed.ShortName
    }
    $headers = @{ 'X-ApiKey' = $adminApiKey }
    $responses = @()
    # If the function parameter $feednames is empty (means to delete all feeds), the ignore errors in the deletion
    $savedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    if ($PSCmdlet.ShouldProcess("ProGet Feed [$($feed.ShortName)]", "Delete feed $($feed.ShortName) at $($feed.Uri.Scheme)://$($feed.Uri.host):$($feed.Uri.port) ")) {
      try {
        Write-PSFMessage -Level Verbose -Message "Calling ProGet API to delete feed '$feedShortName' on port $ProGetBasePort"
        $response = Invoke-RestMethod -Uri $feedAdministrationUri -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 3) -ContentType "application/json"
        Write-PSFMessage -Level Verbose -Message "Successfully deleted feed '$($feed.ShortName)'"
        $responses += $response | ConvertFrom-Json
      }
      catch {
        if ($ErrorActionPreference -eq 'SilentlyContinue') {
          Write-PSFMessage -Level Verbose -Message "Failed to delete feed '$($feed.ShortName)'. Exception: $($_.Exception.Message)"
          continue
        }
        $errorMessage = "Failed to delete feed '$($feed.ShortName)'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -Level Error -Message $errorMessage
        # ToDO: exception handling should wrap then throw, not just throw with only the error message
        throw $errorMessage
      }

      finally {
        $ErrorActionPreference = $savedErrorActionPreference
      }
    }
  }
  # ensure that an array is returned, even if it is empty or only has a single element
  @(, $responses)
}
