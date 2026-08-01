#region Resolve-ProGetFeedFromSettings
function Resolve-ProGetFeedTierName {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)]
    [string]$Tier
  )

  $tierMap = @{
    'sprint'       = 'experimental'
    'experimental' = 'experimental'
    'alpha'        = 'development'
    'development'  = 'development'
    'beta'         = 'integration'
    'integration'  = 'integration'
    'qa'           = 'qa'
    'production'   = 'stable'
    'stable'       = 'stable'
  }

  $normalizedTier = $Tier.Trim().ToLowerInvariant()
  if (-not $tierMap.ContainsKey($normalizedTier)) {
    throw "Unknown ProGet tier '$Tier'. Expected one of Sprint, Alpha, Beta, QA, Production, or canonical tier names."
  }

  return $tierMap[$normalizedTier]
}

function Resolve-ProGetFeedTypeName {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)]
    [string]$FeedType
  )

  $feedTypeMap = @{
    'nuget'         = 'nuget'
    'powershell'    = 'powershellget'
    'powershellget' = 'powershellget'
    'psresourceget' = 'powershellget'
    'database'      = 'database'
    'chocolatey'    = 'chocolatey'
    'universal'     = 'universal'
    'upack'         = 'universal'
  }

  $normalizedFeedType = $FeedType.Trim().ToLowerInvariant()
  if (-not $feedTypeMap.ContainsKey($normalizedFeedType)) {
    throw "Unknown ProGet feed type '$FeedType'. Expected nuget, powershellget, database, chocolatey, or universal."
  }

  return $feedTypeMap[$normalizedFeedType]
}

function Get-ProGetFeedSettingProperty {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [object]$Feed,

    [Parameter(Mandatory)]
    [string]$Name
  )

  if ($Feed -is [System.Collections.IDictionary]) {
    return $Feed[$Name]
  }

  return $Feed.PSObject.Properties[$Name].Value
}

function Get-ProGetFeedCollectionFromSettings {
  [CmdletBinding()]
  [OutputType([hashtable])]
  param()

  if ($null -eq $global:Settings) {
    throw '$global:Settings is not initialized. Load host settings before resolving ProGet feed metadata.'
  }

  if ($null -eq $global:configRootKeys) {
    throw '$global:configRootKeys is not initialized. Load config root keys before resolving ProGet feed metadata.'
  }

  $collectionKey = $global:configRootKeys['ProGetFeedCollectionConfigRootKey']
  if ([string]::IsNullOrWhiteSpace($collectionKey)) {
    throw "Config root key 'ProGetFeedCollectionConfigRootKey' is not defined."
  }

  $feedCollection = $global:Settings[$collectionKey]
  if ($null -eq $feedCollection) {
    throw "ProGet feed collection is not present in `$global:Settings under key '$collectionKey'."
  }

  return $feedCollection
}

function Resolve-ProGetFeedFromSettings {
  <#
  .SYNOPSIS
  Resolves canonical ProGet feed metadata from `$global:Settings.

  .DESCRIPTION
  Reads the ProGetFeedCollection populated by the host settings package-repository
  fragment and returns the feed entry matching the requested feed type and tier.
  This implements the feed metadata access pattern described in Explainer 0111:
  feed names and URLs come from $global:Settings, not from ATAP.IAC PSD1 constants
  or Get-ATAPIACConstant.

  .PARAMETER FeedType
  Feed type to resolve. 'powershell' is accepted as a compatibility alias for
  the canonical 'powershellget' feed type.

  .PARAMETER Tier
  Tier to resolve. Legacy PowerShell build tier names Sprint, Alpha, Beta, QA,
  and Production are accepted and normalized to experimental, development,
  integration, qa, and stable.

  .OUTPUTS
  PSCustomObject with ConfigKey, FeedName, FeedType, Tier, Uri, NuGetV3Uri,
  EndpointUri, ApiKeyName, Connectors, and RetentionPolicy.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [string]$FeedType,

    [Parameter(Mandatory)]
    [string]$Tier
  )

  $canonicalFeedType = Resolve-ProGetFeedTypeName -FeedType $FeedType
  $canonicalTier = Resolve-ProGetFeedTierName -Tier $Tier
  $feedCollection = Get-ProGetFeedCollectionFromSettings

  foreach ($feedKey in $feedCollection.Keys) {
    $feed = $feedCollection[$feedKey]
    $entryFeedType = [string](Get-ProGetFeedSettingProperty -Feed $feed -Name 'FeedType')
    $entryTier = [string](Get-ProGetFeedSettingProperty -Feed $feed -Name 'Tier')

    if ((Resolve-ProGetFeedTypeName -FeedType $entryFeedType) -ne $canonicalFeedType) {
      continue
    }
    if ((Resolve-ProGetFeedTierName -Tier $entryTier) -ne $canonicalTier) {
      continue
    }

    $feedName = [string](Get-ProGetFeedSettingProperty -Feed $feed -Name 'FeedName')
    $uri = Get-ProGetFeedSettingProperty -Feed $feed -Name 'Uri'
    $nugetV3Uri = [string](Get-ProGetFeedSettingProperty -Feed $feed -Name 'NuGetV3Uri')
    $endpointUri = if (-not [string]::IsNullOrWhiteSpace($nugetV3Uri)) {
      $nugetV3Uri
    } elseif ($null -ne $uri) {
      [string]$uri
    } else {
      $null
    }

    if ([string]::IsNullOrWhiteSpace($feedName) -or [string]::IsNullOrWhiteSpace($endpointUri)) {
      throw "ProGet feed entry '$feedKey' for '$canonicalFeedType/$canonicalTier' is missing FeedName or endpoint URI."
    }

    return [PSCustomObject]@{
      ConfigKey       = [string]$feedKey
      FeedName        = $feedName
      FeedType        = $canonicalFeedType
      Tier            = $canonicalTier
      Uri             = $uri
      NuGetV3Uri      = $nugetV3Uri
      EndpointUri     = $endpointUri
      ApiKeyName      = [string](Get-ProGetFeedSettingProperty -Feed $feed -Name 'ApiKeyName')
      Connectors      = Get-ProGetFeedSettingProperty -Feed $feed -Name 'Connectors'
      RetentionPolicy = Get-ProGetFeedSettingProperty -Feed $feed -Name 'RetentionPolicy'
    }
  }

  throw "No ProGet feed entry found in `$global:Settings for feed type '$canonicalFeedType' and tier '$canonicalTier'."
}

function Resolve-ProGetBaseUrlFromSettings {
  [CmdletBinding()]
  [OutputType([string])]
  param()

  if ($null -eq $global:Settings) {
    throw '$global:Settings is not initialized. Load host settings before resolving ProGetBaseUrl.'
  }

  if ($null -eq $global:configRootKeys) {
    throw '$global:configRootKeys is not initialized. Load config root keys before resolving ProGetBaseUrl.'
  }

  $baseUrlKey = $global:configRootKeys['ProGetBaseUrlConfigRootKey']
  if (-not [string]::IsNullOrWhiteSpace($baseUrlKey)) {
    $baseUrl = [string]$global:Settings[$baseUrlKey]
    if (-not [string]::IsNullOrWhiteSpace($baseUrl)) {
      return $baseUrl.TrimEnd('/')
    }
  }

  $scheme = [string]$global:Settings[$global:configRootKeys['ProGetAdminUriSchemeConfigRootKey']]
  $hostName = [string]$global:Settings[$global:configRootKeys['ProGetAdminUriHostConfigRootKey']]
  $port = $global:Settings[$global:configRootKeys['ProGetAdminUriPortConfigRootKey']]

  if ([string]::IsNullOrWhiteSpace($scheme) -or [string]::IsNullOrWhiteSpace($hostName) -or $null -eq $port) {
    throw 'ProGet base URL could not be resolved from $global:Settings.'
  }

  return ([UriBuilder]::new($scheme, $hostName, [int]$port)).Uri.AbsoluteUri.TrimEnd('/')
}

#endregion Resolve-ProGetFeedFromSettings
