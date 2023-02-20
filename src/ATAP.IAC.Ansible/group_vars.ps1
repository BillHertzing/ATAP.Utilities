# Define ansible vars for groups or hosts
param (
  [string] $ymlGenericTemplate
  , [string] $directoryPath
  , [hashtable] $settingHash
  , [array] $namesList
)

function Contents {
  param(
    [string] $name
  )
  # $global:settings that are defined per-host are stored in $settingHash
  $lines = @()
  foreach ($key in $($($settingHash[$name]).keys | Sort-Object)) {
    $escapedvalue = $($($settingHash[$name])[$key]) -replace "'", "''"
    $lines += "$key : '$escapedvalue'"
  }
  return $lines
}

# $global:settings that are defined per-host or per-group are stored in the $settingHash
for ($ansibleNamesIndex = 0; $ansibleNamesIndex -lt $namesList.count; $ansibleNamesIndex++) {
  # create a host_vars file for each host
  $name = $namesList[$ansibleNamesIndex]
  $ymlContents= $ymlGenericTemplate -replace '\{2}', $name
  # Use the Linux newline character
  $ymlContents += $(Contents -name $name) -join "`r"
  Set-Content -Path $(Join-Path $directoryPath "$name.yml") -Value $ymlContents
}
