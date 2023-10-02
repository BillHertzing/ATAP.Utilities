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

[System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

$varsDirectory = 'vars'
$varsFilename = 'vars.yml'
$encryptedVarsFilename = 'vault'

function ContentsVars {
  param(
    [parameter(mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $name
  )
  $settingsHash = Get-HostSettings $name
  foreach ($key in $($settingsHash.keys | Sort-Object)) {
    $escapedvalue = $settingsHash[$key] -replace "'", "''"
    [void]$sb.Append("$key : '$escapedvalue'")
    [void]$sb.Append("`n")
  }
}

function ContentsEncryptedVars {
  param(
    [parameter(mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $name
  )
  # ToDo: get from the Poweshell Secrets vault (today that is  keepass)
  $encryptedSettingsHash = Get-HostSettings $name
  [void]$sb.Append("user : whertzing")
  [void]$sb.Append("`n")
  [void]$sb.Append('password : Su$$ess')
  [void]$sb.Append("`n")


  # foreach ($key in $($encryptedSettingsHash.keys | Sort-Object)) {
  #   $escapedvalue = $encryptedSettingsHash[$key] -replace "'", "''"
  #   [void]$sb.Append("$key : '$escapedvalue'")
  #   [void]$sb.Append("`n")
  # }
}

# Host settings are dot-sourced from the $PSHome/HostSettings.ps1 file, that happens in the calling function
for ($index = 0; $index -lt $namesList.count; $index++) {
  $name = $namesList[$index]
  # create a directory for each host
  $hostSpecificDirectory = $(Join-Path $directoryPath $name)
  New-Item -ItemType Directory -Path $hostSpecificDirectory -ErrorAction SilentlyContinue >$null
  # create a vars directory for each host
  $hostSpecificVarsDirectory = $(Join-Path $hostSpecificDirectory $varsDirectory)
  New-Item -ItemType Directory -Path $hostSpecificVarsDirectory -ErrorAction SilentlyContinue >$null
  # create an unencrypted vars file for each host
  [void]$sb.Clear()
  [void]$sb.Append($($ymlGenericTemplate -replace '\{2}', $name))
  [void]$sb.Append("`n")
  ContentsVars $name
  Set-Content -Path $(Join-Path $hostSpecificVarsDirectory $varsFilename) -Value $($($sb.ToString()) -replace '`r`n','`r')
  # create an encrypted vars file for each host
  [void]$sb.Clear()
  [void]$sb.Append($($ymlGenericTemplate -replace '\{2}', $name))
  [void]$sb.Append("`n")
  ContentsEncryptedVars $name
  Set-Content -Path $(Join-Path $hostSpecificVarsDirectory $encryptedVarsFilename) -Value $($($sb.ToString()) -replace '`r`n','`r')
}
