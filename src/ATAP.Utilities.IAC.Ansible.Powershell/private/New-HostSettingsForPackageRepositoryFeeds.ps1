# ToDo: Move this function over to the Powershell.IAC module
function Get-PackageRepositoryFeedShortName {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$ExternalInternal, # 'External' or 'Internal'
    [Parameter(Mandatory = $true)]
    [string]$ReleasedPrerelease, # 'Released' or 'Prerelease'
    [Parameter(Mandatory = $true)]
    [string]$PackageType, # 'NuGet', 'PSResourceGet', or 'ChocolateyGet'
    [Parameter(Mandatory = $true)]
    [string]$ProductionQualityAssurance, # 'Production' or 'QualityAssurance'
    [Parameter(Mandatory = $true)]
    [string]$PullPush # 'Pull' or 'Push'
  )
  # ToDo: Put the language-specific short form of a word into a ConfigRootKey variable, so that it can be localized
  $ShortExternalInternal = ''
  $ShortReleasedPrerelease = ''
  $ShortPackageType = ''
  $ShortProductionQualityAssurance = ''
  $ShortPullPush = ''

  switch ($ExternalInternal) {
    'External' { $ShortExternalInternal = 'Ext' }
    'Internal' { $ShortExternalInternal = 'Int' }
    # ToDo: use a $message and log it as well as throwing it
    default {
      $message = "Unknown ExternalInternal value: $ExternalInternal"
      PSF_WriteError -Message $message -TargetObject $PSCmdlet.MyInvocation.MyCommand -ErrorId 'UnknownExternalInternalValue' -ErrorCategory InvalidArgument
      throw $message
    }
  }
  switch ($ReleasedPrerelease) {
    'Released' { $ShortReleasedPrerelease = 'Rel' }
    'Prerelease' { $ShortReleasedPrerelease = 'Pre' }
    default {
      $message = "Unknown ReleasedPrerelease value: $ReleasedPrerelease"
      PSF_WriteError -Message $message -TargetObject $PSCmdlet.MyInvocation.MyCommand -ErrorId 'UnknownReleasedPrereleaseValue' -ErrorCategory InvalidArgument
      throw $message
    }
  }
  switch ($PackageType) {
    'NuGet' { $ShortPackageType = 'Nug' }
    'PSResourceGet' { $ShortPackageType = 'PSR' }
    'ChocolateyGet' { $ShortPackageType = 'Cho' }
    default {
      $message = "Unknown PackageType value: $PackageType"
      PSF_WriteError -Message $message -TargetObject $PSCmdlet.MyInvocation.MyCommand -ErrorId 'UnknownPackageTypeValue' -ErrorCategory InvalidArgument
      throw $message
    }
  }
  switch ($ProductionQualityAssurance) {
    'Production' { $ShortProductionQualityAssurance = 'Prod' }
    'QualityAssurance' { $ShortProductionQualityAssurance = 'QA' }
    default {
      $message = "Unknown ProductionQualityAssurance value: $ProductionQualityAssurance"
      PSF_WriteError -Message $message -TargetObject $PSCmdlet.MyInvocation.MyCommand -ErrorId 'UnknownProductionQualityAssuranceValue' -ErrorCategory InvalidArgument
      throw $message
    }
  }
  switch ($PullPush) {
    'Pull' { $ShortPullPush = 'Pull' }
    'Push' { $ShortPullPush = 'Push' }
    default {
      $message = "Unknown PullPush value: $PullPush"
      PSF_WriteError -Message $message -TargetObject $PSCmdlet.MyInvocation.MyCommand -ErrorId 'UnknownPullPushValue' -ErrorCategory InvalidArgument
      throw $message
    }
  }
  # Return the short name for the package repository feed
  "$ShortExternalInternal$ShortReleasedPrerelease$ShortPackageType$ShortProductionQualityAssurance$ShortPullPush"
}

$configRootKeysFragmentPath = "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\Profiles\global_ConfigRootKeysFragment.PackageRepositories.ps1"
$hostSettingsFragmentPath = "C:\Dropbox\whertzing\GitHub\ATAP.IAC\Windows\HostSettingsFragment.PackageRepositories.ps1"
$base = 50000
$cnt = 1

$results = [PSCustomObject]@{HostSettings = [System.Collections.ArrayList]::new(); ConfigRootKeys = [System.Collections.ArrayList]::new(); }

# Output the lines that set $ConfigRootKeys entries for package repository feeds to $results object

$results.ConfigRootKeys += "###################################################"
$results.ConfigRootKeys += "## PackageRepositoryFeed keys. segment of global_ConfigRootKeys.ps1"
$results.ConfigRootKeys += "## External/Internal, Released/Prerelease, NuGet/PSResourceGet/ChocolateyGet, Production/QualityAssurance, Pull/Push"
# Loop through all combinations of External/Internal, Released/Prerelease, NuGet/PSResourceGet/ChocolateyGet, Production/QualityAssurance, Pull/Push
('External', 'Internal') | ForEach-Object { $EI = $_
  ('Released', 'Prerelease') | ForEach-Object { $V = $_
('NuGet', 'PSResourceGet', 'ChocolateyGet') | ForEach-Object { $P = $_
      ('Production' , 'QualityAssurance') | ForEach-Object { $PQ = $_
      ('Pull' , 'Push') | ForEach-Object { $PP = $_
          $crk = 'PackageRepository' + $EI + $V + $P + $PQ + $PP

          $block1 = @"
        # $EI $V$P $PQ $PP
`$global:configRootKeys.Add('${crk}FeedConfigRootKey', '${crk}Feed')
`$global:configRootKeys.Add('${crk}UriSchemeConfigRootKey', '${crk}UriProtocol')
`$global:configRootKeys.Add('${crk}UriHostConfigRootKey', '${crk}UriServer')
`$global:configRootKeys.Add('${crk}UriPortConfigRootKey', '${crk}UriPort')
`$global:configRootKeys.Add('${crk}UriPathConfigRootKey', '${crk}UriPath')
`$global:configRootKeys.Add('${crk}UriQueryStringConfigRootKey', '${crk}UriQueryString')
`$global:configRootKeys.Add('${crk}UriConfigRootKey', '${crk}Uri')
`$global:configRootKeys.Add('${crk}FeedShortNameConfigRootKey', '${crk}FeedShortName')
`$global:configRootKeys.Add('${crk}FeedApiKeyNameConfigRootKey', '${crk}FeedApiKeyName')
"@
          $results.ConfigRootKeys += $block1
        } } } } }
$results.ConfigRootKeys += "###################################################"
$results.ConfigRootKeys | set-content -path $configRootKeysFragmentPath


# Output the lines that set $HostsType1 entries for package repository feeds to $results object
$results.HostSettings += "###################################################"
$results.HostSettings += "## PackageRepositoryFeed population. A fragment of HostSettings.ps1"
$results.HostSettings += "## External/Internal, Released/Prerelease, NuGet/PSResourceGet/ChocolateyGet, Production/QualityAssurance, Pull/Push"
$results.HostSettings += "##  All External feeds are nulled in this script, so that they can be set up later"


$results.HostSettings += "# ToDo: figure out how to modify the $Path and $PSModulePath, as well as this structure to only include the repositories appropriate for the ""environment"" "
$results.HostSettings += "# ToDo: add code throughout that recognizes a ""cluster"" of containers that have the same root path for shared filesystems paths, typically a group of machines in a geolocation having fast access to this network resource, for example a cluster of machines used in a CI/CD pipeline"
$results.HostSettings += "# Repository locations and their component parts for internal and external PackageRepositories"
$results.HostSettings += "# Add the PackageRepositories collection"
$results.HostSettings += "`$HostsType1.Add(`$global:configRootKeys['PackageRepositoriesCollectionConfigRootKey'] , @{})"


# Loop through all combinations of External/Internal, Released/Prerelease, NuGet/PSResourceGet/ChocolateyGet, Production/QualityAssurance, Pull/Push
('External', 'Internal') | ForEach-Object { $EI = $_
  ('Released', 'Prerelease') | ForEach-Object { $V = $_
  ('NuGet', 'PSResourceGet', 'ChocolateyGet') | ForEach-Object { $P = $_
    ('Production' , 'QualityAssurance') | ForEach-Object { $PQ = $_
      ('Pull' , 'Push') | ForEach-Object { $PP = $_
          $crk = 'PackageRepository' + $EI + $V + $P + $PQ + $PP

          $shortFeedName = $(Get-PackageRepositoryFeedShortName $EI  $V  $P  $PQ  $PP) + 'Feed'
          if ( $shortFeedName.count -gt 45) {
            $message = "The short feed name '$shortFeedName' is too long. It must be 45 characters or less."
            PSF_WriteError -Message $message -TargetObject $PSCmdlet.MyInvocation.MyCommand -ErrorId 'ShortFeedNameTooLong' -ErrorCategory InvalidArgument
            throw $message
          }
          $ApiKeyName = 'ApiKey' + $shortFeedName
          $port = $base # + $cnt

          $block1 = @"
# $EI  $V  $PQ  $PP
`$HostsType1.Add(`$global:configRootKeys['${crk}UriSchemeConfigRootKey'] , $($EI -eq 'External' ? '''''' : '''http'''))
`$HostsType1.Add(`$global:configRootKeys['${crk}UriHostConfigRootKey'] , $($EI -eq 'External' ? '''''' : '''utat022''' ))
`$HostsType1.Add(`$global:configRootKeys['${crk}UriPortConfigRootKey'] , $($EI -eq 'External' ? 0 : $port))
`$HostsType1.Add(`$global:configRootKeys['${crk}UriPathConfigRootKey'] , $($EI -eq 'External' ? '''''' : "'/$V/$P/'"))
`$HostsType1.Add(`$global:configRootKeys['${crk}UriQueryStringConfigRootKey'] , $($EI -eq 'External' ? '''''' : ''''''))
"@

          $block2a = @"
`$HostsType1.Add(`$global:configRootKeys['${crk}UriConfigRootKey'], [UriBuilder]::new(
  `$(`$HostsType1[`$global:configRootKeys['${crk}UriSchemeConfigRootKey']]),
  `$(`$HostsType1[`$global:configRootKeys['${crk}UriHostConfigRootKey']]),
  `$(`$HostsType1[`$global:configRootKeys['${crk}UriPortConfigRootKey']]),
  `$(`$HostsType1[`$global:configRootKeys['${crk}UriPathConfigRootKey']]),
  `$(`$HostsType1[`$global:configRootKeys['${crk}UriQueryStringConfigRootKey']])
))
"@
          $block2b = @"
 `$HostsType1.Add(`$global:configRootKeys['${crk}UriConfigRootKey'], '''''')
"@

          $block3 = @"
`$HostsType1.Add(`$global:configRootKeys['${crk}FeedShortNameConfigRootKey'] , '$shortFeedName')
`$HostsType1.Add(`$global:configRootKeys['${crk}FeedApiKeyNameConfigRootKey'] , '$ApiKeyName')
`$HostsType1[`$global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']].add(
  `$global:configRootKeys['${crk}FeedConfigRootKey'], @{
     ShortName  = `$HostsType1[`$global:configRootKeys['${crk}FeedShortNameConfigRootKey']];
     ApiKeyName = `$HostsType1[`$global:configRootKeys['${crk}FeedApiKeyNameConfigRootKey']];
     Uri =   `$HostsType1[`$global:configRootKeys['${crk}UriConfigRootKey']];
   })

"@
          $results.HostSettings += $block1
          if ($EI -eq 'Internal') { $results.HostSettings += $block2a } else { $results.HostSettings += $block2b }
          $results.HostSettings += $block3
          if ($EI -ne 'External') { $cnt++ }
        }
      }
    }
  }
}
$results.HostSettings += "###################################################"
$results.HostSettings | set-content -path $hostSettingsFragmentPath

