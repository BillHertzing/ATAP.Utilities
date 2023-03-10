
param(
    [string] $ymlGenericTemplate
  , [string] $directoryPath
  , [string] $dSCConfigurationName
  , [string] $dSCConfigurationFilename
  , [string] $dSCConfigurationSourcePath
  , [string] $dSCConfigurationAnsibleSourcePath
  , [string] $dSCConfigurationTargetDestinationDirectory
)

function Contents {

return @"
- name: install package
  win_chocolatey:
    name: 'cpu-z'
    state: present
  register: install

- name: show the results of the install
  debug:
    var: install

"@
}

  $ymlContents= $ymlGenericTemplate -replace '\{2}', $dSCConfigurationName
  $ymlContents += Contents
  Set-Content -Path $(Join-Path $directoryPath "main.yml") -Value $ymlContents


