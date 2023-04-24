# Define ansible vars hosts
param (		[parameter(mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string] $ymlGenericTemplate
  , [parameter(mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string] $directoryPath
  , [parameter(mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [array] $namesList
)

[System.Text.StringBuilder]$sbVars = [System.Text.StringBuilder]::new()

function ContentsVars {
  param(
    [parameter(mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $name
  )
  $settingsHash = Get-HostSettings $name
  foreach ($key in $($settingsHash.keys | Sort-Object)) {
    $escapedvalue = $settingsHash[$key] -replace "'", "''"
    [void]$sbVars.AppendLine("$key : '$escapedvalue'")
  }
}

# Host settings are dot-sourced from the $PSHome/HostSettings.ps1 file, that happens in the calling function
for ($index = 0; $index -lt $namesList.count; $index++) {
  # create a vars file for each host
  $name = $namesList[$index]
  [void]$sbVars.Clear()
  [void]$sbVars.AppendLine($($($ymlGenericTemplate -replace '\{1}', 'Host_vars' ) -replace '\{2}', $name))
  ContentsVars $name
  Set-Content -Path $(Join-Path $directoryPath "$name.yml") -Value $sbVars.ToString()
}

#$ymlContents = $ymlGenericTemplate -replace '\{2}', $name
# Use the Linux newline character
#$ymlContents += $($(Contents -name $name) -split "`r`n") -join "`n"

