# Define ansible host_vars
param (
  [string] $ymlGenericTemplate
  , [string] $directoryPath
)

function Contents {
  param(
    [string] $hostname
  )
  # $global:settings that are defined per-host are stored in $defaultPerMachineSettings which are set in the machine or user profile
  $lines = @()
  foreach ($key in $(Sort-Object $($defaultPerMachineSettings[$hostname].keys))) {
    $escapedvalue = $($($defaultPerMachineSettings[$hostname])[$key]) -replace "'", "''"
    $lines += "$key : '$escapedvalue'"
  }
  return $lines
}

# The set of hosts is defined in the $global:settings[$global:configRootKeys['AnsibleHostNamesConfigRootKey']]
$ansibleHostNames = $global:settings[$global:configRootKeys['AnsibleHostNamesConfigRootKey']]
for ($ansibleHostNamesIndex = 0; $ansibleHostNamesIndex -lt $ansibleHostNames.count; $ansibleHostNamesIndex++) {
  # create a host_vars file for each host
  $hostname = $ansibleHostNames[$ansibleHostNamesIndex]
  $ymlContents= $ymlGenericTemplate -replace '\{2}', $hostname
  # Use the Linux newline character
  $ymlContents += $(Contents -hostname $hostname) -join "`r"
  Set-Content -Path $(Join-Path $directoryPath "$hostname.yml") -Value $ymlContents
}



