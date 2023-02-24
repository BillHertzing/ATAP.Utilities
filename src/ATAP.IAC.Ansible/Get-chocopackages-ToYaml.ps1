
param(
  [string] $outputpath
  , [string] $ymlGenericTemplate
  # ToDo: pass a compiled Regex
  , $excludeRegexPattern
  , [string]  $ChocolateyToolRegexPattern
  , [object] $packageAssociative
)


function Contents {
  param(
    [string] $name
    , [string] $version
  )
  return @"
- name: Chocolatey Package for $name
    package: $name
    version: $version
    parameters:

"@
}
# read the existing list of chocolatey packages
$packageAssociative =  @{
all = @()
}


$lines = choco search --lo


$ymlContents = $ymlGenericTemplate
$chocolateyYMLContents = $ymlGenericTemplate
$processedNames = @()
$toplevelGroups =  $packageAssociative.Keys




# split each line into name and version,
for ($index = 0; $index -lt $lines.count; $index++) {
  $parts = $lines[$index].split(' ')
  $name = $parts[0]
  $version = $parts[1]
  # filter the excluded patterns
  # ToDo: use a compiled Regex
  if ($name -notmatch $excludeRegexPattern) {
    $packageTask = Contents $name $version
    $ymlContents += $packageTask 
    if ($name -match $ChocolateyToolRegexPattern) {
      $chocolateyYMLContents  += $packageTask 
  }
}

# Associate the packages with subgroups (children) of the Windows group

Set-Content -Path $outputpath -Value $ymlContents
