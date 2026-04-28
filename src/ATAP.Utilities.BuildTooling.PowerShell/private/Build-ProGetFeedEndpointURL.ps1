
function Build-ProGetFeedEndpointURL {
  param (
    [Parameter(Mandatory = $true)]
    [ValidateSet('http', 'https')]
    [string]$Scheme,
    [Parameter(Mandatory = $true)]
    [string]$HostName,
    [Parameter(Mandatory = $true)]
    [string]$Port,
    [Parameter(Mandatory = $true)]
    #ToDo: ensure the page starts with one of the following ('nuget', 'chocolatey', 'powershell')
    [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
    [string]$Page
  )

  # ToDo: rewrite so that $IndexSuffix is a different parameter set, and a non-blank value generates a v3 endpoint URL
  Write-PSFMessage -Level Verbose -Message "Entering function: Build-ProGetFeedEndpointURL"
  # ToDo: eventually move those suffixes into IAC
  # $versionTypePageComponent = if ([string]::IsNullOrWhiteSpace($VersionType) ) { '' } else { "$versionType/" }
  # $packageTypePageComponent = if ([string]::IsNullOrWhiteSpace($PackageType) ) { '' } else { "$PackageType/" }
  # $proGetFeedTypePageComponent = "$ProGetFeedType/"
  # $feedNamePageComponent = "$FeedName/"
  # $IndexSuffix is used for the NuGet v3 endpoint, but not for the v2 endpoint
  #IndexSuffix is used for the NuGet v3 endpoint, but not for the v2 endpoint

  # pull the ProGet feed type from the page parameter
  $proGetFeedType = $Page -replace '^([a-z]+)(/.*)?$', '$1'

  switch ($proGetFeedType) {
    'nuget' {
      # Add the index suffix here if it is a passed parameter (detected by the different paramaterset)
      $endpointUrl = "${Scheme}://${HostName}:$Port/$Page"

    }
    'chocolatey' {

      $endpointUrl = "${Scheme}://${HostName}:$Port/$Page"
      #$endpointUrl = "${Scheme}://${HostName}:$Port/$versionTypePageComponent$packageTypePageComponent$proGetFeedTypePageComponent$feedNamePageComponent"
    }
    'powershell' {
      $endpointUrl = "${Scheme}://${HostName}:$Port/$Page"
      #$endpointUrl = "${Scheme}://${HostName}:$Port/$versionTypePageComponent$packageTypePageComponent$proGetFeedTypePageComponent$feedNamePageComponent"
    }
    default {
      $errorMessage = "Unknown feed type: $proGetFeedType"
      Write-PSFMessage -Level Error -Message $errorMessage
      throw $errorMessage
    }
  }
  Write-PSFMessage -Level Verbose -Message "Leaving function: Build-ProGetFeedEndpointURL with URL: $endpointUrl"
  return $endpointUrl
}

