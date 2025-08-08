# ToDo: Move this function over to the Powershell.IAC module
# ToDo: Remove this when packaging works
#  if (-not (Get-Command -Name 'ConvertTo-ProGetFeedNameAlternateForm' -CommandType Function -ErrorAction SilentlyContinue)) {
. "$PSScriptRoot\..\private\ConvertTo-ProGetFeedNameAlternateForm.ps1"
# }


$configRootKeysFragmentPath = "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\Profiles\global_ConfigRootKeysFragment.PackageRepositories.ps1"
$hostSettingsFragmentPath = "C:\Dropbox\whertzing\GitHub\ATAP.IAC\Windows\HostSettingsFragment.PackageRepositories.ps1"
$base = 50000
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
          $LongFeedName = 'PackageRepository' + $EI + $V + $P + $PQ + $PP

          $block1 = @"
        # $EI $V$P $PQ $PP
`$global:configRootKeys.Add('${LongFeedName}FeedConfigRootKey', '${LongFeedName}Feed')
`$global:configRootKeys.Add('${LongFeedName}UriSchemeConfigRootKey', '${LongFeedName}UriProtocol')
`$global:configRootKeys.Add('${LongFeedName}UriHostConfigRootKey', '${LongFeedName}UriServer')
`$global:configRootKeys.Add('${LongFeedName}UriPortConfigRootKey', '${LongFeedName}UriPort')
`$global:configRootKeys.Add('${LongFeedName}UriPathConfigRootKey', '${LongFeedName}UriPath')
`$global:configRootKeys.Add('${LongFeedName}UriQueryStringConfigRootKey', '${LongFeedName}UriQueryString')
`$global:configRootKeys.Add('${LongFeedName}UriConfigRootKey', '${LongFeedName}Uri')
`$global:configRootKeys.Add('${LongFeedName}FeedLongNameConfigRootKey', '${LongFeedName}FeedLongName')
`$global:configRootKeys.Add('${LongFeedName}FeedShortNameConfigRootKey', '${LongFeedName}FeedShortName')
`$global:configRootKeys.Add('${LongFeedName}FeedApiKeyNameConfigRootKey', '${LongFeedName}FeedApiKeyName')
"@
          $results.ConfigRootKeys += $block1
        } } } } }
$results.ConfigRootKeys += "###################################################"
$results.ConfigRootKeys | set-content -path $configRootKeysFragmentPath


# Output the lines that set $HostsType1 entries for package repository feeds to $results object
$results.HostSettings += "###################################################"
$results.HostSettings += "## PackageRepositoryFeed population. A fragment of HostSettings.ps1"
$results.HostSettings += "## External/Internal, Released/Prerelease, NuGet/PSResourceGet/ChocolateyGet, Production/QualityAssurance, Pull/Push"
$results.HostSettings += "## External Released NuGet/PSResourceGet/ChocolateyGet Production Push Connectors for ProGet implementation are defined here as well"


$results.HostSettings += "# ToDo: figure out how to modify the $Path and $PSModulePath, as well as this structure, to only include the repositories appropriate for the ""environment"" "
$results.HostSettings += "# Repository locations and their component parts for internal and external PackageRepositories"
$results.HostSettings += "# Add the PackageRepositories collection"
$results.HostSettings += "`$HostsType1.Add(`$global:configRootKeys['PackageRepositoriesCollectionConfigRootKey'] , @{})"


# Loop through all combinations of External/Internal, Released/Prerelease, NuGet/PSResourceGet/ChocolateyGet, Production/QualityAssurance, Pull/Push
('External', 'Internal') | ForEach-Object { $EI = $_
  ('Released', 'Prerelease') | ForEach-Object { $V = $_
    ('NuGet', 'PSResourceGet', 'ChocolateyGet') | ForEach-Object { $P = $_
      ('Production' , 'QualityAssurance') | ForEach-Object { $PQ = $_
        ('Pull' , 'Push') | ForEach-Object { $PP = $_
          $LongFeedName = 'PackageRepository' + $EI + $V + $P + $PQ + $PP

          $shortFeedName = $(ConvertTo-ProGetFeedNameAlternateForm -ExternalInternal $EI -ReleasedPrerelease $V -PackageType $P -ProductionQualityAssurance $PQ -PullPush $PP) + 'Feed'
          if ( $shortFeedName.count -gt 45) {
            $message = "The short feed name '$shortFeedName' is too long. It must be 45 characters or less."
            PSF_WriteError -Message $message -TargetObject $PSCmdlet.MyInvocation.MyCommand -ErrorId 'ShortFeedNameTooLong' -ErrorCategory InvalidArgument
            throw $message
          }
          $ApiKeyName = 'ApiKey' + $shortFeedName
          $port = $base

          $block1 = @"
# $EI  $V  $PQ  $PP
`$HostsType1.Add(`$global:configRootKeys['${LongFeedName}UriSchemeConfigRootKey'] , 'http')
`$HostsType1.Add(`$global:configRootKeys['${LongFeedName}UriHostConfigRootKey'] , 'utat022')
`$HostsType1.Add(`$global:configRootKeys['${LongFeedName}UriPortConfigRootKey'] , $port)
`$HostsType1.Add(`$global:configRootKeys['${LongFeedName}UriPathConfigRootKey'] , 'nuget/$shortFeedName/')
`$HostsType1.Add(`$global:configRootKeys['${LongFeedName}UriQueryStringConfigRootKey'] , '')
"@

          $block2a = @"
`$HostsType1.Add(`$global:configRootKeys['${LongFeedName}UriConfigRootKey'], ([UriBuilder]::new(
  `$(`$HostsType1[`$global:configRootKeys['${LongFeedName}UriSchemeConfigRootKey']]),
  `$(`$HostsType1[`$global:configRootKeys['${LongFeedName}UriHostConfigRootKey']]),
  `$(`$HostsType1[`$global:configRootKeys['${LongFeedName}UriPortConfigRootKey']]),
  `$(`$HostsType1[`$global:configRootKeys['${LongFeedName}UriPathConfigRootKey']]),
  `$(`$HostsType1[`$global:configRootKeys['${LongFeedName}UriQueryStringConfigRootKey']])
)).Uri)
"@

          $block2b = @"
`$HostsType1.Add(`$global:configRootKeys['${LongFeedName}UriConfigRootKey'], '''''')
"@

          $block3 = @"
`$HostsType1.Add(`$global:configRootKeys['${LongFeedName}FeedLongNameConfigRootKey'] , '$longFeedName')
`$HostsType1.Add(`$global:configRootKeys['${LongFeedName}FeedShortNameConfigRootKey'] , '$shortFeedName')
`$HostsType1.Add(`$global:configRootKeys['${LongFeedName}FeedApiKeyNameConfigRootKey'] , '$ApiKeyName')
`$HostsType1[`$global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']].add(
  `$global:configRootKeys['${LongFeedName}FeedConfigRootKey'], @{
    LongName  = `$HostsType1[`$global:configRootKeys['${LongFeedName}FeedLongNameConfigRootKey']];
    ShortName  = `$HostsType1[`$global:configRootKeys['${LongFeedName}FeedShortNameConfigRootKey']];
    ApiKeyName = `$HostsType1[`$global:configRootKeys['${LongFeedName}FeedApiKeyNameConfigRootKey']];
    Uri =   `$HostsType1[`$global:configRootKeys['${LongFeedName}UriConfigRootKey']].URI;
    Connectors =  $(
      ($EI -eq 'Internal') -or ($PP -eq 'Pull') ? '@()' : $(switch ($P) {
        # These are for 'Released' ($V) feeds, ToDo is to return the correct URI for the feed Released and separately the Prereleased feed's source
        # ToDo: external PreReleased feeds are often specific to the package being requested, so eventually
        # ToDo: we will feed this helper function a list of packages and their Prerelease URI feeds
        # In the near term we won't put in any logic that looks at $V, and just use the Released URI
      'ChocolateyGet' { '(,@{ name = "ChocolateyCommunity"; feedType = "nuget"; url = "https://chocolatey.org/api/v2/"; enabled = $true})'}
      'NuGet' { '(,@{ name = "nuget.org"; feedType = "nuget"; url = "https://api.nuget.org/v3/index.json"; enabled = $true})' }
      'PSResourceGet' { '(,@{ name = "PowershellGallery"; feedType = "nuget"; url = "https://www.powershellgallery.com/api/v2/"; enabled = $true})' }
        Default {
          $errorMessage = "Unsupported package type '$P' for external feeds."
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'New-HostSettingsForPackageRepositoryFeeds', 'Trace', 'Error'
          throw $errorMessage
        }
      })
      )

  })
"@


          $results.HostSettings += $block1
          $results.HostSettings += $block2a
          # if ($EI -eq 'Internal') {
          #   $results.HostSettings += $block2a
          # }
          # else {
          #   $results.HostSettings += $block2b
          # }

          $results.HostSettings += $block3
        }
      }
    }
  }
}
$results.HostSettings += "###################################################"
$results.HostSettings | set-content -path $hostSettingsFragmentPath

