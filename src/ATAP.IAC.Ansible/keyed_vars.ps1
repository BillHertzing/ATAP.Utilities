# Define ansible vars for groups or hosts
param (
  [string] $ymlGenericTemplate
  , [string] $directoryPath
  , [hashtable] $settingsHash
  , [array] $namesList
)

function Contents {
  param(
    [string] $name
  )
  # The settingsHash should have an entry
  $lines = @()
  foreach ($key in $($($settingsHash[$name]).keys | Sort-Object)) {
    $escapedvalue = $($($settingsHash[$name])[$key]) -replace "'", "''"
    $lines += "$key : '$escapedvalue'"
  }
  return $lines
}

# $global:settings that are defined per-host or per-group are stored in the $settingsHash
for ($index = 0; $index -lt $namesList.count; $index++) {
  # create a host_vars file for each host
  $name = $namesList[$index]
  $ymlContents= $ymlGenericTemplate -replace '\{2}', $name
  # Use the Linux newline character
  $ymlContents += $(Contents -name $name) -join "`r"
  Set-Content -Path $(Join-Path $directoryPath "$name.yml") -Value $ymlContents
}
