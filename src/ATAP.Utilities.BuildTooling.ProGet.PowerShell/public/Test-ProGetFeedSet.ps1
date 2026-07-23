function Test-ProGetFeedSet {
  [CmdletBinding()]
  param (
  )

  Write-PSFMessage -Level Verbose -Message 'Entering function: Test-ProGetFeedSet' -Tag 'Test-ProGetFeedSet', 'Trace'

  # call List-ProGetFeeds to get the feeds
  $proGetFeeds = List-ProGetFeeds -ErrorAction Stop
  if ($proGetFeeds.count -eq 0) {
    $errorMessage = 'No feeds found in ProGet.'
    Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Test-ProGetFeedSet', 'Trace', 'Error'
    throw $errorMessage
  }

  # Get the expected feed names from the global settings
  $expectedFeedNames = $global:settings[$global:ConfigRootKeys['PackageRepositoriesCollectionConfigRootKey']].keys | Where-Object { $_ -match 'PackageRepositoryInternal' }
  $expectedFeedShortNames = $expectedFeedNames | ForEach-Object {
    $feedName = $_
    $shortFeedName = $($global:settings[$global:ConfigRootKeys['PackageRepositoriesCollectionConfigRootKey']][$feedName]).ShortName
  }

  # The keys to the $proGetFeeds object are feed ShortNames, so ensure that every expected feed is present in the proGetFeeds object
  $missingFeeds = @()
  foreach ($expectedFeedShortName in $expectedFeedShortNames) {
    if (-not $proGetFeeds.ContainsKey($expectedFeedShortName)) {
      # accumulate the list of missing feeds
      $missingFeeds += $expectedFeedShortName
    }
  }
  if ($missingFeeds.Count -gt 0) {
    $errorMessage = "The following expected feeds are missing from ProGet: $($missingFeeds -join ', ')"
    Write-PSFMessage -Level Verbose -Message $errorMessage -Tag 'Test-ProGetFeedSet', 'Trace', 'Error'
  }
  $results = [PSCustomObject]@{
    Success      = $missingFeeds.Count -eq 0
    MissingFeeds = $missingFeeds
    ProGetFeeds  = $proGetFeeds
  }
  Write-PSFMessage -Level Verbose -Message 'Leaving function: Test-ProGetFeedSet' -Tag 'Test-ProGetFeedSet', 'Trace'
  return $results
}
