function New-ProGetFeedSet {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [int]$BasePort = 50025
  )

  Write-PSFMessage -Level Verbose -Message "Entering function: New-ProGetFeedSet"

  $feedNames = @(
    "ReleasedProduction",
    "ReleasedQualityAssurance",
    "PrereleaseProduction",
    "PrereleaseQualityAssurance"
  )

  $feedTypes = @("PowerShell v3", "Chocolatey")
  $counter = 0

  # ToDo: Fetch from Secrets vault instead of environment variable
  $adminApiKey = [Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminApiKeyConfigRootKey'], 'Process')

  if (-not $adminApiKey) {
    $errorMessage = "ProGet admin API key is not available in environment variable."
    Write-PSFMessage -Level Error -Message $errorMessage
    throw $errorMessage
  }

  foreach ($feedType in $feedTypes) {
    foreach ($feedName in $feedNames) {
      $port = $BasePort + $counter
      $uri = "http://localhost:$port/api/feeds"

      $body = @{
        FeedName             = $feedName
        FeedType             = $feedType
        Description          = "$feedType feed: $feedName"
        AllowAnonymousAccess = $true
      }

      $headers = @{ "X-ApiKey" = $adminApiKey }

      if ($PSCmdlet.ShouldProcess("ProGet Feed [$feedName]", "Create on port $port as type '$feedType'")) {
        try {
          Write-PSFMessage -Level Verbose -Message "Attempting to create feed '$feedName' of type '$feedType' on port $port"
          Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 3) -ContentType "application/json"
          Write-PSFMessage -Level Important -Message "Successfully created feed '$feedName' on port $port as type '$feedType'"
        }
        catch {
          $errorMessage = "Failed to create feed '$feedName' on port $port. Exception: $($_.Exception.Message)"
          Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
          throw $_
        }
      }
      $counter++
    }
  }

  Write-PSFMessage -Level Verbose -Message "Exiting function: New-ProGetFeedSet"
}
