# Tool to generate the HostSettings entries for the multitude of PackageRepositories values

$p1s = ('External' , 'Internal' )
$p2s = ('Released' , 'Prerelease')
$p3s = ( 'NuGet' , 'PowershellGet' , 'ChocolateyGet')
$p4s = ('Production' , 'QualityAssurance')
$p5s = ('Pull' , 'Push')
$p6s = ('Protocol', 'Server', 'Port', 'Path', 'QueryString')

# # Use ports in the private port range (49152-65535)
# # https://en.wikipedia.org/wiki/Private_port
# #Initialize the port number to 50000
# $PortNumber = 50000
# $p1s | ForEach-Object {
#   $p1 = $_;
#   $p2s  | ForEach-Object { $p2 = $_;
#     $p3s | ForEach-Object { $p3 = $_;
#       $p4s | ForEach-Object { $p4 = $_;
#         $p5s | ForEach-Object { $p5 = $_;
#           $bk = @"
# PackageRepository${p1}${p2}${p3}${p4}Package${p5}UriConfigRootKey
# "@
#           $PortNumber = $PortNumber + 1 # Increment the port number each time a new push or pull API endpoint is created
#           $p6s | ForEach-Object { $p6 = $_;
#             $val = switch ($p6) {
#               Protocol { 'http' }
#               Server { 'localhost' }
#               Port { "$PortNumber" }
#               Path { '/' }
#               QueryString { '' }
#             }

#             $ck = @"
# `$HostsType1.Add(`$global:configRootKeys['PackageRepository${p1}${p2}${p3}${p4}Package${p5}Uri${p6}ConfigRootKey'] , '$val')
# "@;
#             $ck
#           }
#           # Build the inner lines
#           $uriLines = foreach ($p6 in $p6s) {
#             "  `$(`$HostsType1[`$global:configRootKeys['PackageRepository${p1}${p2}${p3}${p4}Package${p5}Uri${p6}ConfigRootKey']])"
#           }
#           $val = @"
# `$HostsType1.Add(`$global:configRootKeys['PackageRepository${p1}${p2}${p3}${p4}Package${p5}UriConfigRootKey'],[UriBuilder]::new(
# $($uriLines -join ",`n")
# ))
# "@
#           $val
#         }
#       }
#     }
#   }
# }

# Generate the lines that will populate the object
$key = $global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']

# end result should look like this:
# $HostsType1.Add("'$global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']'" , @{})
#  ToDo: figure out how to emit the prior string. For now, it is inside HostSettings correctly
#"$HostsType1.Add($global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']  , @{})"
$lookupUriLines = @()
$p1s | ForEach-Object {
  $p1 = $_;
  $p2s  | ForEach-Object { $p2 = $_;
    $p3s | ForEach-Object { $p3 = $_;
      $p4s | ForEach-Object { $p4 = $_;
        $p5s | ForEach-Object { $p5 = $_;
          $key = '$global:configRootKeys[''PackageRepositoriesCollectionConfigRootKey'']'
          $uriConfigRootKey = "PackageRepository${p1}${p2}${p3}${p4}Package${p5}UriConfigRootKey"
          $uriRootKey = $global:configRootKeys[$uriConfigRootKey]
          $val = $HostsType1[$uriRootKey]
          $lookupUriLines += "`$HostsType1[$key].add('$uriRootKey' , '$val')"
        } } } } }
" Here is the lines to add that load the collection with all the values"
$lookupUriLines
