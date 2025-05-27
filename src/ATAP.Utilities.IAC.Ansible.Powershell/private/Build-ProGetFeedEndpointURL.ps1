
function Build-ProGetFeedEndpointURL {
  param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
    [string]$FeedName,
    [Parameter(Mandatory = $true)]
    [ValidateSet('http', 'https')]
    [string]$Scheme,
    [Parameter(Mandatory = $true)]
    [string]$HostName,
    [Parameter(Mandatory = $true)]
    [string]$Port,
    [ValidateSet('nuget', 'chocolatey', 'powershell')]
    [string]$ProGetFeedType,
    [string]$VersionType,
    [string]$PackageType,
    [string]$IndexSuffix = '/v3/index.json'
  )

  # ToDo: rewrite so that $IndexSuffix is a different parameter set, and a non-blank value generates a v3 endpoint URL
  Write-PSFMessage -Level Verbose -Message "Entering function: Build-ProGetFeedEndpointURL"
  # ToDo: eventually move those suffixes into IAC
  $versionTypePageComponent = if ([string]::IsNullOrWhiteSpace($VersionType) ) { '' } else { "$versionType/" }
  $packageTypePageComponent = if ([string]::IsNullOrWhiteSpace($PackageType) ) { '' } else { "$PackageType/" }
  $proGetFeedTypePageComponent = "$ProGetFeedType/"
  $feedNamePageComponent = "$FeedName/"
  # $IndexSuffix is used for the NuGet v3 endpoint, but not for the v2 endpoint
  #IndexSuffix is used for the NuGet v3 endpoint, but not for the v2 endpoint


  switch ($proGetFeedType) {
    'nuget' {
      # Add the index suffix here if it is a passed parameter (detected by the different paramaterset)
      $endpointUrl = "${Scheme}://${HostName}:$Port/$versionTypePageComponent$packageTypePageComponent$proGetFeedTypePageComponent$feedNamePageComponent"

    }
    'chocolatey' {
      $endpointUrl = "${Scheme}://${HostName}:$Port/$versionTypePageComponent$packageTypePageComponent$proGetFeedTypePageComponent$feedNamePageComponent"
    }
    'powershell' {
      $endpointUrl = "${Scheme}://${HostName}:$Port/$versionTypePageComponent$packageTypePageComponent$proGetFeedTypePageComponent$feedNamePageComponent"
    }
    default {
      $errorMessage = "Unknown feed type: $proGetFeedType"
      Write-PSFMessage -Level Error -Message $errorMessage
      throw $errorMessage
    }
  }
  Write-PSFMessage -Level Verbose -Message "Exiting function: Build-ProGetFeedEndpointURL with URL: $endpointUrl"
  return $endpointUrl
}

