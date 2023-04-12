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
  [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
  foreach ($key in $($($settingsHash[$name]).keys | Sort-Object)) {
    $escapedvalue = $($($settingsHash[$name])[$key]) -replace "'", "''"
    [void]$sb.AppendLine("$key : '$escapedvalue'")
  }
  $sb.ToString()
}

# $global:settings that are defined per-host or per-group are stored in the $settingsHash
for ($index = 0; $index -lt $namesList.count; $index++) {
  # create a host_vars file for each host
  $name = $namesList[$index]
  $ymlContents= $ymlGenericTemplate -replace '\{2}', $name
  # Use the Linux newline character
  $ymlContents += $($(Contents -name $name) -split "`r`n") -join "`n"
  Set-Content -Path $(Join-Path $directoryPath "$name.yml") -Value $ymlContents
}
